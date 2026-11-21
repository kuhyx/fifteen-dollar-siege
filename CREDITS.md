# Credits

Every asset, tool and borrowed file gets a row here in the same edit that adds
it. No AI-generated art or music (see `CLAUDE.md`).

## Idea

| What | Source | Note |
|---|---|---|
| The premise and the 25 buffs with their prices | an image macro of unknown authorship, attached by kuhy to todo task df2a2bf2 | quoted verbatim, typos kept, in `DOCS-design.md` and `src/core/buff_catalog.gd`; never shown on screen |

Real people and brands named in the source text (a general, a film actor, a
rock band and its song, a novel's monster) appear only in that verbatim repo
data. On screen and in ids they are neutral (`emperor`, `pep_talk`,
`rock_band`, `stitched_monster`); the band's music is not used.

## Engine and tools

| What | Version | Licence | How it gets here |
|---|---|---|---|
| Godot Engine | 4.7.2 | MIT | system package / CI download |
| GUT (Godot Unit Test) | 9.7.1 | MIT | `install.sh` clones the tag into `addons/gut` (gitignored) |
| `game_recording`, the session recorder (`kuhyx/utils`) | `game-recording-v0.1.1` | MIT | `tools/recording/build.sh` installs the pinned git tag into a cached venv |
| `kuhy_credit`, the "Created by kuhy" logo button on the hub (`kuhyx/utils`) | `kuhy-credit-v0.3.0` | MIT | `scripts/mount_credit.sh` fetches the pinned tag; `install.sh` links it at `addons/kuhy_credit` (gitignored, not in this repo) |
| `godot_dev_tools`, the dev feedback mode (`kuhyx/utils`): annotator, toolbar, shapes, glyphs, hint, log, logger, saver, entry | `godot-dev-tools-v0.1.1` | MIT | `scripts/mount_dev_tools.sh` fetches the pinned tag; `install.sh` links it at `addons/dev_tools` (gitignored, not in this repo) |
| gdtoolkit, pre-commit, ruff, coverage | `requirements-dev.txt` | MIT / MIT / MIT / Apache-2.0 | `install.sh` |

## Shared helpers

First written by kuhy for an earlier game of his, then adapted to this one.

| Files here | Note |
|---|---|
| `src/ui/vector_glyph.gd`, `src/ui/glyph_texture.gd` | unchanged |
| `src/autodrive/frame_stats.gd`, `input_synth.gd`, `bot_shots.gd`, `bot_report.gd`, `tools/frame_check.gd`, `scripts/xvfb_run.sh`, `tests/run_tmp.gd` | small adaptations |
| `scripts/check_*.sh`, `scripts/todo_hooks.sh`, the shared-gate workflows | shims over `~/src/utils` |
| `src/dev/` (the host glue), `tests/recording/` e2e helpers, `scripts/e2e_recording.sh`, `scripts/recordings.sh` | rewritten for this game around the two `kuhyx/utils` packages above |

## Art, music, sound

No asset comes from outside the repo. The 25 buff pictograms, the menu and
key pictograms (`src/ui/pictograms/`), the 25 buff vignettes and the result
scenes (`src/view/shop/`) are drawn in code for this game: vector shapes, no
raster, no AI. The pictograms in `src/ui/glyphs.gd` and
`addons/dev_tools/dev_glyphs.gd` (the shared dev tools) are code-drawn placeholders.

### Audio

No sound comes from outside the repo either: no sample, no recording, no AI
model. Every file is rendered from the code in `tools/audio/` (details and
the measurements: `DOCS-audio.md`).

| What | Made by | Note |
|---|---|---|
| Music: `hub_loop`, `battle_base` / `_alarm` / `_hope` / `_dread`, `rock_riff`, `win_stinger`, `lose_stinger` | written for this game as code (`tools/audio/music_*.py`) | original; the rock riff quotes no existing song (`DOCS-audio.md` section 3) |
| 32 battle effects and 10 menu sounds | synthesised in code (`tools/audio/sfx_*.py`) | none sourced |
| `music_theory` toolkit, tag `music-theory-v0.1.0` (kuhyx/utils) | kuhy, MIT | pitch, scales, chords, beat grid, additive synth; `tools/audio/build.sh` installs it into its own venv |
| NumPy 2.5.3 | NumPy developers, BSD-3-Clause | the toolkit's one dependency (its pin) |
| Luke Haas, "Music Theory for Programmers" (runjs.app) | the article the toolkit ports | theory only, no code or audio taken |
| Loudness method | ITU-R BS.1770-4; the K-weighting filter design follows pyloudnorm (MIT) | `tools/audio/loudness.py` |
| Filter formulas | Robert Bristow-Johnson, "Audio EQ Cookbook" | the biquad responses in `tools/audio/dsp.py` |

Reference pieces named as a quality bar only, nothing quoted: Robert
Euvino's Stronghold (2001) soundtrack; late-1970s twin-guitar hard rock.
