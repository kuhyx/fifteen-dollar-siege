class_name ShowcaseScript
extends RefCounted
## The showcase's scenes: what stands where, which events fire when, and the
## map box the camera holds for the shot. Grids show a Kind per row and a
## State per column (idle, move, fight, flee, down, hidden); event scenes
## fire each event so that it is 40 % through its life at SHOT_S.

## Sim second (= real second: the showcase runs at speed 1) of an event shot.
const SHOT_S := 1.3
const SEEN_AT := 0.4
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE
const VILLAGE_KINDS: Array[int] = [
	SiegeSnapshot.Kind.VILLAGERS,
	SiegeSnapshot.Kind.MILITIA,
	SiegeSnapshot.Kind.RETINUE,
	SiegeSnapshot.Kind.ARCHERS
]
## Scene -> [kinds], [heads per entity], cell size, top-left cell.
const GRIDS := {
	&"kinds_army": [[0, 5, 6, 7, 8, 9], [6, 4, 1, 1, 1, 4], Vector2(20, 12), Vector2(110, 96)],
	&"kinds_village": [[1, 2, 3, 4], [12, 8, 6, 6], Vector2(22, 15), Vector2(105, 100)],
	&"specials_a": [[10, 11, 12, 13], [1, 3, 40, 3], Vector2(30, 21), Vector2(90, 90)],
	&"specials_b": [[14, 15, 15, 16], [1, 4, 1, 1], Vector2(30, 21), Vector2(90, 90)],
	&"looks": [[0, 5, 6], [8, 4, 1], Vector2(20, 13), Vector2(120, 110)],
}
## Scene -> the map box the camera holds.
const BOXES := {
	&"events_ranged": Rect2(118, 96, 126, 96),
	&"events_melee": Rect2(96, 104, 200, 84),
	&"events_calls": Rect2(336, 126, 188, 148),
	&"orders": Rect2(286, 130, 200, 140),
	&"crowd": Rect2(0, 0, 600, 400),
	&"fight": Rect2(214, 180, 72, 40),
}


static func team_of(kind: int) -> int:
	return VILLAGE if VILLAGE_KINDS.has(kind) else ARMY


## The box the camera holds for `scene` (the staged scenes frame themselves).
static func box(scene: StringName) -> Rect2:
	if not GRIDS.has(scene):
		return BOXES.get(scene, Rect2(0, 0, 600, 400))
	var grid: Array = GRIDS[scene]
	var cell: Vector2 = grid[2]
	var columns := 3 if scene == &"looks" else 6
	var size := Vector2(cell.x * columns, cell.y * (grid[0] as Array).size())
	return Rect2(grid[3] - cell * Vector2(0.6, 0.75), size + cell * Vector2(0.2, 0.3))


static func build(sim: ShowcaseSim, scene: StringName) -> void:
	for i in 9:
		var at := sim.show_map.village_center + Vector2.from_angle(i * 0.7 + 0.3) * (48.0 + i * 5.0)
		sim.show_map.buildings.append(Rect2(at, Vector2(12 + i % 3 * 3, 9 + i % 2 * 5)))
	if GRIDS.has(scene):
		_grid(sim, GRIDS[scene], 3 if scene == &"looks" else 6)
		return
	match scene:
		&"events_ranged":
			_ranged(sim)
		&"events_melee":
			_melee(sim)
		&"events_calls":
			_calls(sim)
		&"orders":
			_host(sim, Vector2(330, 200), Vector2(400, 200), 6)
			sim.fire(0.0, SiegeEvent.CENTRE_HELD, sim.show_map.village_center, {"progress": 0.6})
		&"beats":
			_host(sim, sim.show_map.army_spawn, sim.show_map.village_center, 10)
			sim.fire(0.0, SiegeEvent.UFO_ABDUCT, sim.show_map.village_center)
			sim.fire(0.0, SiegeEvent.PEP_TALK, sim.show_map.army_spawn)
		&"payoff_win", &"payoff_lose":
			_ending(sim, scene == &"payoff_win")
		&"crowd":
			ShowcaseCrowd.build(sim)
		&"fight":
			ShowcaseCrowd.build_fight(sim)


## Every scripted tick of a living scene (the crowd, the fight).
static func stir(sim: ShowcaseSim, tick: int) -> void:
	ShowcaseCrowd.stir(sim, tick)


