class_name VolumeKeys
extends RefCounted
## The pause menu's volume actions, added to the InputMap at runtime like
## `MenuKeys` (the hints read them back, so a rebind shows the new key). Digits
## because the key glyph draws digits [design guess]; they only work while the
## pause menu is open, when no screen is listening for them.

const MUSIC_DOWN := &"volume_music_down"
const MUSIC_UP := &"volume_music_up"
const EFFECTS_DOWN := &"volume_effects_down"
const EFFECTS_UP := &"volume_effects_up"
const DEFAULT_KEYS := {
	MUSIC_DOWN: [KEY_4, KEY_KP_4],
	MUSIC_UP: [KEY_5, KEY_KP_5],
	EFFECTS_DOWN: [KEY_6, KEY_KP_6],
	EFFECTS_UP: [KEY_7, KEY_KP_7],
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
