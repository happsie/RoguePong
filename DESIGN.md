# RoguePong — Design Notes

A table tennis roguelite. Win rallies, stack **Power × Heat** through trick shots, and collect perks that bend the rules. Every run is a climb through tougher opponents with a build you assemble as you go.

**Engine:** Godot 4.7 (2D, side view) → Windows build
**Status:** pre-production, design only

---

## 1. Pillars

1. **Intense** – fast rallies, short reaction windows, constant escalation.
2. **Trick shots are the point** – spin, edges, net clips and smashes should feel like discoveries and be worth far more than safe returns.
3. **Build-driven runs** – a limited number of attempts, scores that explode through perk synergy, and a "one more run" loop.
4. **Juice over realism** – hitstop, screen shake, rising-pitch scoring sounds, tactile wobbly cards. Physics is believable but always serves the fun.

---

## 2. Core Loop

```
Title → Opponent Select → Match (rallies) → Payout → Shop (perks) → next Match
                               │
                      out of rallies → Run Over
```

- A run is **3 circuits** (PoC). Each circuit has three matches: **Qualifier → Challenger → Champion**.
- Each match pits you against an opponent with a **target score**. Reach it before you run out of rallies.
- You get **4 rallies** per match. A rally ends when someone wins the point.
  - **Win the rally** → its Power × Heat is banked into your match score.
  - **Lose the rally** → that rally's score is lost and the rally is used up.
- Reach the target → payout → shop. Fail → run over.

You can't bank anything until you win the point, so stretching a rally for more Heat is a push-your-luck decision.

---

## 3. Moment-to-Moment Gameplay

### View and controls
- **3/4 view from behind your end of the table** (fixed camera, raised, looking down the court). The simulation is true 3D (x lateral, y height, z along the table) and is projected to 2D, so shots can be aimed left and right and curve with sidespin. The ball's shadow on the table shows where it is.
- **A / D (or arrows)** walk your body along your end of the table. Walking only covers the normal rally; the paddle reaches a short way either side of the body.
- **Space + a direction = dash.** A fast, unsteerable burst with a long cooldown (3 s) that carries you past the walking limit, for the very wide balls the opponent occasionally hits. It is meant to be hard to use: afterwards you stumble (slow walking, no lunge), and shots hit during a dash or stumble are less accurate. A successful one pays **DIVE** (+30 Power, +1 Heat).
- **Mouse** moves the paddle on a vertical plane at your end of the table: left/right (within reach of the body) and up/down. The paddle's velocity at contact is the shot. A faint ring shows where the incoming ball will cross your paddle plane (assist, `Game.INTERCEPT_HINT`).
- **Left click = lunge.** A short forward thrust over the table with a cooldown, for volleys and short balls. A well-timed lunge is a **PERFECT** hit: a risky flat shot that skims the net.
- **Lives:** you start with 3. Each rally the opponent wins costs one.
- Keyboard: `Esc` pause, `M` mute.

### Shot model
The shot is read from **how you swing**, not from menus:

| Input at contact | Effect |
|---|---|
| Swing speed | Depth: slow = short drop shot, fast = deep to the baseline |
| Vertical swipe up | Topspin (ball dives, kicks forward off the bounce) |
| Vertical swipe down | Backspin / chop (floaty, dies on the bounce) |
| Sideways swipe | Sidespin (ball curves in flight) and aims the shot left or right |
| Ball height at contact | Low ball → lob arc, high ball → flat or downward **smash** |
| Contact point on paddle | Centre is accurate; **edge hits** add wild deviation but pay big |
| Lunge | Faster, flatter, riskier, plus a perfect-timing bonus |

A shot solver picks the launch speed that lands the ball at your intended depth *given your spin*. Spin changes the arc and the bounce, not whether you hit the table. Skill lives in **positioning, timing, spin choice and risk**, not in fighting the physics.

