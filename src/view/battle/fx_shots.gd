class_name FxShots
extends RefCounted
## Things that fly: sling stones, arrows, the shotgun's blast, pumpkins.
## Each painter is func(canvas, fx) and draws one moment of the effect.

const STONES := 7
const ARROWS := 8
const STONE := Palette.SLING_STONE


## Small stones on a low arc from the squad to its target.
static func sling(canvas: CanvasItem, fx: BattleFx) -> void:
	for i in STONES:
		var part := clampf(fx.progress() * 1.5 - i * 0.05, 0.0, 1.0)
		var from := fx.pos + fx.jitter(i, 4.0) + Vector2(0, -2.0)
		var onto := fx.to + fx.jitter(i + 50, 5.0)
		if part >= 1.0:
			canvas.draw_circle(onto, 0.9 * fx.fading(), Color(WorldPalette.DUST, 0.5))
			continue
		canvas.draw_circle(BattleFx.lob(from, onto, part, 7.0), 0.42, STONE)


## Arrows on a high arc; they stay stuck where they land until the end.
static func arrows(canvas: CanvasItem, fx: BattleFx) -> void:
	for i in ARROWS:
		var part := clampf(fx.progress() * 1.7 - i * 0.04, 0.0, 1.0)
		var from := fx.pos + fx.jitter(i, 4.0) + Vector2(0, -2.5)
		var onto := fx.to + fx.jitter(i + 50, 7.0)
		var tip := BattleFx.lob(from, onto, part, 18.0)
		var tail := BattleFx.lob(from, onto, maxf(part - 0.06, 0.0), 18.0)
		if part >= 1.0:
			tail = onto + Vector2(-0.8, -2.4)
		var shaft := Color(WorldPalette.CLOTH, fx.fading(0.2))
		canvas.draw_line(tail, tip, shaft, 0.28)
		canvas.draw_circle(tip, 0.3, Color(WorldPalette.STEEL, fx.fading(0.2)))
		canvas.draw_circle(tail, 0.34, Color(fx.tint(), fx.fading(0.2)))


## A flash cone toward the target, pellet streaks, then drifting smoke.
static func shotgun(canvas: CanvasItem, fx: BattleFx) -> void:
	var along := fx.heading()
	var muzzle := fx.pos + Vector2(0, -1.6) + along * 2.0
	var bang := clampf(1.0 - fx.progress() * 4.0, 0.0, 1.0)
	if bang > 0.0:
		var reach := 16.0 * (1.2 - bang)
		var cone := PackedVector2Array([muzzle])
		cone.append(muzzle + along.rotated(-0.3) * reach)
		cone.append(muzzle + along * reach * 1.25)
		cone.append(muzzle + along.rotated(0.3) * reach)
		canvas.draw_colored_polygon(cone, Color(WorldPalette.FLAME_MID, bang))
		BattleFx.star(canvas, muzzle, 4.0 * bang, 1.6 * bang, 6, WorldPalette.FLAME_CORE)
		for i in 6:
			var end := muzzle + along.rotated(fx.chance(i) * 0.7 - 0.35) * 26.0 * (1.0 - bang)
			canvas.draw_line(end - along * 3.0, end, Color(WorldPalette.SPARK, bang), 0.22)
	for i in 5:
		var drift := along * (3.0 + i * 2.2) * fx.progress() + Vector2(0, -3.0) * fx.progress()
		var puff := muzzle + fx.jitter(i + 20, 1.5) + drift
		var size := 1.2 + 2.6 * fx.progress() + fx.chance(i + 9)
		canvas.draw_circle(puff, size, Color(WorldPalette.SMOKE, 0.55 * fx.fading(0.7)))


## The catapult lets go: the pumpkin shoots up and away, small against the sky.
static func pumpkin_launch(canvas: CanvasItem, fx: BattleFx) -> void:
	var part := ease(fx.progress(), 0.5)
	var at := fx.pos + Vector2(0, -3.0) + (fx.heading() * 30.0 + Vector2(0, -34.0)) * part
	for i in 4:
		var streak := at - (fx.heading() * 3.0 + Vector2(0, -4.0)) * (i + 1) * 0.7
		canvas.draw_circle(streak, 0.5, Color(WorldPalette.WHITE, 0.35 * fx.fading() / (i + 1)))
	pumpkin(canvas, at, 1.5 * (1.0 - 0.6 * part), fx.fading(0.25))
	canvas.draw_arc(
		fx.pos, 3.0 + 5.0 * part, 0.0, TAU, 24, Color(WorldPalette.DUST, 1.0 - part), 0.5
	)


## The pumpkin comes down from `to` (its catapult) onto `pos` and bursts:
## a splat, flying chunks, and a stain that lingers.
static func pumpkin_splat(canvas: CanvasItem, fx: BattleFx) -> void:
	var fall := clampf(fx.progress() / 0.28, 0.0, 1.0)
	if fall < 1.0:
		var at := BattleFx.lob(fx.to, fx.pos, fall, 30.0)
		canvas.draw_circle(fx.pos, 1.5 * fall, Color(WorldPalette.SOOT, 0.25))
		pumpkin(canvas, at, 1.6, 1.0)
		return
	var after := (fx.progress() - 0.28) / 0.72
	var stain := Color(WorldPalette.PUMPKIN, 0.85 * fx.fading(0.5))
	BattleFx.star(canvas, fx.pos, 6.5 * minf(after * 6.0, 1.0), 3.0, 9, stain)
	canvas.draw_circle(fx.pos, 3.2, stain)
	for i in 9:
		var out := Vector2.from_angle(fx.chance(i) * TAU) * (4.0 + 11.0 * fx.chance(i + 30))
		var chunk := BattleFx.lob(fx.pos, fx.pos + out, minf(after * 2.4, 1.0), 5.0)
		canvas.draw_circle(chunk, 0.7, Color(WorldPalette.PUMPKIN.lightened(0.15), fx.fading(0.5)))
	if after < 0.2:
		BattleFx.star(canvas, fx.pos, 9.0 * (after * 5.0), 4.0, 7, Color(WorldPalette.WHITE, 0.5))


## A pumpkin `size` metres across, with ribs and a stem.
static func pumpkin(canvas: CanvasItem, at: Vector2, size: float, alpha: float) -> void:
	canvas.draw_circle(at, size, Color(WorldPalette.PUMPKIN, alpha))
	canvas.draw_circle(at, size * 0.45, Color(WorldPalette.PUMPKIN.darkened(0.15), alpha))
	var stem := Rect2(at + Vector2(-size * 0.12, -size * 1.3), Vector2(size * 0.24, size * 0.45))
	canvas.draw_rect(stem, Color(WorldPalette.STEM, alpha))
