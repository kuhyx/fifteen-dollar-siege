class_name SevenSegment
extends RefCounted
## Numbers drawn as seven-segment digits: shapes, no font and no string, so a
## number stays a number in a text-free UI and is sharp at any size.

## Lit segments per digit, in the order a b c d e f g
## (top, top right, bottom right, bottom, bottom left, top left, middle).
const DIGITS: Array[int] = [
	0b0111111,
	0b0000110,
	0b1011011,
	0b1001111,
	0b1100110,
	0b1101101,
	0b1111101,
	0b0000111,
	0b1111111,
	0b1101111
]
## A digit is this wide for a height of 1; then a gap.
const ASPECT := 0.56
const GAP := 0.2
const THICK := 0.14


## Width of `value` drawn `height` tall.
static func width(value: int, height: float) -> float:
	var digits := str(absi(value)).length()
	return digits * ASPECT * height + (digits - 1) * GAP * height


## Draws `value` (its absolute value) with its top-left at `at`.
static func draw_number(
	canvas: CanvasItem, value: int, at: Vector2, height: float, tint: Color
) -> void:
	var x := at.x
	for symbol in str(absi(value)):
		_digit(canvas, DIGITS[int(symbol)], Vector2(x, at.y), height, tint)
		x += (ASPECT + GAP) * height


## A percent mark `height` tall with its top-left at `at`: two rings and a slash.
static func draw_percent(canvas: CanvasItem, at: Vector2, height: float, tint: Color) -> void:
	var w := ASPECT * height
	var r := height * 0.13
	canvas.draw_arc(at + Vector2(r, r), r, 0.0, TAU, 24, tint, THICK * height * 0.6)
	canvas.draw_arc(at + Vector2(w - r, height - r), r, 0.0, TAU, 24, tint, THICK * height * 0.6)
	canvas.draw_line(at + Vector2(w, 0), at + Vector2(0, height), tint, THICK * height * 0.6)


static func _digit(canvas: CanvasItem, lit: int, at: Vector2, height: float, tint: Color) -> void:
	var w := ASPECT * height
	var t := THICK * height
	var half := (height - t) / 2.0
	var bars: Array[Rect2] = [
		Rect2(at.x, at.y, w, t),
		Rect2(at.x + w - t, at.y, t, half + t),
		Rect2(at.x + w - t, at.y + half, t, half + t),
		Rect2(at.x, at.y + height - t, w, t),
		Rect2(at.x, at.y + half, t, half + t),
		Rect2(at.x, at.y, t, half + t),
		Rect2(at.x, at.y + half, w, t),
	]
	for i in bars.size():
		if lit & (1 << i):
			canvas.draw_rect(bars[i], tint)
