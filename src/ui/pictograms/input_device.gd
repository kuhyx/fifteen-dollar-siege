class_name InputDevice
extends RefCounted
## The device the player is using (keys and mouse, a pad or a finger) and
## which event of an action that device presses. ONE place for every key hint
## of the game (menus, battle HUD, pause menu): they all read the InputMap
## through `event_for` and draw it with `KeyGlyph`, so a rebind shows the new
## key everywhere and what is shown is what works.

enum Device { KEYS, PAD, TOUCH }

const STICK_PUSH := 0.5

static var device := Device.KEYS


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
		# A touch screen sends an emulated mouse too: that stays touch.
		var from_finger := mouse.device == InputEvent.DEVICE_ID_EMULATION
		seen = Device.TOUCH if from_finger else Device.KEYS
	elif event is InputEventKey:
		seen = Device.KEYS
	var changed := seen != device
	device = seen
	return changed


## The event to draw beside a control bound to `action` for `for_device`
## (default: the one in use): its key or click, or its pad button; on a pad a
## control with none shows the accept button while it has the focus. Null
## means draw nothing (a touch screen needs no hint).
static func event_for(action: StringName, for_device := -1, focused := false) -> InputEvent:
	var wanted := device if for_device < 0 else for_device
	if wanted == Device.TOUCH or not InputMap.has_action(action):
		return null
	var on_pad := wanted == Device.PAD
	for event in InputMap.action_get_events(action):
		if (event is InputEventJoypadButton or event is InputEventJoypadMotion) == on_pad:
			return event
	if on_pad and focused:
		for event in InputMap.action_get_events(&"ui_accept"):
			if event is InputEventJoypadButton:
				return event
	return null
