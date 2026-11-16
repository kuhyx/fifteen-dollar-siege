extends GutTest
## The three orders of Command mode: each must change the fight in a way the
## player can see (DOCS-design-sim.md "Orders").

const K := SiegeSnapshot.Kind
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE
const IDS: Array[StringName] = [&"fifty_men"]


func _sim(sim_seed := 31) -> SiegeSim:
	return SiegeSim.create(Loadout.of(IDS), sim_seed)


func _men(shot: SiegeSnapshot) -> Array[int]:
	var out: Array[int] = []
	for i in shot.entity_count():
		if shot.ent_kind[i] == K.MEN:
			out.append(i)
	return out


func _mean_x(shot: SiegeSnapshot) -> float:
	var sum := 0.0
	for i in _men(shot):
		sum += shot.ent_pos[i].x
	return sum / _men(shot).size()


func test_rally_gathers_the_army_at_the_flag() -> void:
	var sim := _sim()
	var flag := Vector2(230.0, 110.0)
	sim.step(3.0)
	sim.command(SiegeSim.Command.RALLY, flag)
	sim.step(40.0)
	var shot := sim.snapshot()
	for i in _men(shot):
		assert_lt(shot.ent_pos[i].distance_to(flag), 45.0, "squad %d stands by the flag" % i)
		assert_ne(shot.ent_state[i], SiegeSnapshot.State.MOVE, "and holds there")


func test_charge_gets_there_sooner_than_the_default_march() -> void:
	var marching := _sim()
	var charging := _sim()
	charging.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
	marching.step(15.0)
	charging.step(15.0)
	assert_gt(_mean_x(charging.snapshot()), _mean_x(marching.snapshot()) + 15.0)


func test_retreat_brings_the_army_back_to_the_start() -> void:
	var sim := _sim()
	sim.step(20.0)
	var advanced := _mean_x(sim.snapshot())
	sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	sim.step(25.0)
	var shot := sim.snapshot()
	assert_lt(_mean_x(shot), advanced - 40.0)
	for i in _men(shot):
		assert_lt(shot.ent_pos[i].distance_to(sim.map().army_spawn), 60.0)


func test_an_order_stands_until_the_next_one() -> void:
	var sim := _sim()
	sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	sim.step(30.0)
	var held := _mean_x(sim.snapshot())
	assert_lt(held, sim.map().army_spawn.x + 5.0, "nobody marches while the retreat stands")
	sim.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
	sim.step(10.0)
	assert_gt(_mean_x(sim.snapshot()), held + 30.0, "the charge replaced it")


func test_defenders_do_not_chase_beyond_the_leash() -> void:
	var sim := _sim()
	var map := sim.map()
	var limit := map.village_radius + SiegeTuning.LEASH_M + 8.0
	sim.step(55.0)
	sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	for step in 40:
		sim.step(1.0)
		var shot := sim.snapshot()
		for i in shot.entity_count():
			if shot.ent_team[i] != VILLAGE or shot.ent_kind[i] == K.VILLAGERS:
				continue
			if shot.ent_state[i] == SiegeSnapshot.State.FLEE:
				continue
			var from_home := shot.ent_pos[i].distance_to(map.village_center)
			assert_lt(from_home, limit, "squad %d at %.0f m" % [i, from_home])
