class_name KeyGlyph
extends RefCounted
## THE key and button glyph of the game, drawn as shapes, no letters: a key
## cap with a digit (seven segments) or the key's own symbol, a mouse with its
## left button filled, a pad's face buttons, d-pad, start or stick click with
## the right one lit. Every key hint (menus, battle HUD, pause menu) draws it
## through `KeyHint`. An event this class cannot draw is NEVER a blank cap or
## a placeholder: `can_draw` is false, `KeyHint.unknown` is true and
## tests/test_key_hints.gd fails on it (lesson L6).

const SYMBOL_KEYS: Array[Key] = [
	KEY_ENTER,
	KEY_KP_ENTER,
	KEY_SPACE,
	KEY_BACKSPACE,
	KEY_ESCAPE,
	KEY_LEFT,
	KEY_RIGHT,
	KEY_UP,
	KEY_DOWN
]
## Pad face buttons -> where they sit in the diamond.
const PAD_SPOTS := {
	JOY_BUTTON_A: Vector2(0, 1),
	JOY_BUTTON_B: Vector2(1, 0),
	JOY_BUTTON_X: Vector2(-1, 0),
	JOY_BUTTON_Y: Vector2(0, -1),
}
## D-pad buttons -> the arm they press.
const DPAD_ARMS := {
	JOY_BUTTON_DPAD_UP: Vector2(0, -1),
	JOY_BUTTON_DPAD_RIGHT: Vector2(1, 0),
	JOY_BUTTON_DPAD_DOWN: Vector2(0, 1),
	JOY_BUTTON_DPAD_LEFT: Vector2(-1, 0),
}
const CAP := Palette.PANEL_PRESSED
const INK := Palette.INK


## The digit a key types, -1 for none.
static func digit_of(code: Key) -> int:
	if code >= KEY_0 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return code - KEY_KP_0
	return -1


static func can_draw(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		var code := _code(key)
		return digit_of(code) >= 0 or SYMBOL_KEYS.has(code)
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return mouse.button_index == MOUSE_BUTTON_LEFT
	var pad := event as InputEventJoypadButton
	if pad == null:
		return false
	var others := [JOY_BUTTON_START, JOY_BUTTON_RIGHT_STICK]
	return (
		PAD_SPOTS.has(pad.button_index)
		or DPAD_ARMS.has(pad.button_index)
		or others.has(pad.button_index)
	)


## A stable name for the picture of `event` ("" for one without), so two
## bindings that look alike are the same and tests can count the pictures.
static func id_of(event: InputEvent) -> String:
	if not can_draw(event):
		return ""
	var key := event as InputEventKey
	if key != null:
		var code := _code(key)
		return "digit_%d" % digit_of(code) if digit_of(code) >= 0 else "key_%d" % code
	if event is InputEventMouseButton:
		return "mouse_left"
	return "pad_%d" % (event as InputEventJoypadButton).button_index


## Draws the glyph of `event` into `box` (nothing when it cannot be drawn).
static func draw(canvas: CanvasItem, event: InputEvent, box: Rect2) -> void:
	if not can_draw(event):
		return
	if event is InputEventMouseButton:
		_mouse(canvas, box)
		return
	var pad := event as InputEventJoypadButton
	if pad != null:
		_pad(canvas, pad.button_index, box)
		return
	var code := _code(event as InputEventKey)
	_cap(canvas, box)
	var digit := digit_of(code)
	if digit >= 0:
		var height := box.size.y * 0.52
		var corner := box.get_center() - Vector2(SevenSegment.width(digit, height), height) / 2.0
		SevenSegment.draw_number(canvas, digit, corner, height, INK)
		return
	_symbol(canvas, code, box)


## Every glyph this class knows, in a row (the art contact sheet).
static func draw_sheet(canvas: CanvasItem, at: Vector2, px: float) -> void:
	var events: Array[InputEvent] = []
	for code: Key in [KEY_1, KEY_2, KEY_3] + SYMBOL_KEYS:
		var key := InputEventKey.new()
		key.keycode = code
		events.append(key)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	events.append(click)
	for button: JoyButton in PAD_SPOTS.keys() + DPAD_ARMS.keys() + [JOY_BUTTON_START]:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		events.append(pad)
	for i in events.size():
		var column := i % 12
		var spot := at + Vector2(column * px * 1.25, (i / 12) * px * 1.25)
		draw(canvas, events[i], Rect2(spot, Vector2.ONE * px))


static func _code(key: InputEventKey) -> Key:
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	return KEY_ENTER if code == KEY_KP_ENTER else code


static func _cap(canvas: CanvasItem, box: Rect2, tint := CAP) -> void:
	var cap := StyleBoxFlat.new()
	cap.bg_color = tint
	cap.border_color = INK
	cap.set_border_width_all(maxi(2, roundi(box.size.x * 0.06)))
	cap.set_corner_radius_all(roundi(box.size.x * 0.22))
	cap.anti_aliasing = true
	canvas.draw_style_box(cap, box)


static func _symbol(canvas: CanvasItem, code: Key, box: Rect2) -> void:
	var strokes: Array[Array] = []
	match code:
		KEY_ENTER:  # down, then left to an arrow head
			strokes = [[0.72, 0.28, 0.72, 0.6, 0.3, 0.6], [0.44, 0.46, 0.3, 0.6, 0.44, 0.74]]
		KEY_SPACE:  # a wide tray
			strokes = [[0.22, 0.46, 0.22, 0.66, 0.78, 0.66, 0.78, 0.46]]
		KEY_BACKSPACE:  # a tag pointing left with a cross in it
			strokes = [
				[0.2, 0.5, 0.4, 0.3, 0.8, 0.3, 0.8, 0.7, 0.4, 0.7, 0.2, 0.5],
				[0.5, 0.4, 0.68, 0.6],
				[0.68, 0.4, 0.5, 0.6]
			]
		KEY_ESCAPE:  # a cross: leave
			strokes = [[0.3, 0.3, 0.7, 0.7], [0.7, 0.3, 0.3, 0.7]]
		_:
			strokes = _arrow(code)
	var width := maxf(2.0, box.size.x * 0.08)
	for stroke: Array in strokes:
		var points := PackedVector2Array()
		for i in range(0, stroke.size() - 1, 2):
			points.append(box.position + Vector2(stroke[i], stroke[i + 1]) * box.size)
		canvas.draw_polyline(points, INK, width, true)


static func _arrow(code: Key) -> Array[Array]:
	var turns := {KEY_RIGHT: 0.0, KEY_DOWN: 0.25, KEY_LEFT: 0.5, KEY_UP: 0.75}
	var strokes: Array[Array] = []
	for stroke: Array in [[-0.26, 0.0, 0.26, 0.0], [0.08, -0.18, 0.26, 0.0, 0.08, 0.18]]:
		var turned := []
		for i in range(0, stroke.size() - 1, 2):
			var point := Vector2(stroke[i], stroke[i + 1]).rotated(TAU * turns.get(code, 0.0))
			turned.append_array([point.x + 0.5, point.y + 0.5])
		strokes.append(turned)
	return strokes


## A mouse seen from above, its left button filled.
static func _mouse(canvas: CanvasItem, box: Rect2) -> void:
	var body := Rect2(box.position + box.size * Vector2(0.28, 0.06), box.size * Vector2(0.44, 0.88))
	_cap(canvas, body, Palette.PANEL_PRESSED)
	var inner := body.grow(-body.size.x * 0.08)
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x * 0.46, inner.size.y * 0.38)), INK)


