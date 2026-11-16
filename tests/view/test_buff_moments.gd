extends GutTest
## Delights for the buffs that used to show only a chip, and for the armour
## and booze looks that vanished at the default zoom. Each fails when the
## moment stops firing: a badge pops over the army, a clock sweeps, a number
## rolls up, steel glints, cardboard flakes, the drunk hiccup.

const STEP_S := 0.25


func _battle(ids: Array) -> BattleScreen:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of(ids)
	battle.setup(SiegeSim.create(battle.loadout, 5), &"watch", 1.0)
	add_child_autofree(battle)
	return battle


func _play(battle: BattleScreen, seconds: float) -> void:
	for step in int(seconds / STEP_S):
		battle._process(STEP_S)
		await get_tree().process_frame


func _seen(battle: BattleScreen, kind: StringName) -> int:
	return int(battle.effects.seen.get(kind, 0))


func test_stew_shows_a_bowl_and_steam_over_the_army() -> void:
	var battle := _battle([&"stew"])
	await _play(battle, 4.0)
	assert_gt(_seen(battle, &"badge"), 0, "the stew badge pops")
	assert_gt(_seen(battle, &"steam"), 0, "and steam rises")


func test_each_prep_time_sweeps_a_clock() -> void:
	var battle := _battle([&"prep_hour", &"prep_ten_minutes"])
	await _play(battle, 4.0)
	assert_eq(_seen(battle, &"clock"), 2, "one clock per bought prep time")
	var plain := _battle([&"stew"])
	await _play(plain, 4.0)
	assert_eq(_seen(plain, &"clock"), 0, "and none without")


func test_the_army_number_rolls_up_to_what_the_buff_made_it() -> void:
	var battle := _battle([&"double_men"])
	await _play(battle, 4.0)
	assert_eq(_seen(battle, &"count"), 1)
	var rolling: Array = battle.effects.live.filter(
		func(fx: BattleFx) -> bool: return fx.kind == &"count"
	)
	for fx: BattleFx in battle.effects.live:
		if fx.kind == &"count":
			assert_eq(fx.data.to, 200)
			assert_eq(fx.data.from, 100)
	assert_eq(_seen(_battle([]), &"count"), 0)
	assert_true(rolling.size() <= 1)


func _with_event(ids: Array, kind: StringName) -> BattleScreen:
	var battle := _battle(ids)
	var shot := battle.sim.snapshot()
	shot.events.append({"kind": kind, "pos": battle.sim.map().village_center})
	battle._take(shot, 0.1)
	return battle


func test_a_sleepless_village_opens_its_eyes_at_the_alarm() -> void:
	var woke := _with_event([&"sleepless_village"], SiegeEvent.ALARM)
	assert_eq(_seen(woke, &"badge"), 1)
	assert_eq(_seen(_with_event([], SiegeEvent.ALARM), &"badge"), 0)


func test_a_deaf_village_shows_its_crossed_ear_at_the_bell() -> void:
	var rung := _with_event([&"deaf_villagers"], SiegeEvent.BELL_RING)
	assert_eq(_seen(rung, &"badge"), 1)
	assert_eq(_seen(_with_event([&"stew"], SiegeEvent.BELL_RING), &"badge"), 0)


func test_looks_glint_flake_hiccup_and_ping() -> void:
	var want := {
		&"knight_armor": &"glint",
		&"football_helmets": &"glint",
		&"cardboard_armor": &"scrap",
		&"booze": &"hic",
		&"metal_bats": &"ping",
	}
	for id: StringName in want:
		var battle := _battle([id])
		await _play(battle, 5.0)
		assert_gt(_seen(battle, want[id]), 1, "%s shows %s" % [id, want[id]])
	var bare := _battle([])
	await _play(bare, 5.0)
	for kind: StringName in [&"glint", &"scrap", &"hic", &"ping"]:
		assert_eq(_seen(bare, kind), 0, "an army with no look has no %s" % kind)


func test_every_new_moment_draws_to_the_end_of_its_life() -> void:
	var battle := _battle([&"stew", &"prep_hour", &"double_men", &"knight_armor", &"booze"])
	await _play(battle, 8.0)
	battle.effects.queue_redraw()
	await get_tree().process_frame
	assert_gt(battle.effects.draws, 0)
	assert_eq(AudioCues.FUN.size(), 8)
