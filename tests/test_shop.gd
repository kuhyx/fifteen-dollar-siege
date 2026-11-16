extends GutTest
## The buff shop: 25 cards in price rows, the 15 dollars as a coin tray that
## empties as you buy, dimmed cards out of reach, a buy and a sell that move
## coins, a refusal that shakes the tray, the focused card's vignette, and
## touch (tap to look, tap again to buy).

var main: Main
var shop: LoadoutScreen


func before_each() -> void:
	SaveStore.clear()
	InputDevice.device = InputDevice.Device.KEYS
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.open_loadout(&"watch")
	shop = main.screen as LoadoutScreen
	# One frame old before any synthesized input (see tests/test_menu_keys.gd).
	await wait_process_frames(1)


func after_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS


func _card(id: StringName) -> BuffCard:
	return shop.cards[id] as BuffCard


## Waits until no coin is in the air.
func _settled() -> void:
	await wait_until(func() -> bool: return shop.flight.in_air() == 0, 3.0)


func test_cards_stand_in_price_rows_from_five_dollars_down() -> void:
	assert_eq(shop.cards.size(), 25)
	var row_y: Dictionary = {}
	for def in BuffCatalog.all():
		var card := _card(def.id)
		if not row_y.has(def.price):
			row_y[def.price] = card.position.y
		assert_eq(card.position.y, row_y[def.price], "%s stands in its price row" % def.id)
		assert_true(Rect2(Vector2.ZERO, ScreenFrame.SIZE).encloses(card.get_rect()), String(def.id))
		assert_eq(card.text, "")
	for price in [5, 4, 3, 2]:
		assert_lt(row_y[price], row_y[price - 1], "%d dollars is above %d" % [price, price - 1])


func test_a_buy_moves_coins_from_the_tray_into_the_card() -> void:
	assert_eq(shop.tray.coins, 15, "the whole budget lies in the tray")
	assert_eq(_card(&"moose").coins_in, 0)
	assert_true(shop.toggle(&"moose"))
	assert_eq(shop.tray.coins, 12, "three coins left the tray at once")
	assert_eq(shop.flight.in_air(), 3, "and are in the air")
	await _settled()
	assert_eq(_card(&"moose").coins_in, 3, "they landed in the card's price slots")
	assert_true(_card(&"moose").bought)


func test_a_sell_sends_the_coins_back() -> void:
	shop.toggle(&"moose")
	await _settled()
	assert_true(shop.toggle(&"moose"))
	assert_eq(_card(&"moose").coins_in, 0, "the card gave its coins up at once")
	assert_eq(shop.tray.coins, 12, "they are still in the air")
	await _settled()
	assert_eq(shop.tray.coins, 15)
	assert_false(_card(&"moose").bought)


func test_a_quick_change_of_mind_never_loses_a_coin() -> void:
	shop.toggle(&"wasps")
	shop.toggle(&"wasps")
	shop.toggle(&"wasps")
	await _settled()
	assert_eq(shop.tray.coins, 10)
	assert_eq(_card(&"wasps").coins_in, 5)
	assert_eq(shop.loadout.cost(), 5)


func test_a_buy_over_the_budget_shakes_the_tray_and_changes_nothing() -> void:
	for id: StringName in [&"double_men", &"knight_armor", &"wasps"]:
		shop.toggle(id)
	watch_signals(shop)
	assert_false(shop.tray.is_shaking())
	assert_false(shop.toggle(&"stew"), "refused")
	assert_true(shop.tray.is_shaking(), "the tray shakes")
	assert_signal_emitted_with_parameters(shop, "refused", [&"stew"])
	assert_eq(shop.loadout.cost(), 15)
	assert_false(_card(&"stew").bought)
	await _settled()
	assert_eq(shop.tray.coins, 0)
	assert_eq(_card(&"stew").coins_in, 0)


func test_cards_out_of_reach_are_dimmed() -> void:
	for id: StringName in [&"double_men", &"knight_armor", &"deaf_villagers"]:
		shop.toggle(id)
	assert_eq(shop.loadout.remaining(), 1)
	assert_true(_card(&"moose").out_of_reach, "3 dollars with 1 left")
	assert_false(_card(&"stew").out_of_reach, "1 dollar with 1 left")
	assert_false(_card(&"double_men").out_of_reach, "a bought card is never out of reach")


func test_the_focused_card_plays_its_vignette() -> void:
	assert_eq(shop.focused_id, &"", "nothing is focused at first")
	assert_eq(shop.preview.stage.buff, &"")
	shop.focus_card(&"wasps")
	assert_eq(shop.preview.stage.buff, &"wasps")
	assert_true(_card(&"wasps").shown)
	var before := shop.preview.stage.time
	await wait_process_frames(5)
	assert_gt(shop.preview.stage.time, before, "the vignette runs")
	shop.focus_card(&"moose")
	assert_false(_card(&"wasps").shown)
	assert_eq(shop.preview.stage.buff, &"moose")
	_card(&"stew").grab_focus()
	assert_eq(shop.focused_id, &"stew", "keyboard focus shows the card too")


func test_a_tap_looks_and_a_second_tap_buys() -> void:
	shop.press(&"moose", true)
	assert_eq(shop.focused_id, &"moose", "the first tap shows the card")
	assert_false(shop.loadout.has(&"moose"), "and buys nothing")
	shop.press(&"moose", true)
	assert_true(shop.loadout.has(&"moose"), "the second tap buys")
	shop.press(&"stew", true)
	assert_false(shop.loadout.has(&"stew"), "another card: look first")
	shop.press(&"stew", false)
	assert_true(shop.loadout.has(&"stew"), "a mouse click buys at once")


func test_a_real_touch_goes_the_same_way() -> void:
	var at := _card(&"moose").get_global_rect().get_center()
	InputSynth.touch_tap(at)
	await wait_process_frames(3)
	assert_eq(InputDevice.device, InputDevice.Device.TOUCH)
	assert_eq(shop.focused_id, &"moose")
	assert_false(shop.loadout.has(&"moose"), "one finger tap only looks")
	InputSynth.touch_tap(at)
	await wait_process_frames(3)
	assert_true(shop.loadout.has(&"moose"), "the second tap buys")


func test_the_army_number_follows_the_men_bought() -> void:
	assert_eq(shop.army.men, 100)
	shop.toggle(&"fifty_men")
	assert_eq(shop.army.men, 150)
	shop.toggle(&"double_men")
	assert_eq(shop.army.men, 300)
	assert_eq(shop.preview.stage.men, 300, "the idle stage shows the army too")


func test_go_and_back_are_picture_buttons_with_keys() -> void:
	watch_signals(main)
	for button: Button in [shop.go_button, shop.back_button]:
		assert_eq(button.text, "")
		assert_ne(button.accessibility_name, "")
		assert_not_null(button.get_node_or_null("KeyHint"), "a key hint")
		assert_true(Rect2(Vector2.ZERO, ScreenFrame.SIZE).encloses(button.get_rect()))
	shop.toggle(&"stew")
	InputSynth.key_tap(KEY_1)
	await wait_process_frames(2)
	assert_signal_emitted(main, "siege_started", "1 starts the siege")
	assert_eq(main.screen_name, &"battle")
	assert_eq(main.loadout.ids, [&"stew"] as Array[StringName])


func test_backspace_goes_back_to_the_hub() -> void:
	InputSynth.key_tap(KEY_BACKSPACE)
	await wait_process_frames(2)
	assert_eq(main.screen_name, &"hub")
