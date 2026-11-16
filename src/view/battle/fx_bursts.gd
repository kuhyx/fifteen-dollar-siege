class_name FxBursts
extends RefCounted
## Things that hit: the clash of a melee, a squad breaking, rallying or being
## wiped out, the moose's charge, a cart crash, the monster's smash, wasps.
## Each painter is func(canvas, fx) and draws one moment of the effect.


## A white star and four sparks where two lines meet.
static func clash(canvas: CanvasItem, fx: BattleFx) -> void:
	var at := fx.pos + Vector2(0, -1.8)
	var size := 1.5 + 3.5 * ease(fx.progress(), 0.4)
	BattleFx.star(canvas, at, size, size * 0.42, 6, Color(WorldPalette.SPARK, fx.fading(0.6)))
	for i in 4:
		var out := Vector2.from_angle(fx.chance(i) * TAU)
		var from := at + out * size * 1.1
		canvas.draw_line(from, from + out * 1.6, Color(WorldPalette.WHITE, fx.fading(0.6)), 0.3)


## Panic: sweat flies off a breaking squad and a broken ring spreads out.
static func rout(canvas: CanvasItem, fx: BattleFx) -> void:
	var grow := ease(fx.progress(), 0.4)
	for i in 8:
		var out := Vector2.from_angle(TAU * i / 8.0 + fx.chance(i))
		var drop := BattleFx.lob(fx.pos, fx.pos + out * 13.0, grow, 4.0) + Vector2(0, -2.0)
		canvas.draw_circle(drop, 0.55, Color(WorldPalette.WHITE, fx.fading()))
		canvas.draw_circle(drop - out * 0.5, 0.35, Color(WorldPalette.WHITE, fx.fading()))
	for i in 6:
		var from := TAU * i / 6.0 + fx.progress()
		var ring := Color(fx.tint(), 0.8 * fx.fading())
		canvas.draw_arc(fx.pos, 4.0 + 12.0 * grow, from, from + 0.6, 8, ring, 0.6)


## Order returns: a ring closes on the squad and chevrons rise in its colour.
static func rally(canvas: CanvasItem, fx: BattleFx) -> void:
	var close := 1.0 - ease(fx.progress(), 0.5)
	canvas.draw_arc(fx.pos, 3.0 + 12.0 * close, 0.0, TAU, 32, Color(fx.tint(), fx.fading()), 0.6)
	for i in 3:
		var at := fx.pos + Vector2((i - 1) * 3.0, -3.0 - 7.0 * fx.progress() - i % 2)
		BattleFx.chevron(canvas, at, Vector2.UP, 1.6, Color(fx.tint().lightened(0.3), fx.fading()))


## The last of a squad: a dust cloud and small crosses in its colour.
static func wiped(canvas: CanvasItem, fx: BattleFx) -> void:
	var grow := ease(fx.progress(), 0.35)
	for i in 6:
		var at := fx.pos + fx.jitter(i, 5.0) * (0.4 + grow)
		canvas.draw_circle(at, 1.6 + 2.8 * grow, Color(WorldPalette.DUST, 0.5 * fx.fading(0.6)))
	for i in 4:
		var at := fx.pos + fx.jitter(i + 40, 6.0) + Vector2(0, -2.0 - 5.0 * grow)
		var arm := Vector2(1.1, 1.1)
		var mark := Color(fx.tint().lightened(0.2), fx.fading(0.5))
		canvas.draw_line(at - arm, at + arm, mark, 0.45)
		canvas.draw_line(at - arm * Vector2(1, -1), at + arm * Vector2(1, -1), mark, 0.45)


## Dust thrown up along the charge, speed lines, and a hit at the end.
static func moose_charge(canvas: CanvasItem, fx: BattleFx) -> void:
	var along := fx.heading()
	var reach := fx.pos.distance_to(fx.to)
	var head := fx.pos + along * reach * minf(fx.progress() * 1.6, 1.0)
	for i in 8:
		var back := head - along * (i * 3.2) + fx.jitter(i, 1.4)
		if (back - fx.pos).dot(along) < 0.0:
			continue
		var size := 1.0 + i * 0.45 + 1.5 * fx.progress()
		canvas.draw_circle(
			back, size, Color(WorldPalette.DUST, 0.6 * fx.fading(0.5) / (1.0 + i * 0.2))
		)
	for i in 3:
		var from := head - along * 6.0 + along.orthogonal() * (i - 1) * 2.2 + Vector2(0, -3.0)
		canvas.draw_line(
			from, from - along * 7.0, Color(WorldPalette.WHITE, 0.5 * fx.fading()), 0.3
		)
	if fx.progress() > 0.62:
		var hit := (fx.progress() - 0.62) / 0.38
		var spark := Color(WorldPalette.SPARK, 1.0 - hit)
		BattleFx.star(canvas, fx.to + Vector2(0, -2.0), 3.0 + 5.0 * hit, 2.0, 7, spark)


