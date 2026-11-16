class_name BuffVignettes
extends RefCounted
## What each buff does, as a short looping vector scene (the shop plays the
## focused card's). Each painter draws one moment `u` (0..1 of the loop) with
## a VignettePen; the five painter files hold the scenes by price. No words.

## Seconds per loop. [design guess]: long enough to read one cause and effect.
const LOOP_S := 2.4
const MEN_PER_FIGURE := 10
## The army marches three deep.
const RANKS := 3


## Draws the buff's vignette as it looks `at_s` seconds in, fitted into `stage`.
static func draw(id: StringName, canvas: CanvasItem, stage: Rect2, at_s: float) -> void:
	paint(id, VignettePen.fitted(canvas, stage), fposmod(at_s / LOOP_S, 1.0))


## The army on the march, one figure per ten men (the shop's idle stage).
static func draw_army(canvas: CanvasItem, stage: Rect2, at_s: float, men: int) -> void:
	var pen := VignettePen.fitted(canvas, stage)
	var u := fposmod(at_s / LOOP_S, 1.0)
	var stride := u * TAU * 2.0
	VignetteKit.ground(pen, u * VignetteKit.TUFT_GAP)
	var figures := maxi(men / MEN_PER_FIGURE, 1)
	for rank in RANKS:  # the rank at the back first; it is darker, so ranks stay apart
		var tint := VignetteKit.ARMY.darkened(0.22 * (RANKS - 1 - rank))
		for column in ceili(float(figures) / RANKS):
			if column * RANKS + rank >= figures:
				continue
			var foot := Vector2(26.0 + column * 15.0 + rank * 6.0, VignetteKit.FLOOR - 12.0)
			foot.y += rank * 7.0 - absf(sin(stride + rank)) * 1.2
			var head := VignetteKit.man(pen, foot, tint, stride + rank)
			pen.line(head + Vector2(5, 9), head + Vector2(9, -6), 2.0, PictoInk.WOOD)


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
