class_name MenuKeys
extends RefCounted
## The menu screens' own input actions and the device the player is using.
## The actions are added to the InputMap at runtime (the key glyphs are read
## back from it, so a rebind shows the new key). The big controls of a screen
## are picked with 1, 2, 3 from left to right; Backspace goes one step back.

enum Device { KEYS, PAD, TOUCH }

const PICKS: Array[StringName] = [&"menu_pick_1", &"menu_pick_2", &"menu_pick_3"]
const BACK := &"menu_back"
const DEFAULT_KEYS := {
	&"menu_pick_1": [KEY_1, KEY_KP_1],
	&"menu_pick_2": [KEY_2, KEY_KP_2],
	&"menu_pick_3": [KEY_3, KEY_KP_3],
	&"menu_back": [KEY_BACKSPACE],
}
const STICK_PUSH := 0.5

static var device := Device.KEYS


## Adds the actions that are not in the InputMap yet (safe to call often).
static func ensure() -> void:
	for action: StringName in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: Key in DEFAULT_KEYS[action]:
			var key := InputEventKey.new()
			key.keycode = code
			InputMap.action_add_event(action, key)


static func actions() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(DEFAULT_KEYS.keys())
	return out


## Notes which device `event` came from; true when the device changed.
static func note(event: InputEvent) -> bool:
	var seen := device
	var stick := event as InputEventJoypadMotion
	var mouse := event as InputEventMouse
	if event is InputEventJoypadButton or (stick != null and absf(stick.axis_value) > STICK_PUSH):
		seen = Device.PAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		seen = Device.TOUCH
	elif mouse != null:
		var from_finger := mouse.device == InputEvent.DEVICE_ID_EMULATION
		seen = Device.TOUCH if from_finger else Device.KEYS
	elif event is InputEventKey:
		seen = Device.KEYS
	var changed := seen != device
	device = seen
	return changed


## The event to draw beside a control bound to `action` on the device in use:
## its key, or (pad) its own button, else the accept button while the control
## has the focus. Null means: draw nothing (touch needs no hint).
static func event_for(action: StringName, focused: bool) -> InputEvent:
	if device == Device.TOUCH or not InputMap.has_action(action):
		return null
	var wanted_pad := device == Device.PAD
	for event in InputMap.action_get_events(action):
		if (
			(event is InputEventJoypadButton) == wanted_pad
			and (wanted_pad or event is InputEventKey)
		):
			return event
	if wanted_pad and focused:
		for event in InputMap.action_get_events(&"ui_accept"):
			if event is InputEventJoypadButton:
				return event
	return null
