extends GutTest
## Key hints (lesson L6): every control with a hint shows the real key of its
## action for the device in use, read from the InputMap, and that key presses
## it. A key that cannot be drawn without letters fails here, never a blank cap.


func before_each() -> void:
	MenuKeys.ensure()
	InputDevice.device = InputDevice.Device.KEYS


func after_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	return event


## A button with a hint, one frame old. Input synthesized in the frame a node
## is made can miss it: while the tree is processing, the engine skips any
## node whose address matches one removed earlier in that frame.
func _button_with_hint(action: StringName) -> Button:
	var button := Button.new()
	add_child_autofree(button)
	KeyHint.attach(button, action)
	await wait_process_frames(1)
	return button


func test_every_menu_action_has_a_key_that_can_be_drawn() -> void:
	assert_eq(MenuKeys.actions().size(), 5)
	for action in MenuKeys.actions():
		assert_true(InputMap.has_action(action), String(action))
		var event := InputDevice.event_for(action)
		assert_not_null(event, "%s has a key" % action)
		assert_true(KeyGlyph.can_draw(event), "%s shows a real key, not a blank cap" % action)


func test_a_key_with_only_a_letter_cannot_be_drawn() -> void:
	assert_false(KeyGlyph.can_draw(_key(KEY_R)), "letters are words: no glyph")
	assert_false(KeyGlyph.can_draw(_key(KEY_F5)))
	assert_false(KeyGlyph.can_draw(null))
	for code: Key in [KEY_1, KEY_KP_3, KEY_ENTER, KEY_SPACE, KEY_BACKSPACE, KEY_LEFT]:
		assert_true(KeyGlyph.can_draw(_key(code)), "key %d" % code)
	assert_eq(KeyGlyph.digit_of(KEY_7), 7)
	assert_eq(KeyGlyph.digit_of(KEY_KP_2), 2)
	assert_eq(KeyGlyph.digit_of(KEY_ENTER), -1)


func test_a_rebind_to_a_letter_fails_the_gate() -> void:
	InputMap.add_action(&"test_letter_action")
	InputMap.action_add_event(&"test_letter_action", _key(KEY_Q))
	var event := InputDevice.event_for(&"test_letter_action")
	assert_not_null(event)
	assert_false(KeyGlyph.can_draw(event), "the gate above would be red for this action")
	InputMap.erase_action(&"test_letter_action")


func test_the_hinted_key_presses_its_button() -> void:
	var button: Button = await _button_with_hint(MenuKeys.PICKS[1])
	watch_signals(button)
	InputSynth.key_tap(KEY_2)
	await wait_process_frames(2)
	assert_signal_emit_count(button, "pressed", 1, "2 presses the second control")
	InputSynth.key_tap(KEY_3)
	await wait_process_frames(2)
	assert_signal_emit_count(button, "pressed", 1, "3 belongs to another control")
	assert_eq(button.tooltip_text, "", "no words")
	assert_false(button.shortcut_in_tooltip, "the shortcut is never spelled out")


func test_the_hint_follows_the_device() -> void:
	var button: Button = await _button_with_hint(MenuKeys.PICKS[0])
	var hint := button.get_node("KeyHint") as KeyHint
	assert_true(hint.glyph_event() is InputEventKey, "keyboard: the 1 key")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	assert_true(InputDevice.note(pad), "a pad button switches the device")
	assert_null(hint.glyph_event(), "pad: no hint on a control without the focus")
	button.grab_focus()
	var shown := hint.glyph_event() as InputEventJoypadButton
	assert_not_null(shown, "pad: the accept button on the focused control")
	assert_eq(shown.button_index, JOY_BUTTON_A)
	assert_true(KeyGlyph.can_draw(shown))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(InputDevice.note(touch))
	assert_null(hint.glyph_event(), "touch: the control itself is the target")
	var finger := InputEventMouseButton.new()
	finger.device = InputEvent.DEVICE_ID_EMULATION
	assert_false(InputDevice.note(finger), "a mouse event made from a touch is still touch")
	assert_true(InputDevice.note(InputEventMouseMotion.new()), "a real mouse: back to keys")
