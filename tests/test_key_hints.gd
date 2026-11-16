extends GutTest
## ONE key-glyph component for the whole game (lesson L6): every hint on every
## screen is a `KeyHint` that reads the InputMap for the device in use and
## draws `KeyGlyph`. A hint whose binding has no picture is a placeholder,
## and this test fails on it, on every screen and for every device.

const DEVICES: Array[int] = [InputDevice.Device.KEYS, InputDevice.Device.PAD]


func before_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS


func after_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS


## Every KeyHint under `root`, however deep.
func _hints(root: Node) -> Array[KeyHint]:
	var found: Array[KeyHint] = []
	for node in root.find_children("*", "", true, false):
		if node is KeyHint:
			found.append(node)
	return found


func _assert_known(root: Node, what: String) -> void:
	var hints := _hints(root)
	assert_gt(hints.size(), 0, "%s has key hints" % what)
	for device in DEVICES:
		InputDevice.device = device
		for hint in hints:
			if hint.glyph_event() == null:
				continue
			assert_false(
				hint.unknown(), "%s: %s has no picture on device %d" % [what, hint.action, device]
			)
			assert_true(KeyGlyph.can_draw(hint.glyph_event()))


func test_the_battle_hud_shows_only_known_keys() -> void:
	var hud := BattleHud.new()
	hud.setup(true)
	add_child_autofree(hud)
	_assert_known(hud, "the battle HUD")


func test_the_pause_menu_shows_only_known_keys() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	_assert_known(menu, "the pause menu")


func test_the_menu_screens_show_only_known_keys() -> void:
	var hub := HubScreen.new()
	add_child_autofree(hub)
	_assert_known(hub, "the hub")
	var shop := LoadoutScreen.new()
	add_child_autofree(shop)
	_assert_known(shop, "the shop")


func test_the_battle_and_the_menus_draw_with_one_component() -> void:
	var hud := BattleHud.new()
	hud.setup(false)
	add_child_autofree(hud)
	var pause := hud.pause_button.hint
	var hub := HubScreen.new()
	add_child_autofree(hub)
	var pick := _hints(hub)[0]
	assert_eq(pause.get_script(), pick.get_script(), "the same KeyHint everywhere")
	assert_true(FileAccess.file_exists("res://src/ui/pictograms/key_hint.gd"))
	assert_false(FileAccess.file_exists("res://src/view/battle/key_glyphs.gd"), "no second one")


func test_a_binding_without_a_picture_is_a_placeholder_and_is_caught() -> void:
	InputMap.add_action(&"test_odd_action")
	var odd := InputEventKey.new()
	odd.physical_keycode = KEY_F7
	InputMap.action_add_event(&"test_odd_action", odd)
	var button := Button.new()
	add_child_autofree(button)
	var hint := KeyHint.attach(button, &"test_odd_action")
	assert_true(hint.unknown(), "an F7 key has no picture")
	InputMap.erase_action(&"test_odd_action")


func test_every_action_has_a_picture_for_keys_and_for_a_pad() -> void:
	MenuKeys.ensure()
	SiegeActions.ensure()
	var actions: Array[StringName] = SiegeActions.all() + MenuKeys.actions()
	actions.append(&"ui_cancel")
	for action in actions:
		for device in DEVICES:
			var event := InputDevice.event_for(action, device, true)
			assert_not_null(event, "%s: no binding for device %d" % [action, device])
			if event != null:
				assert_true(KeyGlyph.can_draw(event), "%s: %s" % [action, event.as_text()])
