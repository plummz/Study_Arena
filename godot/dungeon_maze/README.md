# Dungeon of Knowledge

Godot 4.7 first-person module for Study Arena (Compatibility renderer, so the same
project runs on desktop and as WebAssembly on GitHub Pages under `/dungeon/`).
Start it locally from the repository root with `Start-Dungeon-Maze.cmd`.

## Controls

- Click the game to capture the mouse, then move the mouse to look (arrow keys also look)
- WASD: walk · hold Shift: run · Space: jump (clears traps and bone serpents)
- M: map · Escape: pause, settings, save, or return to Study Arena
- Walk up to a skeleton or scholar to open its question; 1–4 answer, H hint, Enter continue

On phones and tablets, rotate to landscape: the left stick moves, dragging the right
half looks around, RUN (toggle) and JUMP sit bottom-right, and pause (II) and MAP sit
upper-left. Controls are sized from the screen's short side, and the whole interface is
enlarged 30% on touch screens. Pause → Settings has **Touch look speed** and **Touch
control size** (saved on the device). `-- --touch-preview` shows the controls on a desktop.

GitHub Pages must use **GitHub Actions** as its publishing source; the legacy
"Deploy from a branch" source omits the generated WebAssembly dungeon.

## Runs, questions and coins

- **Signed-in runs** (launched from the Dungeon page with competition enabled) are
  authoritative on the Study Arena server: `POST /api/dungeon/runs` returns a run id
  and a short-lived ticket, and the game fetches questions, submits answers and buys
  hints through `/api/dungeon/runs/{id}/…` with the `X-Dungeon-Ticket` header. The
  server picks questions from approved quizzes and the student's own (plus approved
  public) flashcards, grades answers, awards coins, rolls Mercy Tokens and records the
  outcome. The client never sees correct answers before it submits.
- **Practice runs** (no ticket, offline, or signed out) use the built-in explained
  question bank in `scripts/practice_bank.gd`. The HUD shows
  "Practice run — coins are not saved".
- Every question is single-attempt. Resolve every encounter without running out of
  wrong answers, then walk through the Victory Arch at the EXIT.

## Rules by difficulty

The question count sets the maze size, so every run stays a compact crawl (runs are capped
at 50 questions; the server serves exactly this many and the game sizes its maze to match).

| | Easy | Average | Hard | Hell |
|---|---|---|---|---|
| Questions (encounters) | 20 | 30 | 40 | 50 |
| Maze (4 m cells) | 15×15 (60 m) | 17×17 (68 m) | 19×19 (76 m) | 21×21 (84 m) |
| Themed chambers | 2 | 3 | 4 | up to 5 |
| Timer | 8 min | 12 min | 16 min | 20 min |
| Wrong answers allowed | 5 | 5 | 4 | 3 |
| Hint price (removes two wrong choices) | 2 | 3 | 4 | 5 |
| Traps / penalty | 6 / −10 s | 9 / −15 s | 12 / −20 s | 16 / −30 s |
| Bone serpents / penalty | 3 / −8 s | 4 / −10 s | 5 / −14 s | 6 / −20 s |
| Relics | 6 | 7 | 8 | 8 |
| Friendly scholars | ~34% | ~28% | ~22% | ~16% |

Across 40 seeds per difficulty (`-- --size-report`), the entrance-to-exit walk averages
29–37 cells (about 115–150 m), and every maze has at least twice the cells its encounters
and hazards need.

Harder runs field more Skeleton Warriors and Mages. Answering a scholar correctly
marks nearby traps on the map for 45 seconds; otherwise traps appear once spotted.

## Relics (map boosts) and buffs

Relics float on small pedestals around the maze (Easy 6, Average 7, Hard 8, Hell 8).
Walk into one to claim it; active buffs appear as chips under the timer, and relics show
on the map once spotted (or everywhere while the Scholar's Lens is active).

| Relic | Effect |
|---|---|
| Swiftness Draught | +40% move speed for 30 s |
| Bone Ward | Blocks the next trap or bone serpent (stacks) |
| Scholar's Lens | Traps and relics shown on the map for 60 s |
| Spring Step | ~30% higher jumps for 30 s |
| Radiant Lantern | Lantern lights twice as far for 60 s |
| Hourglass Shard | +45 s (practice runs; becomes a Bone Ward on signed-in runs, whose time limit is enforced by the server) |

Timed buffs stack up to double their duration. Buffs and claimed relics are saved.

## Defeat animations

- Correct answer: the skeleton flashes white, is knocked back, collapses, scatters
  tumbling bones and burns away from the head down with glowing embers as its soul rises;
  a "+1 ◉" pops up when a coin is earned. Scholars ascend in golden light instead.
- Wrong answer: the enemy gloats, then melts into purple shadow.
- Losing (out of wrong answers or time): the staff drops, the view falls and rolls onto
  the floor, and the screen fades before the results panel. Reduced motion uses a gentle
  sink instead of the roll.

## World and presentation

- The maze (15×15 to 21×21 by difficulty, with loops and themed chambers drawn from crypt,
  library, treasure vault, candle shrine and armory) is built from KayKit modular pieces batched into chunked
  MultiMeshes. Wall-mounted torches share a pool of 12 moving lights (6 on Low).
- Enemies and NPCs are animated 3D KayKit characters that stream in near the player;
  skeletons lie dormant and rise when you approach.
- All sound is synthesized at start-up (no audio files). Optional captions describe
  important sounds.
- Settings (pause menu): look sensitivity, field of view, invert Y, volume, reduced
  motion (no head bob, shake, flicker or film grain), captions, and High/Low quality.
  `?quality=low` (web) or `-- --quality=low` forces Low.

Progress saves every eight seconds, on pause and on close. Signed-in runs resume from
the server's answered questions.

## Developer checks

```
godot --headless --path . --import
godot --headless --path . -- --smoke            # practice-run assertions, prints DUNGEON_SMOKE_PASS
godot --headless --path . -- --size-report      # maze capacity / chambers / exit distance per difficulty
godot --path . -- --screenshots=<dir>           # renders fixed views + FPS/draw calls to PNG
godot --headless --path . -- --linked-smoke --api=<url> --run=<id> --ticket=<ticket>
```

`tools/` holds model-inspection scripts; it is excluded from exports.
Third-party asset credits are in `THIRD_PARTY_NOTICES.md` at the repository root.
