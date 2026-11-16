extends GutTest
## The payoff has one subject. At a loss the army's flames: the village crowd
## dims and a night veil falls over the map and the crowd, and only the
## burning army (drawn above it) stays lit. At a win the army and its flag
## stay bright and the village crowd dims.


func _payoff(ids: Array) -> BattleScreen:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of(ids)
	battle.setup(SiegeSim.create(battle.loadout, 5), &"watch", 1.0)
	add_child_autofree(battle)
	battle.speed = 64.0
	return battle


func _dim_of(squad: SquadVisual) -> float:
	var value: Variant = squad.material.get_shader_parameter("dim")
	return 1.0 if value == null else float(value)


func test_at_a_loss_the_flames_are_the_only_bright_thing() -> void:
	var battle := _payoff([&"stew"])
	await wait_until(func() -> bool: return battle.payoff_active, 10.0)
	await wait_frames(3)
	assert_eq(battle.effects.veil_goal, 1.0, "the veil falls")
	var village := 0
	for squad in battle.crowd.squads:
		if squad.team == SiegeSnapshot.Team.ARMY:
			assert_true(squad.burning)
			assert_eq(_dim_of(squad), 1.0, "the burning army is not dimmed")
		else:
			village += 1
			assert_lte(_dim_of(squad), CrowdLayer.DIM_LOSS, "the village crowd is dimmed")
	assert_gt(village, 0)
	await wait_seconds(0.8)
	assert_gt(battle.effects.veil, 0.5, "the veil has fallen")


func test_at_a_win_the_village_dims_and_the_army_stays_bright() -> void:
	var battle := _payoff([&"double_men", &"fifty_men"])
	await wait_until(func() -> bool: return battle.payoff_active, 10.0)
	await wait_frames(3)
	assert_eq(battle.effects.veil_goal, 0.0, "no night over a victory")
	for squad in battle.crowd.squads:
		var want := 1.0 if squad.team == SiegeSnapshot.Team.ARMY else CrowdLayer.DIM_WIN
		assert_eq(_dim_of(squad), want)


func test_the_veil_is_gone_in_a_new_siege() -> void:
	var battle := _payoff([&"double_men", &"fifty_men"])
	assert_eq(battle.effects.veil, 0.0)
	for squad in battle.crowd.squads:
		assert_eq(_dim_of(squad), 1.0)
