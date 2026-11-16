class_name InputSynth
extends RefCounted
## Synthetic input for the bots. Everything goes through Input.parse_input_event
## so the InputMap, actions, polling (Input.get_vector) and the game's own
## handlers see exactly what a keyboard, mouse or pad would send.


static func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # delivered now, not at the next frame start


static func key_tap(code: Key) -> void:
	key(code, true)
	key(code, false)


static func pad_button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # delivered now, not at the next frame start


static func pad_tap(button: JoyButton) -> void:
	pad_button(button, true)
	pad_button(button, false)


## Sets a stick axis (JOY_AXIS_*) to `value` -1..1.
static func pad_axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # delivered now, not at the next frame start


## Relative mouse motion (what a captured mouse sends).
static func mouse_motion(relative: Vector2, at := Vector2.ZERO) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = relative
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # delivered now, not at the next frame start


static func mouse_button(button: MouseButton, pressed: bool, at := Vector2.ZERO) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.position = at
	e.global_position = at
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()  # delivered now, not at the next frame start


static func mouse_tap(button: MouseButton, at := Vector2.ZERO) -> void:
	mouse_button(button, true, at)
	mouse_button(button, false, at)


## The mouse calls above in CANVAS units (the stretched UI space the game's
## handlers and rects use): converted to the window pixels a real mouse sends,
## so they land on the same spot at any window size (1280x800 is 2/3 of the canvas).
static func canvas_button(button: MouseButton, pressed: bool, at: Vector2) -> void:
	mouse_button(button, pressed, _to_window() * at)


static func canvas_tap(button: MouseButton, at: Vector2) -> void:
	canvas_button(button, true, at)
	canvas_button(button, false, at)


static func canvas_motion(relative: Vector2, at: Vector2) -> void:
	mouse_motion(_to_window().basis_xform(relative), _to_window() * at)


## A finger tap at a canvas point. The engine makes the mouse click from it
## (emulate_mouse_from_touch), exactly as on a phone.
static func touch_tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = _to_window() * at
		e.pressed = pressed
		Input.parse_input_event(e)
		Input.flush_buffered_events()


static func _to_window() -> Transform2D:
	return (Engine.get_main_loop() as SceneTree).root.get_final_transform()
