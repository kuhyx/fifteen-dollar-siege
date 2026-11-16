class_name VignettesFour
extends VignetteKit
## The five 4-dollar buffs as looping scenes (BuffVignettes hands them out).
## `u` runs 0..1 over one loop.


static func paint(id: StringName, p: VignettePen, u: float) -> bool:
	match id:
		&"deaf_villagers":
			_deaf(p, u)
		&"shotgun":
			_shotgun(p, u)
		&"emperor":
			_emperor(p, u)
		&"fifty_men":
			_more_men(p, u)
		&"golf_carts":
			_cart(p, u)
		_:
			return false
	return true


## The alarm bell rings: one villager jumps, the deaf one hoes on.
static func _deaf(p: VignettePen, u: float) -> void:
	ground(p)
	var ring := sin(u * TAU * 4.0)
	p.line(Vector2(26, FLOOR), Vector2(26, 52), 3.0, PictoInk.WOOD)
	p.line(Vector2(26, 54), Vector2(42, 54), 3.0, PictoInk.WOOD)
	var bell := Vector2(42, 56) + Vector2(0, 9).rotated(ring * 0.5)
	p.line(Vector2(42, 56), bell, 1.2, PictoInk.GREY)
	p.poly([-6, 5, -4, -4, 4, -4, 6, 5], PictoInk.GOLD, bell)
	p.disc(bell + Vector2(ring * 3.0, 6), 1.6, PictoInk.GOLD)
	for i in 3:
		var grow := fposmod(u * 2.0 + i / 3.0, 1.0)
		var wave := Color(PictoInk.LIGHT, 0.9 * (1.0 - grow))
		p.arc(Vector2(44, 62), 8.0 + grow * 120.0, -24.0, 24.0, 1.6, wave)
	var jump := absf(sin(u * TAU * 4.0)) * 5.0
	var scared := man(p, Vector2(98, FLOOR - jump), FOLK, 1.0)
	arm(p, scared, scared + Vector2(-7, -6), FOLK)
	arm(p, scared, scared + Vector2(7, -6), FOLK)
	star(p, scared + Vector2(0, -13), 4.0 + ring, PictoInk.RED)
	var deaf := man(p, Vector2(150, FLOOR), FOLK, 0.0, 1.0, 0.12)
	var hoe := deaf + Vector2(9.0, 12.0 + sin(u * TAU) * 3.0)
	arm(p, deaf, hoe, FOLK)
	p.line(hoe + Vector2(-3, -8), hoe + Vector2(9, 12), 1.4, PictoInk.WOOD)
	p.picture(BuffPictograms.of(&"deaf_villagers"), deaf + Vector2(0, -18), 18.0)


## One shot: a flash, a spread of pellets, three villagers knocked flat.
static func _shotgun(p: VignettePen, u: float) -> void:
	ground(p)
	var kick := pulse(u, 0.33, 0.1)
	var head := man(p, Vector2(40.0 - kick * 4.0, FLOOR), ARMY, 0.6, 1.0, -0.1 * kick)
	var grip := head + Vector2(5, 9)
	var muzzle := grip + Vector2(17, -1.0 - kick * 3.0)
	arm(p, head, grip, ARMY)
	p.line(grip + Vector2(-4, 2), grip, 3.0, PictoInk.WOOD)
	p.line(grip, muzzle, 2.8, PictoInk.GREY)
	star(p, muzzle + Vector2(6, 0), 11.0 * pulse(u, 0.3, 0.06), PictoInk.GOLD)
	var spread := ramp(u, 0.3, 0.42)
	if spread > 0.0 and spread < 1.0:
		for i in 6:
			var way := Vector2.from_angle((i - 2.5) * 0.09)
			p.disc(muzzle + way * (8.0 + spread * 80.0), 0.9, PictoInk.LIGHT)
	for i in 3:
		var smoke := fposmod(u + i * 0.12 - 0.34, 1.0)
		if u > 0.34 and smoke < 0.6:
			var grey := Color(PictoInk.GREY, 0.6 * (1.0 - smoke / 0.6))
			p.disc(muzzle + Vector2(4.0 + i * 2.0, -smoke * 30.0), 2.0 + smoke * 6.0, grey)
	for i in 3:
		var fall := ramp(u, 0.36 + i * 0.05, 0.56 + i * 0.05)
		var foot := Vector2(118.0 + i * 22.0 + fall * 6.0, FLOOR - 4.0 * fall)
		man(p, foot, FOLK, 0.0, 1.0, fall * 1.5)


