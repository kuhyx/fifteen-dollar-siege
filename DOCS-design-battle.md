# Design: the battle screen

Record of how the siege is drawn and controlled. The rules and the Core API
are in `DOCS-design.md`; nothing here is a task.

## 1. What is on screen

| Layer (back to front) | File | Draws |
|---|---|---|
| Map | `src/view/battle/map_layer.gd`, `map_plan.gd` | grass, fields, the path, the village yard, houses as roofs, the church with its bell tower, trees, the camp |
| Crowd | `crowd_layer.gd`, `squad_visual.gd`, `crowd.gdshader` | one figure per head of every entity |
| Effects | `battle_effects.gd`, `fx_*.gd` | one effect per sim event, the rally flag, the centre ring, the win flag |
| HUD | `battle_hud.gd`, `hud_meters.gd`, `hud_button.gd` | meters, speed and camera buttons, orders |

The first three sit in one `world` node whose transform is the camera, so
their unit is the metre and everything is vector: sharp at any zoom and any
window size.

**The map adds what `SiegeMap` does not hold.** `MapPlan` derives a church at
`village_center`, fields, a path from `army_spawn` and trees from the map's
own numbers with a fixed seed. The sim does not know them. A building under
the church is not drawn.

**The crowd.** The sim is squad-level; the view draws heads. Each entity is
one MultiMesh per figure variant, drawn through the RenderingServer. Every
instance carries its own place in the unit disc (`CrowdScatter`, a sunflower)
and an animation phase; the shader puts it at `anchor + home * spread` and
moves it by the entity's state. Per frame the CPU sends the squads that moved
their anchor, and one global clock (`siege_clock`, `project.godot`
`[shader_globals]`). A head that falls is pinned to its spot in its instance
transform and lies there for the rest of the siege; a healed head stands up.

| State | Shown by |
|---|---|
| IDLE | breathing |
| MOVE | bob and rock; the squad strings out behind its anchor |
| FIGHT | shake, lunge, the weapon arm swings; the squad closes up |
| FLEE | lean into the run, quick steps; the squad scatters |
| DOWN | the whole squad lies, darker |
| HIDDEN | army: a faint glint the player can see. Village: not drawn (indoors) |

**Teams differ in outline, not only in colour.** Army: a block body, widest at
the shoulders, round head, blue. Village: a tunic, widest at the hem, pointed
hood or helm, orange. `tests/view/test_figures.gd` measures both widths.

**Looks.** `knight_armor`, `football_helmets`, `cardboard_armor` change the
figure of MEN, BAT_MEN and SHOTGUNNER; `booze` makes them sway; BAT_MEN always
carry the metal bat. `BattleScreen.loadout` is set by `Main` before `setup`.

**Two levels of detail** follow the zoom: below 26 screen pixels per man the
simple mesh is drawn.

## 2. What the view expects from the sim

All of it is already in the frozen contract; this is how the view reads it.

- `pos` is where the effect is drawn. Volleys, the shotgun, the moose and the
  trumpet aim at the nearest enemy entity within reach of `pos`, else at the
  other side's ground. `team` picks the colour and the enemy (default: army).
- `PUMPKIN_SPLAT.from`, `COMMAND.command`, `CENTRE_HELD.progress` are read.
  Send `CENTRE_HELD` with `progress` 0 when the hold is broken: the ring keeps
  the last value.
- `UFO_ABDUCT` and `PEP_TALK` in the FIRST snapshot (clock 0) are staged: they
  play one after the other, the sim is not stepped meanwhile, Space / Enter /
  pad A / a tap / the skip button cuts one short. Later they are plain effects.
- The payoff starts when `outcome()` leaves RUNNING, with or without a
  `VICTORY` / `COMBUST` event. `finished` fires `payoff_s` real seconds later.
- A squad whose `ent_count` drops loses that many figures (bodies stay). An
  entity whose kind changes, or that grows past the heads it was first seen
  with, is rebuilt and loses its bodies.

## 3. Controls

Every control is a `HudButton`: pictogram, spoken label, and the key or pad
button read from the InputMap for the device last used (no badge on touch).
`SiegeActions.ensure()` adds the actions at runtime unless `project.godot`
defines them. Default keys have symbol caps, so no letter is drawn.

| Control | Keys | Pad | Pointer |
|---|---|---|---|
| Hold / release the sim | Space | Start | button |
| Speed x1 x2 x4 x8 | 1 2 3 4 | d-pad left, up, right, down | buttons |
| Camera back to auto | 0 | right stick click | button |
| Zoom, pan | | | wheel or pinch; drag (any button, one finger) |
| Rally flag (Command) | | A: middle of the view | click or tap the map |
| Charge, retreat (Command) | Enter, Backspace | Y, X | buttons |
| Skip a staged beat | Space, Enter | A | tap, skip button |
| Pause menu | Esc | B | menu button |

A press released on the same spot is a tap; a press that moves 10 px is a
drag and gives no order. The HUD's hold stops the sim, not the camera.

## 4. Showcase and the frame gate

`scripts/autodrive_all.sh showcase` opens the real battle screen through
`Main.open_battle` on a scripted `ShowcaseSim` and saves 22 frames: every Kind
in every State (five grids), six looks, every event (three scenes, the orders,
two beats, two payoffs), the 2,400-figure crowd and a close fight. It fails
when a kind/state pair or an event name was never on screen.

