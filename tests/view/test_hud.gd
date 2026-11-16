extends GutTest
## The battle HUD: every control is a pictogram button with a spoken label
## and the key or pad button that does the same, read from the InputMap for
## the device in use. No words anywhere.

var hud: BattleHud


func before_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS
	hud = BattleHud.new()
	hud.setup(true)
	add_child_autofree(hud)


func after_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS


func _pad_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func test_every_action_is_in_the_input_map_for_keys_and_for_a_pad() -> void:
	for action in SiegeActions.all():
		assert_true(InputMap.has_action(action), String(action))
		for device: int in [InputDevice.Device.KEYS, InputDevice.Device.PAD]:
			var event := InputDevice.event_for(action, device)
			assert_not_null(event, "%s has no binding for device %d" % [action, device])
			assert_true(
				KeyGlyph.can_draw(event), "%s: no picture for %s" % [action, event.as_text()]
			)
		assert_null(InputDevice.event_for(action, InputDevice.Device.TOUCH), "touch has no keys")


func test_every_control_is_a_glyph_button_with_a_spoken_label_and_its_key() -> void:
	var buttons := hud.buttons()
	assert_eq(buttons.size(), 10, "pause, four speeds, auto, rally, charge, retreat, skip")
	for action: StringName in buttons:
		var button := buttons[action] as HudButton
		assert_eq(button.text, "", "%s: no words" % action)
		assert_ne(button.accessibility_name, "", "%s: a spoken label" % action)
		assert_not_null(button.icon, "%s: a pictogram" % action)
		assert_true(button.has_badge(), "%s shows its key" % action)
		assert_false(button.badge_unknown(), "%s shows the placeholder key" % action)
		assert_eq(
			button.focus_mode, Control.FOCUS_NONE, "%s: Space never clicks a HUD button" % action
		)


func test_the_glyphs_follow_the_device_in_use() -> void:
	var on_keys := hud.pause_button.badge_event()
	assert_true(InputDevice.note(_pad_event()), "a pad press switches the device")
	assert_false(InputDevice.note(_pad_event()), "a second one changes nothing")
	assert_ne(hud.pause_button.badge_event(), on_keys, "the pause badge is now a pad button")
	for button: HudButton in hud.buttons().values():
		assert_true(button.has_badge())
		assert_false(button.badge_unknown(), "%s: placeholder on a pad" % button.action)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	InputDevice.note(touch)
	assert_false(hud.pause_button.has_badge(), "a touch screen needs no key badge")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	assert_false(InputDevice.note(emulated), "the mouse a touch emulates is still touch")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	assert_true(InputDevice.note(key))
	assert_eq(InputDevice.device, InputDevice.Device.KEYS)


func test_a_binding_without_a_picture_is_caught() -> void:
	var odd := InputEventKey.new()
	odd.physical_keycode = KEY_F7
	assert_false(KeyGlyph.can_draw(odd))
	InputMap.add_action(&"test_odd_action")
	InputMap.action_add_event(&"test_odd_action", odd)
	var button := HudButton.create(HudGlyphs.texture(HudGlyphs.PAUSE), "odd", &"test_odd_action")
	autofree(button)
	assert_true(button.badge_unknown(), "this is what the test above would fail on")
	InputMap.erase_action(&"test_odd_action")


func test_the_key_pictures_are_distinct() -> void:
	var seen := {}
	for action in SiegeActions.all():
		for device: int in [InputDevice.Device.KEYS, InputDevice.Device.PAD]:
			seen[KeyGlyph.id_of(InputDevice.event_for(action, device))] = true
	assert_gte(seen.size(), 17, "nine keys or buttons per device, the shared ones once")
	for id: StringName in [HudGlyphs.PAUSE, HudGlyphs.PLAY, HudGlyphs.AUTO, HudGlyphs.SKIP]:
		assert_gt(HudGlyphs.texture(id).glyph.area(), 300.0, String(id))
	for id in HudGlyphs.SPEEDS + [HudGlyphs.ARMY, HudGlyphs.VILLAGE]:
		assert_gt(HudGlyphs.texture(id).glyph.area(), 300.0, String(id))


func test_the_buttons_say_what_was_pressed() -> void:
	watch_signals(hud)
	hud.pause_button.pressed.emit()
	assert_signal_emitted(hud, "pause_pressed")
	hud.speed_buttons[2].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "speed_picked", [4.0])
	hud.auto_button.pressed.emit()
	assert_signal_emitted(hud, "auto_pressed")
	hud.charge_button.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "order_pressed", [SiegeSim.Command.CHARGE])
	hud.retreat_button.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "order_pressed", [SiegeSim.Command.RETREAT])
	hud.rally_button.pressed.emit()
	assert_signal_emitted(hud, "rally_pressed")
	hud.skip_button.pressed.emit()
	assert_signal_emitted(hud, "skip_pressed")


func test_the_hud_shows_the_state_it_is_given() -> void:
	var shot := SiegeSnapshot.new()
	shot.army_morale = 0.4
	shot.village_morale = 0.9
	shot.alarm = 0.6
	shot.clock_s = 83.4
	hud.show_state(shot, {"speed": 4.0, "held": true, "auto": false, "centre": 0.5}, 0.1)
	assert_eq(hud.meters.army, 0.4)
	assert_eq(hud.meters.village, 0.9)
	assert_eq(hud.meters.alarm, 0.6)
	assert_eq(hud.meters.centre, 0.5)
	assert_eq(hud.meters.seconds, 83)
	assert_true(hud.pause_button.lit, "the pause button shows the hold")
	assert_eq(
		hud.speed_buttons.map(func(b: HudButton) -> bool: return b.lit), [false, false, true, false]
	)
	assert_false(hud.auto_button.lit)
	assert_false(hud.skip_button.visible)
	hud.show_state(shot, {"speed": 16.0, "staged": true}, 0.1)
	assert_true(hud.skip_button.visible, "a staged beat shows only the skip button")
	assert_false(hud.pause_button.is_visible_in_tree())
	assert_eq(hud.speed_buttons.filter(func(b: HudButton) -> bool: return b.lit).size(), 0)


func test_watch_mode_has_no_orders() -> void:
	var plain := BattleHud.new()
	plain.setup(false)
	add_child_autofree(plain)
	assert_null(plain.charge_button)
	assert_eq(plain.buttons().size(), 7)
