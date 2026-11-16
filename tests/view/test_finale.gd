extends GutTest
## Delights at the big moments: the army hops with every tally, fireworks
## burst over the church at a win, and the monster's ring is big enough to
## find in a melee. Fails when any stops firing.


func _battle(ids: Array) -> BattleScreen:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of(ids)
	battle.setup(SiegeSim.create(battle.loadout, 5), &"watch", 1.0)
	add_child_autofree(battle)
	battle.set_process(false)  # the test owns the clock: no real-time frames on top
	return battle


func _victory(battle: BattleScreen) -> void:
	var shot := battle.sim.snapshot()
	shot.events.append({"kind": SiegeEvent.VICTORY, "pos": battle.sim.map().village_center})
	battle._take(shot, 0.1)


func test_a_win_sets_off_fireworks_and_the_army_cheers() -> void:
	var battle := _battle([])
	_victory(battle)
	assert_gt(battle.crowd._cheer, 0.0, "the men jump for joy")
	for step in 14:
		battle._process(0.25)
		await get_tree().process_frame
	assert_gte(int(battle.effects.seen.get(&"firework", 0)), 5, "a volley of rockets")


func test_a_decided_win_celebrates_even_with_no_victory_event() -> void:
	var battle := _battle([])
	battle.flair.celebrate(battle)
	battle.flair.celebrate(battle)
	for step in 24:
		battle._process(0.25)
		await get_tree().process_frame
	assert_eq(int(battle.effects.seen.get(&"firework", 0)), BattleFlair.ROCKETS, "once, not twice")


func test_a_win_unmasks_the_invisible_men() -> void:
	# Unseen men never strike in a Watch siege, so no REVEAL event ever comes:
	# the potions wear off with the flag instead.
	var battle := _battle([&"invisibility_potions"])
	var hidden := 0
	for i in battle.shot.entity_count():
		var army := battle.shot.ent_team[i] == SiegeSnapshot.Team.ARMY
		if army and battle.shot.ent_state[i] == SiegeSnapshot.State.HIDDEN:
			hidden += 1
	assert_gt(hidden, 0, "the sim hides squads")
	battle._process(0.05)
	battle.flair.celebrate(battle)
	for step in 24:
		battle._process(0.25)
		await get_tree().process_frame
	assert_eq(int(battle.effects.seen.get(SiegeEvent.REVEAL, 0)), hidden)
	for squad in battle.crowd.squads:
		if squad.state == SiegeSnapshot.State.HIDDEN and squad.team == SiegeSnapshot.Team.ARMY:
			assert_eq(squad.material.get_shader_parameter("shimmer"), 0.0, "no longer a ghost")
	var plain := _battle([])
	plain.flair.celebrate(plain)
	for step in 8:
		plain._process(0.25)
	assert_eq(int(plain.effects.seen.get(SiegeEvent.REVEAL, 0)), 0)


func test_no_fireworks_without_a_win() -> void:
	var battle := _battle([])
	for step in 14:
		battle._process(0.25)
		await get_tree().process_frame
	assert_eq(int(battle.effects.seen.get(&"firework", 0)), 0)


func test_the_army_hops_for_each_tally() -> void:
	var battle := _battle([])
	assert_eq(battle.crowd._cheer, 0.0)
	battle.flair.toll.fallen[SiegeSnapshot.Team.VILLAGE] = BattleToll.MILESTONE - 1
	var shot := battle.sim.snapshot()
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.VILLAGE:
			battle.flair.toll.feed(shot, 0.0)
			shot.ent_count[i] -= 3
			break
	battle.flair.take(shot, 1.0, battle)
	assert_gt(battle.crowd._cheer, 0.0)


func test_the_monster_ring_is_the_biggest() -> void:
	var monster := FxHeroes.ring_px(SiegeSnapshot.Kind.MONSTER)
	assert_gt(monster, FxHeroes.ring_px(SiegeSnapshot.Kind.EMPEROR))
	assert_gt(FxHeroes.ring_px(SiegeSnapshot.Kind.EMPEROR), FxHeroes.RING_PX)
	assert_eq(FxHeroes.ring_px(SiegeSnapshot.Kind.TRUMPET_BOY), FxHeroes.RING_PX)
