extends GutTest
## The sim contract (DOCS-design.md "Core API"), tested against the STUB: the
## signatures, determinism from the seed, the rule "+50 men before double", and
## the stub's own behaviour (walk to the centre; WIN at 8 dollars or more).

const WIN_IDS: Array[StringName] = [&"double_men", &"fifty_men"]
const LOSE_IDS: Array[StringName] = [&"pep_talk", &"stew"]


func _run(ids: Array[StringName], sim_seed: int, seconds: float) -> SiegeSim:
	var sim := SiegeSim.create(Loadout.of(ids), sim_seed)
	sim.step(seconds)
	return sim


func _hashes(sim_seed: int, orders: bool) -> Array[int]:
	var sim := SiegeSim.create(Loadout.of(WIN_IDS), sim_seed)
	var out: Array[int] = []
	for tick in 900:
		if orders and tick == 60:
			sim.command(SiegeSim.Command.RALLY, Vector2(200, 80))
		if orders and tick == 200:
			sim.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
		sim.step(SiegeSim.STEP_S)
		out.append(sim.state_hash())
	return out


func test_fifty_men_apply_before_double() -> void:
	assert_eq(SiegeSim.army_size(Loadout.new()), 100)
	assert_eq(SiegeSim.army_size(Loadout.of([&"fifty_men"])), 150)
	assert_eq(SiegeSim.army_size(Loadout.of([&"double_men"])), 200)
	assert_eq(SiegeSim.army_size(Loadout.of([&"double_men", &"fifty_men"])), 300)
	assert_eq(SiegeSim.army_size(Loadout.of([&"fifty_men", &"double_men"])), 300, "any order")


func test_the_same_seed_gives_the_same_hash_sequence() -> void:
	assert_eq(_hashes(42, false), _hashes(42, false))
	assert_eq(_hashes(42, true), _hashes(42, true), "with the same orders too")


func test_a_different_seed_or_order_gives_a_different_sequence() -> void:
	assert_ne(_hashes(42, false), _hashes(43, false))
	assert_ne(_hashes(42, false), _hashes(42, true))


func test_the_hash_changes_as_the_siege_moves() -> void:
	var sim := SiegeSim.create(Loadout.of(WIN_IDS), 1)
	var first := sim.state_hash()
	sim.step(1.0)
	assert_ne(sim.state_hash(), first)


func test_step_runs_whole_fixed_ticks_only() -> void:
	var sim := SiegeSim.create(Loadout.new(), 1)
	sim.step(SiegeSim.STEP_S * 0.4)
	assert_eq(sim.clock_s(), 0.0, "less than one tick: nothing yet")
	sim.step(SiegeSim.STEP_S * 0.7)
	assert_almost_eq(sim.clock_s(), SiegeSim.STEP_S, 0.0001, "the remainder was kept")
	sim.step(-5.0)
	assert_almost_eq(sim.clock_s(), SiegeSim.STEP_S, 0.0001, "time never runs back")


func test_one_big_step_equals_many_small_ones() -> void:
	var big := SiegeSim.create(Loadout.of(WIN_IDS), 9)
	var small := SiegeSim.create(Loadout.of(WIN_IDS), 9)
	big.step(SiegeSim.STEP_S * 300)
	for i in 300:
		small.step(SiegeSim.STEP_S)
	assert_eq(big.state_hash(), small.state_hash())


func test_the_stub_wins_at_eight_dollars_and_loses_below() -> void:
	assert_eq(_run(WIN_IDS, 3, 30.0).outcome(), SiegeSim.Outcome.WIN, "9 dollars")
	assert_eq(_run(LOSE_IDS, 3, 30.0).outcome(), SiegeSim.Outcome.LOSE, "2 dollars")
	var eight: Array[StringName] = [&"double_men", &"moose"]
	assert_eq(_run(eight, 3, 30.0).outcome(), SiegeSim.Outcome.WIN, "exactly 8")
	var seven: Array[StringName] = [&"double_men", &"booze"]
	assert_eq(_run(seven, 3, 30.0).outcome(), SiegeSim.Outcome.LOSE, "7")


func test_the_stub_decides_at_about_twenty_seconds() -> void:
	for sim_seed in 20:
		var sim := SiegeSim.create(Loadout.of(WIN_IDS), sim_seed)
		sim.step(17.9)
		assert_eq(sim.outcome(), SiegeSim.Outcome.RUNNING, "seed %d at 17.9 s" % sim_seed)
		sim.step(4.2)
		assert_ne(sim.outcome(), SiegeSim.Outcome.RUNNING, "seed %d at 22.1 s" % sim_seed)


func test_the_army_walks_to_the_village_centre() -> void:
	var sim := SiegeSim.create(Loadout.new(), 5)
	var centre := sim.map().village_center
	var start := sim.snapshot()
	sim.step(10.0)
	var later := sim.snapshot()
	for i in start.entity_count():
		if start.ent_team[i] != SiegeSnapshot.Team.ARMY:
			continue
		var before := start.ent_pos[i].distance_to(centre)
		assert_lt(later.ent_pos[i].distance_to(centre), before, "entity %d came closer" % i)
		assert_eq(later.ent_state[i], SiegeSnapshot.State.MOVE)


