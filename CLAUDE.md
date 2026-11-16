# fifteen-dollar-siege

A text-free siege sandbox for desktop and web. Source: a meme kuhy attached to
todo task df2a2bf2. You lead 100 random men with clubs and slingshots against
a 1100 AD village of 2,000, and you get 15 dollars to buy buffs from a list of
25. Three modes run on ONE sim core: **Watch** (buy, then the siege plays
itself), **Command** (the same plus a rally flag and charge / retreat), **Lab**
(one loadout, N headless sieges, the win rate as a number and a ring).
Design, rules and the Core API: `DOCS-design.md`. Menu screens (hub, shop,
Lab, result): `DOCS-menus.md`. The battle screen (layers, controls, showcase,
frame gate): `DOCS-design-battle.md`. The fun pass (what makes it surprising, every
delight and its check): `DOCS-design-fun.md`. Feature map and core flows:
`DOCS-features.md`.

**State (2026-11-16):** everything is real and plays together: the sim
(`DOCS-design-sim.md`; balance 0 % with no buffs, 39.7 % random, 95.8 % best,
all 25 buffs in the top 50), the menus, the battle screen, all sound, the dev
tools, the session recorder, the bots and every gate; the Web build is played
in a browser by a gate. The sim stays behind the Core API contract
(`DOCS-design.md`); its numbers are keyed to its hash (`scripts/balance_gate.sh`
fails on a change nobody re-balanced). Sound: `DOCS-audio.md`.

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
  the `rock_band` riff is original (`DOCS-audio.md` section 3).
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
- **Sound is rendered from code, lossless.** 16-bit 44.1 kHz WAV from
  `tools/audio/` (skill `procedural-music`), never compressed or trimmed.
  The browser starts it at the first touch (`DOCS-audio.md` section 6).
- **Binaries never enter git.** `~/data/fifteen-dollar-siege_binaries/` holds
  `assets/` (the rendered audio), `builds/` (`vNN/` per round) and
  `feedback/`. `assets` and `builds` in the repo are gitignored links made by
  `install.sh`.

## Layout