## Fires `kind` so that it is SEEN_AT of the way through its life at SHOT_S.
static func _event(sim: ShowcaseSim, kind: StringName, pos: Vector2, data: Dictionary = {}) -> void:
	sim.fire(SHOT_S - BattleEffects.life_of(kind) * SEEN_AT, kind, pos, data)


static func _grid(sim: ShowcaseSim, grid: Array, columns: int) -> void:
	var kinds: Array = grid[0]
	var cell: Vector2 = grid[2]
	for row in kinds.size():
		for column in columns:
			var at: Vector2 = grid[3] + Vector2(column * cell.x, row * cell.y)
			sim.add(kinds[row], team_of(kinds[row]), grid[1][row], column, at)


## An army of `squads` around `camp` and villagers around `village`.
static func _host(sim: ShowcaseSim, camp: Vector2, village: Vector2, squads: int) -> void:
	for i in squads:
		var at := camp + Vector2((i % 2) * 14.0 - 7.0, (i - squads / 2.0) * 11.0)
		sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, SiegeSnapshot.State.IDLE, at)
	for i in 8:
		var at := village + Vector2.from_angle(i * TAU / 8.0) * 42.0
		sim.add(SiegeSnapshot.Kind.VILLAGERS, VILLAGE, 40, SiegeSnapshot.State.IDLE, at, PI)


static func _ranged(sim: ShowcaseSim) -> void:
	var fight := SiegeSnapshot.State.FIGHT
	var lanes: Array[float] = [112.0, 134.0, 156.0, 178.0]
	sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, fight, Vector2(150, lanes[0]))
	sim.add(SiegeSnapshot.Kind.MILITIA, VILLAGE, 10, fight, Vector2(196, lanes[0]), PI)
	_event(sim, SiegeEvent.SLING_VOLLEY, Vector2(150, lanes[0]), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.ARCHERS, VILLAGE, 8, fight, Vector2(208, lanes[1]), PI)
	sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, SiegeSnapshot.State.MOVE, Vector2(148, lanes[1]))
	_event(sim, SiegeEvent.ARROW_VOLLEY, Vector2(208, lanes[1]), {"team": VILLAGE})
	sim.add(SiegeSnapshot.Kind.SHOTGUNNER, ARMY, 1, fight, Vector2(160, lanes[2]))
	sim.add(
		SiegeSnapshot.Kind.MILITIA, VILLAGE, 8, SiegeSnapshot.State.FLEE, Vector2(184, lanes[2])
	)
	_event(sim, SiegeEvent.SHOTGUN_BLAST, Vector2(160, lanes[2]), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.CATAPULT, ARMY, 1, fight, Vector2(146, lanes[3]))
	sim.add(
		SiegeSnapshot.Kind.VILLAGERS, VILLAGE, 12, SiegeSnapshot.State.FLEE, Vector2(214, lanes[3])
	)
	_event(sim, SiegeEvent.PUMPKIN_LAUNCH, Vector2(146, lanes[3]), {"team": ARMY})
	var from := {"from": Vector2(146, lanes[3]), "team": ARMY}
	_event(sim, SiegeEvent.PUMPKIN_SPLAT, Vector2(214, lanes[3]), from)


