# Audio: music, sound effects, the director

Record of what is decided for sound. The screen has no words, so sound is a
main information channel: drums mean the village knows, a horn means it is
breaking. Nothing here is a task. Nobody has LISTENED to any of it yet: every
file is measured (section 7), the final check is kuhy's ears.

## 1. What plays

All files are code-rendered 16-bit 44.1 kHz PCM WAV in `assets/audio/`
(`~/data/fifteen-dollar-siege_binaries/assets/audio/`, never in git).
Music is stereo, effects are mono and placed by the game.

| File (`music/`) | Length | Key | Tempo | Role |
|---|---|---|---|---|
| `hub_loop` | 41.74 s, 32 bars of 6/8 | D dorian | 138 quarters (92 pulses) | hub, shop, Lab, after a stinger |
| `battle_base` | 32.00 s, 16 bars | D minor | 120 | the sneak: tip-toe pizzicato, pad, heartbeat drum |
| `battle_alarm` | 32.00 s | D minor | 120 | war drums and a string ostinato |
| `battle_hope` | 32.00 s | D minor | 120 | horn tune, kettle drums |
| `battle_dread` | 32.00 s | D minor | 120 | shaking low strings, sighs, lament bass |
| `rock_riff` | 16.00 s, 8 bars | D minor pentatonic + flat fifth | 120 | the `rock_band` buff |
| `win_stinger` | 4.71 s | D major | 132 | the flag goes up |
| `lose_stinger` | 5.25 s | D minor | 96 | the army combusts |

Effects: 32 in `sfx/`, 10 in `ui/`, all synthesised, none sourced. The cue
sheet `src/audio/audio_cues.gd` maps every `SiegeEvent.ALL` name and every
menu action to a file; no event is silent.

| Event | Sound | Event | Sound |
|---|---|---|---|
| `command` | horn call per order: two toots (rally), a leap up (charge), a fall (retreat) | `wasp_swarm` | three wingbeat tones fluttering past |
| `alarm` | two horns a semitone apart lurch up, a snare | `moose_charge` | a bellow through a nose, hooves |
| `bell_ring` | church bell on D | `cart_crash` | "meep meep", then a crash and rattle |
| `sling_volley` | whirl and snap (3 takes) | `monster_smash` | ground thump and a growl |
| `arrow_volley` | bowstring and hiss (2 takes) | `trumpet_call` | two notes, a leap, the top note cracks |
| `melee_clash` | wood knock (3 takes) | `band_riff` | one distorted low D chord; the riff loop takes the bed |
| `squad_rout` | slide whistle down, feet (village higher, army lower) | `reveal` | a pop up and three sparkles |
| `squad_rally` | short rising horn | `ufo_abduct` | wavering rise, throbbing beam, zip |
| `squad_wiped` | thud and a sinking tone | `pep_talk` | four gruff "mwah" syllables, the men grunt back |
| `shotgun_blast` | flat boom with an echo | `centre_held` | kettle drum that climbs with `progress` |
| `pumpkin_launch` | creak, crack, whoosh | `victory` | a crowd's "aaah" (plus the win stinger) |
| `pumpkin_splat` | squelch, thud, two drips | `combust` | flame whoomp and crackle (plus the lose stinger) |
| `heal` | four chimes up D major | | |
| `fun_toll` | a bright bell and a fifth above, higher with each tally | `fun_heartbeat` | lub, dub |
| `fun_glint` | a twinkle off steel | `fun_dice` | a rattle, two dice land |
| `fun_star` | a small bell and a shimmer; climbs with each star | `fun_firework` | a whistle, a burst, crackle |
| `fun_hic` | a squeak that jumps and falls | `fun_tick` | the `centre_tick` file, for the prep clocks |

Menu: `ui_buy` (coins up), `ui_unbuy` (coins down), `ui_refuse` (two dull
knocks), `ui_go` (war drum and horn), `ui_mode` (lute strum), `ui_pause` /
`ui_resume` (two notes down / up), `ui_lab_tick` (high for a win, low for a
loss), `ui_lab_done` (two bells, higher the more wins), `ui_button` (wooden
click on any other button).

## 2. How it is built

`./install.sh` runs `tools/audio/build.sh`: a venv with the pinned toolkit
(`tools/audio/requirements.txt`: `music_theory` tag `music-theory-v0.1.0`,
skill `procedural-music`), then `render.py`, then the offline gate. Theory
comes from the toolkit (`pitch`, `scales`, `progressions`, `sequencer`'s
beat grid and `NoteEvent`, `synth.additive` / `adsr`, `analysis`,
`manifest`). The tag has no filters, noise, drums or stereo, so
`tools/audio/dsp.py`, `voices.py`, `drums.py`, `guitar.py` add them.
`MANIFEST.json` beside the files records recipe, seed, toolkit version and
SHA-256; a file whose entry matches the code is not rendered again.

