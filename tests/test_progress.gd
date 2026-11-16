extends GutTest
## Saved progress (build-game R18): the last loadout, the shelf of buffs won
## with and the Lab ranking survive a restart. "Restart" here is what a real
## one does to them: the game is freed and built again from the save files.
## Each test is RED when its save call is removed (Main._remember_loadout,
## WinShelf.record's write, LabBook.record's write).

var main: Main


func before_each() -> void:
	SaveStore.clear()
	_start()


func _start() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.options.speed = 32.0
	main.options.sim_seed = 5
	main.options.lab_runs = 6


func _restart() -> void:
	main.free()
	_start()


func after_each() -> void:
	get_tree().paused = false
	main.free()


func _play_to_the_result(mode: StringName, ids: Array) -> void:
	main.mode = mode
	main.start_siege(Loadout.of(ids))
	(main.screen as BattleScreen).payoff_s = 0.05
	await wait_until(func() -> bool: return main.screen_name == &"result", 20.0)


func test_the_last_loadout_survives_a_restart() -> void:
	main.open_loadout(&"command")
	var shop := main.screen as LoadoutScreen
	shop.toggle(&"moose")
	shop.toggle(&"stew")
	shop.go_button.pressed.emit()
	_restart()
	main.open_loadout(&"command")
	var again := main.screen as LoadoutScreen
	assert_eq(again.loadout.ids, [&"moose", &"stew"] as Array[StringName])
	assert_true((again.cards[&"moose"] as BuffCard).bought, "the card shows it")
	assert_eq(again.tray.coins, 11, "and so does the tray")


func test_a_won_siege_fills_the_shelf_and_it_survives_a_restart() -> void:
	assert_true(WinShelf.won().is_empty(), "an empty shelf at first")
	await _play_to_the_result(&"watch", [&"double_men", &"fifty_men"])
	assert_eq(main.last_outcome, SiegeSim.Outcome.WIN)
	assert_eq(WinShelf.won(), [&"double_men", &"fifty_men"] as Array[StringName])
	_restart()
	var hub := main.screen as HubScreen
	assert_eq(hub.shelf.won, [&"double_men", &"fifty_men"] as Array[StringName])


func test_a_lost_siege_adds_nothing_to_the_shelf() -> void:
	await _play_to_the_result(&"watch", [&"stew"])
	assert_eq(main.last_outcome, SiegeSim.Outcome.LOSE)
	assert_true(WinShelf.won().is_empty())


func test_the_shelf_only_reports_what_is_new() -> void:
	assert_eq(WinShelf.record(Loadout.of([&"moose", &"stew"])).size(), 2)
	assert_eq(WinShelf.record(Loadout.of([&"stew", &"wasps"])), [&"wasps"] as Array[StringName])
	assert_true(WinShelf.record(Loadout.of([&"stew"])).is_empty())
	assert_eq(WinShelf.won(), [&"wasps", &"moose", &"stew"] as Array[StringName], "shelf order")


func test_the_lab_ranking_survives_a_restart() -> void:
	main.mode = &"lab"
	main.start_siege(Loadout.of([&"double_men", &"fifty_men"]))
	var lab := main.screen as LabScreen
	await wait_until(func() -> bool: return lab.done, 20.0)
	main.start_siege(Loadout.of([&"stew"]))
	lab = main.screen as LabScreen
	await wait_until(func() -> bool: return lab.done, 20.0)
	_restart()
	var ranked := LabBook.ranked()
	assert_eq(ranked.size(), 2)
	assert_eq(ranked[0]["key"], "double_men,fifty_men", "the winner leads")
	assert_eq(ranked[0]["wins"], 6)
	assert_eq(ranked[0]["runs"], 6)
	assert_eq(ranked[1]["key"], "stew")
	assert_eq(ranked[1]["rate"], 0.0)
	var hub := main.screen as HubScreen
	assert_eq(hub.best_lab.rate, 1.0, "the hub shows the best rate so far")
	assert_eq(hub.best_lab.ids, [&"double_men", &"fifty_men"] as Array[StringName])


func test_the_lab_book_adds_batches_up_and_ignores_the_buying_order() -> void:
	LabBook.record(Loadout.of([&"stew", &"moose"]), 3, 10)
	LabBook.record(Loadout.of([&"moose", &"stew"]), 5, 10)
	LabBook.record(Loadout.new(), 0, 4)
	LabBook.record(Loadout.of([&"wasps"]), 2, 0)
	var ranked := LabBook.ranked()
	assert_eq(ranked.size(), 2, "a batch of no runs leaves no line")
	assert_eq(ranked[0]["key"], "moose,stew")
	assert_eq(ranked[0]["wins"], 8)
	assert_eq(ranked[0]["runs"], 20)
	assert_almost_eq(ranked[0]["rate"], 0.4, 0.0001)
	assert_eq(ranked[1]["key"], LabBook.EMPTY_KEY)
	assert_true((ranked[1]["ids"] as Array).is_empty(), "nothing bought")
	assert_eq(LabBook.best()["key"], "moose,stew")


func test_a_broken_save_file_reads_as_empty() -> void:
	SaveStore.write_json(LabBook.FILE, {"entries": "nonsense"})
	SaveStore.write_json(WinShelf.FILE, {"won": 7})
	assert_true(LabBook.ranked().is_empty())
	assert_true(LabBook.best().is_empty())
	assert_true(WinShelf.won().is_empty())
	LabBook.record(Loadout.of([&"stew"]), 1, 2)
	assert_eq(LabBook.ranked().size(), 1, "and can be written again")