static func _melee(sim: ShowcaseSim) -> void:
	var fight := SiegeSnapshot.State.FIGHT
	var flee := SiegeSnapshot.State.FLEE
	var spots: Array[Vector2] = []
	for i in 7:
		spots.append(Vector2(124 + (i % 4) * 48, 128 + (i / 4) * 36))
	sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, fight, spots[0] - Vector2(4, 0))
	sim.add(SiegeSnapshot.Kind.MILITIA, VILLAGE, 10, fight, spots[0] + Vector2(5, 0), PI)
	_event(sim, SiegeEvent.MELEE_CLASH, spots[0], {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.MILITIA, VILLAGE, 10, flee, spots[1])
	_event(sim, SiegeEvent.SQUAD_ROUT, spots[1], {"team": VILLAGE})
	sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, SiegeSnapshot.State.IDLE, spots[2])
	_event(sim, SiegeEvent.SQUAD_RALLY, spots[2], {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.RETINUE, VILLAGE, 6, SiegeSnapshot.State.DOWN, spots[3])
	_event(sim, SiegeEvent.SQUAD_WIPED, spots[3], {"team": VILLAGE})
	sim.add(SiegeSnapshot.Kind.MONSTER, ARMY, 1, fight, spots[4] - Vector2(6, 0))
	sim.add(SiegeSnapshot.Kind.VILLAGERS, VILLAGE, 10, flee, spots[4] + Vector2(5, 0))
	_event(sim, SiegeEvent.MONSTER_SMASH, spots[4] + Vector2(3, 0), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.MOOSE, ARMY, 1, SiegeSnapshot.State.MOVE, spots[5] - Vector2(14, 0))
	sim.add(SiegeSnapshot.Kind.MILITIA, VILLAGE, 8, flee, spots[5] + Vector2(12, 0))
	_event(sim, SiegeEvent.MOOSE_CHARGE, spots[5] - Vector2(14, 0), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.GOLF_CARTS, ARMY, 1, SiegeSnapshot.State.DOWN, spots[6])
	_event(sim, SiegeEvent.CART_CRASH, spots[6], {"team": ARMY})


static func _calls(sim: ShowcaseSim) -> void:
	var c := sim.show_map.village_center
	var idle := SiegeSnapshot.State.IDLE
	sim.add(SiegeSnapshot.Kind.MEDICS, ARMY, 3, idle, c + Vector2(-56, -42))
	sim.add(SiegeSnapshot.Kind.MEN, ARMY, 6, idle, c + Vector2(-46, -42))
	_event(sim, SiegeEvent.HEAL, c + Vector2(-46, -42), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.WASPS, ARMY, 30, SiegeSnapshot.State.FIGHT, c + Vector2(0, -52))
	sim.add(
		SiegeSnapshot.Kind.VILLAGERS, VILLAGE, 10, SiegeSnapshot.State.FLEE, c + Vector2(8, -50)
	)
	_event(sim, SiegeEvent.WASP_SWARM, c + Vector2(6, -50), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.TRUMPET_BOY, ARMY, 1, idle, c + Vector2(48, -44))
	_event(sim, SiegeEvent.TRUMPET_CALL, c + Vector2(48, -44), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.ROCK_BAND, ARMY, 4, SiegeSnapshot.State.FIGHT, c + Vector2(-50, 46))
	_event(sim, SiegeEvent.BAND_RIFF, c + Vector2(-50, 46), {"team": ARMY})
	sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, SiegeSnapshot.State.HIDDEN, c + Vector2(50, 46))
	_event(sim, SiegeEvent.REVEAL, c + Vector2(50, 46), {"team": ARMY})
	_event(sim, SiegeEvent.ALARM, c + Vector2(0, 30))
	_event(sim, SiegeEvent.BELL_RING, c)


## The last moment of a siege: the decision comes 0.3 s in.
static func _ending(sim: ShowcaseSim, won: bool) -> void:
	var c := sim.show_map.village_center
	var middle := c if won else c + Vector2(-70, 10)
	for i in 12:
		var at := (
			middle + Vector2((i % 4 - 1.5) * 13.0, (i / 4 - 1.0) * 12.0 + (4.0 if won else 0.0))
		)
		var state := SiegeSnapshot.State.IDLE if won else SiegeSnapshot.State.DOWN
		sim.add(SiegeSnapshot.Kind.MEN, ARMY, 10, state, at)
	for i in 10:
		var at := c + Vector2.from_angle(i * TAU / 10.0 + 0.3) * (64.0 if won else 36.0)
		var state := SiegeSnapshot.State.FLEE if won else SiegeSnapshot.State.IDLE
		var kind := SiegeSnapshot.Kind.VILLAGERS if i % 3 else SiegeSnapshot.Kind.MILITIA
		sim.add(kind, VILLAGE, 30, state, at, (at - c).angle() if won else PI)
	sim.show_decide_at = 0.3
	sim.show_verdict = SiegeSim.Outcome.WIN if won else SiegeSim.Outcome.LOSE
	sim.show_army_morale = 0.9 if won else 0.0
	sim.show_village_morale = 0.0 if won else 0.9
	sim.show_alarm = 1.0
	sim.fire(0.3, SiegeEvent.VICTORY if won else SiegeEvent.COMBUST, middle)
