"""Synthesizes every sound effect and music loop into audio/. Stdlib only: `python tools/gen_audio.py [name ...]`.

Nothing here is a raw square wave. Impacts are modal (a handful of decaying resonances, like a struck
piece of wood or plastic), tuned sounds use marimba / vibraphone / bell / electric-piano voices, brass
is a filtered saw, and everything gets a touch of room reverb. Each sound is a function returning a
list of float samples; tweak the numbers, rerun, and Godot reimports the WAVs.
"""
import math
import os
import random
import struct
import sys
import wave
from functools import lru_cache

SR = 44100
TAU = math.tau
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")


# ---------------------------------------------------------------------------------------------
# DSP building blocks
# ---------------------------------------------------------------------------------------------

def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def gain(s, g):
    return [v * g for v in s]


def fade(s, ms=4.0):
    """Short fade at both ends so nothing clicks."""
    s = list(s)
    n = min(len(s) // 2, int(ms / 1000.0 * SR))
    for i in range(n):
        k = i / n
        s[i] *= k
        s[-1 - i] *= k
    return s


def mix(*parts):
    """Overlay sounds; each part is a list or (offset_seconds, list)."""
    placed = [(0.0, p) if isinstance(p, list) else p for p in parts]
    n = max(int(o * SR) + len(s) for o, s in placed)
    out = [0.0] * n
    for o, s in placed:
        base = int(o * SR)
        for i, v in enumerate(s):
            out[base + i] += v
    return out


def modal(parts, dur, vol=1.0):
    """Sum of decaying resonances [(freq, amp, tau_seconds)]. Uses a two-pole resonator ringing from an impulse."""
    n = int(dur * SR)
    out = [0.0] * n
    for f, a, tau in parts:
        if f >= SR * 0.45 or tau <= 0.0:
            continue
        w = TAU * f / SR
        r = math.exp(-1.0 / (tau * SR))
        c1 = 2.0 * r * math.cos(w)
        c2 = r * r
        y1 = r * math.sin(w)
        y2 = 0.0
        g = a * vol
        out[1] += g * y1 if n > 1 else 0.0
        for i in range(2, n):
            y = c1 * y1 - c2 * y2
            out[i] += g * y
            y2 = y1
            y1 = y
    return out


def noise(dur, tau=None, vol=1.0):
    n = int(dur * SR)
    if tau is None:
        return [random.uniform(-1.0, 1.0) * vol for _ in range(n)]
    return [random.uniform(-1.0, 1.0) * vol * math.exp(-i / SR / tau) for i in range(n)]


def sweep(f0, f1, dur, tau=None, vol=1.0, vib=0.0, vib_rate=5.5):
    """Sine gliding exponentially f0 -> f1, optionally with a decay envelope and vibrato."""
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        k = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** k
        if vib:
            f *= 1.0 + vib * math.sin(TAU * vib_rate * i / SR)
        phase += f / SR
        env = math.exp(-i / SR / tau) if tau else 1.0
        out.append(math.sin(TAU * phase) * env * vol)
    return out


def filt(s, kind, f, q=0.707, f_end=None):
    """RBJ biquad (lp / hp / bp). The cutoff glides exponentially to f_end if given."""
    out = []
    n = len(s)
    x1 = x2 = y1 = y2 = 0.0
    b0 = b1 = b2 = a1 = a2 = 0.0
    f_end = f if f_end is None else f_end
    for i in range(n):
        if i % 16 == 0:
            ff = f * (f_end / f) ** (i / max(1, n - 1))
            w0 = TAU * min(ff, SR * 0.45) / SR
            c, sn = math.cos(w0), math.sin(w0)
            alpha = sn / (2.0 * q)
            if kind == "lp":
                b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
            elif kind == "hp":
                b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
            else:
                b0, b1, b2 = alpha, 0.0, -alpha
            a0 = 1 + alpha
            b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, (-2 * c) / a0, (1 - alpha) / a0
        x = s[i]
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def shape(s, attack, release, curve=1.0):
    """Amplitude envelope: linear attack, then a release over the final `release` seconds."""
    n = len(s)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    out = list(s)
    for i in range(n):
        g = min(1.0, i / a) * min(1.0, ((n - i) / r)) ** curve
        out[i] *= g
    return out


def saturate(s, drive=1.0):
    return [math.tanh(v * drive) for v in s]


def reverb(s, wet=0.2, room=0.8, damp=0.35, tail=0.6):
    """Small Schroeder room: four damped combs into two allpasses. Returns dry + wet, with a tail appended."""
    s = list(s) + [0.0] * int(tail * SR)
    wetbuf = [0.0] * len(s)
    fb = 0.7 + room * 0.25
    for d in (1116, 1188, 1277, 1356):
        buf = [0.0] * d
        idx = 0
        lp = 0.0
        for i, x in enumerate(s):
            y = buf[idx]
            lp = y * (1.0 - damp) + lp * damp
            buf[idx] = x + lp * fb
            idx += 1
            if idx == d:
                idx = 0
            wetbuf[i] += y * 0.25
    for d in (556, 341):
        buf = [0.0] * d
        idx = 0
        for i, x in enumerate(wetbuf):
            b = buf[idx]
            y = -x + b
            buf[idx] = x + b * 0.5
            wetbuf[i] = y
            idx += 1
            if idx == d:
                idx = 0
    return [s[i] + wetbuf[i] * wet * 3.0 for i in range(len(s))]


def normalize(s, peak):
    m = max(1e-9, max(abs(v) for v in s))
    return [v * peak / m for v in s]


def save(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in s))


