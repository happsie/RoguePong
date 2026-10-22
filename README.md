# RoguePong

A 3D-simulated table tennis roguelite made in Godot 4.7. Win rallies, stack Power x Heat through trick shots, buy magic balls and paddles, and beat 10 opponents.

Everything is drawn in code, with no art assets.

## Play

Open the project in Godot 4.7 and press F5, or run:

```
Godot_v4.7.2-stable_win64.exe --path .
```

## Controls

- **Mouse** moves the paddle across the table
- **Left click** lunges
- **Space** fires the paddle's ability (if it has one)

## The run

- 10 stages, two per map: a regular opponent, then that map's boss.
- Reach the stage's target score before you run out of lives.
- A rally scores Power x Heat. Trick shots raise both.
- Spend plinks in the shop between stages on magic balls and paddles.
- After each boss you can play a bonus round for extra Heat and a life.

## Development

See [CLAUDE.md](CLAUDE.md) for architecture, dev flags and test commands.
