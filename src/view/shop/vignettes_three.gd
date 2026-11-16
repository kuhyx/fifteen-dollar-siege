class_name VignettesThree
extends VignetteKit
## The five 3-dollar buffs as looping scenes (BuffVignettes hands them out).
## `u` runs 0..1 over one loop.


static func paint(id: StringName, p: VignettePen, u: float) -> bool:
	match id:
		&"prep_hour":
			prep(p, u, 60.0)
		&"pumpkin_catapults":
			_catapult(p, u)
		&"rock_band":
			_band(p, u)
		&"football_helmets":
			_helmet(p, u)
		&"moose":
			_moose(p, u)
		_:
			return false
	return true


## Time to prepare: the clock's hand sweeps `minutes` of the face while a man
## drives stakes into a palisade. An hour builds a wall, ten minutes one stake.
static func prep(p: VignettePen, u: float, minutes: float) -> void:
	ground(p)
	var built := ramp(u, 0.04, 0.78)
	var swept := built * minutes / 60.0
	var face := Vector2(46, 50)
	p.disc(face, 23, PictoInk.LIGHT)
	p.disc(face, 19.5, VignetteStage.SKY)
	wedge(p, face, 19.5, swept)
	p.line(face, face + Vector2.from_angle(TAU * swept - PI / 2.0) * 16.0, 2.4, PictoInk.LIGHT)
	p.disc(face, 2.6, PictoInk.LIGHT)
	var stakes := 5 if minutes >= 60.0 else 1
	var driving := mini(int(built * stakes), stakes - 1)
	for i in stakes:
		var rise := clampf(built * stakes - i, 0.0, 1.0)
		if rise > 0.02:
			var top := -30.0 * rise
			var neck := minf(top + 6.0, -0.5)
			p.poly([-4, 0, -4, neck, 0, top - 0.5, 4, neck, 4, 0], PictoInk.WOOD, _stake(i))
	var blow := absf(sin(u * TAU * 5.0)) * float(built < 1.0)
	var head := man(p, _stake(driving) + Vector2(-15, 0), ARMY, 0.6)
	var hand := head + Vector2(8.0, 2.0 + blow * 6.0)
	arm(p, head, hand, ARMY)
	p.line(hand, hand + Vector2(5, -7), 1.6, PictoInk.WOOD)
	p.line(hand + Vector2(2, -9), hand + Vector2(8, -6), 4.0, PictoInk.GREY)


## The arm winds back, lets go, and a pumpkin sails onto a house.
static func _catapult(p: VignettePen, u: float) -> void:
	ground(p)
	house(p, Vector2(160, FLOOR))
	var wind := ramp(u, 0.0, 0.26)
	var flung := ramp(u, 0.28, 0.34)
	var fly := ramp(u, 0.31, 0.7)
	var pivot := Vector2(44, FLOOR - 24.0)
	p.line(Vector2(20, FLOOR - 3.0), Vector2(64, FLOOR - 3.0), 3.4, PictoInk.WOOD)
	p.line(Vector2(44, FLOOR - 3.0), pivot, 3.4, PictoInk.WOOD)
	p.line(Vector2(28, FLOOR - 3.0), pivot + Vector2(0, 5), 2.4, PictoInk.WOOD)
	for x: float in [26.0, 58.0]:
		p.disc(Vector2(x, FLOOR - 4.0), 4.6, PictoInk.WOOD)
		p.disc(Vector2(x, FLOOR - 4.0), 1.4, Palette.GROUND)
	var angle := lerpf(lerpf(-2.5, -3.0, wind), -1.2, flung)
	var cup := pivot + Vector2.from_angle(angle) * 27.0
	p.line(pivot - Vector2.from_angle(angle) * 8.0, cup, 2.8, PictoInk.WOOD)
	var release := pivot + Vector2.from_angle(-1.2) * 27.0 + Vector2(0, -5)
	var target := Vector2(158, 78)
	if fly <= 0.0:
		pumpkin(p, cup + Vector2(0, -5), 5.0)
	elif fly < 1.0:
		pumpkin(p, release.lerp(target, fly) + Vector2(0, -sin(fly * PI) * 26.0), 5.0)
	else:
		var burst := ramp(u, 0.7, 0.95)
		for i in 7:
			var way := Vector2.from_angle(-PI * i / 6.0)
			var bit := target + way * burst * 26.0 + Vector2(0, burst * burst * 18.0)
			p.disc(bit, 2.4 * (1.0 - burst * 0.5), PictoInk.ORANGE)
	star(p, target, 12.0 * pulse(u, 0.71, 0.06), PictoInk.GOLD)