## A small man in a wide hat points the way; the column behind keeps step.
static func _emperor(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP)
	var stride := u * TAU * 2.0
	var bob := absf(sin(stride)) * 1.4
	for i in 5:
		var mate := man(p, Vector2(28.0 + i * 19.0, FLOOR - bob), ARMY, stride)
		p.line(mate + Vector2(5, 9), mate + Vector2(9, -6), 2.0, PictoInk.WOOD)
	var foot := Vector2(150, FLOOR - bob)
	var head := man(p, foot, ARMY, stride, 0.8)
	arm(p, head, head + Vector2(12, 3.0 + sin(stride) * 0.6), ARMY, 0.8)
	p.disc(head + Vector2(0, 0.5), 3.4, PictoInk.LIGHT)
	p.poly([-13, 0, -8, -6, 0, -10, 8, -6, 13, 0, 7, -2, 0, -2.6, -7, -2], PictoInk.SLATE, head)
	p.line(head + Vector2(-12, -0.4), head + Vector2(12, -0.4), 1.0, PictoInk.GOLD)
	p.disc(head + Vector2(0, -5.5), 1.6, PictoInk.RED)
	p.disc(foot + Vector2(-3.5, -15.5), 1.5, PictoInk.GOLD)


## More men walk in, one after another, and the band grows.
static func _more_men(p: VignettePen, u: float) -> void:
	ground(p)
	for i in 4:
		man(p, Vector2(130.0 + i * 15.0, FLOOR), ARMY)
	for i in 3:
		var come := ramp(u, i * 0.22, i * 0.22 + 0.4)
		var x := lerpf(-14.0, 112.0 - i * 16.0, come)
		man(p, Vector2(x, FLOOR), ARMY, come * 18.0 * float(come < 1.0))
		var pop := pulse(u, i * 0.22 + 0.44, 0.1)
		plus(p, Vector2(112.0 - i * 16.0, 64), 6.0 * pop, PictoInk.LIGHT)


## A golf cart bowls along, wheels spinning, past a man on foot.
static func _cart(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP * 4.0)
	man(p, Vector2(lerpf(214.0, -22.0, u), FLOOR), ARMY, u * TAU * 3.0)
	var at := Vector2(86, FLOOR - 5.0 - absf(sin(u * TAU * 6.0)) * 0.8)
	for i in 3:
		var grow := fposmod(u * 4.0 + i / 3.0, 1.0)
		var dust := Color(PictoInk.GREY, 0.6 * (1.0 - grow))
		p.disc(at + Vector2(-26.0 - grow * 26.0, 2.0 - grow * 7.0), 2.0 + grow * 4.5, dust)
	p.line(at + Vector2(-16, -22), at + Vector2(-17, -8), 1.4, PictoInk.GREY)
	p.line(at + Vector2(16, -22), at + Vector2(19, -8), 1.4, PictoInk.GREY)
	p.rect(Rect2(at + Vector2(-21, -25), Vector2(42, 3.2)), PictoInk.LIGHT)
	p.disc(at + Vector2(0, -17), 4.4, ARMY)
	p.rect(Rect2(at + Vector2(-4, -13), Vector2(8, 7)), ARMY)
	p.line(at + Vector2(3, -9), at + Vector2(10, -11), 2.4, ARMY)
	p.line(at + Vector2(10, -6), at + Vector2(12, -13), 1.4, PictoInk.GREY)
	p.rect(Rect2(at + Vector2(-23, -8), Vector2(47, 9)), PictoInk.LIGHT)
	for x: float in [-14.0, 15.0]:
		var hub := at + Vector2(x, 1.0)
		p.disc(hub, 5.2, PictoInk.SLATE)
		var spoke := Vector2.from_angle(u * TAU * 6.0) * 4.0
		p.line(hub - spoke, hub + spoke, 1.1, PictoInk.LIGHT)
		p.line(hub - spoke.orthogonal(), hub + spoke.orthogonal(), 1.1, PictoInk.LIGHT)
