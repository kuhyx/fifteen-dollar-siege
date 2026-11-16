extends GutTest
## The 25 buffs: each one changes the siege, and the ones that put something
## on the field put the right thing there (DOCS-design-sim.md "Buffs").

const K := SiegeSnapshot.Kind
const ST := SiegeSnapshot.State
const ARMY := SiegeSnapshot.Team.ARMY


func _sim(ids: Array, sim_seed := 21) -> SiegeSim:
	return SiegeSim.create(Loadout.of(ids), sim_seed)


## [entities, heads] of `kind` in the snapshot.
func _of_kind(shot: SiegeSnapshot, kind: int) -> Vector2i:
	var out := Vector2i.ZERO
	for i in shot.entity_count():
		if shot.ent_kind[i] == kind:
			out += Vector2i(1, shot.ent_count[i])
	return out


func _army_heads(shot: SiegeSnapshot) -> int:
	var heads := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == ARMY:
			heads += shot.ent_count[i]
	return heads


## Mean x of the army's entities of `kind`.
func _front_x(shot: SiegeSnapshot, kind: int) -> float:
	var sum := 0.0
	var n := 0
	for i in shot.entity_count():
		if shot.ent_kind[i] == kind and shot.ent_team[i] == ARMY:
			sum += shot.ent_pos[i].x
			n += 1
	return sum / maxi(n, 1)


func _event_kinds(sim: SiegeSim, seconds: float) -> Array[StringName]:
	var out: Array[StringName] = []
	var left := seconds
	while left > 0.0 and sim.outcome() == SiegeSim.Outcome.RUNNING:
		sim.step(1.0)
		left -= 1.0
		for event in sim.snapshot().events:
			out.append(event["kind"])
	return out


## True when the siege with `ids` differs from the one without, 70 s in, for at
## least one of three seeds (a small buff can leave one siege untouched).
func _changes_the_siege(ids: Array, plain: Array[int]) -> bool:
	for index in plain.size():
		var buffed := _sim(ids, 21 + index)
		buffed.step(70.0)
		if buffed.state_hash() != plain[index]:
			return true
	return false


func test_every_buff_changes_the_siege() -> void:
	var plain: Array[int] = []
	for index in 3:
		var sim := _sim([], 21 + index)
		sim.step(70.0)
		plain.append(sim.state_hash())
	for def in BuffCatalog.all():
		assert_true(_changes_the_siege([def.id], plain), "%s does something" % def.id)


func test_specials_take_the_field_with_the_right_heads() -> void:
	var rows := {
		&"stitched_monster": [K.MONSTER, 1, 1],
		&"moose": [K.MOOSE, 3, 3],
		&"wasps": [K.WASPS, 1, 300],
		&"medics": [K.MEDICS, 2, 20],
		&"emperor": [K.EMPEROR, 1, 1],
		&"trumpet_boy": [K.TRUMPET_BOY, 1, 1],
		&"rock_band": [K.ROCK_BAND, 1, 5],
	}
	for id: StringName in rows:
		var shot := _sim([id]).snapshot()
		var row: Array = rows[id]
		assert_eq(_of_kind(shot, row[0]), Vector2i(row[1], row[2]), "%s joins the army" % id)
		assert_eq(_army_heads(shot), 100 + row[2], "%s comes on top of the 100 men" % id)


func test_gear_goes_to_men_already_in_the_army() -> void:
	var rows := {
		&"metal_bats": [K.BAT_MEN, 1, 10],
		&"shotgun": [K.SHOTGUNNER, 1, 1],
		&"golf_carts": [K.GOLF_CARTS, 6, 60],
		&"pumpkin_catapults": [K.CATAPULT, 2, 10],
	}
	for id: StringName in rows:
		var shot := _sim([id]).snapshot()
		var row: Array = rows[id]
		assert_eq(_of_kind(shot, row[0]), Vector2i(row[1], row[2]), "%s" % id)
		assert_eq(_army_heads(shot), 100, "%s adds no men" % id)


func _hidden_heads(shot: SiegeSnapshot) -> int:
	var hidden := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == ARMY and shot.ent_state[i] == ST.HIDDEN:
			hidden += shot.ent_count[i]
	return hidden


func test_fifty_potions_hide_fifty_men_who_sneak_into_the_plaza() -> void:
	var sim := _sim([&"invisibility_potions", &"double_men"])
	var map := sim.map()
	assert_eq(_hidden_heads(sim.snapshot()), 50)
	sim.step(64.0)
	var shot := sim.snapshot()
	assert_eq(_hidden_heads(shot), 50, "nobody saw them come")
	for i in shot.entity_count():
		if shot.ent_state[i] == ST.HIDDEN and shot.ent_team[i] == ARMY:
			var from_centre := shot.ent_pos[i].distance_to(map.village_center)
			assert_lt(from_centre, map.centre_radius, "squad %d stands in the plaza" % i)