# ---------------------------------------------------------------------------------------------
# Instruments (tuned)
# ---------------------------------------------------------------------------------------------

@lru_cache(maxsize=None)
def marimba(midi, dur=0.35):
    f = hz(midi)
    s = modal([(f, 1.0, 0.28), (f * 3.95, 0.35, 0.06), (f * 9.2, 0.12, 0.02)], dur)
    tick = filt(noise(0.012, 0.002), "bp", f * 4, 1.0)
    return fade(mix(s, gain(tick, 0.12)), 6)


@lru_cache(maxsize=None)
def vibes(midi, dur=0.8):
    f = hz(midi)
    s = modal([(f, 1.0, 0.9), (f * 3.99, 0.22, 0.32), (f * 10.4, 0.07, 0.12)], dur)
    return fade([v * (1.0 + 0.22 * math.sin(TAU * 5.0 * i / SR)) for i, v in enumerate(s)], 8)


@lru_cache(maxsize=None)
def bell(midi, dur=1.0):
    """Glockenspiel / small bell: bright inharmonic partials."""
    f = hz(midi)
    return fade(modal([(f, 1.0, 0.5), (f * 2.76, 0.5, 0.25), (f * 5.4, 0.3, 0.14), (f * 8.93, 0.15, 0.08)], dur), 4)


@lru_cache(maxsize=None)
def epiano(midi, dur=0.9):
    """Soft FM electric piano."""
    f = hz(midi)
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        idx = 1.6 * math.exp(-t / 0.22)
        ph = TAU * f * t
        v = math.sin(ph + idx * math.sin(ph))
        v += 0.12 * math.sin(TAU * f * 7.0 * t) * math.exp(-t / 0.05)
        out.append(v * math.exp(-t / 0.7))
    return fade(out, 6)


@lru_cache(maxsize=None)
def pluck_bass(midi, dur=0.4):
    f = hz(midi)
    s = modal([(f, 1.0, 0.3), (f * 2, 0.4, 0.15), (f * 3, 0.14, 0.08)], dur)
    return fade(s, 6)


def brass(f, dur, vol=1.0, vib=0.0, f_end=None, bright=4.0, attack=0.04, release=0.08):
    """Filtered saw with a short 'blat': the filter opens at the start and settles."""
    n = int(dur * SR)
    f_end = f if f_end is None else f_end
    out = []
    p1 = p2 = 0.0
    for i in range(n):
        k = i / max(1, n - 1)
        ff = f * (f_end / f) ** k
        if vib:
            ff *= 1.0 + vib * math.sin(TAU * 5.5 * i / SR)
        p1 += ff / SR
        p2 += ff * 1.004 / SR
        out.append(((p1 % 1.0) * 2 - 1 + (p2 % 1.0) * 2 - 1) * 0.5)
    out = filt(out, "lp", f * bright * 1.6, 1.1, f * bright)
    return gain(shape(out, attack, release), vol)


# ---------------------------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------------------------

def sfx_hit():
    click = filt(noise(0.015, 0.0025), "hp", 1800)
    body = modal([(900, 1.0, 0.022), (2000, 0.55, 0.012), (3400, 0.3, 0.007), (280, 0.8, 0.03)], 0.16)
    thump = sweep(190, 85, 0.06, 0.018, 0.8)
    return fade(reverb(mix(gain(click, 0.55), gain(body, 0.9), thump), 0.06, 0.4, tail=0.15), 3)


def sfx_opp_hit():
    click = filt(noise(0.012, 0.002), "hp", 1500)
    body = modal([(700, 1.0, 0.02), (1600, 0.5, 0.01), (240, 0.8, 0.03)], 0.14)
    return fade(mix(gain(click, 0.35), gain(body, 0.8), sweep(160, 80, 0.05, 0.018, 0.6)), 3)


def sfx_bounce():
    tick = filt(noise(0.01, 0.0015), "hp", 2500)
    body = modal([(640, 1.0, 0.03), (1420, 0.5, 0.018), (2500, 0.25, 0.01)], 0.12)
    return fade(mix(gain(tick, 0.3), body), 3)


def sfx_wall():
    body = modal([(170, 1.0, 0.09), (330, 0.6, 0.06), (560, 0.35, 0.04), (900, 0.2, 0.02)], 0.3)
    thud = filt(noise(0.08, 0.02), "lp", 700)
    return fade(mix(body, gain(thud, 0.6)), 4)


def sfx_net():
    cloth = filt(noise(0.35, 0.09), "lp", 1400, 0.7, 300)
    return fade(reverb(mix(gain(cloth, 0.8), sweep(120, 55, 0.2, 0.07, 0.6),
                            gain(modal([(2100, 1.0, 0.03), (3100, 0.6, 0.02)], 0.12), 0.18)), 0.1, 0.5, tail=0.2), 5)


def sfx_net_clip():
    tick = filt(noise(0.03, 0.005), "hp", 3500)
    return fade(mix(gain(tick, 0.5), modal([(3200, 0.5, 0.03), (4700, 0.3, 0.02), (1900, 0.4, 0.04)], 0.14)), 3)


def sfx_swoosh():
    n = noise(0.28)
    air = filt(n, "bp", 500, 1.3, 2600)
    n2 = len(air)
    out = [v * math.sin(math.pi * (i / n2)) ** 1.6 for i, v in enumerate(air)]
    return fade(gain(out, 1.4), 8)


