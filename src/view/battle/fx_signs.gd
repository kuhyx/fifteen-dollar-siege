class_name FxSigns
extends RefCounted
## Signature moments of buffs that have no figure of their own: the buff's
## pictogram pops over the field, steam rises off a fed army, a clock sweeps,
## the army number rolls up. Sizes are screen pixels (`fx.zoom` turns them to
## metres), so a moment reads at any zoom and its pictogram mesh is the
## size `BuffChips.warm` already built (a badge never starts smaller than a
## chip: nothing is triangulated on first sight, lesson L7). Painters are func(canvas, fx).

## Canvas pixels: the badge's picture, a clock's radius, the number's height.
const BADGE_PX := BuffChips.BIG_CHIP
const CLOCK_PX := 44.0
const NUMBER_PX := 56.0


## `fx.data.id`'s pictogram pops on a round plate, hangs, then fades.
static func badge(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var pop := minf(fx.progress() * 7.0, 1.0)
	var grow := 0.5 + 0.5 * ease(pop, 0.35) + 0.12 * sin(pop * PI)
	var side := BADGE_PX * px * grow
	var centre := fx.pos + Vector2(0.0, -50.0 * px - 12.0 * px * fx.progress())
	var plate := Color(Palette.PANEL, 0.9 * fx.fading(0.3))
	canvas.draw_circle(centre, side * 0.66, Color(WorldPalette.SOOT, 0.5 * fx.fading(0.3)))
	canvas.draw_circle(centre, side * 0.6, plate)
	canvas.draw_arc(centre, side * 0.6, 0.0, TAU, 40, Color(Palette.COIN, fx.fading(0.3)), 3.0 * px)
	var fade := 1.0 - fx.fading(0.3)
	var box := Rect2(centre - Vector2.ONE * side / 2.0, Vector2.ONE * side)
	BuffPictograms.of(fx.data.get("id", &"stew")).draw(canvas, box, fade, Palette.PANEL)


## Warm wisps rise off the army and curl, with a few glowing motes.
static func steam(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	for i in 7:
		var rise := fmod(fx.age * (0.35 + 0.2 * fx.chance(i)) + fx.chance(i + 50), 1.0)
		var base := fx.pos + Vector2((i - 3) * 16.0 * px, 6.0 * px)
		var path := PackedVector2Array()
		for k in 8:
			var up := rise + k * 0.05
			var sway := sin(up * 9.0 + i) * 7.0 * px
			path.append(base + Vector2(sway, -up * 120.0 * px))
		var tint := Color(WorldPalette.WHITE, 0.5 * (1.0 - rise) * fx.fading(0.2))
		canvas.draw_polyline(path, tint, (5.0 - 3.0 * rise) * px, true)
	for i in 5:
		var mote := fmod(fx.age * 0.5 + fx.chance(i + 70), 1.0)
		var at := fx.pos + fx.jitter(i + 80, 40.0 * px) + Vector2(0.0, -mote * 90.0 * px)
		canvas.draw_circle(at, 2.2 * px, Color(Palette.COIN, (1.0 - mote) * fx.fading(0.2)))


## A clock face whose long hand sweeps `turns` times, then rings out.
static func clock(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var reach := CLOCK_PX * px * (0.8 + 0.2 * float(fx.data.get("scale", 1.0)))
	var centre := fx.pos + Vector2(float(fx.data.get("slot", 0)) * 110.0 * px, -70.0 * px)
	var alpha := fx.fading(0.25)
	canvas.draw_circle(centre, reach * 1.12, Color(WorldPalette.SOOT, 0.55 * alpha))
	canvas.draw_circle(centre, reach, Color(Palette.INK, 0.96 * alpha))
	for i in 12:
		var out := Vector2.from_angle(TAU * i / 12.0 - PI / 2.0)
		var inner := reach * (0.8 if i % 3 == 0 else 0.88)
		canvas.draw_line(
			centre + out * inner,
			centre + out * reach * 0.96,
			Color(WorldPalette.SOOT, alpha),
			2.0 * px
		)
	var sweep := ease(minf(fx.progress() * 1.5, 1.0), 0.6)
	var turns := float(fx.data.get("turns", 1.0))
	var long_hand := Vector2.from_angle(TAU * turns * sweep - PI / 2.0)
	var short_hand := Vector2.from_angle(TAU * turns * sweep / 12.0 - PI / 2.0)
	canvas.draw_line(centre, centre + short_hand * reach * 0.5, Color(Palette.BAD, alpha), 4.0 * px)
	canvas.draw_line(
		centre, centre + long_hand * reach * 0.82, Color(WorldPalette.SOOT, alpha), 3.0 * px
	)
	canvas.draw_circle(centre, 3.5 * px, Color(Palette.BAD, alpha))
	if fx.progress() > 0.66:
		var ring := (fx.progress() - 0.66) / 0.34
		canvas.draw_arc(
			centre, reach * (1.1 + ring), 0.0, TAU, 40, Color(Palette.COIN, 1.0 - ring), 3.0 * px
		)


## The army number rolls from `from` up to `to` in gold, with a flash at the end.
static func count(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var roll := ease(clampf(fx.progress() * 1.8, 0.0, 1.0), 0.5)
	var shown := roundi(lerpf(float(fx.data.get("from", 0)), float(fx.data.get("to", 0)), roll))
	var height := (
		NUMBER_PX * px * (1.0 + 0.25 * sin(clampf(fx.progress() * 1.8 - 0.9, 0.0, 1.0) * PI))
	)
	var width := SevenSegment.width(shown, height)
	var top_left := fx.pos + Vector2(-width / 2.0, -150.0 * px)
	var gold := Color(Palette.COIN, fx.fading(0.3))
	var edge := Color(WorldPalette.SOOT, fx.fading(0.3))
	for dir in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		SevenSegment.draw_number(canvas, shown, top_left + dir * 3.0 * px, height, edge)
	SevenSegment.draw_number(canvas, shown, top_left, height, gold)
	if fx.progress() > 0.55:
		var flash := (fx.progress() - 0.55) / 0.45
		var spark := Color(WorldPalette.SPARK, 1.0 - flash)
		BattleFx.star(
			canvas,
			top_left + Vector2(width / 2.0, height / 2.0),
			(30.0 + 70.0 * flash) * px,
			10.0 * px,
			8,
			spark
		)
