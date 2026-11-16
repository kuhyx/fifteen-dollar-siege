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


func test_the_village_buffs_show_at_the_alarm_one_after_another() -> void:
	var both := _with_event([&"sleepless_village", &"deaf_villagers"], SiegeEvent.ALARM)
	await _play(both, 0.5)
	assert_eq(_seen(both, &"badge"), 1, "sleepless first")
	await _play(both, 1.5)
	assert_eq(_seen(both, &"badge"), 2, "deaf a beat later")
	var deaf := _with_event([&"deaf_villagers"], SiegeEvent.ALARM)
	await _play(deaf, 0.5)
	assert_eq(_seen(deaf, &"badge"), 1, "alone it is at once")
	var none := _with_event([], SiegeEvent.ALARM)
	await _play(none, 2.5)
	assert_eq(_seen(none, &"badge"), 0, "no buff, no badge")
	var bell := _with_event([&"deaf_villagers"], SiegeEvent.BELL_RING)
	await _play(bell, 0.5)
	assert_eq(_seen(bell, &"badge"), 0, "the bell is usually off screen: the alarm is the cue")


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


func test_a_badge_builds_no_pictogram_mesh_on_first_sight() -> void:
	# Lesson L7: nothing is triangulated mid-siege. The chips warm every size
	# between a chip and a large chip; a badge must stay inside that range.
	var ids: Array[StringName] = [&"stew", &"sleepless_village", &"deaf_villagers"]
	var battle := _battle(ids)
	var before := {}
	for id in ids:
		before[id] = BuffPictograms.of(id)._meshes.size()
	for id in ids:
		battle.effects.flourish(&"badge", FxSigns.badge, 2.5, Vector2(300, 300), {"id": id})
	for step in 40:
		battle.effects.advance(0.001 if step < 8 else 0.07)  # the pop-in frames first
		var zoom: float = [3.0, 6.0, 12.0, 22.0][step % 4]
		battle.world.scale = Vector2.ONE * zoom
		battle.effects.view_zoom = zoom
		battle.effects.queue_redraw()
		await get_tree().process_frame
	for id in ids:
		assert_eq(BuffPictograms.of(id)._meshes.size(), before[id], "%s built a mesh" % id)