def sfx_dash():
    air = filt(noise(0.34), "bp", 350, 1.0, 1800)
    n = len(air)
    air = [v * min(1.0, i / (0.03 * SR)) * math.exp(-3.2 * i / n) for i, v in enumerate(air)]
    squeak = shape(sweep(1500, 2300, 0.07, 0.04, 0.35), 0.003, 0.02)
    return fade(mix(gain(air, 1.3), (0.02, squeak)), 8)


def sfx_serve():
    return reverb(mix(gain(marimba(93, 0.3), 0.8), (0.07, marimba(100, 0.4))), 0.15, 0.5, tail=0.3)


def sfx_point_win():
    parts = [(i * 0.085, gain(marimba(m, 0.5), 0.9)) for i, m in enumerate([72, 76, 79, 84])]
    parts.append((0.255, gain(bell(96, 0.9), 0.35)))
    return reverb(mix(*parts), 0.18, 0.65, tail=0.5)


def sfx_point_big():
    run = [72, 76, 79, 84, 88, 91, 96]
    parts = [(i * 0.065, gain(marimba(m, 0.5), 0.8)) for i, m in enumerate(run)]
    parts += [(0.39, gain(bell(103, 1.2), 0.5)), (0.39, gain(vibes(84, 1.0), 0.5)), (0.39, gain(vibes(91, 1.0), 0.4))]
    cheer = filt(noise(0.7), "bp", 1500, 0.6, 2400)
    cheer = [v * math.sin(math.pi * (i / len(cheer))) ** 1.5 * 0.12 for i, v in enumerate(cheer)]
    parts.append((0.3, cheer))
    return reverb(mix(*parts), 0.22, 0.75, tail=0.7)


def tape_stop(s, dur):
    """Resample so the sound slows and drops in pitch to a halt, like a stopping tape."""
    n = int(dur * SR)
    out = []
    pos = 0.0
    for i in range(n):
        k = i / n
        j = int(pos)
        if j + 1 >= len(s):
            break
        fr = pos - j
        out.append(s[j] * (1 - fr) + s[j + 1] * fr)
        pos += max(0.03, 1.0 - k ** 1.6)
    return shape(out, 0.005, 0.08)


def sfx_point_lose_1():
    """Cartoon bonk and a springy boing."""
    bonk = modal([(250, 1.0, 0.05), (520, 0.6, 0.03), (880, 0.3, 0.02)], 0.2)
    boing = shape(sweep(520, 150, 0.5, 0.22, 0.5, vib=0.07, vib_rate=15.0), 0.005, 0.1)
    return fade(mix(bonk, (0.04, boing)), 4)


def sfx_point_lose_2():
    """Balloon letting go of its air."""
    air = filt(noise(0.75), "bp", 1900, 1.2, 260)
    n = len(air)
    air = [v * (1.0 + 0.6 * math.sin(TAU * 26.0 * i / SR)) * math.exp(-1.6 * i / n) for i, v in enumerate(air)]
    tone = filt(sweep(640, 140, 0.7, 0.4, 0.25), "lp", 1500)
    return fade(mix(gain(air, 1.6), tone), 8)


def sfx_point_lose_3():
    """Glass shattering, then the pieces tinkling away."""
    crash = filt(noise(0.35, 0.09), "hp", 2500)
    shards = [(0.02 + 0.07 * i + random.uniform(0.0, 0.03), gain(bell(100 - 3 * i + random.randint(-1, 1), 0.5), 0.3))
              for i in range(7)]
    return fade(reverb(mix(gain(crash, 0.8), *shards), 0.14, 0.6, tail=0.4), 40)


def sfx_point_lose_4():
    """A little chord that winds down like a tape machine losing power."""
    chord = mix(*[epiano(m, 1.4) for m in (45, 52, 57, 60, 64)])
    return fade(reverb(tape_stop(chord, 1.0), 0.1, 0.5, tail=0.3), 30)


def sfx_clear():
    seq = [(72, 0.11), (72, 0.11), (72, 0.11), (76, 0.1), (79, 0.1), (84, 0.7)]
    parts = []
    t = 0.0
    for m, d in seq:
        parts.append((t, brass(hz(m), d + 0.03, 0.55, bright=4.0, release=0.05 if d < 0.5 else 0.3)))
        parts.append((t, brass(hz(m - 12), d + 0.03, 0.4, bright=3.0, release=0.05 if d < 0.5 else 0.3)))
        parts.append((t, gain(bell(m + 12, 1.0 if d > 0.5 else 0.3), 0.3)))
        t += d
    return reverb(mix(*parts), 0.2, 0.7, tail=0.7)


def sfx_game_over():
    whistle = shape(sweep(1500, 220, 0.9, None, 0.45, vib=0.015, vib_rate=7.0), 0.02, 0.1)
    breath = filt(noise(0.9), "bp", 1200, 1.0, 400)
    breath = gain(shape(breath, 0.02, 0.2), 0.08)
    tuba = brass(hz(46), 1.1, 0.7, f_end=hz(34), bright=2.5, attack=0.08, release=0.5)
    return reverb(mix(whistle, breath, (0.85, tuba)), 0.12, 0.5, tail=0.5)


def sfx_buy():
    return reverb(mix(gain(bell(95, 0.5), 0.8), (0.07, gain(bell(100, 0.9), 0.9)),
                      gain(filt(noise(0.04, 0.008), "hp", 4000), 0.15)), 0.15, 0.5, tail=0.4)


