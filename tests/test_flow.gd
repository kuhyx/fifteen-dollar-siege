extends GutTest
## The stub game flow through the real main scene, without the bot: hub ->
## loadout -> battle / lab -> result -> hub, the pause menu, the signals the
## dev tools listen to, and the remembered loadout (in the throwaway save).

var main: Main
var seen: Array = []


func before_each() -> void:
	seen = []
	SaveStore.clear()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.options.speed = 32.0
	main.options.sim_seed = 5
	main.options.lab_runs = 6
	main.screen_changed.connect(func(screen: StringName) -> void: seen.append(screen))


func after_each() -> void:
	get_tree().paused = false


## Plays the battle on show until the result opens (the payoff cut short).
func _battle_until_done() -> void:
	(main.screen as BattleScreen).payoff_s = 0.05
	await wait_until(func() -> bool: return main.screen_name != &"battle", 20.0)


func test_the_game_opens_on_the_hub_with_three_modes() -> void:
	assert_eq(main.screen_name, &"hub")
	var hub := main.screen as HubScreen
	assert_eq(hub.buttons.keys(), [&"watch", &"command", &"lab"])
	for mode: StringName in hub.buttons:
		var button := hub.buttons[mode] as Button
		assert_eq(button.text, "", "no words on %s" % mode)
		assert_ne(button.accessibility_name, "", "%s has a spoken label" % mode)


func test_a_hub_button_opens_that_modes_loadout_screen() -> void:
	((main.screen as HubScreen).buttons[&"command"] as Button).pressed.emit()
	assert_eq(main.screen_name, &"loadout")
	assert_eq(main.mode, &"command")
	var shop := main.screen as LoadoutScreen
	assert_eq(shop.cards.size(), 25)
	for id: StringName in shop.cards:
		var card := shop.cards[id] as BuffCard
		assert_eq(card.text, "", "no words on a card")
		assert_eq(card.accessibility_name, BuffCatalog.by_id(id).source_text)


func test_cards_buy_within_the_budget_and_refuse_beyond_it() -> void:
	main.open_loadout(&"watch")
	var shop := main.screen as LoadoutScreen
	watch_signals(shop)
	for id: StringName in [&"double_men", &"knight_armor", &"wasps"]:
		(shop.cards[id] as BuffCard).pressed.emit()
	assert_eq(shop.loadout.cost(), 15)
	assert_true((shop.cards[&"wasps"] as BuffCard).bought)
	assert_true((shop.cards[&"stew"] as BuffCard).out_of_reach, "nothing left for stew")
	(shop.cards[&"stew"] as BuffCard).pressed.emit()
	assert_signal_emitted_with_parameters(shop, "refused", [&"stew"])
	assert_eq(shop.loadout.cost(), 15, "the refused buy changed nothing")
	(shop.cards[&"wasps"] as BuffCard).pressed.emit()
	assert_eq(shop.loadout.cost(), 10, "a second click sells it back")
	assert_false((shop.cards[&"stew"] as BuffCard).out_of_reach)


func test_watch_plays_itself_to_the_result_and_back_to_the_hub() -> void:
	main.open_loadout(&"watch")
	watch_signals(main)
	(main.screen as LoadoutScreen).toggle(&"double_men")
	(main.screen as LoadoutScreen).toggle(&"fifty_men")
	(main.screen as LoadoutScreen).go_button.pressed.emit()
	assert_eq(main.screen_name, &"battle")
	assert_signal_emitted(main, "siege_started")
	await _battle_until_done()
	assert_eq(main.screen_name, &"result")
	assert_signal_emitted(main, "siege_ended")
	assert_eq(main.last_outcome, SiegeSim.Outcome.WIN)
	assert_true((main.screen as ResultScreen).won())
	(main.screen as ResultScreen).home_button.pressed.emit()
	assert_eq(seen, [&"loadout", &"battle", &"result", &"hub"])


func test_a_cheap_loadout_combusts() -> void:
	main.mode = &"watch"
	main.start_siege(Loadout.of([&"stew"]))
	await _battle_until_done()
	assert_eq(main.screen_name, &"result")
	assert_false((main.screen as ResultScreen).won())
	assert_eq(main.last_outcome, SiegeSim.Outcome.LOSE)


