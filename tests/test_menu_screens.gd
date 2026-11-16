extends GutTest
## The hub, the Lab and the result screen through the real main scene: mode
## buttons with keys, the Lab's time-sliced batch and its ranking, the payoff
## that plays before any control shows, and the three ways on.

var main: Main


func before_each() -> void:
	SaveStore.clear()
	MenuKeys.device = MenuKeys.Device.KEYS
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.options.speed = 32.0
	main.options.sim_seed = 5
	main.options.lab_runs = 6
	# One frame old before any synthesized input (see tests/test_menu_keys.gd).
	await wait_process_frames(1)


func after_each() -> void:
	get_tree().paused = false


func _frame_holds(control: Control) -> bool:
	var frame := control.get_parent() as Control
	while frame != null and not frame is ScreenFrame:
		control = frame
		frame = frame.get_parent() as Control
	return frame != null and Rect2(Vector2.ZERO, ScreenFrame.SIZE).encloses(control.get_rect())


func _to_result(ids: Array) -> ResultScreen:
	main.mode = &"watch"
	main.start_siege(Loadout.of(ids))
	(main.screen as BattleScreen).payoff_s = 0.05
	await wait_until(func() -> bool: return main.screen_name == &"result", 20.0)
	return main.screen as ResultScreen


func test_the_hub_has_three_picture_buttons_a_shelf_and_no_lab_rate_yet() -> void:
	var hub := main.screen as HubScreen
	for mode: StringName in hub.buttons:
		var button := hub.buttons[mode] as PictoButton
		assert_false(button.picture.is_empty(), "%s has a picture" % mode)
		assert_true(_frame_holds(button), "%s is inside the frame" % mode)
		assert_not_null(button.get_node_or_null("KeyHint"), "%s shows its key" % mode)
	assert_true(_frame_holds(hub.shelf), "the shelf is inside the frame")
	assert_true(hub.shelf.won.is_empty())
	assert_lt(hub.best_lab.rate, 0.0, "the Lab has not run yet")
	assert_true(Rect2(Vector2.ZERO, hub.shelf.size).encloses(hub.shelf.slot(24)), "25 slots fit")
	assert_eq(
		main.pick_at(hub.shelf.get_global_transform() * hub.shelf.slot(3).get_center())["id"],
		"abduction"
	)


func test_a_number_key_picks_a_mode() -> void:
	InputSynth.key_tap(KEY_3)
	await wait_process_frames(2)
	assert_eq(main.screen_name, &"loadout")
	assert_eq(main.mode, &"lab", "3 is the third button: the Lab")


func test_the_lab_runs_in_slices_and_agrees_with_the_core() -> void:
	var loadout := Loadout.of([&"double_men", &"fifty_men"])
	var runner := LabRunner.new(loadout, 5, 11)
	var slices := 0
	while not runner.is_done():
		runner.work(0)
		slices += 1
	assert_gt(slices, 5, "a zero budget still moves, a few ticks at a time")
	assert_eq(runner.result, Lab.run_batch(loadout, 5, 11), "the same numbers as the core")
	assert_eq(runner.outcomes, PackedByteArray([1, 1, 1, 1, 1]))
	var none := LabRunner.new(loadout, 0, 1)
	assert_true(none.is_done(), "an empty batch is done at once")


func test_the_lab_screen_reveals_every_siege_and_ranks_the_loadout() -> void:
	main.mode = &"lab"
	main.start_siege(Loadout.of([&"stew"]))
	var lab := main.screen as LabScreen
	assert_true(_frame_holds(lab.controls), "the controls are inside the frame")
	assert_true(_frame_holds(lab.ranking))
	await wait_until(func() -> bool: return lab.done and lab.shown_runs == 6, 20.0)
	assert_eq(lab.ticks.shown, 6, "one tick per siege")
	assert_eq(lab.ticks.share_won(0), 0.0, "a lost siege")
	assert_eq(lab.shown_rate(), 0.0)
	assert_eq(lab.ranking.lines.size(), 1)
	assert_eq(lab.ranking.current_key, "stew")
	watch_signals(main)
	InputSynth.key_tap(KEY_1)
	await wait_process_frames(2)
	assert_signal_emitted(main, "siege_started", "1 runs the same loadout again")
	assert_eq(main.loadout.ids, [&"stew"] as Array[StringName])
	lab = main.screen as LabScreen
	lab.controls.edit.pressed.emit()
	assert_eq(main.screen_name, &"loadout")
	assert_eq((main.screen as LoadoutScreen).loadout.ids, [&"stew"] as Array[StringName])


