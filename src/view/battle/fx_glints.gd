class_name FxGlints
extends RefCounted
## Little signs of the looks the army wears, drawn at screen-constant sizes
## so they read at the auto camera's zoom: steel glints off armour and
## helmets, cardboard flakes, a drunk man's bubbles, a bat's ping.
## Painters are func(canvas, fx); BuffLooks decides when and where.

const STAR_PX := 22.0


## A four-point twinkle that swells and snaps shut.
static func glint(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var size := STAR_PX * px * sin(fx.progress() * PI)
	var at := fx.pos + Vector2(0.0, -10.0 * px)
	BattleFx.star(canvas, at, size, size * 0.18, 4, Color(WorldPalette.WHITE, fx.fading(0.5)))
	BattleFx.star(canvas, at, size * 0.55, size * 0.3, 4, Color(Palette.GLINT, fx.fading(0.5)))


## Flakes of cardboard tumble off the men.
static func scrap(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	for i in 4:
		var fall := fx.progress() + fx.chance(i) * 0.2
		var at := (
			fx.pos + Vector2((fx.chance(i + 4) - 0.5) * 30.0 * px, -8.0 * px + fall * 46.0 * px)
		)
		var turn := Vector2.from_angle(fx.age * (5.0 + i) + i) * 4.0 * px
		var tint := Color(WorldPalette.CARDBOARD, fx.fading(0.4))
		canvas.draw_line(at - turn, at + turn, tint, 3.0 * px)
		canvas.draw_line(
			at - turn, at + turn, Color(WorldPalette.TAPE, fx.fading(0.4) * 0.6), 1.0 * px
		)


## Three bubbles float up and pop; the squeak plays with them.
static func hic(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	for i in 3:
		var rise := clampf(fx.progress() * 1.3 - i * 0.12, 0.0, 1.0)
		var at := (
			fx.pos + Vector2(sin(rise * 6.0 + i * 2.0) * 7.0 * px, -12.0 * px - rise * 54.0 * px)
		)
		var size := (3.0 + 2.0 * i) * px * (1.0 + 0.4 * rise)
		var tint := Color(WorldPalette.WHITE, (1.0 - rise) * fx.fading(0.3))
		canvas.draw_arc(at, size, 0.0, TAU, 14, tint, 1.4 * px)
		canvas.draw_circle(at + Vector2(-size * 0.3, -size * 0.3), size * 0.22, tint)


## A bat strikes: a steel ring and four spokes.
static func ping(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var grow := ease(fx.progress(), 0.4)
	var at := fx.pos + Vector2(0.0, -10.0 * px)
	canvas.draw_arc(
		at,
		(6.0 + 20.0 * grow) * px,
		0.0,
		TAU,
		24,
		Color(WorldPalette.STEEL, fx.fading(0.6)),
		2.5 * px
	)
	for i in 4:
		var out := Vector2.from_angle(PI / 4.0 + i * PI / 2.0)
		var from := at + out * (8.0 + 12.0 * grow) * px
		canvas.draw_line(
			from, from + out * 9.0 * px, Color(WorldPalette.WHITE, fx.fading(0.6)), 2.0 * px
		)
