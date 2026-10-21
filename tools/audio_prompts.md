# Audio prompts

Style: a goofy, cartoony table-tennis roguelike (googly-eyed opponents, beach and arcade settings). Sounds should be punchy, bright and playful, never harsh. File names match `audio.gd` (`audio/sfx/<name>.wav`).

Generators usually have a minimum length (about 0.5 s for ElevenLabs sound effects), so generate the very short ones at the minimum and trim them. Make 3 variants of the sounds that play constantly (hit, bounce, opp_hit) and pick the best, or rotate through them.

## Sound effects

| File | Length | Prompt |
|---|---|---|
| hit | 0.5 s, trim to ~0.15 s | Crisp table tennis paddle hitting a ping pong ball, dry close-mic, snappy rubber pock, no reverb, single hit |
| perfect | 1 s | Perfect ping pong smash: sharp paddle crack followed by a bright sparkly chime shimmer rising, arcade bonus feel, satisfying |
| opp_hit | 0.5 s, trim to ~0.15 s | Softer, slightly hollow ping pong paddle tap, single hit, dry, no reverb |
| bounce | 0.5 s, trim to ~0.1 s | Ping pong ball bouncing once on a hard wooden table, light bright tock, dry, single bounce |
| wall | 0.5 s | Ping pong ball bonking against a wooden board, dull thud with a small cartoon boing, single hit |
| net | 1 s | Ping pong ball smacking into a mesh net and dropping, soft fabric thump with a tiny rattle, dull, no echo |
| net_clip | 0.5 s | Quick light tick of a ping pong ball clipping the top of a net, tiny cord rattle, single, delicate |
| swoosh | 0.5 s | Fast cartoon whoosh of a paddle swung forward, airy, rises then fades, short |
| dash | 0.75 s | Cartoon sprint burst: quick air whoosh with a squeaky shoe scuff, short, energetic |
| serve | 0.5 s | Friendly bright bell-like ding blip signalling a serve, soft arcade, single note |
| point_win | 1 s | Short cheerful victory jingle, four rising marimba notes, playful and upbeat |
| point_big | 2 s | Big excited win stinger: fast rising xylophone run, sparkle shimmer, coin shower, short crowd cheer burst |
| point_lose | 1.5 s | Comedic sad trombone wah-wah-wah-waaah, descending, cartoon fail sound |
| clear | 2.5 s | Triumphant short fanfare, brass and glockenspiel, level complete, ends on a held bright chord |
| game_over | 3 s | Dramatic comic defeat sting: descending slide whistle then a low deflating tuba, cartoon game over |
| buy | 1 s | Cheerful shop purchase: coin clink followed by a bright cash register ding |
| deny | 0.5 s | Short negative error sound, soft double wooden blip meaning "nope", not harsh |
| reroll | 0.75 s | Quick card shuffle with a rising magical sparkle, short dice-roll feel |
| remove | 0.75 s | Paper crumple and a puff of smoke, quick cartoon discard, short |
| click | 0.5 s, trim to ~0.05 s | Soft UI button click, light wooden tick, very short, dry |
| trick | 0.5 s | Short bright sparkle chime, two rising glockenspiel notes, magical and light |
| fire | 1.5 s | Whooshing flame ignition with a crackling roar swell, fireball lighting up, cartoon |

## Music

Both are instrumental and must loop. Ask for a seamless loop; where the generator can't, crossfade the last second into the first in a script.

**rally** (plays during matches)
> Upbeat bouncy quirky instrumental loop for a goofy table tennis roguelike. 132 BPM, A minor, driving bassline, plucky marimba arpeggios, light punchy drums, playful synth lead melody. Energetic but not fatiguing. Seamless loop, no intro, no outro, no vocals, 30 seconds.

**shop** (plays in the ball shop)
> Relaxed jazzy lo-fi shop theme, 96 BPM, A minor. Warm electric piano, soft round bass, brushed drums, whimsical vibraphone melody, cozy and slightly mischievous. Seamless loop, no intro, no outro, no vocals, 30 to 60 seconds.
