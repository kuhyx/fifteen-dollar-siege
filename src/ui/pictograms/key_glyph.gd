class_name KeyGlyph
extends RefCounted
## Key and pad-button glyphs as shapes, no letters: a key cap holding a digit
## (seven-segment) or the key's own symbol, or the pad's four face buttons with
## the right one lit. A key this class cannot draw is NOT drawn as a blank cap:
## `can_draw` is false and tests/test_menu_keys.gd fails on it (lesson L6).

const SYMBOL_KEYS: Array[Key] = [
	KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_BACKSPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN
]
## Pad face buttons -> where they sit in the diamond.
const PAD_SPOTS := {
	JOY_BUTTON_A: Vector2(0, 1),
	JOY_BUTTON_B: Vector2(1, 0),
	JOY_BUTTON_X: Vector2(-1, 0),
	JOY_BUTTON_Y: Vector2(0, -1),
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
	var pad := event as InputEventJoypadButton
	return pad != null and PAD_SPOTS.has(pad.button_index)


## Draws the glyph of `event` into `box` (nothing when it cannot be drawn).
static func draw(canvas: CanvasItem, event: InputEvent, box: Rect2) -> void:
	if not can_draw(event):
		return
	var pad := event as InputEventJoypadButton
	if pad != null:
		_pad(canvas, pad.button_index, box)
		return
	var code := _code(event as InputEventKey)
	var cap := StyleBoxFlat.new()
	cap.bg_color = CAP
	cap.border_color = INK
	cap.set_border_width_all(maxi(2, roundi(box.size.x * 0.06)))
	cap.set_corner_radius_all(roundi(box.size.x * 0.22))
	canvas.draw_style_box(cap, box)
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
	for button: JoyButton in PAD_SPOTS:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		events.append(pad)
	for i in events.size():
		draw(canvas, events[i], Rect2(at + Vector2(i * px * 1.25, 0), Vector2.ONE * px))


static func _code(key: InputEventKey) -> Key:
	return key.keycode if key.keycode != KEY_NONE else key.physical_keycode


static func _symbol(canvas: CanvasItem, code: Key, box: Rect2) -> void:
	var strokes: Array[Array] = []
	match code:
		KEY_ENTER, KEY_KP_ENTER:  # down, then left to an arrow head
			strokes = [[0.72, 0.28, 0.72, 0.6, 0.3, 0.6], [0.44, 0.46, 0.3, 0.6, 0.44, 0.74]]
		KEY_SPACE:  # a wide tray
			strokes = [[0.22, 0.46, 0.22, 0.66, 0.78, 0.66, 0.78, 0.46]]
		KEY_BACKSPACE:  # a tag pointing left with a cross in it
			strokes = [
				[0.2, 0.5, 0.4, 0.3, 0.8, 0.3, 0.8, 0.7, 0.4, 0.7, 0.2, 0.5],
				[0.5, 0.4, 0.68, 0.6],
				[0.68, 0.4, 0.5, 0.6]
			]
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


## The four face buttons as a diamond, the wanted one filled.
static func _pad(canvas: CanvasItem, button: JoyButton, box: Rect2) -> void:
	var reach := box.size.x * 0.28
	var dot := box.size.x * 0.17
	for other: JoyButton in PAD_SPOTS:
		var at: Vector2 = box.get_center() + PAD_SPOTS[other] * reach
		if other == button:
			canvas.draw_circle(at, dot, INK, true, -1.0, true)
		else:
			canvas.draw_circle(at, dot, CAP, true, -1.0, true)
			canvas.draw_circle(at, dot, Palette.DIM, false, maxf(1.5, dot * 0.25), true)
