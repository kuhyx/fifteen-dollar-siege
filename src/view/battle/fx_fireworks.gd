class_name FxFireworks
extends RefCounted
## A rocket over the church at a win: a spark climbs, then a ring of sparks
## bursts, droops and fades. Screen-constant sizes, one colour a rocket.

const RISE_PX := 160.0
const BURST_PX := 190.0
const TINTS: Array[Color] = [Palette.COIN, Palette.ARMY, Palette.GOOD, Palette.INK, Palette.BAD]


static func burst(canvas: CanvasItem, fx: BattleFx) -> void:
	var px := 1.0 / maxf(fx.zoom, 0.001)
	var tint := TINTS[int(fx.chance(1) * TINTS.size()) % TINTS.size()]
	var top := fx.pos + Vector2(0.0, -RISE_PX * px)
	if fx.progress() < 0.3:
		var climb := fx.progress() / 0.3
		var head := fx.pos.lerp(top, ease(climb, 0.5))
		canvas.draw_line(head + Vector2(0, 26.0 * px), head, Color(tint, 0.5), 2.0 * px)
		canvas.draw_circle(head, 5.0 * px, Color(WorldPalette.WHITE, 1.0))
		return
	var out := (fx.progress() - 0.3) / 0.7
	var reach := BURST_PX * px * ease(minf(out * 2.0, 1.0), 0.3)
	for i in 18:
		var dir := Vector2.from_angle(TAU * i / 18.0 + fx.chance(i) * 0.2)
		var at := top + dir * reach * (0.8 + 0.3 * fx.chance(i + 30))
		at.y += 60.0 * px * out * out
		var alpha := (1.0 - out * out * out) * (0.8 + 0.2 * sin(fx.age * 30.0 + i))
		canvas.draw_line(at - dir * 8.0 * px, at, Color(tint, alpha), 5.0 * px)
		canvas.draw_circle(at, 5.5 * px, Color(tint.lightened(0.5), alpha))
	var flash := clampf(1.0 - out * 4.0, 0.0, 1.0)
	canvas.draw_circle(top, 26.0 * px * flash, Color(tint, 0.5 * flash))