func test_the_payoff_plays_before_the_result_opens() -> void:
	main.mode = &"watch"
	main.start_siege(Loadout.of([&"double_men", &"fifty_men"]))
	var battle := main.screen as BattleScreen
	watch_signals(battle)
	await wait_until(func() -> bool: return battle.payoff_active, 20.0)
	assert_true(battle.payoff_active)
	assert_signal_emitted(battle, "decided")
	assert_signal_not_emitted(battle, "finished")
	assert_eq(main.screen_name, &"battle", "the result UI is not up yet")


func test_command_mode_sends_orders_to_the_sim() -> void:
	main.mode = &"command"
	main.start_siege(Loadout.of([&"double_men", &"fifty_men"]))
	var battle := main.screen as BattleScreen
	watch_signals(main)
	assert_not_null(battle.charge_button)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = battle.map_to_canvas(Vector2(150, 100))
	battle._gui_input(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	battle._gui_input(release)
	battle.retreat_button.pressed.emit()
	assert_eq(battle.commands_sent, 2)
	assert_signal_emit_count(main, "command_given", 2)
	var rally: Vector2 = get_signal_parameters(main, "command_given", 0)[1]
	assert_almost_eq(rally, Vector2(150, 100), Vector2(0.5, 0.5))


func test_watch_mode_has_no_orders() -> void:
	main.mode = &"watch"
	main.start_siege(Loadout.new())
	var battle := main.screen as BattleScreen
	assert_null(battle.charge_button)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = battle.map_to_canvas(Vector2(150, 100))
	battle._gui_input(click)
	assert_eq(battle.commands_sent, 0)


func test_lab_runs_the_batch_and_shows_the_win_rate() -> void:
	main.mode = &"lab"
	watch_signals(main)
	main.start_siege(Loadout.of([&"double_men", &"fifty_men"]))
	var lab := main.screen as LabScreen
	await wait_until(func() -> bool: return lab.done, 20.0)
	assert_true(lab.done)
	assert_eq(lab.result["runs"], 6)
	assert_eq(lab.result["wins"], 6)
	assert_eq(lab.win_rate(), 1.0)
	assert_eq(lab.result, Lab.run_batch(main.loadout, 6, 5), "the screen agrees with Lab")
	assert_signal_emitted(main, "lab_finished")
	lab.home_button.pressed.emit()
	assert_eq(main.screen_name, &"hub")


func test_the_pause_menu_pauses_and_leads_back_to_the_hub() -> void:
	main.mode = &"watch"
	main.start_siege(Loadout.new())
	var menu := main.pause_menu
	assert_eq(menu.buttons.keys(), ["resume", "hub", "quit"])
	menu.open()
	assert_true(menu.is_open())
	assert_true(get_tree().paused)
	(menu.buttons["resume"] as Button).pressed.emit()
	assert_false(get_tree().paused)
	main.menu_button.pressed.emit()
	assert_true(menu.is_open(), "the on-screen menu button opens it (touch has no Esc)")
	(menu.buttons["hub"] as Button).pressed.emit()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)
	assert_eq(main.screen_name, &"hub")


func test_the_last_loadout_of_a_mode_is_remembered() -> void:
	main.mode = &"watch"
	main.start_siege(Loadout.of([&"moose", &"stew"]))
	main.open_hub()
	main.open_loadout(&"watch")
	assert_eq((main.screen as LoadoutScreen).loadout.ids, [&"moose", &"stew"] as Array[StringName])
	main.open_loadout(&"lab")
	assert_true((main.screen as LoadoutScreen).loadout.ids.is_empty(), "per mode")


func test_debug_state_and_pick_describe_the_screen() -> void:
	main.mode = &"command"
	main.start_siege(Loadout.of([&"double_men"]))
	var state := main.debug_state()
	assert_eq(state["screen"], "battle")
	assert_eq(state["loadout"], ["double_men"])
	assert_eq(state["men"], 200)
	assert_eq(state["siege"]["outcome"], "RUNNING")
	assert_eq(state["siege"]["entities"].size(), (main.screen as BattleScreen).shot.entity_count())
	var battle := main.screen as BattleScreen
	var picked := main.pick_at(battle.map_to_canvas(battle.shot.ent_pos[0]))
	assert_eq(picked["kind"], "entity")
	assert_eq(picked["team"], "army")
	assert_eq(main.pick_at(Vector2(-900, -900)), {}, "nothing out there")
	assert_not_null(JSON.parse_string(JSON.stringify(state)), "plain data: it serialises")
