class_name FxSignals
extends RefCounted
## Things that are heard or ordered, made visible: the player's orders, the
## alarm, the church bell, the trumpet, the band, a heal, a squad shimmering
## back into sight, the hold on the village centre.
## Each painter is func(canvas, fx) and draws one moment of the effect.

## Chevrons the charge sends, and the retreat sends: more and filled with the
## team's colour against fewer and plain white (shape and colour, not hue).
const CHARGE_CHEVRONS := 3
const RETREAT_CHEVRONS := 2
const CHEVRON_M := 3.4
## A chevron is never smaller than this on screen (canvas px).
const CHEVRON_PX := 40.0


## Metres one chevron measures at `view_zoom` (canvas pixels per metre).
static func chevron_m(view_zoom: float) -> float:
	return maxf(CHEVRON_M, CHEVRON_PX / view_zoom)


static func charge_fill() -> Color:
	return Palette.ARMY


static func retreat_fill() -> Color:
	return WorldPalette.WHITE


## An order lands: rally thumps a ring onto the spot; charge and retreat send
## chevrons from the army (fx.to) to where it should go (fx.pos).
static func order(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / fx.zoom
	var tint := Color(WorldPalette.WHITE, fx.fading(0.5))
	if int(fx.data.get("command", SiegeSim.Command.RALLY)) == SiegeSim.Command.RALLY:
		var close := 1.0 - ease(fx.progress(), 0.4)
		var wide := 3.0 * px
		canvas.draw_arc(fx.pos, 2.0 + 14.0 * close, 0.0, TAU, 32, tint, wide, true)
		canvas.draw_arc(
			fx.pos, 1.0 + 7.0 * close, 0.0, TAU, 24, Color(fx.tint(), fx.fading()), wide
		)
		return
	var charge := int(fx.data["command"]) == SiegeSim.Command.CHARGE
	var along := (fx.pos - fx.to).normalized() if fx.pos != fx.to else Vector2.RIGHT
	var span := fx.to.distance_to(fx.pos)
	var size := chevron_m(fx.zoom)
	var count := CHARGE_CHEVRONS if charge else RETREAT_CHEVRONS
	for i in count:
		var part := fmod(fx.progress() * 1.2 + float(i) / count, 1.0)
		var at := fx.to + along * span * part
		var seen := fx.fading(0.3) * (0.6 + 0.4 * sin(part * PI))
		var fill := charge_fill() if charge else retreat_fill()
		BattleFx.vee(canvas, at, along, size, px, Color(fill, seen))
		if charge:
			BattleFx.vee(canvas, at - along * size * 0.9, along, size, px, Color(fill, seen))
	canvas.draw_arc(
		fx.pos, 3.0 + 5.0 * fx.progress(), 0.0, TAU, 24, Color(fx.tint(), fx.fading()), 3.0 * px
	)


## The village wakes: red rings roll out and a bell jumps up over the spot.
static func alarm(canvas: CanvasItem, fx: BattleFx) -> void:
	for i in 2:
		var part := clampf(fx.progress() * 1.3 - i * 0.25, 0.0, 1.0)
		var ring := Color(Palette.BAD, (1.0 - part) * 0.9)
		canvas.draw_arc(fx.pos, 6.0 + 70.0 * ease(part, 0.5), 0.0, TAU, 64, ring, 1.6)
	var pop := 9.0 + 9.0 * sin(minf(fx.progress() * 4.0, 1.0) * PI * 0.5)
	var box := Rect2(fx.pos + Vector2(-pop / 2.0, -16.0 - pop), Vector2.ONE * pop)
	canvas.draw_texture_rect(Glyphs.texture(&"alarm"), box, false, Color(Palette.BAD, fx.fading()))
	for i in 6:
		var out := Vector2.from_angle(TAU * i / 6.0 + 0.5)
		var from := box.get_center() + out * pop * 0.75
		canvas.draw_line(from, from + out * 3.0, Color(Palette.BAD, fx.fading()), 0.6)


## The bell swings in its tower and its sound spreads as arcs on both sides.
static func bell(canvas: CanvasItem, fx: BattleFx) -> void:
	for i in 3:
		var part := clampf(fx.progress() * 1.4 - i * 0.2, 0.0, 1.0)
		var wave := Color(WorldPalette.BRASS, (1.0 - part) * 0.95)
		var reach := 5.0 + 26.0 * part
		canvas.draw_arc(fx.pos, reach, -0.6, 0.6, 12, wave, 0.9)
		canvas.draw_arc(fx.pos, reach, PI - 0.6, PI + 0.6, 12, wave, 0.9)
	var swing := sin(fx.age * 11.0) * 2.2 * fx.fading(0.8)
	var box := Rect2(fx.pos + Vector2(-4.0 + swing, -12.0), Vector2.ONE * 8.0)
	canvas.draw_texture_rect(Glyphs.texture(&"alarm"), box, false, WorldPalette.BRASS)


## The boy blows: brass arcs fan out ahead of him and notes float up.
static func trumpet(canvas: CanvasItem, fx: BattleFx) -> void:
	var facing := fx.heading().angle()
	var mouth := fx.pos + Vector2(0, -2.4)
	for i in 3:
		var part := clampf(fx.progress() * 1.5 - i * 0.2, 0.0, 1.0)
		var wave := Color(WorldPalette.BRASS, 1.0 - part)
		canvas.draw_arc(mouth, 3.0 + 22.0 * part, facing - 0.5, facing + 0.5, 12, wave, 0.8)
	for i in 3:
		var at := mouth + Vector2(2.0 + i * 2.6, -3.0 - 8.0 * fx.progress() - sin(fx.age * 5.0 + i))
		BattleFx.note(canvas, at, 1.5, Color(WorldPalette.BRASS, fx.fading()))


## The band hits a riff: lightning jumps out of the stage and notes fly.
static func riff(canvas: CanvasItem, fx: BattleFx) -> void:
	var flash := absf(sin(fx.age * 18.0))
	for i in 7:
		var out := Vector2.from_angle(TAU * i / 7.0 + fx.chance(i) + floorf(fx.age * 6.0))
		var reach := 9.0 + 12.0 * fx.chance(i + 11)
		var tint := Color(WorldPalette.BRASS.lerp(WorldPalette.WHITE, flash), fx.fading(0.4))
		BattleFx.bolt(
			canvas, fx.pos + out * 3.0 + Vector2(0, -3.0), fx.pos + out * reach, 5, 0.55, tint
		)
	canvas.draw_arc(
		fx.pos, 4.0 + 30.0 * fx.progress(), 0.0, TAU, 48, Color(fx.tint(), fx.fading()), 0.9
	)
	for i in 4:
		var at := (
			fx.pos + Vector2((i - 1.5) * 5.0, -6.0 - 9.0 * fx.progress() - sin(fx.age * 7.0 + i))
		)
		BattleFx.note(canvas, at, 1.8, Color(WorldPalette.WHITE, fx.fading()))


## A green plus rises from the healed and sparkles circle it.
static func heal(canvas: CanvasItem, fx: BattleFx) -> void:
	var rise := Vector2(0, -3.0 - 6.0 * ease(fx.progress(), 0.5))
	BattleFx.plus(canvas, fx.pos + rise, 4.2, Color(WorldPalette.WHITE, fx.fading()))
	BattleFx.plus(canvas, fx.pos + rise, 3.2, Color(Palette.GOOD, fx.fading()))
	canvas.draw_arc(
		fx.pos, 3.0 + 4.0 * fx.progress(), 0.0, TAU, 24, Color(Palette.GOOD, fx.fading()), 0.5
	)
	for i in 5:
		var at := fx.pos + Vector2.from_angle(TAU * i / 5.0 + fx.age * 2.0) * 5.0 + rise * 0.5
		BattleFx.plus(canvas, at, 1.0, Color(Palette.GOOD.lightened(0.3), fx.fading()))


## An unseen squad appears: glints rush in from a ring and flash on the spot.
static func reveal(canvas: CanvasItem, fx: BattleFx) -> void:
	var close := 1.0 - ease(fx.progress(), 0.5)
	for i in 10:
		var at := fx.pos + Vector2.from_angle(TAU * i / 10.0 + fx.age * 3.0) * (2.0 + 12.0 * close)
		BattleFx.star(
			canvas, at + Vector2(0, -2.0), 1.3, 0.4, 4, Color(0.8, 0.95, 1.0, fx.fading())
		)
	canvas.draw_arc(
		fx.pos, 2.0 + 12.0 * close, 0.0, TAU, 32, Color(fx.tint(), 0.7 * fx.fading()), 0.5
	)
	if fx.progress() > 0.6:
		var flash := (fx.progress() - 0.6) / 0.4
		BattleFx.star(
			canvas, fx.pos + Vector2(0, -2.0), 7.0 * flash, 2.0, 8, Color(1, 1, 1, 1.0 - flash)
		)


## The hold on the centre grows: a green pulse at the church.
static func centre(canvas: CanvasItem, fx: BattleFx) -> void:
	var held := float(fx.data.get("progress", 0.0))
	var ring := Color(Palette.GOOD, 0.8 * fx.fading(0.8))
	canvas.draw_arc(
		fx.pos, 18.0 + 6.0 * fx.progress(), -PI / 2.0, -PI / 2.0 + TAU * held, 48, ring, 1.2
	)
