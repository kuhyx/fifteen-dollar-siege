# fifteen-dollar-siege

A text-free siege sandbox for desktop and web. Source: a meme kuhy attached to
todo task df2a2bf2. You lead 100 random men with clubs and slingshots against
a 1100 AD village of 2,000, and you get 15 dollars to buy buffs from a list of
25. Three modes run on ONE sim core: **Watch** (buy, then the siege plays
itself), **Command** (the same plus a rally flag and charge / retreat), **Lab**
(one loadout, N headless sieges, the win rate as a number and a ring).
Design, rules and the Core API: `DOCS-design.md`. Feature map and core flows:
`DOCS-features.md`.

**Scaffold state (2026-11-16):** the sim in `src/core/siege_sim.gd` and the
screens in `src/view/` are STUBS behind a fixed contract. Three agents build
the real sim, view and art against it.

## Settled decisions

- **Godot 4.7.2, GDScript, Compatibility renderer** (the web build needs it).
  Base 1920x1080, stretch `canvas_items`, aspect `expand`. Linux desktop plus
  a single-threaded Web export. Mouse first; touch works through the same
  buttons (the menu button stands in for Esc).
- **Zero visible text (textgate).** Pictograms, coins, bars, seven-segment
  numbers (`SevenSegment`), motion and sound only. Every icon-only control
  sets `accessibility_name`. A buff's `source_text` is repo data and the
  card's accessibility label; it is never drawn.
- **No real names or brands on screen.** Buff ids are neutral (`pep_talk`,
  `emperor`, `rock_band`, `stitched_monster`). The verbatim meme text, typos
  included, lives only in `BuffCatalog.ROWS`; never "fix" it. No AC/DC music:
  an original riff comes later (skill `procedural-music`).
- **No AI art.** Procedural or code-drawn first, then sourced CC0 with a
  `CREDITS.md` row in the same edit. Pictograms are `VectorGlyph` shapes in a
  128-unit square, never fixed-size rasters. Never shrink or compress assets.
- **Rules:** 15 dollar cap, each buff at most once, unspent dollars are lost,
  "+50 men" applies before "double" (300 men). Win: village morale breaks OR
  the army holds the village centre 30 s. Lose: army dead or routed (it then
  combusts).
- **Pure core.** `src/core` has no Node, scene, global RNG or clock. The same
  loadout, seed and orders give the same `state_hash()` sequence. Core API
  changes are additive only.
- **Binaries never enter git.** `~/data/fifteen-dollar-siege_binaries/` holds
  `assets/`, `builds/` and `feedback/`. `assets` and `builds` in the repo are
  gitignored links made by `install.sh`.

## Layout

| Path | Holds | Owner after the scaffold |
|---|---|---|
| `src/core/` | buffs, loadout, map, snapshot, sim, lab | sim agent |
| `src/app/` | `LaunchOptions` (CLI), `SaveStore` (guarded saves) | shared |
| `src/ui/` | `VectorGlyph`, `GlyphTexture`, `Glyphs`, `GlyphButton`, `SevenSegment`, `Palette` | view and art agents |
| `src/view/` | `Main` flow and the five screens, `PauseMenu` | view agent |
| `src/autodrive/` | the `--autodrive` bot (ships in builds too) | whoever changes the flow |
| `src/dev/` | dev feedback mode, loaded only with `--dev` | shared |
| `tools/recording/` | the session recorder (Python) | shared |
| `tests/` | GUT (`test_*.gd`), `tests/recording/` (unittest) | with the code |
| `scripts/` | every gate; `scripts/lib/` is shared shell | shared |

## Contracts the three agents must keep

- **Core API** (`DOCS-design.md`): signatures only grow. `tests/core/` pins
  them; a stub-only assertion may change, a contract assertion may not.
- **View hooks:** `Main` keeps its signals (`screen_changed`,
  `siege_started`, `siege_ended`, `lab_finished`, `loadout_changed`,
  `command_given`, `quitting`), `screen` / `screen_name`, `pause_menu`,
  `menu_button`, `pick_at(point)` and `debug_state()`. Each screen keeps the
  fields its header comment lists: the bot and the dev tools read them.
- **Bot:** a mode with no autodrive path is not playable. When the flow
  changes, change `src/autodrive/autodrive.gd` and `bot_frames` in
  `scripts/lib/bot.sh` in the same commit.