## A cart hits something: a burst, a wheel bouncing away, planks, smoke.
static func cart_crash(canvas: CanvasItem, fx: BattleFx) -> void:
	var grow := ease(fx.progress(), 0.4)
	var burst := Color(WorldPalette.SPARK, clampf(1.0 - fx.progress() * 2.5, 0.0, 1.0))
	BattleFx.star(canvas, fx.pos + Vector2(0, -1.5), 3.0 + 6.0 * grow, 2.2, 8, burst)
	var hop := absf(sin(fx.progress() * PI * 3.0)) * 4.0 * (1.0 - fx.progress())
	var wheel := fx.pos + Vector2(4.0 + 16.0 * grow, -0.6 - hop)
	canvas.draw_circle(wheel, 1.3, Color(WorldPalette.SOOT, fx.fading()))
	canvas.draw_circle(wheel, 0.5, Color(WorldPalette.STEEL, fx.fading()))
	for i in 5:
		var out := Vector2.from_angle(-PI * fx.chance(i)) * (6.0 + 8.0 * fx.chance(i + 9))
		var plank := BattleFx.lob(fx.pos, fx.pos + out, grow, 7.0)
		var turn := Vector2.from_angle(fx.progress() * 9.0 + i) * 1.3
		canvas.draw_line(plank - turn, plank + turn, Color(WorldPalette.WHITE, fx.fading()), 0.5)
	for i in 3:
		var puff := fx.pos + Vector2((i - 1) * 2.0, -2.0 - 7.0 * fx.progress() - i)
		canvas.draw_circle(
			puff, 1.5 + 2.5 * fx.progress(), Color(WorldPalette.SMOKE, 0.5 * fx.fading(0.6))
		)


## The ground cracks under the monster's fist and a shock ring rolls out.
static func monster_smash(canvas: CanvasItem, fx: BattleFx) -> void:
	var grow := ease(fx.progress(), 0.35)
	canvas.draw_arc(
		fx.pos, 2.0 + 16.0 * grow, 0.0, TAU, 40, Color(WorldPalette.WHITE, fx.fading()), 0.8
	)
	canvas.draw_arc(
		fx.pos, 1.0 + 10.0 * grow, 0.0, TAU, 32, Color(WorldPalette.DUST, fx.fading()), 1.4
	)
	for i in 7:
		var out := Vector2.from_angle(TAU * i / 7.0 + fx.chance(i) * 0.5)
		var crack := Color(WorldPalette.SOOT, 0.8 * fx.fading(0.5))
		BattleFx.bolt(
			canvas, fx.pos, fx.pos + out * (5.0 + 7.0 * minf(grow * 2.0, 1.0)), 4, 0.4, crack
		)
	for i in 6:
		var out := Vector2.from_angle(-PI * fx.chance(i + 20)) * (5.0 + 9.0 * fx.chance(i + 3))
		var rock := BattleFx.lob(fx.pos, fx.pos + out, grow, 6.0)
		canvas.draw_circle(rock, 0.7, Color(WorldPalette.STONE_SHADE, fx.fading()))


## A buzzing cloud of yellow dots, and the stings it lands.
static func wasp_swarm(canvas: CanvasItem, fx: BattleFx) -> void:
	var t := fx.age * 9.0
	for i in 16:
		var loop := Vector2(
			sin(t * (0.7 + fx.chance(i)) + i), cos(t * (0.9 + fx.chance(i + 7)) + i * 2.0)
		)
		var at := fx.pos + Vector2(0, -3.0) + loop * (2.0 + 5.0 * fx.chance(i + 3))
		canvas.draw_circle(at, 0.45, Color(WorldPalette.BRASS, fx.fading(0.2)))
		canvas.draw_circle(at + Vector2(0.4, 0), 0.28, Color(WorldPalette.SOOT, fx.fading(0.2)))
	for i in 3:
		var beat := fmod(fx.age * 2.5 + fx.chance(i + 60), 1.0)
		var at := fx.pos + fx.jitter(i + 70 + int(fx.age * 2.5), 5.0) + Vector2(0, -3.5)
		BattleFx.star(
			canvas, at, 1.6 * beat, 0.6 * beat, 5, Color(Palette.BAD, (1.0 - beat) * fx.fading(0.2))
		)