| Command | Does | Time |
|---|---|---|
| `tools/audio/build.sh [--force]` | render stale files, run the gate | ~15 s clean, ~4 s current |
| `tools/audio/check.sh` | tool tests, staleness, the gate, the boot probe | ~6 s |
| `tools/audio/demo.sh [out.wav]` | "a siege in 20 seconds" through the real director, to `~/data/claude-scratch/fifteen-dollar-siege/audio/` | ~25 s |
| `tools/audio/render.py --list` | every file, kind and loudness target | |

Seeds: hub 20261116, battle 20261117 (+1 per stem), rock 20261118, stingers
20261119; each effect is seeded from its name.

## 3. The music, and the rock riff

One tonal centre, D, for the whole game: hub in D dorian, battle in D minor
(one scale step lower, B to B flat), the win in D major (one chord tone
higher, F to F sharp). Pitched effects sit on D and A.

The buff's source text names a real band and song. The game uses neither.
`rock_riff` is original and differs on every axis a listener would name:

| | `rock_riff` | the song in the source text |
|---|---|---|
| Key | D minor pentatonic with the blues flat fifth, on a dropped low D | B major |
| Tempo | 120, a mid-tempo stomp | about 134 |
| Rhythm | syncopated power-chord stabs and rests between palm-muted chugs; the F chord pushed onto the "and" of two | an unbroken stream of sixteenths on one string |
| Melody | chords D5 F5 G5, answered C5 D5, then F5 G5 B-flat5 C5 and a blues-scale run | a pedal-point figure against an open string, a chanted hook |

Reference pieces for the quality bar (nothing quoted): Robert Euvino's
Stronghold (2001) cues for the hub and the bed; late-1970s twin-guitar hard
rock for the riff. The skill's blind A/B against a reference is not done:
it needs a listener.

## 4. The director

`Main` owns one `AudioDirector` node (`add_child(AudioDirector.new())` in
`_ready`). It is not an autoload: it follows `Main`'s signals, and a test
gets a fresh one with each main scene.

- **Music** (`MusicDeck`): `screen_changed` picks hub or battle; `siege_ended`
  plays a stinger over the fading bed and the hub loop returns when it ends.
  The bed is five loops in one `AudioStreamSynchronized` (sample-locked).
- **Menus:** `loadout_changed`, `LoadoutScreen.refused`,
  `HubScreen.mode_picked`, `siege_started`, `PauseMenu.toggled`,
  `lab_finished`, the Lab's `result` counts, and every `BaseButton` under
  `Main` (a press that already played a cue does not click as well).
- **Battle:** ONE entry point, called once per new snapshot:

  ```gdscript
  AudioDirector.on_snapshot(shot, Rect2(camera.to_map(Vector2.ZERO), size / camera.zoom))
  ```

  `view_rect` is the part of the MAP on screen, in map metres. An event
  left of its centre sounds on the left; outside it, 9 dB quieter per view
  width (at most 12). Without a camera pass `sim.map().bounds`. The call is
  static and does nothing when no director exists.
- **Silent runs:** a bot (`--autodrive`) and a GUT run mute both buses; the
  players still play, so tests can see them. With no audio files every call
  is a quiet no-op.
- **Volume:** `AudioDirector.live()` then `set_music_volume(0..1)`,
  `set_sfx_volume(0..1)`, `set_muted(bool)`, `toggle_muted()`; saved in
  `audio.json` through `SaveStore`, restored at boot. The pause menu draws the
  control (`DOCS-menus.md`, "Pause menu and volume"): ten steps per channel.

The delights (`FunCue.play(cue, pitch, at)`, `AudioDirector.fun`) join these
rules: they use the battle voices (a pause stops them, the menu voices go on),
`at` (map metres) is placed against the view of the last `on_snapshot` and
without it the cue is central, and each one counts in `heard`, like a battle
cue asked for.

Events of one kind in one snapshot become ONE sound at their mean position,
up to 4 dB louder for a crowd. A cue then waits its `gap` before it may
start again and never holds more than its `voices` (a new start takes its
own oldest voice). The pool has 20 voices; when full, a sound of rank 2 or 3
(orders, alarm, UFO, pep talk, centre held, the endings) takes the oldest
lower-ranked voice and others are dropped.

Bed mix (`BattleMix.targets`), each stem gliding there in 1.2 s:

| Stem | Level |
|---|---|
| base | 1, falling to 0.55 as the drums come in |
| alarm | smoothstep(0.05, 0.6, `alarm`) |
| hope | smoothstep(0.2, 0.75, 1 - `village_morale`), halved by full dread |
| dread | smoothstep(0.2, 0.75, 1 - `army_morale`), halved by full hope |
| rock | 1 for 8 s after each `band_riff` (the sim sends one every 6 s); the other four at 0.15 |

## 5. Constants

Every value is a `[design guess]` unless a source is named.

