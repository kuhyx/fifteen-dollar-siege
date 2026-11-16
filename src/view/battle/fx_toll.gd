class_name FxToll
extends RefCounted
## The fallen made visible: a pop where a squad lost heads, and a gold number
## over the army for every ten villagers down (a seven-segment number is
## a shape, not text). Painters are func(canvas, fx) like every Fx* file.

## Canvas pixels tall the tally number is at its largest.
const NUMBER_PX := 64.0
## Canvas pixels the tally climbs while it stays, real seconds its pop takes, and
## the seconds it fades out in.
const RISE_PX := 70.0
const POP_S := 0.42
const FADE_S := 0.75


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


## The tally rings on the field once: while one is up, the next milestone
## rolls ITS number (a new pop, a fresh stay) instead of a second number
## stacking on top of it, so tallies never overlap at any speed.
static func land(effects: BattleEffects, ring: Dictionary) -> void:
	for fx in effects.live:
		if fx.kind == &"toll":
			ring["bump_at"] = fx.age
			fx.data = ring
			fx.life = fx.age + BattleFlair.KEEP_S
			effects.seen[&"toll"] = int(effects.seen.get(&"toll", 0)) + 1
			return
	ring["bump_at"] = 0.0
	effects.flourish(&"toll", FxToll.toll, BattleFlair.KEEP_S, ring.pos, ring)


## Real seconds since the tally's number last changed.
static func _since(fx: BattleFx) -> float:
	return fx.age - float(fx.data.get("bump_at", 0.0))


## The number's rectangle in map metres, as `toll` paints it.
static func number_rect(fx: BattleFx) -> Rect2:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var pop := minf(_since(fx) / POP_S, 1.0)
	var scale := 1.0 + 0.35 * sin(pop * PI) - (1.0 - pop) * 0.6
	var height := NUMBER_PX * px * scale
	var width := SevenSegment.width(int(fx.data.get("total", 0)), height)
	var rise := RISE_PX * px * ease(clampf(fx.age / BattleFlair.KEEP_S, 0.0, 1.0), 0.4)
	var corner := fx.pos + Vector2(-width / 2.0, -26.0 * px - height - rise)
	return Rect2(corner, Vector2(width, height))


## A gold number pops over the army, rises, and rings out.
static func toll(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var box := number_rect(fx)
	var since := clampf(_since(fx) / BattleFlair.KEEP_S, 0.0, 1.0)
	var fade := clampf((fx.life - fx.age) / FADE_S, 0.0, 1.0)
	var ring := 24.0 * px + 80.0 * px * ease(since, 0.3)
	var gold := Color(Palette.COIN, fade)
	canvas.draw_arc(fx.pos + Vector2(0, -10.0 * px), ring, 0.0, TAU, 48, gold, 4.0 * px, true)
	var total := int(fx.data.get("total", 0))
	var edge := Color(WorldPalette.SOOT, fade)
	for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		SevenSegment.draw_number(canvas, total, box.position + dir * 3.0 * px, box.size.y, edge)
	SevenSegment.draw_number(canvas, total, box.position, box.size.y, gold)