func test_snapshot_arrays_are_parallel_and_head_counts_add_up() -> void:
	var loadout := Loadout.of(WIN_IDS)
	var shot := SiegeSim.create(loadout, 2).snapshot()
	var n := shot.entity_count()
	assert_gt(n, 0)
	for sizes: int in [
		shot.ent_kind.size(),
		shot.ent_team.size(),
		shot.ent_count.size(),
		shot.ent_state.size(),
		shot.ent_facing.size()
	]:
		assert_eq(sizes, n)
	var men := 0
	var villagers := 0
	for i in n:
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY:
			men += shot.ent_count[i]
		else:
			villagers += shot.ent_count[i]
	assert_eq(men, 300)
	assert_eq(villagers, 2000)


func test_snapshot_values_stay_in_range() -> void:
	var sim := SiegeSim.create(Loadout.of(LOSE_IDS), 4)
	for i in 30:
		sim.step(1.0)
		var shot := sim.snapshot()
		for value: float in [shot.army_morale, shot.village_morale, shot.alarm]:
			assert_between(value, 0.0, 1.0)
		assert_almost_eq(shot.clock_s, sim.clock_s(), 0.0001)
		assert_eq(shot.outcome, sim.outcome())
		for at in shot.ent_pos:
			assert_true(sim.map().bounds.grow(0.01).has_point(at), "inside the map: %s" % at)


func test_events_are_drained_once_per_snapshot() -> void:
	var sim := SiegeSim.create(Loadout.of(WIN_IDS), 6)
	sim.command(SiegeSim.Command.RALLY, Vector2(100, 100))
	var first := sim.snapshot()
	assert_eq(first.events.size(), 1)
	assert_eq(first.events[0]["kind"], &"command")
	assert_eq(first.events[0]["pos"], Vector2(100, 100))
	assert_eq(sim.snapshot().events.size(), 0, "handed over once")


func test_the_decision_raises_one_event_and_marks_the_losers() -> void:
	var win := _run(WIN_IDS, 8, 30.0).snapshot()
	var kinds := win.events.map(func(e: Dictionary) -> StringName: return e["kind"])
	assert_has(kinds, &"alarm")
	assert_has(kinds, &"victory")
	assert_eq(win.village_morale, 0.0)
	var lose := _run(LOSE_IDS, 8, 30.0).snapshot()
	assert_has(lose.events.map(func(e: Dictionary) -> StringName: return e["kind"]), &"combust")
	assert_eq(lose.army_morale, 0.0)
	for i in lose.entity_count():
		if lose.ent_team[i] == SiegeSnapshot.Team.ARMY:
			assert_eq(lose.ent_state[i], SiegeSnapshot.State.DOWN)


func test_commands_move_the_target_and_stop_after_the_decision() -> void:
	var sim := SiegeSim.create(Loadout.of(WIN_IDS), 11)
	sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	assert_eq(sim.snapshot().events[0]["pos"], sim.map().army_spawn)
	sim.command(SiegeSim.Command.RALLY, Vector2(-500, 9000))
	var clamped: Vector2 = sim.snapshot().events[0]["pos"]
	assert_true(sim.map().bounds.grow(0.01).has_point(clamped), "a rally point stays on the map")
	sim.command(99, Vector2.ZERO)
	assert_eq(sim.snapshot().events.size(), 0, "an unknown order is ignored")
	sim.step(30.0)
	sim.snapshot()
	var decided := sim.state_hash()
	sim.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
	assert_eq(sim.snapshot().events.size(), 0, "no orders after the decision")
	assert_eq(sim.state_hash(), decided)


func test_the_map_is_sane_and_seeded() -> void:
	var map := SiegeSim.create(Loadout.new(), 12).map()
	assert_true(map.bounds.has_point(map.village_center))
	assert_true(map.bounds.has_point(map.army_spawn))
	assert_false(map.in_village(map.army_spawn), "the army starts outside the village")
	assert_true(map.in_village(map.village_center))
	assert_eq(map.buildings.size(), SiegeSim.BUILDINGS)
	for building in map.buildings:
		assert_true(map.in_village(building.get_center()), "buildings stand in the village")
	var again := SiegeSim.create(Loadout.new(), 12).map()
	assert_eq(again.buildings, map.buildings, "the same seed builds the same village")


func test_create_copies_the_loadout() -> void:
	var loadout := Loadout.of(WIN_IDS)
	var sim := SiegeSim.create(loadout, 13)
	loadout.ids.clear()
	sim.step(30.0)
	assert_eq(sim.outcome(), SiegeSim.Outcome.WIN, "a later edit does not reach the sim")