## A four-piece plays on its stage; the men march to it, clubs in the air.
static func _band(p: VignettePen, u: float) -> void:
	ground(p)
	var beat := absf(sin(u * TAU * 2.0))
	var boards := FLOOR - 6.0
	p.rect(Rect2(20, boards, 88, 6), PictoInk.GREY)
	var drummer := man(p, Vector2(66, boards - 9.0), PictoInk.LIGHT)
	p.disc(Vector2(66, boards - 8.0), 8.0, PictoInk.GOLD)
	p.disc(Vector2(66, boards - 8.0), 4.4, PictoInk.DARK)
	p.line(drummer + Vector2(3, 8), drummer + Vector2(11.0, 6.0 + beat * 6.0), 1.0, PictoInk.WOOD)
	p.line(
		drummer + Vector2(-3, 8), drummer + Vector2(-11.0, 12.0 - beat * 6.0), 1.0, PictoInk.WOOD
	)
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(64.0 + side * 30.0, boards - beat * 1.5)
		man(p, foot, PictoInk.LIGHT, 0.5, 1.0, side * 0.1 * beat)
		p.disc(foot + Vector2(-side * 2.0, -13), 3.8, PictoInk.RED)
		p.line(
			foot + Vector2(-side * 2.0, -13), foot + Vector2(-side * 13.0, -21), 1.7, PictoInk.RED
		)
	man(p, Vector2(50, boards), PictoInk.LIGHT, 0.0, 1.0, -0.08 * beat)
	p.line(Vector2(56, boards), Vector2(56, boards - 23.0), 1.0, PictoInk.GREY)
	p.disc(Vector2(56, boards - 24.0), 1.8, PictoInk.GREY)
	for i in 3:
		var grow := fposmod(u * 2.0 + i / 3.0, 1.0)
		var wave := Color(PictoInk.LIGHT, 0.9 * (1.0 - grow))
		p.arc(Vector2(104, 72), 8.0 + grow * 60.0, -32.0, 32.0, 1.8, wave)
		note(p, Vector2(44.0 + i * 24.0, 58.0 - grow * 22.0), 1.6, Color(PictoInk.GOLD, 1.0 - grow))
	for i in 3:
		var head := man(p, Vector2(132.0 + i * 18.0, FLOOR - beat * 4.0), ARMY, u * TAU * 2.0)
		arm(p, head, head + Vector2(6, -4), ARMY)
		p.line(head + Vector2(6, -4), head + Vector2(9, -15), 2.2, PictoInk.WOOD)


## A stone lands on a helmeted head and bounces off; he walks on.
static func _helmet(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP)
	var stride := u * TAU * 2.0
	var foot := Vector2(84, FLOOR - absf(sin(stride)))
	var head := man(p, foot, ARMY, stride)
	p.line(head + Vector2(5, 8), head + Vector2(10, -6), 2.2, PictoInk.WOOD)
	p.disc(head + Vector2(-0.5, -0.8), 6.2, PictoInk.LIGHT)
	p.rect(Rect2(head + Vector2(-1.2, -7.0), Vector2(2.4, 6.0)), PictoInk.RED)
	p.rect(Rect2(head + Vector2(1.5, 0.5), Vector2(5, 5)), ARMY)
	p.line(head + Vector2(2, 1.6), head + Vector2(7.6, 2.2), 0.9, PictoInk.GREY)
	p.line(head + Vector2(2, 4.2), head + Vector2(7.6, 4.4), 0.9, PictoInk.GREY)
	p.line(head + Vector2(7.6, 1.2), head + Vector2(7.6, 5.0), 0.9, PictoInk.GREY)
	stone(p, u, Vector2(190, 26), head + Vector2(4, -6), 0.5)


## A moose thunders across and the villagers in its way go flying.
static func _moose(p: VignettePen, u: float) -> void:
	ground(p)
	var x := lerpf(-36.0, 236.0, u)
	var gallop := u * TAU * 5.0
	for i in 2:
		var stood := 84.0 + i * 52.0
		var hit := ramp(x + 22.0, stood, stood + 70.0)
		if hit <= 0.0:
			man(p, Vector2(stood, FLOOR), FOLK)
		else:
			var height := lerpf(13.0, 4.0, hit) + sin(hit * PI) * 38.0
			tumble(p, Vector2(stood + hit * 22.0, FLOOR - height), FOLK, hit * TAU * 1.25)
	var at := Vector2(x, FLOOR - 15.0 - absf(sin(gallop)) * 3.0)
	for i in 4:
		var swing := sin(gallop + i * 1.6) * 6.0
		var hip := at + Vector2(-11.0 + i * 7.0, 5)
		p.line(hip, Vector2(hip.x + swing, FLOOR - absf(swing) * 0.3), 2.2, PictoInk.WOOD)
	p.oval(at, 16, 8.5, PictoInk.WOOD)
	p.oval(at + Vector2(-8, -6), 7, 5, PictoInk.WOOD)
	p.line(at + Vector2(12, -3), at + Vector2(19, -9), 6.0, PictoInk.WOOD)
	p.oval(at + Vector2(23, -8), 7, 4.4, PictoInk.WOOD)
	for side: float in [-1.0, 1.0]:
		var palm := at + Vector2(19.0 + side * 5.0, -17)
		p.oval(palm, 5.5, 2.6, PictoInk.LIGHT)
		for i in 3:
			p.line(
				palm + Vector2(-3.0 + i * 3.0, -1),
				palm + Vector2(-4.0 + i * 4.0, -6),
				1.4,
				PictoInk.LIGHT
			)
	for i in 3:
		var grow := fposmod(u * 5.0 + i / 3.0, 1.0)
		var dust := Color(PictoInk.GREY, 0.55 * (1.0 - grow))
		p.disc(Vector2(x - 20.0 - grow * 22.0, FLOOR - 2.0 - grow * 6.0), 2.0 + grow * 5.0, dust)


static func _stake(index: int) -> Vector2:
	return Vector2(100.0 + index * 17.0, FLOOR)