def sfx_deny():
    a = modal([(210, 1.0, 0.07), (420, 0.5, 0.04), (630, 0.2, 0.03)], 0.2)
    return fade(mix(a, (0.12, gain(modal([(185, 1.0, 0.09), (370, 0.5, 0.05)], 0.25), 0.9))), 4)


def sfx_reroll():
    parts = []
    for i, m in enumerate([72, 76, 74, 79, 77, 84]):
        parts.append((i * 0.045, gain(marimba(m, 0.2), 0.7)))
        parts.append((i * 0.045, gain(filt(noise(0.02, 0.005), "bp", 3000, 1.0), 0.15)))
    return reverb(mix(*parts), 0.12, 0.5, tail=0.3)


def sfx_remove():
    crackle = []
    for i in range(int(0.22 * SR)):
        crackle.append(random.uniform(-1, 1) * (1.0 if random.random() < 0.06 else 0.1) * math.exp(-i / SR / 0.1))
    crackle = filt(crackle, "hp", 1500)
    poof = filt(noise(0.2, 0.06), "lp", 1800, 0.7, 400)
    return fade(mix(gain(crackle, 0.7), (0.05, gain(poof, 0.8)), sweep(260, 90, 0.15, 0.06, 0.4)), 4)


def sfx_click():
    return fade(modal([(2600, 1.0, 0.006), (1500, 0.5, 0.01), (4200, 0.3, 0.004)], 0.05), 2)


def sfx_fire():
    swell = filt(noise(0.9), "lp", 300, 0.8, 3500)
    n = len(swell)
    swell = [v * math.sin(math.pi * (i / n)) ** 0.8 for i, v in enumerate(swell)]
    crack = []
    for i in range(int(0.9 * SR)):
        crack.append(random.uniform(-1, 1) if random.random() < 0.0012 else 0.0)
    crack = filt(crack, "hp", 2000)
    return fade(reverb(mix(gain(swell, 0.9), gain(crack, 4.0)), 0.1, 0.5, tail=0.3), 8)


SFX = {
    "hit": (sfx_hit, 0.75), "opp_hit": (sfx_opp_hit, 0.6),
    "bounce": (sfx_bounce, 0.6), "wall": (sfx_wall, 0.7), "net": (sfx_net, 0.7), "net_clip": (sfx_net_clip, 0.55),
    "swoosh": (sfx_swoosh, 0.55), "dash": (sfx_dash, 0.6), "serve": (sfx_serve, 0.55),
    "point_win": (sfx_point_win, 0.7), "point_big": (sfx_point_big, 0.75), "point_lose_1": (sfx_point_lose_1, 0.7), "point_lose_2": (sfx_point_lose_2, 0.6),
    "point_lose_3": (sfx_point_lose_3, 0.65), "point_lose_4": (sfx_point_lose_4, 0.65),
    "clear": (sfx_clear, 0.75), "game_over": (sfx_game_over, 0.75),
    "buy": (sfx_buy, 0.65), "deny": (sfx_deny, 0.6), "reroll": (sfx_reroll, 0.6), "remove": (sfx_remove, 0.6),
    "click": (sfx_click, 0.5), "fire": (sfx_fire, 0.6),
}


# ---------------------------------------------------------------------------------------------
# Drums
# ---------------------------------------------------------------------------------------------

@lru_cache(maxsize=None)
def kick(soft=False):
    n = int(0.28 * SR)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 48 + 95 * math.exp(-t / 0.028)
        ph += f / SR
        out.append(math.sin(TAU * ph) * math.exp(-t / 0.11))
    click = gain(filt(noise(0.006, 0.001), "hp", 1500), 0.25 if not soft else 0.08)
    return fade(mix(out, click), 3)


@lru_cache(maxsize=None)
def snare():
    n = filt(noise(0.2, 0.07), "bp", 2000, 0.8)
    return fade(mix(gain(n, 0.9), sweep(210, 160, 0.12, 0.04, 0.5)), 3)


@lru_cache(maxsize=None)
def hat(open_=False):
    return fade(filt(noise(0.2 if open_ else 0.05, 0.07 if open_ else 0.012), "hp", 7500), 2)


@lru_cache(maxsize=None)
def brush():
    n = filt(noise(0.14), "bp", 4500, 0.7)
    return fade(shape(n, 0.012, 0.1), 3)


@lru_cache(maxsize=None)
def rim():
    return fade(modal([(1800, 1.0, 0.012), (3300, 0.5, 0.008), (700, 0.4, 0.02)], 0.08), 2)


# ---------------------------------------------------------------------------------------------
# Music: Am7 - Fmaj7 - Cmaj7 - G7, then Am7 - Fmaj7 - Dm7 - E7. Renders a loop whose tail wraps onto its start.
# A laid-back groove (dusty drums, electric piano, round bass, muted plucks, a mellow synth lead).
# ---------------------------------------------------------------------------------------------

@lru_cache(maxsize=None)
def soft_lead(midi, dur=0.5):
    """Mellow synth lead: a few harmonics, slow vibrato, rounded off."""
    f = hz(midi)
    n = int(dur * SR)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        ph += f * (1.0 + 0.004 * math.sin(TAU * 5.2 * t) * min(1.0, t / 0.3)) / SR
        out.append(math.sin(TAU * ph) + 0.4 * math.sin(2 * TAU * ph) + 0.15 * math.sin(3 * TAU * ph))
    return filt(shape(out, 0.025, 0.14), "lp", f * 4.0, 0.7)