### Physics (simulated for real)
- Gravity, light drag, and the **Magnus effect**: spin curves the ball's flight.
- **Spin-aware table bounces**: topspin kicks forward, backspin checks.
- The **net is a physical object**. Clipping the top can still go over, and that's a scoring trick.
- The same simulation drives the opponent AI and the shot solver.

### Rules (arcade-tolerant)
- The opponent feeds the ball to start each rally.
- Your shot must land on the opponent's half first, otherwise you lose the point.
- The opponent loses if the ball bounces twice on their side, or if they whiff.
- **Volleys are allowed** (hitting before the bounce) and rewarded.

---

## 4. Scoring: Power × Heat

Rally scoring is shown in a central **Power × Heat** display, live during the rally. **Power** (blue) is the raw punch. **Heat** (red) is how fired up the rally is. When you win the rally, the two slam together into your match score. Lose it and the display shatters.

### Base
- Each of your returns: **+10 Power**.
- Each return after the first: **+0.5 Heat** (rally streak).

### Trick bonuses

| Trick | Trigger | Bonus |
|---|---|---|
| TOPSPIN | strong topspin | +20 Power |
| CHOP | strong backspin | +30 Power |
| SMASH | fast, steeply downward hit from height | +2 Heat |
| LOB | very high arc | +25 Power |
| DROP SHOT | slow, short, backspin | +2 Heat |
| RIM SHOT | contact on the paddle rim | +50 Power, +1 Heat |
| VOLLEY | hit before it bounces | +1 Heat |
| PERFECT | lunge timed on contact | +10 Power, +1 Heat |
| NET CLIP | ball touches the net and still crosses | +2 Heat |
| EDGE BALL | bounce on the table's edge or end | +20 Power, +1 Heat |
| WINNER | opponent never touches it | +30 Power |

Every bonus pops up as a floating label at the ball, colour-coded (Power blue, Heat red) with a rising pitch per event.

### Target scaling (starting values, to tune)

| Circuit | Qualifier | Challenger | Champion |
|---|---|---|---|
| 1 | 300 | 500 | 800 |
| 2 | 1,200 | 2,000 | 3,200 |
| 3 | 5,000 | 8,000 | 13,000 |

---

## 5. Opponents

Each opponent is a character token with a face that tracks the ball and reacts to the score. The AI runs the real physics: it predicts the bounce, moves at a limited speed after a reaction delay, then picks a landing target with the same shot solver. **Miss chance grows with rally length and ball speed**, so long rallies are risky and short ones are safe.

| Circuit | Qualifier | Challenger | Champion |
|---|---|---|---|
| 1 | Rookie | Club Pro | **The Fan** – gusting wind pushes the ball sideways |
| 2 | Basement Champ | Coach Spin | **The Moon** – low gravity, floaty ball |
| 3 | The Olympian | The Machine | **The Grandmaster** – tall net, fast paddle, corner shots |

Each Champion changes the physics environment, so perks and tricks behave differently there.

---

## 6. Perks

- Up to **5 perk slots**, shown as cards across the top of the screen.
- Bought in the **shop** between matches, with money. Reroll costs $2. You can sell a perk for half its price.
- Most perks are data-driven: *on event X, add Power / add Heat / multiply Heat*. A few change the rules.

### Starter list (about 15, to be expanded)

| Perk | Effect |
|---|---|
| Spin Doctor | Topspin shots +2 Heat |
| Chop Shop | Chops +40 Power |
| Edgelord | Rim shots +3 Heat |
| Net Gain | Net clips ×1.5 Heat |
| Metronome | Every return +0.3 Heat |
| Hot Streak | From the 5th return on, ×2 Heat |
| Smash Bros | Smashes +4 Heat |
| Magnus Force | Spin curves 50% more, spin adds Power |
| Glass Paddle | ×2 Heat per return, but the paddle is 30% smaller |
| Big Paddle | Paddle 40% bigger |
| Bullet Time | World slows near the ball |
| Featherweight | Ball gravity −15% |
| Rabbit's Foot | Opponent misses 8% more |
| Banker | +$1 per rally won |
| Extra Ball | +1 rally per match |
| Insurance | First lost rally each match is free |