func test_ticks_share_out_a_big_batch_and_the_ranking_keeps_the_current_row() -> void:
	var strip := TickStrip.new()
	autofree(strip)
	strip.total = 1000
	strip.outcomes = PackedByteArray([1, 1, 0, 1, 0, 0])
	strip.shown = 5
	assert_eq(strip.tick_count(), TickStrip.MAX_TICKS)
	assert_almost_eq(strip.share_won(0), 2.0 / 3.0, 0.001, "three sieges per tick")
	assert_almost_eq(strip.share_won(1), 0.5, 0.001, "only the sieges on show count")
	assert_eq(strip.share_won(2), -1.0, "nothing there yet")
	var ranking := LabRanking.new()
	autofree(ranking)
	var lines: Array[Dictionary] = []
	for i in 12:
		lines.append(
			{"key": "k%d" % i, "ids": [], "wins": 12 - i, "runs": 12, "rate": 1.0 - i / 12.0}
		)
	ranking.show_lines(lines, "k10")
	assert_eq(ranking.places(), [0, 1, 2, 3, 4, 5, 6, 10] as Array[int], "the last row is its own")


func test_the_payoff_plays_before_any_control_shows() -> void:
	var result: ResultScreen = await _to_result([&"double_men", &"fifty_men"])
	assert_true(result.won())
	assert_false(result.controls_shown, "the payoff has the screen to itself")
	assert_false(result.retry_button.is_visible_in_tree())
	assert_eq(result.fresh, [&"double_men", &"fifty_men"] as Array[StringName], "new on the shelf")
	result.payoff_s = 0.1
	await wait_until(func() -> bool: return result.controls_shown, 5.0)
	for button: Button in [result.retry_button, result.edit_button, result.home_button]:
		assert_true(button.is_visible_in_tree())
		assert_eq(button.text, "")
		assert_ne(button.accessibility_name, "")
		assert_not_null(button.get_node_or_null("KeyHint"))
	assert_true(_frame_holds(result.controls))


func test_a_press_skips_the_payoff_but_does_not_click_through() -> void:
	var result: ResultScreen = await _to_result([&"stew"])
	assert_false(result.won())
	await wait_process_frames(1)
	InputSynth.canvas_tap(MOUSE_BUTTON_LEFT, result.retry_button.get_global_rect().get_center())
	await wait_process_frames(2)
	assert_true(result.controls_shown, "the press brought the controls up")
	assert_eq(main.screen_name, &"result", "and pressed none of them")


func test_retry_runs_the_same_loadout_and_edit_opens_it_in_the_shop() -> void:
	var result: ResultScreen = await _to_result([&"moose", &"stew"])
	result.payoff_s = 0.0
	await wait_until(func() -> bool: return result.controls_shown, 5.0)
	watch_signals(main)
	InputSynth.key_tap(KEY_1)
	await wait_process_frames(2)
	assert_eq(main.screen_name, &"battle", "1 fights again")
	assert_eq(main.loadout.ids, [&"moose", &"stew"] as Array[StringName])
	assert_eq(main.mode, &"watch")
	main.open_result(SiegeSim.Outcome.LOSE)
	result = main.screen as ResultScreen
	result.edit_button.pressed.emit()
	assert_eq(main.screen_name, &"loadout")
	assert_eq((main.screen as LoadoutScreen).loadout.ids, [&"moose", &"stew"] as Array[StringName])
	main.open_result(SiegeSim.Outcome.LOSE)
	(main.screen as ResultScreen).home_button.pressed.emit()
	assert_eq(main.screen_name, &"hub")


func test_the_result_scenes_draw_and_move() -> void:
	for won: bool in [true, false]:
		var seen: Dictionary = {}
		for age: float in [0.0, 0.4, 0.9, 1.6, 2.3]:
			var pen := VignettePen.new()
			ResultScene.paint(pen, won, age)
			assert_gt(pen.count, 12, "a scene at %s" % age)
			assert_eq(pen.broken, 0)
			seen[pen.digest] = true
		assert_eq(seen.size(), 5, "the %s scene never stands still" % ("win" if won else "combust"))
