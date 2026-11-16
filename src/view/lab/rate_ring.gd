class_name RateRing
extends RefCounted
## A win rate without a word: a ring whose green part is the share won (the
## rest is dark red), and the same share as a seven-segment number with a
## percent mark. The Lab, its ranking and the hub all draw it with this.

const LOST := Palette.LOST
const SEGMENTS := 96


## The ring: `rate` 0..1 of it is green, starting at the top, clockwise.
static func draw(
	canvas: CanvasItem, centre: Vector2, radius: float, thick: float, rate: float
) -> void:
	canvas.draw_arc(centre, radius, 0.0, TAU, SEGMENTS, LOST, thick, true)
	var share := clampf(rate, 0.0, 1.0)
	if share > 0.0:
		var top := -PI / 2.0
		canvas.draw_arc(centre, radius, top, top + TAU * share, SEGMENTS, Palette.GOOD, thick, true)


## How wide `percent(...)` draws `rate` at this height.
static func percent_width(rate: float, height: float) -> float:
	return SevenSegment.width(roundi(rate * 100.0), height) + height * 0.8


## The rate as a whole percent with its mark, its top-left at `at`.
static func percent(
	canvas: CanvasItem, at: Vector2, height: float, rate: float, tint: Color
) -> void:
	var number := roundi(clampf(rate, 0.0, 1.0) * 100.0)
	SevenSegment.draw_number(canvas, number, at, height, tint)
	var mark := at + Vector2(SevenSegment.width(number, height) + height * 0.24, 0.0)
	SevenSegment.draw_percent(canvas, mark, height, tint)