The frame gate (`BattleChecks.smooth`) judges the screen's OWN work per frame
(`FrameMeter`: `_process` and the effects' `_draw`, not the sim, not the GPU).
On Xvfb the GPU is a software rasteriser, so wall frame time says nothing. The
bots also time on the thread's CPU clock and take the smaller value, so a busy
machine cannot fail the gate. It also fails when a figure is built or a
MultiMesh allocated after the screen is up. Measured on 2026-11-16, 2,400
figures, about 15 live effects: worst frame 1.3 to 1.5 ms, mean 0.7 ms,
entering the screen 5 to 8 ms.

The effects limit themselves: over 1 ms of drawing in a frame they drop the
oldest short ones until they fit.

## 5. Decisions and deviations

- **Palette.** Team, good, bad and coin colours come from the shared
  `Palette`; `WorldPalette` adds the ground and figure colours. The
  procedural-art skill's "exactly four Lospec colours" rule is NOT followed:
  the shared palette already had more, and two teams, flames, pumpkins and a
  HUD do not fit in four.
- **Figures stand upright on a top-down map** (board-game meeples), about
  1.9 times life size, so a kind reads at a glance. `[design guess]`
- **No letters on key badges.** A binding without a picture shows the UNKNOWN
  cap and `tests/view/test_hud.gd` fails on it.
- **`ShowcaseSim` extends `SiegeSim`** and overrides its seven public calls.
  It breaks if `SiegeSim.new()` ever needs arguments.

## 6. Sources

| Convention | Source |
|---|---|
| Speed controls, freeze, free camera | TABS: "move the camera in battle, slow or freeze time" (en.wikipedia.org/wiki/Totally_Accurate_Battle_Simulator) |
| Logic per squad, each man a visual with an offset and a phase | UEBS / Total War notes (discussions.unity.com/t/661025) |
| Every buff's effect visible, causes clear | research file, "What makes watching fun" |
| Space pauses, number keys pick the speed | genre habit (colony and grand-strategy games); `[design guess]` |

## 7. Constants (all `[design guess]`, tuned on the showcase frames)

| constant | value |
|---|---|
| `BattleScreen.PAYOFF_S`, `RING_S` | 3.2 s, 1.5 s |
| `BattleCamera.MAX_ZOOM`, `MIN_FIT`, `FOLLOW_S`, `WHEEL_STEP` | 22 px/m, 0.85, 0.45 s, 1.15 |
| `BattleCamera.PAD_M`, `MIN_SPAN_M`, `ENGAGE_M`, `LEAD_M` | 24 m, 150 x 84 m, 70 m, 60 m |
| `CameraInput.DRAG_PX`, `SnapshotTween.TELEPORT_M` | 10 px, 40 m |
| `CrowdLayer.FAR_BELOW_PX`, `LOD_SLACK`, `MAN_M` | 26 px, 1.15, 3.4 m |
| `CrowdLayer.SCATTER_M`, `SCATTER_KICK`, `CHEER_FADE` | 30 m, 1.2, 0.5 m/s |
| `SquadVisual.LAG_S`, `SETTLE_S` | 0.3 s, 0.35 s |
| `SquadVisual.FLEE_SPREAD`, `FIGHT_SPREAD`, `MOVE_SPREAD` | 1.6, 0.9, 1.1 |
| `FigureLibrary.MOVES` | per kind: spacing, bob, shake, lean, swing, buzz, hover, down turn |
| `FigureParts` sizes, `FigureBeasts.MONSTER_SCALE` | a man 3.4 m tall; 1.6 |
| `BattleEffects.MAX_LIVE`, `MIN_LIVE`, `DRAW_BUDGET_MS`, `SHED_BELOW_S` | 72, 12, 1 ms, 2.4 s |
| `BattleEffects.FLAG_RISE_S`, `DEFAULT_REACH` | 1.4 s, 60 m |
| `FxRecipes` | per event: life 0.45 to 3 s, reach 0 to 120 m |
| `FxMarks.RALLY_POLE_M`, `WIN_POLE_M`, `CENTRE_RING_M` | 10 m, 22 m, 18 m |
| `BattleBeats.FRAMES`, `CHURCH_BOX`, `ARMY_PAD_M` | 172 x 100 m and 168 x 124 m, 150 x 96 m, 30 m |
| `MapPlan.FIELDS`, `PATH_STEPS`, `PATH_SWAY_M`, tries | 9, 14, 14 m, 60 and 160 |
| `MapLayer.FURROW_M`, `PATH_M` | 3.2 m, 5.5 m |
| `HudButton.SIZE`, `BADGE`; `BattleHud.EDGE`, `GAP` | 96 px, 40 px; 28 px, 14 px |
| `HudMeters.WIDE`, `TALL`, `BAR`, `RING_R`, `LOW_MORALE` | 1440 px, 96 px, 300 x 26 px, 32 px, 0.25 |
| `PauseMenu.BUTTON_PX`, `BADGE_PX`, `PADDING` | 200 px, 60 px, 44 px |
| `SiegeActions.STICK_DEADZONE` | 0.5 |
| `FrameStats.WORK_BUDGET_MS` | 4 ms: a quarter of a 60 fps frame |
| `BattleChecks.PAYOFF_SEEN`, `TRIES`, `ENTER_BUDGET_MS` | 0.6, 3, 1000 ms (lesson L9) |
| `ShowcaseScript.SHOT_S`, `SEEN_AT`; `ShowcaseBot.CROWD_FRAMES` | 1.3 s, 0.4; 150 frames |
| `ShowcaseCrowd` | 2,000 villagers, 300 men, 100 wasps; an event every tick |
