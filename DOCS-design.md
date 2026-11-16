# Design: fifteen-dollar-siege

Record of what is decided. The sim, view and art agents extend it; nothing
here is a task (tasks live in the todo app, repo `kuhyx/fifteen-dollar-siege`).

## 1. Goal

Turn one meme (attached to todo task df2a2bf2) into a toy you can argue with:
pick buffs for 15 dollars, watch or lead the siege, and see in the Lab how
often your pick really wins. Done means: a player with no instructions buys a
loadout, sees the siege end in a win or in flames, and can tell from the Lab
number which of two loadouts is better.

The premise, verbatim:

> You are the leader of a small army comprised of 100 random men picked off
> the street. They just met, and in 1 hour you will start a siege of a 1100 AD
> european village with a population of 2,000. They are not aware of your
> invasion, but will notice as your men draw near. Each man in your army
> starts with a with wooden club and slingshot that shoots small stones. You
> must succesfully siege the village and take control, otherwise you combust
> into flames and perish. To maximize your chances of victory, you are allowed
> to spend $15 to give buffs to your army. Which buffs do you choose and why?

## 2. Modes (one sim core, picked from the hub)

| Mode | The player | The sim |
|---|---|---|
| Watch | buys buffs | plays itself |
| Command | buys buffs, places a rally flag, calls charge / retreat | takes `command()` calls |
| Lab | buys buffs | runs N times headless; the win rate shows as a ring and a number |

## 3. Rules (decided by kuhy)

- 15 dollar cap. Each buff at most once. Unspent dollars are lost.
- "+50 men" applies before "double": 100, 150, 200 or 300 men.
- **Win:** village morale breaks OR the army holds the village centre 30 s.
- **Lose:** the army is dead or routed (or nothing is decided after 300 s). It
  then combusts.
- The village does not know at first; it notices as the men draw near
  (`alarm` 0..1).

## 4. Buffs

25 buffs, ids neutral, prices 5 to 1. The verbatim words (typos kept) are in
`src/core/buff_catalog.gd` `ROWS` and nowhere else; they are the accessibility
label of a card and are never drawn.

| $ | ids |
|---|---|
| 5 | `invisibility_potions` `knight_armor` `double_men` `abduction` `stitched_monster` `wasps` `medics` |
| 4 | `deaf_villagers` `shotgun` `emperor` `fifty_men` `golf_carts` |
| 3 | `prep_hour` `pumpkin_catapults` `rock_band` `football_helmets` `moose` |
| 2 | `metal_bats` `sleepless_village` `trumpet_boy` `booze` |
| 1 | `pep_talk` `cardboard_armor` `stew` `prep_ten_minutes` |

What each buff does, and its catch: `DOCS-design-sim.md` section 6.

## 5. Core API (`src/core`, additions only)

Pure logic: no Node, no scene, no global RNG, no wall clock. Units are metres
and sim seconds.

```gdscript
class_name BuffDef            # id: StringName, price: int, source_text: String
class_name BuffCatalog
    static func all() -> Array[BuffDef]          # the 25, source order
    static func by_id(id: StringName) -> BuffDef # null when unknown
class_name Loadout
    const BUDGET := 15
    var ids: Array[StringName]
    static func of(ids: Array) -> Loadout        # as given, legal or not
    func cost() -> int
    func remaining() -> int
    func has(id: StringName) -> bool
    func is_legal() -> bool                      # known, no duplicate, <= BUDGET
    func toggle(id: StringName) -> bool          # buy / sell; false = refused
    func duplicate() -> Loadout
class_name SiegeMap
    var bounds: Rect2
    var village_center: Vector2
    var village_radius: float
    var buildings: Array[Rect2]
    var army_spawn: Vector2
    var church: Rect2                            # = buildings[0]
    var bell: Vector2
    var centre_radius: float                     # the plaza to hold
    func in_village(point: Vector2) -> bool
class_name SiegeSnapshot
    enum Team { ARMY, VILLAGE }
    enum Kind { MEN, VILLAGERS, MILITIA, RETINUE, ARCHERS, BAT_MEN, SHOTGUNNER,
        EMPEROR, TRUMPET_BOY, MEDICS, MONSTER, MOOSE, WASPS, GOLF_CARTS,
        CATAPULT, ROCK_BAND, UFO }               # add new kinds at the END
    enum State { IDLE, MOVE, FIGHT, FLEE, DOWN, HIDDEN }
    var clock_s: float
    var outcome: int                             # SiegeSim.Outcome
    var army_morale: float                       # 0..1
    var village_morale: float                    # 0..1
    var alarm: float                             # 0..1
    var centre_hold: float                       # 0..1 of the 30 s in the plaza
    var ent_pos: PackedVector2Array
    var ent_kind: PackedInt32Array
    var ent_team: PackedByteArray
    var ent_count: PackedInt32Array              # heads alive in the entity
    var ent_state: PackedByteArray
    var ent_facing: PackedFloat32Array           # radians, 0 = +x
    var ent_morale: PackedFloat32Array           # 0..1, the squad's own
    var events: Array[Dictionary]                # {kind, pos, ...}
    func entity_count() -> int
class_name SiegeSim
    enum Outcome { RUNNING, WIN, LOSE }
    enum Command { RALLY, CHARGE, RETREAT }
    const STEP_S := 0.1                          # fixed internal timestep
    static func army_size(loadout: Loadout) -> int
    static func create(loadout: Loadout, sim_seed: int) -> SiegeSim
    func map() -> SiegeMap
    func step(dt: float) -> void                 # whole ticks; keeps the rest
    func command(kind: int, pos: Vector2) -> void
    func snapshot() -> SiegeSnapshot
    func outcome() -> int
    func clock_s() -> float
    func state_hash() -> int
    func run_to_end() -> int                     # no view: plays to the decision
    func village_low() -> float                  # lowest village morale so far
class_name Lab
    static func run_one(loadout: Loadout, sim_seed: int) -> Dictionary
        # {outcome, seconds}
    static func run_batch(loadout: Loadout, runs: int, base_seed: int) -> Dictionary
        # {wins, runs, mean_seconds}; run i uses seed base_seed + i
class_name SiegeEvent         # the event names (`kind`), e.g. SiegeEvent.ALARM
class_name SiegeFixtures      # WIN_IDS + WIN_SEED, LOSE_IDS + LOSE_SEED (pinned)
```

