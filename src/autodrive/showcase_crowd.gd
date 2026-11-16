class_name ShowcaseCrowd
extends RefCounted
## The showcase's two living scenes. `crowd` is the worst case the frame gate
## measures: 2,400 figures (2,000 villagers, 300 men, 100 wasps), every
## entity moving, changing state and losing heads while events fire thirty
## times a second. `fight` is a close-up of a melee for the 4K crop.

const VILLAGER_GROUPS := 20
const SQUADS := 30
const WASPS := 100
const FIGURES := VILLAGER_GROUPS * 100 + SQUADS * 10 + WASPS
## Ticks between two events of the storm (the sim ticks 30 times a second).
const STORM_EVERY := 1
const STORM: Array[StringName] = [
	SiegeEvent.SLING_VOLLEY,
	SiegeEvent.ARROW_VOLLEY,
	SiegeEvent.MELEE_CLASH,
	SiegeEvent.SQUAD_ROUT,
	SiegeEvent.SQUAD_RALLY,
	SiegeEvent.SHOTGUN_BLAST,
	SiegeEvent.HEAL,
	SiegeEvent.MOOSE_CHARGE,
	SiegeEvent.MONSTER_SMASH,
	SiegeEvent.TRUMPET_CALL,
	SiegeEvent.WASP_SWARM,
	SiegeEvent.CART_CRASH,
	SiegeEvent.PUMPKIN_SPLAT,
	SiegeEvent.BAND_RIFF,
]
const STATES: Array[int] = [
	SiegeSnapshot.State.MOVE,
	SiegeSnapshot.State.FIGHT,
	SiegeSnapshot.State.FLEE,
	SiegeSnapshot.State.MOVE
]


static func build(sim: ShowcaseSim) -> void:
	var c := sim.show_map.village_center
	var move := SiegeSnapshot.State.MOVE
	for i in VILLAGER_GROUPS:
		var at := c + Vector2.from_angle(i * TAU / VILLAGER_GROUPS * 3.0) * (26.0 + (i % 4) * 22.0)
		var kind := SiegeSnapshot.Kind.MILITIA if i % 4 == 0 else SiegeSnapshot.Kind.VILLAGERS
		var index := sim.add(kind, SiegeSnapshot.Team.VILLAGE, 100, move, at, PI)
		sim.show_orbit[index] = 7.0
	for i in SQUADS:
		var at := Vector2(246 + (i % 5) * 15, 112 + (i / 5) * 34)
		var index := sim.add(SiegeSnapshot.Kind.MEN, SiegeSnapshot.Team.ARMY, 10, move, at)
		sim.show_orbit[index] = 6.0
	var swarm := sim.add(
		SiegeSnapshot.Kind.WASPS, SiegeSnapshot.Team.ARMY, WASPS, move, c - Vector2(96, 0)
	)
	sim.show_orbit[swarm] = 14.0
	sim.show_alive = true


## A melee seen from close: men and bat men against militia and retinue,
## archers behind, medics at the back.
static func build_fight(sim: ShowcaseSim) -> void:
	var army := SiegeSnapshot.Team.ARMY
	var village := SiegeSnapshot.Team.VILLAGE
	var fight := SiegeSnapshot.State.FIGHT
	for i in 3:
		sim.add(SiegeSnapshot.Kind.MEN, army, 10, fight, Vector2(240, 190 + i * 10))
		sim.add(SiegeSnapshot.Kind.MILITIA, village, 10, fight, Vector2(256, 190 + i * 10), PI)
	sim.add(SiegeSnapshot.Kind.BAT_MEN, army, 5, fight, Vector2(247, 204))
	sim.add(SiegeSnapshot.Kind.RETINUE, village, 6, fight, Vector2(259, 195), PI)
	sim.add(SiegeSnapshot.Kind.ARCHERS, village, 6, fight, Vector2(274, 200), PI)
	sim.add(SiegeSnapshot.Kind.MEDICS, army, 2, SiegeSnapshot.State.IDLE, Vector2(226, 202))
	sim.add(SiegeSnapshot.Kind.EMPEROR, army, 1, SiegeSnapshot.State.IDLE, Vector2(222, 194))
	sim.show_alive = true


static func stir(sim: ShowcaseSim, tick: int) -> void:
	if sim.scene == &"fight":
		_brawl(sim, tick)
		return
	var seconds := tick * SiegeSim.STEP_S
	var count := sim.show_pos.size()
	for i in count:
		var turn := seconds * (0.5 + (i % 5) * 0.12) + i
		sim.show_pos[i] = sim.show_home[i] + Vector2.from_angle(turn) * sim.show_orbit[i]
		sim.show_facing[i] = turn + PI / 2.0
		if tick % 60 == (i * 7) % 60:
			sim.show_state[i] = STATES[(tick / 60 + i) % STATES.size()]
	var hit := (tick * 7) % count
	if tick % 6 == 0 and sim.show_count[hit] > (60 if hit < VILLAGER_GROUPS else 6):
		sim.show_count[hit] -= 1
	if tick % STORM_EVERY == 0:
		var at := (tick * 13) % count
		var data := {"team": sim.show_team[at], "from": sim.show_pos[at] - Vector2(60, 0)}
		sim.fire(sim.show_clock, STORM[(tick / STORM_EVERY) % STORM.size()], sim.show_pos[at], data)
	sim.show_army_morale = 0.6 + 0.3 * sin(seconds * 0.7)
	sim.show_village_morale = 0.5 + 0.4 * cos(seconds * 0.5)
	sim.show_alarm = minf(seconds / 4.0, 1.0)


## The close-up: a few fall early, then clashes and volleys keep coming.
static func _brawl(sim: ShowcaseSim, tick: int) -> void:
	if tick == 8:
		for i in 6:
			sim.show_count[i] -= 3
	if tick % 14 == 2:
		var row := (tick / 14) % 3
		sim.fire(sim.show_clock, SiegeEvent.MELEE_CLASH, Vector2(248, 190 + row * 10), {"team": 0})
	if tick % 40 == 5:
		sim.fire(sim.show_clock, SiegeEvent.ARROW_VOLLEY, Vector2(274, 200), {"team": 1})
	if tick % 40 == 25:
		sim.fire(sim.show_clock, SiegeEvent.SLING_VOLLEY, Vector2(240, 200), {"team": 0})
