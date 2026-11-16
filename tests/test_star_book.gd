extends GutTest
## The best star count is kept, per mode (Watch, Command), and shown on the hub
## as three stars. Saving goes through SaveStore, so it survives a restart and
## a test can never touch the real save. RED without StarBook's write, without
## its never-lower rule, and without the hub row.

var main: Main


func before_each() -> void:
	SaveStore.clear()


func after_each() -> void:
	get_tree().paused = false
	if main != null:
		main.free()
		main = null


func _start() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.options.speed = 400.0
	main.options.sim_seed = SiegeFixtures.WIN_SEED


func test_a_saved_best_reads_back_the_same() -> void:
	assert_eq(StarBook.best(&"watch"), 0, "nothing yet")
	assert_true(StarBook.record(&"watch", 2))
	assert_eq(StarBook.best(&"watch"), 2, "write, reload, same value")
	assert_eq(StarBook.best(&"command"), 0, "the other mode is its own")


func test_a_worse_result_never_lowers_it() -> void:
	StarBook.record(&"command", 3)
	assert_false(StarBook.record(&"command", 1))
	assert_false(StarBook.record(&"command", 0), "a loss is nothing")
	assert_eq(StarBook.best(&"command"), 3)
	assert_false(StarBook.record(&"command", 3), "the same is not a new best")
	assert_true(StarBook.record(&"watch", 1))
	assert_true(StarBook.record(&"watch", 2), "a better one raises it")
	assert_eq(StarBook.best(&"watch"), 2)


func test_only_watch_and_command_keep_stars_and_values_stay_in_range() -> void:
	assert_false(StarBook.record(&"lab", 3), "the Lab has no stars")
	assert_eq(StarBook.best(&"lab"), 0)
	assert_true(StarBook.record(&"watch", 99))
	assert_eq(StarBook.best(&"watch"), 3, "never above three")
	SaveStore.write_json(StarBook.FILE, {"best": {"watch": "many", "command": -4}})
	assert_eq(StarBook.best(&"watch"), 0, "a damaged file reads as none")
	assert_eq(StarBook.best(&"command"), 0)


func test_the_test_run_never_uses_the_real_save() -> void:
	assert_ne(SaveStore.root, SaveStore.DEFAULT_ROOT)
	assert_false(SaveStore.is_real_save(SaveStore.root))


func test_a_won_siege_keeps_its_stars_through_a_restart() -> void:
	_start()
	main.mode = &"watch"
	main.start_siege(Loadout.of(SiegeFixtures.WIN_IDS))
	(main.screen as BattleScreen).payoff_s = 0.05
	(main.screen as BattleScreen).beats.skip_all()
	await wait_until(func() -> bool: return main.screen_name == &"result", 20.0)
	assert_eq(StarBook.best(&"watch"), 1, "a 15 dollar win is one star")
	main.free()
	_start()
	var hub := main.screen as HubScreen
	assert_eq(hub.stars[&"watch"].earned, 1)
	assert_eq(hub.stars[&"command"].earned, 0)
	assert_false(hub.stars.has(&"lab"))


func test_a_lost_siege_leaves_the_stars_as_they_were() -> void:
	StarBook.record(&"watch", 2)
	_start()
	main.mode = &"watch"
	main.options.sim_seed = SiegeFixtures.LOSE_SEED
	main.start_siege(Loadout.of(SiegeFixtures.LOSE_IDS))
	(main.screen as BattleScreen).payoff_s = 0.05
	(main.screen as BattleScreen).beats.skip_all()
	await wait_until(func() -> bool: return main.screen_name == &"result", 20.0)
	assert_eq(StarBook.best(&"watch"), 2)


func test_the_hub_row_draws_lit_and_empty_stars_without_words() -> void:
	var row := StarRow.new()
	row.size = Vector2(StarRow.wide(), StarRow.HEIGHT)
	row.earned = 2
	assert_eq(row.earned, 2)
	assert_ne(row.accessibility_name, "", "a spoken label stands in for the picture")
	assert_gt(StarRow.wide(), StarRow.HEIGHT * 2.0)
	row.free()


func test_the_hand_off_hub_save_reads_back_through_the_real_stores() -> void:
	var dir := "res://scripts/handoff/saves/hub"
	for file in ["stars.json", "shelf.json", "lab_book.json"]:
		var text := FileAccess.get_file_as_string(dir.path_join(file))
		assert_ne(text, "", "%s is in the fixture" % file)
		var out := FileAccess.open(SaveStore.root.path_join(file), FileAccess.WRITE)
		if out == null:
			DirAccess.make_dir_recursive_absolute(SaveStore.root)
			out = FileAccess.open(SaveStore.root.path_join(file), FileAccess.WRITE)
		out.store_string(text)
		out.close()
	assert_eq(StarBook.best(&"watch"), 2)
	assert_eq(StarBook.best(&"command"), 1)
	assert_gt(WinShelf.won().size(), 5, "a shelf with something on it")
	assert_almost_eq(float(LabBook.best().get("rate", -1.0)), 0.85, 0.001)
