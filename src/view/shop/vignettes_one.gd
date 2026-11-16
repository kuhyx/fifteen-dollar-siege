class_name VignettesOne
extends VignetteKit
## The four 1-dollar buffs as looping scenes (BuffVignettes hands them out).
## `u` runs 0..1 over one loop. The pep-talk
## man is a generic tough guy: broad, grey, a red headband.


static func paint(id: StringName, p: VignettePen, u: float) -> bool:
	match id:
		&"pep_talk":
			_pep_talk(p, u)
		&"cardboard_armor":
			_cardboard(p, u)
		&"stew":
			_stew(p, u)
		&"prep_ten_minutes":
			VignettesThree.prep(p, u, 10.0)
		_:
			return false
	return true


## A tough guy punches the air; with every word the men stand taller.
static func _pep_talk(p: VignettePen, u: float) -> void:
	ground(p)
	var pump := absf(sin(u * TAU * 2.0))
	var head := man(p, Vector2(44, FLOOR), PictoInk.GREY, 0.7, 1.4)
	p.rect(Rect2(head + Vector2(-6.8, -3.6), Vector2(13.6, 2.6)), PictoInk.RED)
	p.poly([-6.8, -3.6, -13, -6, -12, -1], PictoInk.RED, head)
	p.line(head + Vector2(1.5, -0.2), head + Vector2(5.0, 0.4), 0.9, PictoInk.DARK)
	var fist := head + Vector2(13.0, -4.0 - pump * 9.0)
	arm(p, head, fist, PictoInk.GREY, 1.4)
	p.disc(fist, 3.4, PictoInk.GREY)
	for i in 3:
		var grow := fposmod(u * 2.0 + i / 3.0, 1.0)
		var wave := Color(PictoInk.LIGHT, 0.9 * (1.0 - grow))
		p.arc(head + Vector2(8, 1), 8.0 + grow * 52.0, -28.0, 28.0, 1.7, wave)
	for i in 3:
		var foot := Vector2(114.0 + i * 24.0, FLOOR - pump * 3.0)
		var mate := man(p, foot, ARMY, 0.5, 1.0 + 0.12 * pump)
		arm(p, mate, mate + Vector2(6.0, -5.0 - pump * 4.0), ARMY)
		heart(p, mate + Vector2(-1.0, -12.0 - pump * 4.0), 2.0 + 2.2 * pump)


## A man in a cardboard box takes a stone: the box dents, bits fly, he walks on.
static func _cardboard(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP)
	var stride := u * TAU * 2.0
	var knock := pulse(u, 0.52, 0.12)
	var foot := Vector2(84.0 - knock * 5.0, FLOOR - absf(sin(stride)))
	var head := man(p, foot, ARMY, stride, 1.0, -0.1 * knock)
	var dent := ramp(u, 0.48, 0.54) * (1.0 - ramp(u, 0.93, 1.0)) * 4.0
	p.poly([-9, -23, 9, -23, 9, -19, 9.0 - dent, -15, 9, -11, 9, -8, -9, -8], PictoInk.WOOD, foot)
	p.rect(Rect2(foot + Vector2(-1.2, -23), Vector2(2.4, 15)), PictoInk.LIGHT)
	p.poly([-9, -23, -14, -27, -11, -29, -6, -25], PictoInk.WOOD, foot)
	p.poly([9, -23, 14, -27, 11, -29, 6, -25], PictoInk.WOOD, foot)
	arm(p, head, foot + Vector2(-13, -11), ARMY)
	arm(p, head, foot + Vector2(13, -11), ARMY)
	stone(p, u, Vector2(192, 44), foot + Vector2(9, -15), 0.5)
	var burst := ramp(u, 0.5, 0.8)
	if burst > 0.0 and burst < 1.0:
		for i in 4:
			var way := Vector2.from_angle(-0.4 - i * 0.5)
			var bit := (
				foot + Vector2(9, -15) + way * burst * 22.0 + Vector2(0, burst * burst * 16.0)
			)
			p.rect(Rect2(bit, Vector2(2.6, 1.8)), PictoInk.WOOD)


## A pot of stew over a fire: a man eats, and grows stronger with every spoon.
static func _stew(p: VignettePen, u: float) -> void:
	ground(p)
	var pot := Vector2(84, FLOOR - 13.0)
	for i in 3:
		var lick := 7.0 + absf(sin(u * TAU * 3.0 + i * 2.0)) * 6.0
		var base := Vector2(74.0 + i * 10.0, FLOOR)
		p.poly([-5, 0, 0, -lick, 5, 0], PictoInk.RED, base)
		p.poly([-2.5, 0, 0, -lick * 0.55, 2.5, 0], PictoInk.GOLD, base)
	p.line(Vector2(64, FLOOR), Vector2(72, FLOOR - 26.0), 1.6, PictoInk.WOOD)
	p.line(Vector2(104, FLOOR), Vector2(96, FLOOR - 26.0), 1.6, PictoInk.WOOD)
	p.oval(pot, 15, 10, PictoInk.SLATE)
	p.rect(Rect2(pot + Vector2(-16, -10), Vector2(32, 3.4)), PictoInk.GREY)
	p.oval(pot + Vector2(0, -8.5), 13, 2.6, PictoInk.ORANGE)
	p.disc(pot + Vector2(-5, -8.8), 1.5, PictoInk.GREEN)
	p.disc(pot + Vector2(4, -8.2), 1.5, PictoInk.GREEN)
	for i in 3:
		var rise := fposmod(u + i / 3.0, 1.0)
		var steam := Color(PictoInk.LIGHT, 0.8 * (1.0 - rise))
		var at := pot + Vector2(-8.0 + i * 8.0 + sin(rise * TAU) * 2.5, -14.0 - rise * 26.0)
		p.line(at, at + Vector2(sin(rise * TAU + 1.0) * 2.5, -6), 1.5, steam)
	var bite := pulse(fposmod(u * 3.0, 1.0), 0.5, 0.35)
	var grown := ramp(u, 0.1, 0.9) * (1.0 - ramp(u, 0.95, 1.0))
	var head := man(p, Vector2(136, FLOOR), ARMY, 0.6, 1.0 + 0.3 * grown)
	var bowl := head + Vector2(-7, 12)
	var spoon := head + Vector2(-5.0, 9.0 - bite * 7.0)
	arm(p, head, bowl, ARMY)
	p.oval(bowl + Vector2(-1, 1), 4.4, 2.6, PictoInk.LIGHT)
	arm(p, head, spoon, ARMY)
	p.disc(spoon + Vector2(-1.5, -0.5), 1.7, PictoInk.LIGHT)
	heart(p, head + Vector2(3.0, -12.0 - grown * 4.0), 2.0 + 3.6 * grown)