- **Dev files:** no `class_name` in `src/dev/`; game code never preloads a
  dev file (`Main` loads `dev_tools.gd` by path). `export_presets.cfg`
  excludes `src/dev/*`.
- **Saves:** go through `SaveStore`. Tests and bots never touch the real
  save: see "Save guard" below.

## Run rules for agents

- Every heavy command: `~/.claude/scripts/capped.sh timeout 55 <cmd>`. Every
  `godot` run is `--headless` or on a private Xvfb with `--audio-driver
  Dummy`. Nothing opens on display `:0`, plays sound or runs past 60 s.
- Never run `./run.sh` plainly: it is kuhy's windowed, recorded launcher.
- Never hand-build a GUT command. Use `scripts/test.sh` (one file:
  `scripts/test.sh -gselect=test_loadout`). Never pass `-gconfig=`.
- After adding or renaming a `class_name`: `godot --headless --path .
  --import`, and commit the `.uid`. `--import` does not report parse errors
  in scripts without a `class_name` (all of `src/dev/`): run them.
- Copy a screenshot before Reading it; a hook downscales files in place.
- 250 lines per file, no lint suppressions, no `TODO*.md` (tasks go to the
  todo app, repo `kuhyx/fifteen-dollar-siege`).

## Save guard (R11, lessons L10 and L11)

Three layers keep a test away from `user://save`:
`scripts/test.sh` points `user://` at a throwaway folder (`XDG_DATA_HOME`);
`tests/pre_run.gd` moves `SaveStore.root` into the run's own folder
(`tests/test_save_guard.gd` is red without it); `SaveStore.blocked` refuses
the real save in any GUT process (`scripts/test_save_guard.sh` proves it with
the hook's redirect off). Bots refuse to start without `--save-dir`.

## Dev feedback mode (R10)

`./run.sh` passes `--dev`. F12, the camera glyph (top right) or the camera in
the pause menu freeze the frame. The toolbar has rect, arrow, circle, pen,
text label, select entity (keys R A C P T S), undo (Ctrl+Z), clear, a typed
note, save (Enter) and cancel (Esc; with unsaved work the first press only
arms it). A save writes `<stamp>/` with `screenshot.png`, `annotated.png`,
`report.json` (marks and selected entities in PNG pixels), `game.log` and
`snapshot.json`, plus an entry in `feedback-<date>.md`, all under
`~/data/fifteen-dollar-siege_binaries/feedback/`. The feedback inbox turns
each bundle into a todo task. F9 wipes the saved loadouts. kuhy's own dev play
is recorded beside the game with moments as chapters
(`scripts/recordings.sh latest`); bots, tests and muted runs never are.

## Game CLI (after `--`)

`--dev` | `--mode=watch|command|lab` with `--loadout=id,id` opens straight
into a siege | `--seed=N` | `--speed=N` (0.1 to 64) | `--lab-runs=N` |
`--save-dir=DIR` | `--autodrive=MODE` with `--result-file=`,
`--screenshot-dir=`, `--expect-window=WxH` | `--feedback-dir=DIR`,
`--session-id=ID`, `--dev-tag=T`, `--dev-shot=/abs/out.png` (dev tools).

## Commands

- run: `./run.sh`
- test: `scripts/test.sh`
- test-changed: `scripts/test_changed.sh`
- lint: `scripts/lint.sh`
- coverage: `scripts/coverage.sh`
- coverage-gaps: `coverage-gaps coverage.xml`

Other gates, each one call under 60 s:

- `./install.sh` tools, GUT, export templates, binaries links, git hooks
- `scripts/autodrive_all.sh [mode ...]` the done gate; frames land in
  `~/data/claude-scratch/fifteen-dollar-siege/<checkout>/shots/<mode>/`
- `scripts/screenshot.sh <out_dir> [mode] [WxH]` one mode's frames
- `scripts/test_save_guard.sh` the save guard with the hook's redirect off
- `scripts/test_launcher.sh` `run.sh` on a broken GPU GL, plus the F12 bundle
- `scripts/test_recording.sh` recorder unit tests
- `scripts/e2e_recording.sh never|sync|gap|game` recorder on Xvfb, one case
  per call
- `scripts/export.sh <web|linux> <out_dir>` one export (`builds/vNN/` per
  round, R17)
- `scripts/check.sh [gate ...]` every gate; `scripts/check.sh --list` names
  them
