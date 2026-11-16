class_name SiegeActions
extends RefCounted
## The battle's input actions. They are added to the InputMap when the battle
## opens (an action project.godot already defines is left alone, so a later
## rebind wins), and every HUD glyph is read back from the InputMap, never
## from a table: what the button shows is what the game listens to.
## Defaults follow the genre (Space pauses, number keys pick the speed) and
## use only keys whose cap is a symbol, so no letter is drawn. [design guess]

const PAUSE := &"siege_pause"
const SPEEDS: Array[StringName] = [
	&"siege_speed_1", &"siege_speed_2", &"siege_speed_4", &"siege_speed_8"
]
const SPEED_VALUES: Array[float] = [1.0, 2.0, 4.0, 8.0]
const CAMERA_AUTO := &"siege_camera_auto"
const RALLY := &"siege_rally"
const CHARGE := &"siege_charge"
const RETREAT := &"siege_retreat"
## Skips a staged beat (the engine's own accept: Space, Enter, pad A).
const SKIP := &"ui_accept"


## Adds the actions that are missing, each with a key and a pad button.
static func ensure() -> void:
	_add(PAUSE, [_key(KEY_SPACE), _pad(JOY_BUTTON_START)])
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	var pads: Array[JoyButton] = [
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN
	]
	for i in SPEEDS.size():
		_add(SPEEDS[i], [_key(keys[i]), _pad(pads[i])])
	_add(CAMERA_AUTO, [_key(KEY_0), _pad(JOY_BUTTON_RIGHT_STICK)])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	_add(RALLY, [click, _pad(JOY_BUTTON_A)])
	_add(CHARGE, [_key(KEY_ENTER), _pad(JOY_BUTTON_Y)])
	_add(RETREAT, [_key(KEY_BACKSPACE), _pad(JOY_BUTTON_X)])


## Every action a HUD control shows a glyph for.
static func all() -> Array[StringName]:
	var out: Array[StringName] = [PAUSE, CAMERA_AUTO, RALLY, CHARGE, RETREAT, SKIP]
	out.append_array(SPEEDS)
	return out


static func _add(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
