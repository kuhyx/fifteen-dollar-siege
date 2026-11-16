extends GutTest
## Delights: every fallen head pops where it fell, and every ten of the
## village that fall ring a gold tally over the army. Fails when either stops
## firing, when the army's own losses ring the bell, or when a storm of
## deaths floods the screen with pops.


## A real sim whose village loses `loss` heads more on every snapshot.
class BleedSim:
	extends SiegeSim
	var inner: SiegeSim
	var loss := 0
	var taken := 0

	func map() -> SiegeMap:
		return inner.map()

	func step(dt: float) -> void:
		inner.step(dt)

	func command(kind: int, pos: Vector2) -> void:
		inner.command(kind, pos)

	func snapshot() -> SiegeSnapshot:
		var shot := inner.snapshot()
		taken += loss
		var left := taken
		for i in shot.entity_count():
			if shot.ent_team[i] == SiegeSnapshot.Team.VILLAGE and left > 0:
				var cut := mini(left, shot.ent_count[i])
				shot.ent_count[i] -= cut
				left -= cut
		return shot

	func outcome() -> int:
		return SiegeSim.Outcome.RUNNING

	func clock_s() -> float:
		return inner.clock_s()

	func state_hash() -> int:
		return inner.state_hash()


func _shot(counts: Array, team := SiegeSnapshot.Team.VILLAGE) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	for i in counts.size():
		shot.ent_pos.append(Vector2(100.0 + i * 50.0, 200.0))
		shot.ent_kind.append(SiegeSnapshot.Kind.VILLAGERS)
		shot.ent_team.append(team)
		shot.ent_count.append(counts[i])
		shot.ent_state.append(SiegeSnapshot.State.FIGHT)
		shot.ent_facing.append(0.0)
	return shot


func test_a_fall_pops_once_then_waits_and_adds_up() -> void:
	var toll := BattleToll.new()
	toll.feed(_shot([50, 50]), 0.0)
	var first: Dictionary = toll.feed(_shot([48, 50]), 0.1)
	assert_eq(first.pops.size(), 1, "two heads fell in one squad: one pop")
	assert_eq(first.pops[0].n, 2)
	assert_eq(first.pops[0].pos, Vector2(100.0, 200.0))
	assert_eq(toll.feed(_shot([46, 50]), 0.15).pops.size(), 0, "the same squad waits its turn")
	var later: Dictionary = toll.feed(_shot([45, 50]), 0.5)
	assert_eq(later.pops[0].n, 3, "what fell meanwhile adds up")


func test_every_tenth_fallen_villager_rings_the_tally_once() -> void:
	var step := BattleToll.MILESTONE
	var toll := BattleToll.new()
	toll.feed(_shot([500]), 0.0)
	assert_eq(toll.feed(_shot([500 - step + 1]), 1.0).tolls.size(), 0, "one short")
	var rung: Array = toll.feed(_shot([500 - step - 2]), 2.0).tolls
	assert_eq(rung.size(), 1)
	assert_eq(rung[0].total, step)
	assert_eq(toll.feed(_shot([500 - step - 3]), 3.0).tolls.size(), 0, "once")
	var jump: Array = toll.feed(_shot([500 - 3 * step - 3]), 4.0).tolls
	assert_eq(jump.size(), 2, "two milestones in one jump ring twice")
	assert_eq(jump[1].total, 3 * step)


func test_the_armys_own_dead_do_not_ring_the_bell() -> void:
	var toll := BattleToll.new()
	toll.feed(_shot([500], SiegeSnapshot.Team.ARMY), 0.0)
	var out: Dictionary = toll.feed(_shot([100], SiegeSnapshot.Team.ARMY), 1.0)
	assert_eq(out.tolls.size(), 0)
	assert_eq(out.pops.size(), 1, "but they still pop where they fell")


func test_a_storm_of_deaths_is_capped_per_snapshot() -> void:
	var toll := BattleToll.new()
	var before: Array = []
	var after: Array = []
	for i in 40:
		before.append(20)
		after.append(10)
	toll.feed(_shot(before), 0.0)
	assert_lte(toll.feed(_shot(after), 1.0).pops.size(), BattleToll.MAX_POPS)


func test_the_screen_shows_pops_and_the_tally_for_a_bleeding_village() -> void:
	var sim := BleedSim.new()
	sim.inner = SiegeSim.create(Loadout.new(), 5)
	var battle := BattleScreen.new()
	battle.setup(sim, &"watch", 1.0)
	add_child_autofree(battle)
	battle.set_process(false)  # the test owns the clock: no real-time frames on top
	sim.loss = 60
	for tick in 12:
		battle._take(sim.snapshot(), 0.1)
		battle._process(0.3)
	assert_gt(int(battle.effects.seen.get(&"pop", 0)), 0, "pops on the field")
	assert_gt(int(battle.effects.seen.get(&"toll", 0)), 0, "the tally rang: 720 fell")
	var live_toll := battle.effects.live.filter(
		func(fx: BattleFx) -> bool: return fx.kind == &"toll"
	)
	assert_gt(live_toll.size(), 0, "and one is still on screen")
	assert_eq(AudioCues.FUN.size(), 8)


func test_the_rare_moments_outlive_the_shedding_threshold() -> void:
	assert_gt(BattleFlair.KEEP_S, BattleEffects.SHED_BELOW_S, "a busy frame must not shed them")
