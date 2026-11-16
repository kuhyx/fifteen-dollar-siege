class_name KeyGlyphs
extends RefCounted
## The picture of a key or a button, built from the input event itself: a key
## cap with its symbol (digits as seven segments, Space as a bar, Enter and
## Backspace as their arrows), a mouse with the left button filled, a pad's
## four face buttons, d-pad, stick or start button with the right one filled.
## No letters. An event without a picture gives the UNKNOWN cap, and
## tests/view/test_hud.gd fails on any HUD control that shows it.

const FACE: Array[JoyButton] = [JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_X]
const DPAD: Array[JoyButton] = [
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT
]
const SPOTS: Array[Vector2] = [Vector2(64, 28), Vector2(100, 64), Vector2(64, 100), Vector2(28, 64)]

static var _textures: Dictionary = {}


## A stable name for the event's picture ("" for an event without one).
static func id_of(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code >= KEY_0 and code <= KEY_9:
			return "digit_%d" % (code - KEY_0)
		var named := {KEY_SPACE: "space", KEY_ENTER: "enter", KEY_KP_ENTER: "enter"}
		named[KEY_BACKSPACE] = "backspace"
		named[KEY_ESCAPE] = "escape"
		return named.get(code, "")
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return "mouse_left" if mouse.button_index == MOUSE_BUTTON_LEFT else ""
	var pad := event as InputEventJoypadButton
	if pad == null:
		return ""
	if FACE.has(pad.button_index):
		return "face_%d" % FACE.find(pad.button_index)
	if DPAD.has(pad.button_index):
		return "dpad_%d" % DPAD.find(pad.button_index)
	var others := {JOY_BUTTON_START: "start", JOY_BUTTON_RIGHT_STICK: "stick"}
	return others.get(pad.button_index, "")


static func known(event: InputEvent) -> bool:
	return event != null and id_of(event) != ""


## The picture as a texture (the UNKNOWN cap for an event without one).
static func texture(event: InputEvent) -> GlyphTexture:
	var id := id_of(event) if event != null else ""
	if not _textures.has(id):
		_textures[id] = GlyphTexture.of(_build(id))
	return _textures[id]


static func _build(id: String) -> VectorGlyph:
	var g := VectorGlyph.new()
	if id.begins_with("digit_"):
		_cap(g)
		_digit(g, int(id.trim_prefix("digit_")))
	elif id.begins_with("face_"):
		_spots(g, int(id.trim_prefix("face_")))
	elif id.begins_with("dpad_"):
		_dpad(g, int(id.trim_prefix("dpad_")))
	else:
		_symbol(g, id)
	return g


static func _cap(g: VectorGlyph) -> void:
	g.frame(8, 8, 112, 112, 9)


static func _symbol(g: VectorGlyph, id: String) -> void:
	match id:
		"space":
			g.frame(2, 34, 124, 60, 9)
			g.rect(30, 66, 68, 9)
			g.rect(30, 54, 9, 14)
			g.rect(89, 54, 9, 14)
		"enter":
			_cap(g)
			g.rect(78, 36, 11, 40)
			g.rect(48, 65, 41, 11)
			g.polygon(PackedVector2Array([Vector2(50, 52), Vector2(50, 90), Vector2(28, 71)]))
		"backspace":
			_cap(g)
			g.rect(52, 58, 44, 12)
			g.polygon(PackedVector2Array([Vector2(54, 42), Vector2(54, 86), Vector2(28, 64)]))
		"escape":  # a small keyboard with its top-left key filled
			g.frame(2, 22, 124, 84, 7)
			for row in 3:
				for column in 5:
					var x := 14.0 + column * 21.0
					var y := 32.0 + row * 22.0
					if row == 0 and column == 0:
						g.rect(x - 2.0, y - 2.0, 20, 20)
					else:
						g.frame(x, y, 16, 16, 4)
		"mouse_left":
			g.frame(30, 8, 68, 112, 9)
			g.rect(39, 17, 22, 40)
			g.rect(62, 17, 6, 40)
		"start":
			g.frame(18, 40, 92, 48, 9)
			g.polygon(PackedVector2Array([Vector2(52, 50), Vector2(52, 78), Vector2(80, 64)]))
		"stick":
			g.ring(Vector2(64, 58), 46, 37)
			g.ring(Vector2(64, 58), 24)
			g.polygon(PackedVector2Array([Vector2(48, 106), Vector2(80, 106), Vector2(64, 124)]))
		_:
			_cap(g)
			g.line(Vector2(36, 92), Vector2(92, 36), 10)


## Seven segments, the same order and bits as SevenSegment.DIGITS.
static func _digit(g: VectorGlyph, value: int) -> void:
	var lit := SevenSegment.DIGITS[value]
	var bars: Array[Rect2] = [
		Rect2(44, 28, 40, 9),
		Rect2(75, 28, 9, 40),
		Rect2(75, 60, 9, 40),
		Rect2(44, 91, 40, 9),
		Rect2(44, 60, 9, 40),
		Rect2(44, 28, 9, 40),
		Rect2(44, 59, 40, 9),
	]
	for i in bars.size():
		if lit & (1 << i):
			g.rect(bars[i].position.x, bars[i].position.y, bars[i].size.x, bars[i].size.y)


## A pad's four face buttons: the chosen one is filled, the others are rings.
static func _spots(g: VectorGlyph, chosen: int) -> void:
	for i in SPOTS.size():
		g.ring(SPOTS[i], 20, 0.0 if i == chosen else 13.0)


## A d-pad: the chosen arm is filled, the others are outlines.
static func _dpad(g: VectorGlyph, chosen: int) -> void:
	var arms: Array[Rect2] = [
		Rect2(46, 8, 36, 40), Rect2(80, 46, 40, 36), Rect2(46, 80, 36, 40), Rect2(8, 46, 40, 36)
	]
	for i in arms.size():
		var arm := arms[i]
		if i == chosen:
			g.rect(arm.position.x, arm.position.y, arm.size.x, arm.size.y)
		else:
			g.frame(arm.position.x, arm.position.y, arm.size.x, arm.size.y, 8)
	g.frame(46, 46, 36, 36, 8)
