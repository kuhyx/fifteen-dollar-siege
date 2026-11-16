class_name FxToll
extends RefCounted
## The fallen made visible: a pop where a squad lost heads, and a gold number
## over the army for every ten villagers down (a seven-segment number is
## a shape, not text). Painters are func(canvas, fx) like every Fx* file.

## Canvas pixels tall the tally number is at its largest.
const NUMBER_PX := 64.0


## A flash, a dust ring and fragments in the fallen side's colour.
static func pop(canvas: CanvasItem, fx: BattleFx) -> void:
	var weight := clampf(sqrt(float(fx.data.get("n", 1))), 1.0, 4.0)
	var grow := ease(fx.progress(), 0.35)
	var at := fx.pos + Vector2(0, -1.4)
	var flash := Color(WorldPalette.SPARK, clampf(1.0 - fx.progress() * 2.4, 0.0, 1.0))
	BattleFx.star(canvas, at, (1.2 + 1.4 * grow) * weight, 0.8 * weight, 6, flash)
	canvas.draw_arc(
		at, (1.0 + 3.0 * grow) * weight, 0.0, TAU, 20, Color(WorldPalette.DUST, fx.fading(0.6)), 0.5
	)
	for i in int(weight) + 2:
		var out := Vector2.from_angle(-PI * fx.chance(i)) * (2.0 + 2.5 * weight * fx.chance(i + 9))
		var bit := BattleFx.lob(at, at + out, grow, 2.5)
		var bit_tint := Color(fx.tint(), fx.fading(0.4))
		canvas.draw_rect(Rect2(bit - Vector2(0.3, 0.3), Vector2(0.6, 0.6)), bit_tint)


## A gold number pops over the army, rises, and rings out.
static func toll(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var back := minf(fx.progress() * 6.0, 1.0)
	var scale := 1.0 + 0.35 * sin(back * PI) - (1.0 - back) * 0.6
	var height := NUMBER_PX * px * scale
	var total := int(fx.data.get("total", 0))
	var width := SevenSegment.width(total, height)
	var lane := (total / BattleToll.MILESTONE) % 3
	var rise := (36.0 + lane * 70.0) * px * ease(fx.progress(), 0.4)
	var top_left := fx.pos + Vector2(-width / 2.0, -26.0 * px - height - rise)
	var ring := 24.0 * px + 80.0 * px * ease(fx.progress(), 0.3)
	var gold := Color(Palette.COIN, fx.fading(0.3))
	canvas.draw_arc(fx.pos + Vector2(0, -10.0 * px), ring, 0.0, TAU, 48, gold, 4.0 * px, true)
	var edge := Color(WorldPalette.SOOT, fx.fading(0.3))
	for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		SevenSegment.draw_number(canvas, total, top_left + dir * 3.0 * px, height, edge)
	SevenSegment.draw_number(canvas, total, top_left, height, gold)
