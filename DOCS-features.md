# FEATURES: fifteen-dollar-siege

> Feature map + core-flow ground truth (skill: `e2e-ground-truth`). Keep it
> current: a user-visible change updates its row in the same commit. "How to
> reach it" is a path a driver can follow; "expected outcome" is something a
> check can observe.

- **Primary target:** Godot 4.7.2, Linux desktop and single-threaded Web
- **Driver:** the game's own `--autodrive=<mode>` bot on a private Xvfb
  (`scripts/autodrive_all.sh`), muted, under 60 s; never `godot-mcp-runtime`
- **Run one flow:** the command in the table (each is one call under 60 s)
- **Artefacts:** `~/data/claude-scratch/fifteen-dollar-siege/<checkout>/shots/<mode>/NN_<beat>.png`;
  a failed run keeps its log dir and prints the path

## Feature map

| feature | how to reach it | expected outcome |
|---|---|---|
| Hub | start the game | three pictogram buttons (eye, flag, bar chart) and a menu button, all inside the viewport, no words |
| Pause menu | Esc, pad B or the menu button on any screen | the tree pauses; resume, hub and quit buttons; Esc closes it; the hub button returns to the hub |
| Loadout | hub -> a mode button | 25 cards in price rows 5 to 1, each with coins for its price; 15 budget coins; the army size as a number |
| Buy / sell | click a card | the card gets a green frame and a check, budget coins dim, the army number follows `fifty_men` / `double_men` |
| Budget refusal | click a card that costs more than is left | the card shakes red; cost and loadout unchanged |
| Remembered loadout | open a mode's loadout again | last time's picks for that mode are bought already |
| Watch | hub -> eye -> go | every man and villager is a drawn figure on a map with a church; two morale bars, an alarm bell, a hold-the-centre ring and a clock; it ends by itself |
| Speed and hold | battle: Space / 1 2 3 4, or the buttons bottom left | the sim stands still or runs at x1, x2, x4, x8; each button shows its key |
| Camera | battle: wheel or pinch, drag; 0 or the view-finder button | zoom and pan by hand; back to framing the action by itself |
| Command | hub -> flag -> go | as Watch, plus: a click on the map plants a rally flag (a drag only pans), Enter / Backspace or the buttons charge and retreat |
| Staged beats | a siege whose first snapshot has `ufo_abduct` or `pep_talk` | they play before the clock starts; Space, Enter, a tap or the skip button cuts one short |
| Payoff | the sim decides | on the battle screen: the camera goes to the church and the army's flag climbs its tower (win), or the army burns (lose), before the result opens |
| Showcase | `scripts/autodrive_all.sh showcase` | 22 frames: every kind in every state, six looks, every event, both beats, both payoffs, 2,400 figures inside the frame budget |
| Result | after the payoff | a green flag or a red flame, one home button -> hub |
| Lab | hub -> bar chart -> go | N sieges run without a hitch; a ring and a percent number show the win rate, a bar the runs done, a number the mean seconds |
| Dev annotate | `./run.sh`, then F12, the camera glyph or the pause menu's camera | the frame freezes; toolbar rect, arrow, circle, pen, text, select, undo, clear; a save writes the bundle folder and a Markdown entry under `~/data/fifteen-dollar-siege_binaries/feedback/` |
| Session recording | `./run.sh` (kuhy's own play only) | `feedback/recordings/<session>.mkv` with moments as chapters; `scripts/recordings.sh latest` lists them |
| Straight into a siege | `./run.sh --mode=watch --loadout=double_men,stew --seed=7` | the battle opens with that loadout and seed |

## Core flows

| id | goal | command | last green |
|---|---|---|---|
| F1 | Watch: buy through the cards, win once, combust once, pause works | `scripts/autodrive_all.sh watch` | 2026-11-16, scaffold |
| F2 | Command: the same plus rally, retreat and charge reach the sim | `scripts/autodrive_all.sh command` | 2026-11-16, scaffold |
| F3 | Lab: a batch per loadout, 100 % for the winner and 0 % for the loser (stub rule) | `scripts/autodrive_all.sh lab` | 2026-11-16, scaffold |
| F4 | `run.sh` starts on a broken GPU GL and F12 saves a complete bundle | `scripts/test_launcher.sh` | 2026-11-16, scaffold |
| F5 | The exported Linux build plays without the dev tools | `scripts/test_export.sh` | 2026-11-16, scaffold |
| F6 | Battle screen: every kind, state, look and event is drawn; no frame of 2,400 figures over budget | `scripts/autodrive_all.sh showcase` | 2026-11-16, battle view |

On failure a bot flow prints `AUTODRIVE FAIL: <the assert that broke>`, then
`<label>: FAILED (<why>; exit <n>, log <path>)`, keeps its run directory
(log, verdict, frames so far) and exits non-zero. F4 and F5 print the tail of
the game's log and the same `FAILED` line.

F3's expected numbers are the stub's. When the real sim lands, F1-F3 keep
their steps and change only which loadouts they call a win and a loss
(`WIN_IDS`, `LOSE_IDS` in `src/autodrive/autodrive.gd`).
