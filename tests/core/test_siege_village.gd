extends GutTest
## The village of 2,000 (DOCS-design-sim.md "The village"): who lives there,
## how it notices the army, how the alarm spreads and how the militia musters.

const K := SiegeSnapshot.Kind
const ST := SiegeSnapshot.State


func _heads(shot: SiegeSnapshot, kind: int) -> int:
	var total := 0
	for i in shot.entity_count():
		if shot.ent_kind[i] == kind:
			total += shot.ent_count[i]
	return total


func _kinds(shot: SiegeSnapshot) -> Array[StringName]:
	var out: Array[StringName] = []
	for event in shot.events:
		out.append(event["kind"])
	return out


func test_the_village_has_fighters_and_non_combatants() -> void:
	var shot := SiegeSim.create(Loadout.new(), 1).snapshot()
	assert_eq(_heads(shot, K.MILITIA), 250, "militia with farm tools")
	assert_eq(_heads(shot, K.RETINUE), 20, "the lord's mailed retinue")
	assert_eq(_heads(shot, K.ARCHERS), 30, "hunters with bows")
	assert_eq(_heads(shot, K.VILLAGERS), 1700, "everybody else flees or hides")
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.VILLAGE and shot.ent_kind[i] != K.VILLAGERS:
			assert_lte(shot.ent_count[i], 10, "fighters stand in squads of about 10")


func test_the_church_is_a_building_with_a_bell() -> void:
	var map := SiegeSim.create(Loadout.new(), 2).map()
	assert_eq(map.church, map.buildings[0], "the church is the first building")
	assert_true(map.church.has_point(map.bell), "the bell hangs in the church")
	assert_gt(map.centre_radius, 0.0)
	assert_lt(map.centre_radius, map.village_radius)


func test_the_village_sleeps_until_the_army_draws_near() -> void:
	var sim := SiegeSim.create(Loadout.new(), 3)
	sim.step(2.0)
	var early := sim.snapshot()
	assert_eq(early.alarm, 0.0, "nobody has seen anything yet")
	assert_does_not_have(_kinds(early), SiegeEvent.ALARM)
	sim.step(48.0)
	var later := sim.snapshot()
	assert_gt(later.alarm, 0.5, "the alarm spread while the army closed in")
	var kinds := _kinds(later)
	assert_has(kinds, SiegeEvent.ALARM)
	assert_has(kinds, SiegeEvent.BELL_RING)
	assert_eq(kinds.count(SiegeEvent.ALARM), 1, "the alarm goes up once")


func test_the_alarm_never_falls() -> void:
	var sim := SiegeSim.create(Loadout.new(), 4)
	var last := 0.0
	for i in 120:
		sim.step(0.5)
		var alarm := sim.snapshot().alarm
		assert_gte(alarm, last)
		last = alarm


func test_the_militia_musters_after_the_alarm_not_before() -> void:
	var sim := SiegeSim.create(Loadout.new(), 5)
	var start := sim.snapshot()
	sim.step(3.0)
	var calm := sim.snapshot()
	for i in calm.entity_count():
		if calm.ent_team[i] == SiegeSnapshot.Team.VILLAGE:
			assert_eq(calm.ent_pos[i], start.ent_pos[i], "nobody moves before the alarm")
	sim.step(50.0)
	var roused := sim.snapshot()
	var moved := 0
	var hidden := 0
	for i in roused.entity_count():
		if roused.ent_team[i] != SiegeSnapshot.Team.VILLAGE:
			continue
		if roused.ent_kind[i] == K.VILLAGERS:
			hidden += int(roused.ent_state[i] in [ST.HIDDEN, ST.FLEE])
		elif roused.ent_pos[i].distance_to(start.ent_pos[i]) > 5.0:
			moved += 1
	assert_gt(moved, 5, "armed squads left their homes")
	assert_gt(hidden, 5, "non-combatants flee or hide")


func test_an_abduction_takes_a_hundred_villagers_before_the_first_tick() -> void:
	var sim := SiegeSim.create(Loadout.of([&"abduction"]), 6)
	var shot := sim.snapshot()
	var villagers := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.VILLAGE:
			villagers += shot.ent_count[i]
	assert_eq(villagers, 1900)
	var taken := 0
	for event in shot.events:
		assert_eq(event["kind"], SiegeEvent.UFO_ABDUCT, "only pre-battle events at tick 0")
		assert_true(sim.map().in_village(event["pos"]))
		taken += int(event["heads"])
	assert_eq(taken, 100)
	assert_eq(sim.clock_s(), 0.0)