static func _pad(canvas: CanvasItem, button: JoyButton, box: Rect2) -> void:
	if DPAD_ARMS.has(button):
		_dpad(canvas, DPAD_ARMS[button], box)
	elif button == JOY_BUTTON_START:
		_cap(
			canvas,
			Rect2(box.position + box.size * Vector2(0.08, 0.28), box.size * Vector2(0.84, 0.44))
		)
		var middle := box.get_center()
		var half := box.size.x * 0.11
		var play := PackedVector2Array([middle + Vector2(-half, -half * 1.3)])
		play.append_array([middle + Vector2(half * 1.4, 0.0), middle + Vector2(-half, half * 1.3)])
		canvas.draw_colored_polygon(play, INK)
	elif button == JOY_BUTTON_RIGHT_STICK:
		var middle := box.get_center()
		canvas.draw_arc(middle, box.size.x * 0.4, 0.0, TAU, 32, INK, box.size.x * 0.07, true)
		canvas.draw_circle(middle, box.size.x * 0.17, INK, true, -1.0, true)
	else:
		_face(canvas, button, box)


## The four face buttons as a diamond, the wanted one filled.
static func _face(canvas: CanvasItem, button: JoyButton, box: Rect2) -> void:
	var reach := box.size.x * 0.28
	var dot := box.size.x * 0.17
	for other: JoyButton in PAD_SPOTS:
		var at: Vector2 = box.get_center() + PAD_SPOTS[other] * reach
		if other == button:
			canvas.draw_circle(at, dot, INK, true, -1.0, true)
		else:
			canvas.draw_circle(at, dot, CAP, true, -1.0, true)
			canvas.draw_circle(at, dot, Palette.DIM, false, maxf(1.5, dot * 0.25), true)


## A d-pad: the pressed arm is filled, the others are outlines.
static func _dpad(canvas: CanvasItem, pressed: Vector2, box: Rect2) -> void:
	var unit := box.size.x
	var middle := box.get_center()
	for arm: Vector2 in DPAD_ARMS.values():
		var length := Vector2(0.3, 0.34) if arm.x == 0.0 else Vector2(0.34, 0.3)
		var centre := middle + arm * unit * 0.3
		var rect := Rect2(centre - length * unit / 2.0, length * unit)
		if arm == pressed:
			canvas.draw_rect(rect, INK)
		else:
			canvas.draw_rect(rect, Palette.DIM, false, maxf(1.5, unit * 0.04))
	canvas.draw_rect(
		Rect2(middle - Vector2.ONE * unit * 0.15, Vector2.ONE * unit * 0.3),
		Palette.DIM,
		false,
		maxf(1.5, unit * 0.04)
	)