func test_the_unseen_show_when_the_potion_wears_off_or_they_strike() -> void:
	# Held back at the start line the whole army outlives the potion.
	var waiting := _sim([&"invisibility_potions"])
	waiting.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	var kinds := _event_kinds(waiting, BuffTuning.POTION_S + 2.0)
	assert_eq(kinds.count(SiegeEvent.REVEAL), 5, "every unseen squad shows exactly once")
	assert_eq(_hidden_heads(waiting.snapshot()), 0, "nobody is unseen after the potion")
	# Rallied at the village edge they fight: the first blow is an ambush.
	var striking := _sim([&"invisibility_potions"])
	var edge := striking.map().village_center - Vector2(striking.map().village_radius, 0.0)
	striking.command(SiegeSim.Command.RALLY, edge)
	assert_has(_event_kinds(striking, 70.0), SiegeEvent.REVEAL, "an ambush shows them")


func test_knight_armor_slows_the_march() -> void:
	var plain := _sim([])
	var armored := _sim([&"knight_armor"])
	plain.step(20.0)
	armored.step(20.0)
	assert_lt(_front_x(armored.snapshot(), K.MEN), _front_x(plain.snapshot(), K.MEN) - 5.0)


func test_golf_carts_ram_and_are_heard_from_afar() -> void:
	var sim := _sim([&"golf_carts"])
	sim.step(10.0)
	assert_gt(sim.snapshot().alarm, 0.0, "the engines woke the village at once")
	assert_has(_event_kinds(sim, 60.0), SiegeEvent.CART_CRASH)


func test_a_rock_band_wakes_the_village_at_once_and_keeps_playing() -> void:
	var sim := _sim([&"rock_band"])
	var kinds := _event_kinds(sim, 20.0)
	assert_eq(kinds[0], SiegeEvent.ALARM, "the first chord is the alarm")
	assert_gt(kinds.count(SiegeEvent.BAND_RIFF), 2)


func test_a_sleepless_village_notices_later() -> void:
	# At 12 s the nearest man is about 90 m from the houses: inside a rested
	# village's sight (105 m), outside a sleepless one's (70 m).
	for sim_seed in 6:
		var sim := _sim([&"sleepless_village"], sim_seed)
		sim.step(12.0)
		assert_eq(sim.snapshot().alarm, 0.0, "seed %d: still asleep" % sim_seed)


func test_deaf_villagers_slow_the_alarm() -> void:
	var plain := _sim([&"rock_band"])
	var deaf := _sim([&"rock_band", &"deaf_villagers"])
	plain.step(12.0)
	deaf.step(12.0)
	assert_lt(deaf.snapshot().alarm, plain.snapshot().alarm)


func test_the_pep_talk_happens_before_the_first_tick() -> void:
	var sim := _sim([&"pep_talk"])
	var events := sim.snapshot().events
	assert_eq(events.size(), 1)
	assert_eq(events[0]["kind"], SiegeEvent.PEP_TALK)
	assert_eq(events[0]["pos"], sim.map().army_spawn)


func test_each_special_is_seen_and_heard_in_a_siege() -> void:
	var rows := {
		&"shotgun": SiegeEvent.SHOTGUN_BLAST,
		&"pumpkin_catapults": SiegeEvent.PUMPKIN_SPLAT,
		&"wasps": SiegeEvent.WASP_SWARM,
		&"moose": SiegeEvent.MOOSE_CHARGE,
		&"stitched_monster": SiegeEvent.MONSTER_SMASH,
		&"trumpet_boy": SiegeEvent.TRUMPET_CALL,
		&"medics": SiegeEvent.HEAL,
	}
	for id: StringName in rows:
		var kinds: Array[StringName] = []
		for sim_seed in [5, 6, 7]:
			if not kinds.has(rows[id]):
				kinds = _event_kinds(_sim([id, &"double_men"], sim_seed), 150.0)
		assert_has(kinds, rows[id], "%s shows" % id)


func test_drunk_squads_may_ignore_an_order() -> void:
	var sim := _sim([&"booze", &"double_men"])
	sim.step(5.0)
	sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	var before := sim.snapshot()
	sim.step(6.0)
	var after := sim.snapshot()
	var obeyed := 0
	var ignored := 0
	for i in after.entity_count():
		if after.ent_kind[i] != K.MEN:
			continue
		if after.ent_pos[i].x > before.ent_pos[i].x + 5.0:
			ignored += 1
		else:
			obeyed += 1
	assert_gt(ignored, 0, "some squads keep marching on the village")
	assert_gt(obeyed, ignored, "most obey")