@lru_cache(maxsize=None)
def muted_pluck(midi, dur=0.2):
    f = hz(midi)
    return fade(modal([(f, 1.0, 0.13), (f * 2, 0.5, 0.09), (f * 3, 0.28, 0.06), (f * 4, 0.12, 0.04)], dur), 4)


@lru_cache(maxsize=None)
def pad_saw(midi, dur=2.0):
    """Wide, slow pad: three detuned saws through a soft low-pass."""
    f = hz(midi)
    n = int(dur * SR)
    out = []
    p1 = p2 = p3 = 0.0
    for i in range(n):
        p1 += f * 0.997 / SR
        p2 += f / SR
        p3 += f * 1.003 / SR
        out.append(((p1 % 1.0) + (p2 % 1.0) + (p3 % 1.0)) * 2.0 - 3.0)
    return filt(shape(out, 0.5, 0.7), "lp", 1300, 0.7)


@lru_cache(maxsize=None)
def organ(midi, dur=2.0):
    f = hz(midi)
    n = int(dur * SR)
    harm = [(1, 1.0), (2, 0.6), (3, 0.35), (4, 0.3), (6, 0.12)]
    out = []
    for i in range(n):
        t = i / SR
        out.append(sum(a * math.sin(TAU * f * h * t) for h, a in harm) * (1.0 + 0.06 * math.sin(TAU * 5.5 * t)))
    return shape(out, 0.04, 0.3)


@lru_cache(maxsize=None)
def harpsichord(midi, dur=0.3):
    f = hz(midi)
    body = modal([(f, 1.0, 0.2), (f * 2, 0.7, 0.15), (f * 3, 0.5, 0.12), (f * 4, 0.35, 0.1),
                  (f * 5, 0.25, 0.08), (f * 6, 0.15, 0.06)], dur)
    return fade(mix(body, gain(filt(noise(0.01, 0.002), "hp", 3000), 0.15)), 4)


@lru_cache(maxsize=None)
def synth_pluck(midi, dur=0.22):
    """Analogue-ish pluck: detuned saws, the filter closing quickly."""
    f = hz(midi)
    n = int(dur * SR)
    out = []
    p1 = p2 = 0.0
    for i in range(n):
        p1 += f / SR
        p2 += f * 1.006 / SR
        out.append(((p1 % 1.0) + (p2 % 1.0)) - 1.0)
    out = filt(out, "lp", min(f * 9, 9000), 1.2, f * 1.5)
    return fade([v * math.exp(-i / SR / 0.12) for i, v in enumerate(out)], 4)


@lru_cache(maxsize=None)
def saw_bass(midi, dur=0.2):
    f = hz(midi)
    n = int(dur * SR)
    out = []
    ph = 0.0
    for i in range(n):
        ph += f / SR
        out.append((ph % 1.0) * 2.0 - 1.0)
    out = filt(out, "lp", f * 6, 1.0, f * 2)
    sub = sweep(f, f, dur, None, 0.7)
    return fade(shape(mix(out, sub), 0.004, 0.05), 3)


@lru_cache(maxsize=None)
def sub_bass(midi, dur=0.8):
    f = hz(midi)
    return shape(mix(sweep(f, f, dur, None, 1.0), sweep(f * 2, f * 2, dur, None, 0.18)), 0.03, 0.2)


@lru_cache(maxsize=None)
def tom():
    return fade(mix(modal([(95, 1.0, 0.14), (190, 0.4, 0.07)], 0.4), sweep(140, 85, 0.1, 0.05, 0.5)), 3)


@lru_cache(maxsize=None)
def clap():
    parts = [(0.0, filt(noise(0.012), "bp", 1500, 1.0)), (0.011, filt(noise(0.012), "bp", 1500, 1.0)),
             (0.022, filt(noise(0.22, 0.06), "bp", 1400, 0.9))]
    return fade(mix(*parts), 2)


def echo(s, delay, fb=0.35):
    d = int(delay * SR)
    y = list(s)
    for i in range(d, len(y)):
        y[i] += fb * y[i - d]
    return y


# ---------------------------------------------------------------------------------------------
# Tracks
#
# Each track is a spec: tempo, two 4-chord progressions (A, then B for the last phrase), two lead
# melodies to match, and a list of parts. A part is one voice playing a pattern each bar:
#   hits = [(sixteenth, selector, seconds, gain)]  selector: ("r", oct) root, ("c", i, oct) i-th chord
#   tone, ("all", oct) the whole chord, None for drums. A phrase (4 bars) switches parts on by layer name.
# ---------------------------------------------------------------------------------------------

def hits8(idx, oct_, dur, g):
    """An arpeggio on every eighth note, picking chord tones from idx."""
    return [(s, ("c", idx[k % len(idx)], oct_), dur, g) for k, s in enumerate(range(0, 16, 2))]


def hits16(idx, oct_, dur, g):
    return [(s, ("c", idx[s % len(idx)], oct_), dur, g) for s in range(16)]