| Constant | Value | Source |
|---|---|---|
| sample format | 16-bit PCM, 44.1 kHz | the brief; build-game R13 |
| full-mix loudness | -18 LUFS (hub), -17.5 (riff) | Sony ASWG-R001: portable target -18 +-2 |
| stem / stinger / effect / menu targets | -21..-22 / -16.5..-17 / -15..-21 / -17.5..-27 | `[design guess]` by role |
| `catalog.CEILING_DB` | -1.5 dBFS | under EBU R 128's -1 dB peak |
| `AudioSettings.DEFAULT_MUSIC`, `DEFAULT_SFX` | 0.7, 1.0 | `[design guess]`: effects are the news |
| `AudioBuses.CEILING_DB` | -0.5 dB | `[design guess]` |
| `MusicDeck.FADE_S`, `LAYER_S`, `DUCKED` | 0.6 s, 1.2 s, 0.35 | `[design guess]` |
| `AudioDirector.ROCK_HOLD_S` | 8 s | over the sim's 6 s riff period |
| `SfxPool.VOICES`, `PAN_STRENGTH` | 20, 2.4 (about 80 : 20 at the edge) | `[design guess]` |
| cue `gap`, `voices`, `jitter`, `rank`, `db` | `AudioCues.CUES` | `[design guess]` |
| `BattleMix` thresholds | section 4 | `[design guess]` |

## 6. Godot traps found here

- **A looping WAV skips frame 0.** Godot 4.7.2 imports `loop_end` as the last
  frame index, plays that frame, then continues from frame 1: a file of L
  frames loops every L - 1. So `wavio.write(loop=True)` appends the first
  frame again and Godot repeats exactly L. `test_audio_bank.gd` mixes across
  the wrap with `AudioStreamPlayback.mix_audio` and compares it with the
  start of the file.
- **A WAV imports lossy by default** (Quite OK Audio). The renderer writes
  each `.import` sidecar (`compress/mode=0`, loop mode 2 or 1); the test
  checks the loaded stream, not the sidecar.
- **`AudioStreamPlayback.start(seconds)` truncates to a frame:** `N / rate`
  can land a frame early. Tests add half a frame.
- **Exit message:** a player that was playing at exit left its playback with
  the audio server, which frees it on its next mix step, so Godot printed "1
  resources still in use at exit" (found with `godot --verbose`: the hub loop).
  `AudioExit.settle` stops every voice as the director leaves the tree and waits
  100 ms (a few mix steps; not in a GUT run). The smoke gate and every bot
  verdict fail on that line.
- **Web:** music players force `PLAYBACK_TYPE_STREAM` (sample playback
  cannot run a synchronized stream). `scripts/test_web.sh` plays the export in
  headless Chromium: before a touch the audio context is `suspended`, after the
  first touch it is `running` and the hub music starts, and in a battle the
  bed's position advances. No "tap to start" screen is needed: the engine
  resumes the context on the first gesture. The mixer works frame by frame on
  the single thread, so the gate counts sound per frame (software GL runs the
  page at a few frames a second).

## 7. Offline gate (`tools/audio/analyze.py`, limits in `checks.py`)

| Fault | Limit | Source |
|---|---|---|
| `sample_rate` | at least 44100 Hz | the brief |
| `clipping` | peak over -1 dBFS, or 3 frames at full scale | EBU R 128 |
| `silence` | RMS under -60 dBFS | `[design guess]` |
| `dc_offset` | mean over 0.002 | `[design guess]` |
| `loudness` | music -20..-16, stem -26..-19, stinger -20..-14, sfx -26..-12, ui -30..-16 LUFS | ASWG-R001 for full mixes; the rest `[design guess]` |
| `loop_seam`, `loop_frame` | the wrap steps over 2x the file's own 99.9th-percentile step; no closing frame | `[design guess]` |
| `shrill` (effects) | spectral centroid over 4000 Hz | ISO 226: the ear is keenest at 2 to 5 kHz |
| `late_start`, `abrupt_start`, `abrupt_end` (one-shots) | 20 ms of silence first; first or last frame over 0.004 | `[design guess]` |
| `missing`, `unlisted` | manifest and folder disagree | |

Loudness is ITU-R BS.1770-4: gated programme loudness for music, the
loudest 100 ms for an effect (`loudness.py`; a 997 Hz full-scale sine reads
-3.01 in its test). Measured 2026-11-16: 57 of 57 files clean (7 fun cues added); music
-18.0 / -17.5, stems -22.0..-21.0, stingers -17.0 / -16.5, effects
-21.0..-15.0, menu -27.0..-17.5 LUFS; worst loop seam 0.52x; highest effect
centroid 2644 Hz. The demo mix (23 s) peaks at -4.1 dBFS and reads -18.7 LUFS.

## 8. Not done

No ear has judged any of it; no blind A/B. Python coverage of `tools/audio`
and the recorder is 100 % branch (`scripts/coverage.sh`, a gate of
`scripts/check.sh`); the web harness (`tools/web`) is a browser end-to-end
check and has no unit tests.