Contract notes:

- **Entities.** An entity is a squad or a special. The logic may stay at
  squad level; the view scatters `ent_count` figures around `ent_pos`. Arrays
  are parallel; the index is the entity for the whole siege.
- **Events** are handed over once: a second `snapshot()` of the same tick has
  none. Names: `SiegeEvent`; their data: `DOCS-design-sim.md` section 7.
- **States.** `HIDDEN` is an army squad nobody sees (potion; `REVEAL` ends
  it), a crowd that hid indoors, or the UFO once it has left.
- **Head counts** of the army equal `army_size()` unless a buff adds people or
  beasts (emperor, trumpet boy, band, medics, monster, moose, wasps, UFO).
- **Determinism.** The same loadout, seed and `command()` sequence (same
  ticks) give the same `state_hash()` after every tick. `tests/core/`
  enforces it; the exported build prints the same hashes as the source run.
- **`step(dt)`** never runs a partial tick, so one big step equals many small
  ones. Orders after the decision are ignored.
- `create()` copies the loadout and does not validate it; callers pass a
  legal one.

## 6. What is a stub today

The sim is real: `DOCS-design-sim.md`. The bot and the flow tests play the
pinned sieges of `SiegeFixtures`.

The screens in `src/view/` are placeholders: every buff card shows the same
star, tinted per card; the battle is dots. `Glyphs` holds placeholder
pictograms. There is no sound yet (R4 baseline: music at boot, win and
combust cues are the art and audio agents' work).

## 7. View contract

- Zero visible text. Channels: pictogram + `accessibility_name`, coins,
  bars, `SevenSegment` numbers, motion, sound. Every cue has a second channel
  (a refused buy shakes AND turns red; a bought card has a frame AND a check).
- The payoff (flag on the village, flames on the army) plays on the battle
  screen before the result screen opens. The bot takes its payoff frame then
  (lesson L13).
- Screens answer `pick_at(canvas_point) -> Dictionary` (`kind`, `id`,
  `state`, optional `position`) for the dev select tool, and `Main` answers
  `debug_state()` for `snapshot.json`.
- No loading screen: Lab runs sieges inside a 6 ms per-frame budget.

## 8. Sources

One row per tuning constant (`constant | value | source`):
`DOCS-design-sources.md` (the base model) and `DOCS-design-buff-sources.md`
(the buffs). `tests/core/test_sources.gd` keeps them in step with the code.

## 9. Scaffold constants

| constant | value | source |
|---|---|---|
| `Loadout.BUDGET` | 15 | premise: "$15" |
| `SiegeSim.BASE_MEN` | 100 | premise: "100 random men" |
| `SiegeSim.EXTRA_MEN` | 50 | buff text: "+50 men" |
| villagers | 2000 | premise: "population of 2,000"; who they are: `DOCS-design-sim.md` section 2 |
| `SiegeSim.SQUAD_SIZE` | 10 | `[design guess]` |
| `SiegeSim.BUILDINGS` | 14 | `[design guess]` |
| map bounds, village radius | 600 x 400 m, 110 m | `[design guess]` |
| `LaunchOptions.DEFAULT_LAB_RUNS` | 200 | `[design guess]` |
| `BattleScreen.PAYOFF_S` | 1.2 s | `[design guess]` |
| `LabScreen.FRAME_BUDGET_MS` | 6 ms | `[design guess]`: under half a 60 fps frame |
