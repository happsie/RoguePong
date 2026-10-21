# RoguePong

A 3D-simulated table tennis roguelite in Godot 4.7 (GDScript, GL Compatibility, 1280x720, everything drawn in code with `_draw`, no art assets). Win rallies, stack Power x Heat through trick shots, buy magic balls, beat 10 opponents.

`DESIGN.md` is the original pre-production design and is **out of date** (2D side view, perks, rallies per match). This file describes what is actually built.

## Run and test

Godot lives at `C:\Users\njesp\godot\4.7.2-stable\` (use the `_console.exe` for headless runs).

- Play: `Godot_v4.7.2-stable_win64.exe --path .`
- Solver test: `--headless --path . --script tests/solver_test.gd`
- After adding a new `class_name` script, run `--headless --path . --import` once, or Godot reports "Could not find type".
- Dev flags go after `--`:
  - `--bot` plays by itself, `--stage=N` starts at stage N.
  - `--show=clear|win|lose|shop|victory|settings|over` jumps to a screen.
  - `--show=offer1..4` opens a bonus offer, `--show=bonus1..4` starts a bonus round.
  - `--shot=<png> --shot-at=<sec>` saves a screenshot and quits. `--ball=<id>` fills the bag with one ball. `--noassist`, `--sloppy=<cm>`, `--nettest`.
- Headless bot runs: add `--fixed-fps 60` to run faster than real time.

## Architecture

Game state is all in `Game`; the views only draw.

| File | Role |
|---|---|
| `game.gd` | `Game`: state machine (`S`), input, rally rules, scoring, opponent AI, shop flow, bonus flow, FX lists (popups, particles) |
| `phys.gd` | `Phys`: 3D ball sim (gravity, drag, Magnus spin, spin-aware bounce, net), shot solver, `predict`. Shared by the game, the AI, the solver and the bonus rounds. Ball tweaks are static (`Phys.reset_tweaks()`) |
| `bonus.gd` | `Bonus`: the two bonus rounds (own small simulation, borrows paddle/fx/sound from `Game`) |
| `balls.gd` | `Balls`: magic ball definitions, prices, shop rolls |
| `paddles.gd` | `Paddles`: the paddles you can hold (face size, reach, speed, ability, look) and their shop prices |
| `roster.gd` | `Roster`: the 10 stages (opponent, map, target score, `diff` 0..1, taunts) |
| `world_view.gd` | draws the court, opponent, balls, player, and the bonus wall/bricks |
| `hud_view.gd` | draws HUD, intro card, shop, bonus offer/result, game over |
| `art.gd`, `scenery.gd`, `cam.gd`, `audio.gd` | drawing helpers, 5 themed backdrops, the fixed camera/projection, the `Audio` autoload |

Coordinates: centimetres. x lateral, y height above the table, z along the table from the player (0) to the opponent (`Phys.LENGTH`).

## The run

- 10 stages, two per map: a regular opponent, then that map's boss. Reach the stage's target score before running out of lives.
- Opponent difficulty comes from `Roster` `diff` (reaction time, speed, miss chance, wide shots), set in `Game._begin_stage`.
- Score a rally = Power x Heat. Heat starts at `Game.base_heat()` (1.0 plus permanent bonus Heat).
- **Smash falloff:** each smash in the same rally pays 60% of the previous one (`SMASH_FALLOFF`, floor `SMASH_FLOOR`).
- Plinks (currency) come from banked points, capped per stage; spent in the ball shop between stages.
- **Lives carry over between stages** (start 3, max `MAX_LIVES` = 5). They only reset on a new run.
- The serve hovers for a random 0.7-1.7s and its aim and angle are randomised, so it can't be timed.

## Bonus rounds

After each boss (stages 2, 4, 6, 8) the shop leads to an offer card instead of the next stage (`Game._leave_shop`). They alternate Multiball Mayhem and Break the Table, harder each time (`bonus_level` 0..3).

- Play and win: +1 life and +`BONUS_WIN_HEAT` (0.5) permanent base Heat.
- Skip: +`BONUS_SKIP_HEAT` (0.25) permanent base Heat.
- Fail (drop 3 balls): nothing. Bonus tries are `Bonus.tries`, separate from the run's lives.
- States: `BONUS_OFFER`, `BONUS`, `BONUS_END`. `Bonus` calls back `Game._bonus_end(won)`.
- Balls move through phases `OUT` (to the wall), `HELD` (parked at the wall, then fired by a solved shot), `IN` (towards you). Multiball staggers arrivals with a fire time; Break the Table damages bricks where the ball hits the wall.
- Tuning constants are at the top of `bonus.gd` (`HARD_SPEED`, `BRICK_H`, `WALL_HALF`, `MAX_BALLS`, goals) and `game.gd` (`BONUS_*`). The bonus rounds were verified with the bot and screenshots only. Break the Table's difficulty for a human is untested.

## Conventions

- Match the existing style: tabs, typed vars, `##` doc comments, short comments that explain why.
- Drawing helpers take the `CanvasItem` as the first argument and must be called from `_draw`.
- Don't add art files; everything is drawn in code. Sounds are synthesized by `tools/gen_audio.py`.

## Paddle and controls

There is no player body and no walking. The mouse moves the paddle across the whole table (`Game.base_range()`, scaled by the paddle's `reach`); left click lunges; **Space** fires the paddle's ability. A gloved hand (`Art.hand`) holds the handle.

- Abilities are optional, fired with Space in `Game._ability`: `focus` slows time (`_ball_time`), `grab` boosts the hit assist (`_assist`). Cooldown and duration are per paddle. The Classic has none. The opponent never sends a ball across your plane farther out than `OPP_REACH`, so everything is reachable with the mouse.
- `Game.equip_paddle(id)` swaps the held paddle (size, reach, speed, ability). A new run starts with the Classic. `--paddle=<id>` starts a run with another one.
- The shop's third slot is often a paddle offer (always after stage 1): ids are `paddle:<id>` in `shop_offers`, priced by `Game.offer_price`. Buying one replaces the one you hold.
