class_name FxSpecials
extends RefCounted
## The staged moments: the UFO taking villagers the night before, the pep
## talk at the camp, the burst of joy at a win and the burst of fire at a
## loss. Each painter is func(canvas, fx) and draws one moment of the effect.

const HOVER := Vector2(0.0, -30.0)

static var _plain := FigureLook.new()


## Night falls, a saucer comes down over the village, its beam lifts a few
## villagers off the ground, and it is gone.
static func abduct(canvas: CanvasItem, fx: BattleFx) -> void:
	var part := fx.progress()
	var dusk := clampf(minf(part * 6.0, (1.0 - part) * 5.0), 0.0, 1.0)
	var around: Rect2 = fx.data.get("bounds", Rect2(fx.pos - Vector2(300, 200), Vector2(600, 400)))
	canvas.draw_rect(around.grow(3000.0), Color(WorldPalette.NIGHT, WorldPalette.NIGHT.a * dusk))
	var ship := fx.pos + HOVER
	if part < 0.22:
		ship += Vector2(-120.0, -90.0) * (1.0 - ease(part / 0.22, 0.4))
	elif part > 0.82:
		ship += Vector2(160.0, -140.0) * ease((part - 0.82) / 0.18, 2.5)
	else:
		var glow := 0.75 + 0.25 * sin(fx.age * 14.0)
		var cone := PackedVector2Array([ship + Vector2(-3.0, 4.0), ship + Vector2(3.0, 4.0)])
		cone.append_array([fx.pos + Vector2(10.0, 2.0), fx.pos + Vector2(-10.0, 2.0)])
		canvas.draw_colored_polygon(cone, Color(WorldPalette.BEAM, WorldPalette.BEAM.a * glow))
		canvas.draw_circle(fx.pos + Vector2(0, 2.0), 10.0, Color(WorldPalette.BEAM, 0.3 * glow))
		var taken := FigureLibrary.spec(SiegeSnapshot.Kind.VILLAGERS, _plain).far[0]
		for i in 5:
			var lift := clampf((part - 0.24 - i * 0.07) / 0.4, 0.0, 1.0)
			if lift >= 1.0:
				continue
			var at := (fx.pos + Vector2((i - 2) * 3.4, 0)).lerp(ship + Vector2(0, 6.0), lift)
			var spin := Transform2D(lift * 5.0 + i, Vector2.ONE * (1.0 - 0.6 * lift), 0.0, at)
			canvas.draw_mesh(taken, null, spin)
	var saucer := FigureLibrary.spec(SiegeSnapshot.Kind.UFO, _plain).near[0]
	var tilt := sin(fx.age * 3.0) * 0.06
	canvas.draw_mesh(
		saucer, null, Transform2D(tilt, Vector2.ONE * 3.2, 0.0, ship + Vector2(0, 10.0))
	)


## A big man on a crate flexes at the camp: rings of confidence roll over the
## army and hearts rise from it.
static func pep(canvas: CanvasItem, fx: BattleFx) -> void:
	var crate := Rect2(fx.pos + Vector2(-3.0, -3.0), Vector2(6.0, 3.0))
	canvas.draw_rect(crate, WorldPalette.WOOD)
	canvas.draw_rect(crate, WorldPalette.WOOD_DARK, false, 0.5)
	canvas.draw_line(crate.position, crate.end, WorldPalette.WOOD_DARK, 0.5)
	var flex := 1.0 + 0.08 * sin(fx.age * 12.0)
	var hero := FigureLibrary.spec(SiegeSnapshot.Kind.BAT_MEN, _plain).near[0]
	var stand := Transform2D(0.0, Vector2(2.2, 2.2 * flex), 0.0, fx.pos + Vector2(0, -3.0))
	canvas.draw_mesh(hero, null, stand)
	canvas.draw_rect(Rect2(fx.pos + Vector2(-1.5, -9.9 * flex), Vector2(3.0, 0.7)), Palette.BAD)
	for i in 3:
		var part := fmod(fx.progress() * 2.0 + i / 3.0, 1.0)
		var ring := Color(Palette.COIN, (1.0 - part) * fx.fading())
		canvas.draw_arc(fx.pos + Vector2(0, -6.0), 6.0 + 60.0 * part, 0.0, TAU, 48, ring, 1.0)
	for i in 9:
		var rise := fmod(fx.progress() * 1.6 + fx.chance(i), 1.0)
		var at := fx.pos + fx.jitter(i, 55.0) + Vector2(0, -6.0 - 14.0 * rise)
		var box := Rect2(at - Vector2.ONE * 2.5, Vector2.ONE * 5.0)
		var heart := Color(Palette.ARMY.lightened(0.3), (1.0 - rise) * fx.fading())
		canvas.draw_texture_rect(Glyphs.texture(&"morale"), box, false, heart)