BEACH = dict(
    bpm=118, swing=0.08, wet=0.1, room=0.6, damp=0.5,
    A=[([57, 60, 64, 67], 45), ([53, 57, 60, 64], 41), ([60, 64, 67, 71], 48), ([55, 59, 62, 65], 43)],
    B=[([57, 60, 64, 67], 45), ([53, 57, 60, 64], 41), ([62, 65, 69, 72], 38), ([56, 59, 62, 64], 40)],
    LA=[[76, None, None, None, 72, None, 69, None], [77, None, None, None, 72, None, 69, 72],
        [76, None, None, None, 79, None, 76, None], [74, None, None, None, 71, None, 67, 71]],
    LB=[[81, None, None, None, 79, None, 76, None], [77, None, 76, None, 72, None, None, None],
        [74, None, 77, None, 81, None, None, None], [80, None, None, None, 76, None, 71, None]],
    lead=soft_lead, lead_vol=0.4,
    parts=[
        dict(layer="bass", voice=pluck_bass, hits=[(s, ("r", o), 0.3, 0.9) for s, o in
                                                   [(0, 0), (3, 0), (6, 12), (8, 0), (11, 0), (14, 12)]]),
        dict(layer="pluck", voice=muted_pluck, hits=hits8([0, 1, 2, 3, 2, 1, 2, 3], 12, 0.2, 0.2)),
        dict(layer="comp", voice=epiano, hits=[(0, ("all", 0), 0.9, 0.11), (6, ("all", 0), 0.35, 0.09),
                                               (10, ("all", 0), 0.35, 0.09)]),
        dict(layer="drums", voice=kick, hits=[(s, None, 0, 0.95) for s in (0, 6, 10)]),
        dict(layer="drums", voice=snare, hits=[(s, None, 0, 0.5) for s in (4, 12)]),
        dict(layer="drums", voice=hat, hits=[(s, None, 0, 0.1 if s % 4 else 0.14) for s in range(0, 14, 2)]),
        dict(layer="drums", voice=lambda: hat(True), hits=[(14, None, 0, 0.1)]),
        dict(layer="fill", only_bar=3, voice=snare, hits=[(s, None, 0, 0.25 + 0.08 * (s - 13)) for s in (13, 14, 15)]),
    ],
    phrases=[
        dict(bass=1, pluck=1, drums=1, comp=1),
        dict(bass=1, pluck=1, drums=1, comp=1, lead=1, shift=-12),
        dict(bass=1, pluck=1, drums=1, comp=1, lead=1, shift=0),
        dict(bass=1, pluck=1, drums=1, comp=1, lead=1, shift=-12, b=1, fill=1),
    ],
)

EVEREST = dict(
    bpm=100, swing=0.0, wet=0.24, room=0.88, damp=0.45,
    A=[([62, 65, 69, 72], 38), ([58, 62, 65, 69], 46), ([53, 57, 60, 64], 41), ([60, 64, 67, 71], 48)],
    B=[([62, 65, 69, 72], 38), ([55, 58, 62, 65], 43), ([58, 62, 65, 69], 46), ([57, 61, 64, 67], 45)],
    LA=[[74, None, None, None, 77, None, 76, None], [74, None, None, None, 72, None, 70, None],
        [72, None, None, None, 69, None, 72, None], [71, None, None, None, 72, None, 76, None]],
    LB=[[77, None, None, None, 76, None, 74, None], [74, None, None, None, 70, None, 67, None],
        [77, None, None, None, 74, None, 70, None], [73, None, None, None, 76, None, 69, None]],
    lead=soft_lead, lead_vol=0.36,
    parts=[
        dict(layer="pad", voice=pad_saw, hits=[(0, ("all", 0), "bar", 0.07)]),
        dict(layer="bass", voice=sub_bass, hits=[(0, ("r", 0), 1.4, 0.75), (8, ("r", 0), 1.2, 0.6)]),
        dict(layer="harp", voice=muted_pluck, hits=hits8([0, 1, 2, 3, 2, 1, 2, 1], 12, 0.35, 0.2)),
        dict(layer="glint", voice=bell, hits=[(8, ("c", 3, 12), 1.2, 0.1)]),
        dict(layer="drums", voice=kick, hits=[(0, None, 0, 0.8), (10, None, 0, 0.55)]),
        dict(layer="drums", voice=tom, hits=[(6, None, 0, 0.5), (14, None, 0, 0.4)]),
        dict(layer="drums", voice=hat, hits=[(s, None, 0, 0.05) for s in range(0, 16, 2)]),
    ],
    phrases=[
        dict(pad=1, bass=1, harp=1, glint=1),
        dict(pad=1, bass=1, harp=1, glint=1, drums=1, lead=1, shift=-12),
        dict(pad=1, bass=1, harp=1, glint=1, drums=1, lead=1, shift=0),
        dict(pad=1, bass=1, harp=1, glint=1, drums=1, lead=1, shift=-12, b=1),
    ],
)

