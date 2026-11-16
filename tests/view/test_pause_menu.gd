extends GutTest
## The pause menu (baseline R4): Esc, pad B or the menu button stop the game
## and offer resume, the hub and quit as pictogram buttons on one card.

var menu: PauseMenu


func before_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS
	menu = PauseMenu.new()
	add_child_autofree(menu)


func after_each() -> void:
	get_tree().paused = false
	InputDevice.device = InputDevice.Device.KEYS


func test_escape_opens_it_pauses_the_game_and_closes_it_again() -> void:
	watch_signals(menu)
	assert_false(menu.is_open())
	InputSynth.key_tap(KEY_ESCAPE)
	assert_true(menu.is_open())
	assert_true(get_tree().paused, "the game stands still")
	assert_signal_emitted_with_parameters(menu, "toggled", [true])
	assert_true((menu.buttons["resume"] as Button).has_focus(), "resume is one key away")
	InputSynth.key_tap(KEY_ESCAPE)
	assert_false(menu.is_open())
	assert_false(get_tree().paused)


func test_the_buttons_are_pictograms_on_one_card() -> void:
	assert_eq(menu.buttons.keys(), ["resume", "hub", "quit"])
	for id: String in menu.buttons:
		var button := menu.buttons[id] as Button
		assert_eq(button.text, "", "%s: no words" % id)
		assert_ne(button.accessibility_name, "", "%s: a spoken label" % id)
		assert_not_null(button.icon, "%s: a pictogram" % id)
		assert_true(menu.card.is_ancestor_of(button), "%s sits on the card" % id)
	menu.open()
	await wait_frames(2)
	var view := get_viewport().get_visible_rect()
	assert_true(view.encloses(menu.card.get_global_rect()), "the card is on screen")
	assert_almost_eq(menu.card.get_global_rect().get_center().x, view.get_center().x, 2.0)


func test_resume_and_hub_close_the_menu() -> void:
	watch_signals(menu)
	menu.open()
	(menu.buttons["resume"] as Button).pressed.emit()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)
	menu.open()
	(menu.buttons["hub"] as Button).pressed.emit()
	assert_signal_emitted(menu, "hub_pressed")
	assert_false(menu.is_open(), "back at the hub the game runs")
	menu.open()
	(menu.buttons["quit"] as Button).pressed.emit()
	assert_signal_emitted(menu, "quit_pressed")


func test_the_resume_button_shows_the_key_that_closes_the_menu() -> void:
	menu.open()
	var on_keys := menu.close_hint.glyph_event()
	assert_true(on_keys is InputEventKey, "Esc on a keyboard")
	assert_false(menu.close_hint.unknown(), "Esc has a picture")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	pad.pressed = true
	Input.parse_input_event(pad)
	Input.flush_buffered_events()
	assert_true(menu.close_hint.glyph_event() is InputEventJoypadButton, "on a pad: its button")
	assert_false(menu.close_hint.unknown(), "pad B has a picture")


func test_dev_tools_can_add_an_entry() -> void:
	var pressed := [false]
	var extra := menu.add_entry("annotate", &"menu", "Annotate", func() -> void: pressed[0] = true)
	assert_eq(menu.buttons.keys(), ["resume", "hub", "quit", "annotate"])
	extra.pressed.emit()
	assert_true(pressed[0])
	var textured := menu.add_texture_entry("shot", Glyphs.texture(&"play"), "Shot", menu.close)
	assert_eq(textured.icon, Glyphs.texture(&"play"))