| Path | Holds | Owner after the scaffold |
|---|---|---|
| `src/core/` | buffs, loadout, map, snapshot, the sim and its systems, lab, fixtures | sim agent |
| `tools/sim/` | balance search, report, pins, the scripted commander (headless) | sim agent |
| `src/app/` | `LaunchOptions` (CLI), `SaveStore` (guarded saves), `WebProbe` (read-only state for the browser gate, only with `?probe`) | shared |
| `src/audio/` | `AudioDirector` (owned by `Main`; `AudioDirector.live()` for the volume API), `FunCue` (the delights' cues), `AudioBank`, `AudioBuses`, `AudioCues` (the cue sheet), `MusicDeck`, `SfxPool`, `BattleMix`, `AudioSettings`, `AudioExit` | audio agent |
| `src/ui/` | `VectorGlyph`, `GlyphTexture`, `Glyphs`, `GlyphButton`, `SevenSegment`, `Palette` (the only file with colour literals) | view and art agents |
| `src/ui/pictograms/` | `Pictogram`, the 25 buff and the menu pictograms, `PictoButton`, `KeyGlyph` + `KeyHint` + `InputDevice` (every key hint of the game) | menu-screen agent |
| `src/view/` | `Main` flow, the five screens, `PauseMenu`, the battle screen with `src/view/battle/` (map, crowd, effects, HUD, camera, and `BattleFlair`: the delights of the fun pass) | view agent |
| `src/view/volume/` | the pause menu's volume control: `VolumeRow`, `VolumeBar`, `VolumeGlyphs`, `VolumeKeys` | view agent |
| `src/view/shop/`, `src/view/lab/` | the shop's tray, cards' coins, vignettes, result scenes, shelf, dice (`ShopDice`, `LoadoutDice`); `src/view/lab/` also holds `StarRating` and `ResultStars`; the Lab's runner, ranking, book | menu-screen agent |
| `src/autodrive/` | the `--autodrive` bots: the flow (`autodrive`, `siege_round`, `menu_beats`), `showcase`, `touch`, `reel` (films one siege), `buffs` (every buff seen and heard, `buff_signs`), `fun` (one siege per fun-pass delight); `bot_commander` plays Command mode (ships in builds too) | whoever changes the flow |
| `src/dev/` | this game's host glue for the dev feedback mode (loaded only with `--dev`): `dev_tools.gd` (mounts the addon), `siege_host.gd`, `siege_context.gd`, `siege_telemetry.gd` | shared |
| `addons/dev_tools/` | NOT in git: the shared dev feedback mode (`kuhyx/utils` `godot_dev_tools`), a gitignored link made by `install.sh` from `scripts/mount_dev_tools.sh` (the only place of the pinned URL and tag) | utils |
| `tools/recording/` | the session recorder (Python) | shared |
| `tools/audio/` | music and effects rendered from code, the offline gate, the boot probe (Python) | audio agent |
| `tools/web/` | the browser smoke gate: isolated headless Chromium over CDP (`smoke.py`, `browser.py`, `venv.sh`) | shared |
| `tests/` | GUT (`test_*.gd`, `view/`, `core/`), `tests/recording/` and `tests/audio/` (unittest) | with the code |
| `scripts/` | every gate; `scripts/lib/` is shared shell | shared |

## Contracts the three agents must keep

- **Core API** (`DOCS-design.md`): signatures only grow. `tests/core/` pins
  them; a contract assertion may not change.
- **View hooks:** `Main` keeps its signals (`screen_changed`,
  `siege_started`, `siege_ended`, `lab_finished`, `loadout_changed`,
  `command_given`, `quitting`), `screen` / `screen_name`, `pause_menu`,
  `menu_button`, `pick_at(point)` and `debug_state()`. Each screen keeps the
  fields its header comment lists: the bot and the dev tools read them.
- **Sound:** every `SiegeEvent` and menu action has a cue in
  `src/audio/audio_cues.gd`; the battle screen calls
  `AudioDirector.on_snapshot` once per snapshot. Volumes change only through
  `AudioDirector.live()`, which saves them (`audio.json`) and sets the buses.
- **Bot:** a mode with no autodrive path is not playable. When the flow
  changes, change `src/autodrive/autodrive.gd` and `bot_frames` in
  `scripts/lib/bot.sh` in the same commit.
- **Dev files:** no `class_name` in `src/dev/`; game code never preloads a
  dev file or the addon (`Main` loads `dev_tools.gd` by path, which loads
  `addons/dev_tools/dev_tools.gd` by path and hands it `siege_host.gd`). No
  addon, no dev mode: one line on stderr, the game plays on.
  `export_presets.cfg` excludes `src/dev/*` and `addons/dev_tools/*`. Change
  the shared mode in `~/src/utils/godot_dev_tools` (tests: `godot_dev_tools/test.sh`),
  tag it `godot-dev-tools-vX.Y.Z`, then bump `PIN_TAG` in
  `scripts/mount_dev_tools.sh` and rerun `./install.sh`. Override for an
  unreleased commit: `SIEGE_UTILS_REMOTE=file:///path SIEGE_UTILS_DEVTOOLS_REF=<hash>`.
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
into a siege | `--seed=N` | `--speed=N` (0.1 to 64, default 2) | `--lab-runs=N` |
`--save-dir=DIR` | `--autodrive=MODE` (a mode, `showcase`, `touch`, `reel`, `buffs` or
`fun`) with `--result-file=`, `--screenshot-dir=`, `--expect-window=WxH`,
`--every=S` (reel), `--shard=I/N` (buffs) |
`--feedback-dir=DIR`, `--session-id=ID`, `--dev-tag=T`,
`--dev-shot=/abs/out.png` (dev tools; the shared addon's README lists them).

## Commands

- run: `./run.sh`
- test: `scripts/test.sh`
- test-changed: `scripts/test_changed.sh`
- lint: `scripts/lint.sh`
- coverage: `scripts/coverage.sh`
- coverage-gaps: `coverage-gaps coverage.xml`

Other gates, each one call under 60 s:

- `./install.sh` tools, GUT, the dev tools mount, export templates, binaries links, git hooks
- `scripts/autodrive_all.sh [mode ...]` the done gate (watch, command, lab,
  `touch` (a finger's whole loop, touch events only), `fun` (one real siege per
  delight of `DOCS-design-fun.md` on screen) and `showcase`: every kind, state, look and event on the battle screen plus
  the 2,400-figure frame gate); frames land in
  `~/data/claude-scratch/fifteen-dollar-siege/<checkout>/shots/<mode>/`
- `scripts/screenshot.sh <out_dir> [mode] [WxH]` one mode's frames
- `scripts/reel.sh <out_dir> <id,id|-> <seed> [every_s] [WxH]` ONE siege on
  the real screen, a frame every few sim seconds plus the payoff (to LOOK)
- `scripts/test_buffs.sh` each of the 25 buffs alone on the battle screen until
  its chip, figure, look, effect and cue show; one frame each (5 shards)
- `scripts/balance_gate.sh` the pinned balance checks (30, about 17 s);
  `scripts/balance_search.sh` (sharded, resumable), `balance_report.sh`,
  `balance_lift.sh <base>`, `balance_quick.sh`: `DOCS-design-sim.md` section 9
- `scripts/art_sheet.sh <kind> <out.png> [WxH]` contact sheet of the
  code-drawn art (`buffs`, `buffs_big`, `ui`, `vignettes`, `vignette`, `shop`)
- `scripts/check_palette.sh` no colour literal outside `src/ui/palette.gd`
- `scripts/test_save_guard.sh` the save guard with the hook's redirect off
- `scripts/test_mount_dev_tools.sh` the mount script: default pin is the GitHub URL and tag, a fixture remote
- `scripts/test_launcher.sh` `run.sh` on a broken GPU GL, plus the F12 bundle
- `scripts/test_recording.sh` recorder unit tests
- `scripts/e2e_recording.sh never|sync|gap|game` recorder on Xvfb, one case
  per call
- `scripts/export.sh <web|linux> <out_dir>` one export
- `scripts/build_round.sh <NN> "<note>"` one prototype round: `builds/vNN/`
  (Web at the top, `linux/`, a `NOTES` line), never overwritten (R17)
- `scripts/test_build_round.sh` that script, in a throwaway folder
- `scripts/test_web.sh` the Web build in an isolated headless Chromium: hub
  drawn, no console error, touch taps reach the shop and a battle, the audio
  context runs and the music advances after the first touch
- `tools/audio/check.sh`, `scripts/coverage.sh` the audio gate and the 100 %
  Python coverage gate

**Every gate runs through `scripts/check.sh`, in groups that each stay under
60 s** (a hook kills any call over that). One call per group:

| Group | Gates | Time |
|---|---|---|
| `scripts/check.sh --group fast` | smoke, lint, static, shared, save_guard, mount, recording | ~15 s |
| `scripts/check.sh --group play` | test | ~35 s |
| `scripts/check.sh --group bots` | autodrive, launcher | ~15 s |
| `scripts/check.sh --group tools` | audio, coverage | ~43 s |
| `scripts/check.sh --group sim` | balance, buffs | ~20 s |
| `scripts/check.sh --group build` | export, round | ~24 s |
| `scripts/check.sh --group web` | web | ~21 s |

`scripts/check.sh <gate> ...` runs single gates, `--list` names groups and
gates, and `--all` runs every group in turn (about 2 minutes: for people and
CI, never in one agent call). A new gate goes into exactly one group
(`scripts/lib/check_groups.sh` refuses anything else). CI runs every group.
