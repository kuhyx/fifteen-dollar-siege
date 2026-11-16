class_name MenuKeys
extends RefCounted
## The menu screens' own input actions (the device in use is `InputDevice`).
## The actions are added to the InputMap at runtime (the key glyphs are read
## back from it, so a rebind shows the new key). The big controls of a screen
## are picked with 1, 2, 3 from left to right; Backspace goes one step back.

const PICKS: Array[StringName] = [&"menu_pick_1", &"menu_pick_2", &"menu_pick_3"]
const BACK := &"menu_back"
const DEFAULT_KEYS := {
	&"menu_pick_1": [KEY_1, KEY_KP_1],
	&"menu_pick_2": [KEY_2, KEY_KP_2],
	&"menu_pick_3": [KEY_3, KEY_KP_3],
	&"menu_back": [KEY_BACKSPACE],
}


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