## The village is yours: rays behind the church and confetti in the air.
static func victory(canvas: CanvasItem, fx: BattleFx) -> void:
	var grow := ease(minf(fx.progress() * 2.0, 1.0), 0.4)
	for i in 12:
		var out := Vector2.from_angle(TAU * i / 12.0 + fx.age * 0.5)
		var ray := PackedVector2Array([fx.pos + out * 9.0])
		ray.append(fx.pos + out.rotated(0.09) * (12.0 + 34.0 * grow))
		ray.append(fx.pos + out.rotated(-0.09) * (12.0 + 34.0 * grow))
		canvas.draw_colored_polygon(ray, Color(Palette.COIN, 0.28 * fx.fading()))
	var tints: Array[Color] = [Palette.ARMY, WorldPalette.WHITE, Palette.COIN, Palette.GOOD]
	for i in 36:
		var out := Vector2.from_angle(-PI * fx.chance(i)) * (10.0 + 34.0 * fx.chance(i + 100))
		var at := BattleFx.lob(fx.pos, fx.pos + out, minf(fx.progress() * 1.4, 1.0), 22.0)
		at.y += maxf(fx.progress() - 0.7, 0.0) * 30.0
		var turn := Vector2.from_angle(fx.age * 7.0 + i) * 0.9
		canvas.draw_line(at - turn, at + turn, Color(tints[i % 4], fx.fading(0.25)), 0.7)


## The army goes up: a flash, embers climbing, smoke over the bodies.
static func combust(canvas: CanvasItem, fx: BattleFx) -> void:
	var flash := clampf(1.0 - fx.progress() * 3.0, 0.0, 1.0)
	canvas.draw_arc(
		fx.pos, 6.0 + 60.0 * (1.0 - flash), 0.0, TAU, 48, Color(Palette.BAD, flash), 2.0
	)
	if flash > 0.0:
		BattleFx.star(
			canvas,
			fx.pos,
			20.0 * (1.0 - flash) + 4.0,
			5.0,
			9,
			Color(WorldPalette.FLAME_CORE, flash)
		)
	for i in 26:
		var rise := fmod(fx.age * (0.5 + fx.chance(i)) + fx.chance(i + 200), 1.0)
		var at := fx.pos + fx.jitter(i, 45.0) + Vector2(sin(fx.age * 4.0 + i) * 1.5, -22.0 * rise)
		var ember := WorldPalette.FLAME_MID.lerp(WorldPalette.FLAME_CORE, fx.chance(i + 5))
		canvas.draw_circle(at, 0.55 * (1.0 - rise) + 0.2, Color(ember, (1.0 - rise) * fx.fading()))
	for i in 7:
		var at := fx.pos + fx.jitter(i + 300, 40.0) + Vector2(0, -8.0 - 22.0 * fx.progress())
		var size := 4.0 + 7.0 * fx.progress()
		canvas.draw_circle(at, size, Color(WorldPalette.SMOKE, 0.3 * fx.fading(0.5)))