MOON = dict(
    bpm=108, swing=0.0, wet=0.2, room=0.8, damp=0.4, echo=(3, 0.38),
    A=[([52, 55, 59, 62], 40), ([48, 52, 55, 59], 48), ([57, 60, 64, 67], 45), ([62, 66, 69, 71], 38)],
    B=[([52, 55, 59, 62], 40), ([48, 52, 55, 59], 48), ([57, 60, 64, 67], 45), ([59, 63, 66, 69], 47)],
    LA=[[79, None, None, None, 83, None, 79, None], [76, None, None, None, 79, None, 83, None],
        [81, None, None, None, 79, None, 76, None], [78, None, None, None, 76, None, 74, None]],
    LB=[[83, None, 81, None, 79, None, 76, None], [79, None, None, None, 76, None, 72, None],
        [81, None, 84, None, 81, None, 79, None], [78, None, None, None, 75, None, 78, None]],
    lead=soft_lead, lead_vol=0.34,
    parts=[
        dict(layer="pad", voice=pad_saw, hits=[(0, ("all", 0), "bar", 0.06)]),
        dict(layer="bass", voice=sub_bass, hits=[(0, ("r", 0), 1.0, 0.8), (6, ("r", 0), 0.4, 0.6),
                                                 (8, ("r", 0), 1.0, 0.7), (14, ("r", 12), 0.4, 0.5)]),
        dict(layer="arp", voice=synth_pluck,
             hits=[(s, ("c", [0, 2, 1, 3, 2, 1, 3, 2][s % 8], 12), 0.2, 0.2 if s % 4 else 0.28) for s in range(16)]),
        dict(layer="drums", voice=kick, hits=[(0, None, 0, 0.8), (8, None, 0, 0.7)]),
        dict(layer="drums", voice=clap, hits=[(4, None, 0, 0.35), (12, None, 0, 0.4)]),
        dict(layer="drums", voice=lambda: hat(True), hits=[(s, None, 0, 0.08) for s in (2, 6, 10, 14)]),
    ],
    phrases=[
        dict(pad=1, bass=1, arp=1),
        dict(pad=1, bass=1, arp=1, drums=1, lead=1, shift=-12),
        dict(pad=1, bass=1, arp=1, drums=1, lead=1, shift=-12),
        dict(pad=1, bass=1, arp=1, drums=1, lead=1, shift=-12, b=1),
    ],
)

MANSION = dict(
    bpm=92, swing=0.0, wet=0.3, room=0.9, damp=0.4,
    A=[([60, 63, 67, 70], 48), ([56, 60, 63, 67], 44), ([53, 56, 60, 63], 41), ([55, 59, 62, 65], 43)],
    B=[([60, 63, 67, 70], 48), ([53, 56, 60, 63], 41), ([62, 65, 68, 72], 38), ([55, 59, 62, 65], 43)],
    LA=[[75, None, None, None, 74, None, 72, None], [72, None, None, None, 75, None, 79, None],
        [77, None, None, None, 75, None, 72, None], [74, None, None, None, 71, None, 74, None]],
    LB=[[79, None, None, None, 75, None, 72, None], [77, None, 75, None, 72, None, 68, None],
        [77, None, None, None, 74, None, 72, None], [71, None, 74, None, 77, None, 74, None]],
    lead=soft_lead, lead_vol=0.36,
    parts=[
        dict(layer="organ", voice=organ, hits=[(0, ("all", 0), "bar", 0.05)]),
        dict(layer="bass", voice=pluck_bass, hits=[(0, ("r", 0), 0.4, 0.85), (6, ("r", 7), 0.3, 0.7),
                                                   (8, ("r", 0), 0.4, 0.8), (12, ("r", 12), 0.3, 0.6)]),
        dict(layer="harpsi", voice=harpsichord, hits=hits8([0, 1, 2, 3, 2, 1, 2, 1], 12, 0.3, 0.2)),
        dict(layer="toll", voice=bell, hits=[(0, ("r", 24), 1.6, 0.22)]),
        dict(layer="drums", voice=lambda: kick(True), hits=[(0, None, 0, 0.6), (8, None, 0, 0.5)]),
        dict(layer="drums", voice=rim, hits=[(4, None, 0, 0.3), (12, None, 0, 0.3)]),
    ],
    phrases=[
        dict(organ=1, bass=1, harpsi=1),
        dict(organ=1, bass=1, harpsi=1, drums=1, toll=1, lead=1, shift=-12),
        dict(organ=1, bass=1, harpsi=1, drums=1, toll=1, lead=1, shift=0),
        dict(organ=1, bass=1, harpsi=1, drums=1, toll=1, lead=1, shift=-12, b=1),
    ],
)

ARCADE = dict(
    bpm=124, swing=0.0, wet=0.12, room=0.6, damp=0.5, echo=(3, 0.3),
    A=[([53, 56, 60, 63], 41), ([61, 65, 68, 72], 37), ([56, 60, 63, 67], 44), ([63, 67, 70, 74], 39)],
    B=[([53, 56, 60, 63], 41), ([61, 65, 68, 72], 37), ([58, 61, 65, 68], 46), ([60, 64, 67, 70], 48)],
    LA=[[77, None, 80, None, 84, None, 80, None], [77, None, None, None, 80, None, 84, None],
        [79, None, None, None, 80, None, 75, None], [82, None, None, None, 79, None, 75, None]],
    LB=[[84, None, 80, None, 77, None, 80, None], [85, None, None, None, 80, None, 77, None],
        [82, None, None, None, 85, None, 82, None], [84, None, 79, None, 76, None, 79, None]],
    lead=soft_lead, lead_vol=0.38,
    parts=[
        dict(layer="pad", voice=pad_saw, hits=[(0, ("all", 0), "bar", 0.06)]),
        dict(layer="bass", voice=saw_bass, hits=[(s, ("r", 12 if s % 4 == 2 else 0), 0.18, 0.7) for s in range(0, 16, 2)]),
        dict(layer="arp", voice=synth_pluck, hits=hits16([0, 1, 2, 3, 2, 1, 2, 3], 12, 0.2, 0.2)),
        dict(layer="drums", voice=kick, hits=[(s, None, 0, 0.95) for s in (0, 4, 8, 12)]),
        dict(layer="drums", voice=clap, hits=[(s, None, 0, 0.5) for s in (4, 12)]),
        dict(layer="drums", voice=lambda: hat(True), hits=[(s, None, 0, 0.13) for s in (2, 6, 10, 14)]),
        dict(layer="drums", voice=hat, hits=[(s, None, 0, 0.05) for s in (1, 3, 5, 7, 9, 11, 13, 15)]),
    ],
    phrases=[
        dict(pad=1, bass=1, arp=1, drums=1),
        dict(pad=1, bass=1, arp=1, drums=1, lead=1, shift=-12),
        dict(pad=1, bass=1, arp=1, drums=1, lead=1, shift=-12),
        dict(pad=1, bass=1, arp=1, drums=1, lead=1, shift=-12, b=1),
    ],
)