### Economy
- Match payout: $3 / $4 / $5 (Qualifier / Challenger / Champion).
- +$1 per unused rally.
- Interest: +$1 per $5 held (capped).

---

## 7. Art & Style

A chunky, tactile, card-table feel: heavy drop shadows, bouncy UI, a swirling backdrop and a retro screen.

- **Resolution:** 1280×720 logical, pixel-leaning UI with a pixel font.
- **Background:** animated paint-swirl shader (red / blue / dark palette) behind everything. Champion matches shift to a darker, hostile palette.
- **CRT pass:** slight barrel distortion, scanlines, vignette, chromatic aberration and light bloom as a full-screen shader.
- **Palette:** dark slate panels (`#374244`), Heat red (`#fe5f55`), Power blue (`#009dff`), gold money (`#eac058`), perk green (`#4bc292`). Table in teal-blue with white lines.
- **Typography:** pixel font with a hard drop shadow under every text element.
- **Cards:** rounded perk cards with a drop shadow that tilt and wobble toward the cursor on hover, and a rarity-coloured border.
- **Opponents:** round character tokens with eyes that follow the ball, an accessory per character (headband, glasses, crown, horns), and idle bobbing.
- **Ball:** squash and stretch along its velocity, trail, shadow cast onto the table, visible spin rotation.
- **Paddle:** red rubber face, wooden handle, wobbles on impact.

### Juice checklist
- Hitstop (~40ms) on paddle impact; screen shake scaled to shot power.
- Particles on bounces, net hits and smashes.
- Score numbers count up and pop, and Heat "slams" into Power.
- Rally lost: the Power × Heat display shatters.
- Camera punch-in on smashes and on a won long rally.

### Audio
- Synthesized/foley-style hits: paddle thock, table tick, net thud, edge-ball ping.
- Scoring chimes rise in pitch with each bonus in the rally.
- Looping lo-fi arcade track whose intensity rises with the rally length.

---

## 8. Technical Plan (Godot)

- **Scenes:** `Main` (state machine), `Court`, `Ball`, `Paddle`, `Opponent`, `HUD`, `PerkCard`, `OpponentCard`, `Shop`, `PostFX` (swirl and CRT).
- **Physics:** custom fixed-step ball simulation in GDScript (240 Hz substeps), not Godot's rigid bodies, so the shot solver and AI can call the identical code to look ahead.
- **Data:** perks, opponents and tricks as `Resource` files or dictionaries, so adding content is cheap.
- **Shaders:** canvas-item shaders for the swirl background, CRT and card tilt.
- **Autoloads:** `Game` (run state, money, perks), `Audio`, `Fx` (shake, hitstop).
- **Tests:** headless GDScript tests that check the solver can land a shot from a spread of positions, heights and spins.

---

## 9. Proof-of-Concept Scope

**In:** one full run of 3 circuits; the core shot model; 9 opponents with 3 Champion modifiers; ~15 perks; shop and economy; title, opponent select, run-over and victory screens; swirl and CRT look; synthesized audio.

**Out (later):** meta-progression and unlocks, multiple characters/paddles, consumables, daily seeds, controller support, a settings menu, endless mode, 3D.

## 10. Open Questions

- Is mouse-only control enough, or does the timing want a keyboard "swing" button as well?
- Should a lost rally keep a fraction of its Power (a consolation)? Currently it keeps none.
- Is 4 rallies per match the right pressure, or should it vary by opponent?
- A trajectory preview (ghost dots) as an assist option, or does it spoil the trick shots?
- Should the opponent score against you (lives), or is a limited number of rallies enough?
