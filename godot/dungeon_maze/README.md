# Dungeon of Knowledge

Godot 4.7 module for Study Arena. Start it from the repository root with
`Start-Dungeon-Maze.cmd`.

## Controls

- WASD: walk
- Hold Shift: run
- Space: jump
- Arrow keys: orbit and tilt the third-person camera
- M: toggle the dungeon map
- Escape: pause, save, resume, or return to Study Arena
- Walk into an NPC or enemy: answer its question

## Current rules

- 100 encounters and 24 one-use traps are generated per run.
- Correct answer: one maze coin and a slaying effect.
- Wrong answer: enemy skill effect and one lost mistake allowance.
- A correct answer has a server-independent 5% prototype chance to add one
  Mercy Token and one mistake allowance.
- Timers: Easy 30m, Average 45m, Hard 60m, Hell 80m.
- Wrong-answer limits: Easy 10, Average 7, Hard 5, Hell 3.
- Hint prices: Easy 2, Average 3, Hard 4, Hell 5 maze coins.
- Progress is saved every eight seconds, whenever the game is paused, and when
  the window closes. A saved run restores the exact maze, player position,
  timer, cleared encounters, coins, mistake allowance, and selected companion.
- Victory and game-over screens provide **Try Again** and **Return to Study
  Arena** actions.

The current arithmetic bank and in-run coins are a gameplay prototype. Before
release, question selection, random rewards, and wallet credits must be moved
to the authenticated Study Arena server so clients cannot forge rewards.