SHOP = dict(
    bpm=96, swing=0.0, wet=0.14, room=0.6, damp=0.5,
    A=BEACH["A"], B=BEACH["B"], LA=BEACH["LA"], LB=BEACH["LB"], lead=soft_lead, lead_vol=0.3,
    parts=[
        dict(layer="bass", voice=pluck_bass, hits=[(s, ("r", o), 0.45, 0.8) for s, o in [(0, 0), (6, 7), (8, 0), (14, 7)]]),
        dict(layer="comp", voice=epiano, hits=[(s, ("all", 12 if s == 3 else 0), 0.6, 0.1) for s in (0, 3, 6, 10, 12)]),
        dict(layer="drums", voice=brush, hits=[(s, None, 0, 0.22 if s % 4 else 0.3) for s in range(0, 16, 2)]),
        dict(layer="drums", voice=lambda: kick(True), hits=[(0, None, 0, 0.5), (8, None, 0, 0.5)]),
        dict(layer="drums", voice=rim, hits=[(s, None, 0, 0.2) for s in (3, 6, 10, 12)]),
    ],
    phrases=[
        dict(bass=1, comp=1, drums=1),
        dict(bass=1, comp=1, drums=1, lead=1, shift=-12),
        dict(bass=1, comp=1, drums=1),
        dict(bass=1, comp=1, drums=1, lead=1, shift=-12, b=1),
    ],
)


def render_track(spec):
    step = 60.0 / spec["bpm"] / 4.0  # one sixteenth
    spb = int(step * 16 * SR)
    buf = [0.0] * (spb * 4 * len(spec["phrases"]))
    swing = spec["swing"]

    def put(bar, s16, samples, g=1.0):
        off = s16 + (swing if int(s16) % 2 == 1 else 0.0)
        base = bar * spb + int(off * step * SR)
        g *= random.uniform(0.9, 1.0)
        for i, v in enumerate(samples):
            buf[(base + i) % len(buf)] += v * g

    random.seed(7)
    for ph, layers in enumerate(spec["phrases"]):
        chords = spec["B"] if layers.get("b") else spec["A"]
        lead = spec["LB"] if layers.get("b") else spec["LA"]
        for b in range(4):
            bar = ph * 4 + b
            chord, root = chords[b]
            for part in spec["parts"]:
                if not layers.get(part["layer"]) or part.get("only_bar", b) != b:
                    continue
                for s16, sel, dur, g in part["hits"]:
                    if sel is None:
                        put(bar, s16, part["voice"](), g)
                        continue
                    d = step * 16 + 0.6 if dur == "bar" else dur
                    if sel[0] == "r":
                        notes = [root + sel[1]]
                    elif sel[0] == "c":
                        notes = [chord[sel[1] % len(chord)] + sel[2]]
                    else:
                        notes = [n + sel[1] for n in chord]
                    for n in notes:
                        put(bar, s16, part["voice"](n, d), g)
            if layers.get("lead"):
                notes = lead[b]
                i = 0
                while i < 8:
                    if notes[i] is not None:
                        j = i + 1
                        while j < 8 and notes[j] is None:
                            j += 1
                        put(bar, i * 2, spec["lead"](notes[i] + layers.get("shift", 0),
                                                     min(1.2, step * 2 * (j - i) * 1.05)), spec["lead_vol"])
                        i = j
                    else:
                        i += 1
    # Echo, reverb and filter over three copies back to back, keeping the middle one, so the tail of the
    # last bar rings into the first and the loop seam is continuous.
    n = len(buf)
    mixed = buf * 3
    if spec.get("echo"):
        mixed = echo(mixed, step * spec["echo"][0], spec["echo"][1])
    wet = reverb(mixed, spec["wet"], spec["room"], spec["damp"], tail=0.0)
    out = filt(wet, "lp", 10000, 0.7)[n:2 * n]
    # glue the peaks gently; scale first so the tanh only rounds off the loudest drum hits
    return saturate(normalize(out, 0.9), 1.0)


MUSIC = {name: ((lambda sp=spec: render_track(sp)), 0.6) for name, spec in
         [("beach", BEACH), ("everest", EVEREST), ("moon", MOON), ("mansion", MANSION), ("arcade", ARCADE),
          ("shop", SHOP)]}


def main():
    only = set(sys.argv[1:])
    random.seed(1)
    for name, (fn, peak) in SFX.items():
        if only and name not in only:
            continue
        save(os.path.join(ROOT, "sfx", name + ".wav"), normalize(fn(), peak))
        print("sfx", name, flush=True)
    for name, (fn, peak) in MUSIC.items():
        if only and name not in only:
            continue
        save(os.path.join(ROOT, "music", name + ".wav"), normalize(fn(), peak))
        print("music", name, flush=True)


if __name__ == "__main__":
    main()
