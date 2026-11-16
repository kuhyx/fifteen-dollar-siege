class_name BuffVignettes
extends RefCounted
## What each buff does, as a short looping vector scene (the shop plays the
## focused card's). Each painter draws one moment `u` (0..1 of the loop) with
## a VignettePen; the five painter files hold the scenes by price. No words.

## Seconds per loop. [design guess]: long enough to read one cause and effect.
const LOOP_S := 2.4


## Draws the buff's vignette as it looks `at_s` seconds in, fitted into `stage`.
static func draw(id: StringName, canvas: CanvasItem, stage: Rect2, at_s: float) -> void:
	paint(id, VignettePen.fitted(canvas, stage), fposmod(at_s / LOOP_S, 1.0))


static func has(id: StringName) -> bool:
	return paint(id, VignettePen.new(), 0.0)


## Draws moment `u` with `pen`; false (and nothing drawn) for an unknown buff.
static func paint(id: StringName, pen: VignettePen, u: float) -> bool:
	return (
		VignettesFive.paint(id, pen, u)
		or VignettesFour.paint(id, pen, u)
		or VignettesThree.paint(id, pen, u)
		or VignettesTwo.paint(id, pen, u)
		or VignettesOne.paint(id, pen, u)
	)
