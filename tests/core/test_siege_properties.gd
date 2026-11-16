extends GutTest
## Property tests of the sim (build-game R18, skill
## property-and-differential-tests): laws that must hold for ANY legal loadout,
## seed and order sequence. The cases come from a seeded generator, so a
## failure names the case and replays exactly. Laws:
##   determinism  the same loadout, seed and orders give the same hash sequence
##   no-crash     a legal loadout never stops the sim before it is decided
##   invariants   head counts never rise except by a HEAL event; morale, alarm
##                and the plaza hold stay in 0..1; nobody leaves the map; the
##                entity list never changes; every event is a known one
##   finality     the outcome never changes once set, and no event follows it

const Space = preload("res://tools/sim/loadout_space.gd")
const CASES := 6
const GENERATOR_SEED := 20261116

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = GENERATOR_SEED


## One generated case: {loadout, seed, orders: {tick: [kind, pos]}}.
func _case() -> Dictionary:
	var orders := {}
	for i in _rng.randi_range(0, 4):
		var at := Vector2(_rng.randf_range(-50.0, 650.0), _rng.randf_range(-50.0, 450.0))
		orders[_rng.randi_range(1, 1200)] = [_rng.randi_range(0, 3), at]
	return {"loadout": Space.random(_rng), "seed": _rng.randi(), "orders": orders}


## Plays a case to its decision in 0.5 s steps; `each` sees every snapshot.
func _play(case: Dictionary, each: Callable) -> SiegeSim:
	var sim := SiegeSim.create(case["loadout"], case["seed"])
	var orders: Dictionary = case["orders"]
	var tick := 0
	each.call(sim, sim.snapshot())
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		for i in SiegeTuning.THINK_TICKS:
			tick += 1
			if orders.has(tick):
				sim.command(orders[tick][0], orders[tick][1])
			sim.step(SiegeSim.STEP_S)
		each.call(sim, sim.snapshot())
	return sim


func _name(case: Dictionary) -> String:
	return "%s seed %d orders %s" % [Space.key(case["loadout"]), case["seed"], case["orders"]]


func test_the_same_case_gives_the_same_hash_sequence() -> void:
	for index in CASES:
		var case := _case()
		var runs: Array[Array] = [[], []]
		for run in 2:
			var hashes: Array = runs[run]
			_play(
				case,
				func(sim: SiegeSim, _shot: SiegeSnapshot) -> void: hashes.append(sim.state_hash())
			)
		assert_eq(runs[0], runs[1], _name(case))
		assert_gt(runs[0].size(), 20, "the siege was played")


func test_every_legal_loadout_plays_to_a_decision_inside_the_time_cap() -> void:
	for index in CASES:
		var case := _case()
		assert_true((case["loadout"] as Loadout).is_legal())
		var sim := _play(case, func(_sim: SiegeSim, _shot: SiegeSnapshot) -> void: pass)
		assert_ne(sim.outcome(), SiegeSim.Outcome.RUNNING, _name(case))
		assert_lte(sim.clock_s(), SiegeTuning.TIME_CAP_S + 0.5, _name(case))


func test_invariants_hold_on_every_snapshot() -> void:
	for index in CASES:
		var case := _case()
		var before: Array[SiegeSnapshot] = [null]
		var bad: Array[String] = []
		_play(
			case,
			func(sim: SiegeSim, shot: SiegeSnapshot) -> void:
				_check(sim, shot, before[0], bad)
				before[0] = shot
		)
		assert_eq(bad, [] as Array[String], _name(case))


## Appends what is wrong with `shot` (given the one before it) to `bad`.
func _check(sim: SiegeSim, shot: SiegeSnapshot, before: SiegeSnapshot, bad: Array[String]) -> void:
	var bounds := sim.map().bounds.grow(0.01)
	var healed := {}
	for event in shot.events:
		if not SiegeEvent.ALL.has(event["kind"]):
			bad.append("unknown event %s" % event["kind"])
		if not event.get("pos") is Vector2 or not bounds.grow(20.0).has_point(event["pos"]):
			bad.append("event %s has no place on the map" % event["kind"])
		if event["kind"] == SiegeEvent.HEAL:
			healed[event["entity"]] = healed.get(event["entity"], 0) + int(event["heads"])
	for value: float in [shot.army_morale, shot.village_morale, shot.alarm, shot.centre_hold]:
		if value < 0.0 or value > 1.0 or is_nan(value):
			bad.append("a meter left 0..1: %s" % value)
	for i in shot.entity_count():
		if not bounds.has_point(shot.ent_pos[i]) or is_nan(shot.ent_facing[i]):
			bad.append("entity %d left the map: %s" % [i, shot.ent_pos[i]])
		if shot.ent_morale[i] < 0.0 or shot.ent_morale[i] > 1.0 or shot.ent_count[i] < 0:
			bad.append("entity %d: morale %s heads %d" % [i, shot.ent_morale[i], shot.ent_count[i]])
	if before == null:
		return
	if shot.ent_kind != before.ent_kind or shot.ent_team != before.ent_team:
		bad.append("the entity list changed")
	if shot.alarm < before.alarm:
		bad.append("the alarm fell")
	for i in mini(shot.entity_count(), before.entity_count()):
		var rose := shot.ent_count[i] - before.ent_count[i]
		if rose > int(healed.get(i, 0)):
			bad.append("entity %d grew by %d without a heal" % [i, rose])


func test_the_outcome_is_final() -> void:
	for index in CASES:
		var case := _case()
		var sim := _play(case, func(_sim: SiegeSim, _shot: SiegeSnapshot) -> void: pass)
		var outcome := sim.outcome()
		var seconds := sim.clock_s()
		sim.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
		sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
		sim.step(20.0)
		var shot := sim.snapshot()
		assert_eq(sim.outcome(), outcome, _name(case))
		assert_eq(shot.events, [] as Array[Dictionary], "nothing happens after the decision")
		assert_almost_eq(sim.clock_s(), seconds + 20.0, 0.001, "the clock still runs for the view")
		assert_between(shot.army_morale, 0.0, 1.0)
		assert_eq(Lab.run_one(case["loadout"], case["seed"]).keys(), ["outcome", "seconds"])
