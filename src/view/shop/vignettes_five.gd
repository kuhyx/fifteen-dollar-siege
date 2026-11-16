class_name VignettesFive
extends VignetteKit
## The seven 5-dollar buffs as looping scenes (BuffVignettes hands them out).
## `u` runs 0..1 over one loop.


static func paint(id: StringName, p: VignettePen, u: float) -> bool:
	match id:
		&"invisibility_potions":
			_potion(p, u)
		&"knight_armor":
			_armor(p, u)
		&"double_men":
			_twins(p, u)
		&"abduction":
			_saucer(p, u)
		&"stitched_monster":
			_monster(p, u)
		&"wasps":
			_wasps(p, u)
		&"medics":
			_medics(p, u)
		_:
			return false
	return true


## A man drinks, turns into a dashed outline and walks past a villager unseen.
static func _potion(p: VignettePen, u: float) -> void:
	ground(p)
	var watcher := man(p, Vector2(134, FLOOR), FOLK)
	arm(p, watcher, watcher + Vector2(-7, 14), FOLK)
	p.line(watcher + Vector2(-7, 14), Vector2(121, FLOOR - 26), 1.6, PictoInk.WOOD)
	var walk := ramp(u, 0.36, 0.95)
	var foot := Vector2(lerpf(42.0, 214.0, walk), FLOOR)
	if u >= 0.3:
		ghost(p, foot, walk * 34.0)
		return
	var sip := ramp(u, 0.05, 0.2)
	var head := man(p, foot, ARMY)
	var hand := head + Vector2(8, 9.0 - 8.0 * sip)
	arm(p, head, hand, ARMY)
	p.line(hand + Vector2(0, -1), hand + Vector2(0, -5), 1.6, PictoInk.LIGHT)
	p.disc(hand + Vector2(0, 1.5), 3.2, PictoInk.VIOLET)
	star(p, head + Vector2(0, -12), 7.0 * pulse(u, 0.27, 0.05), PictoInk.VIOLET)


## A man in a helm and plate trudges, pants and sweats; a stone bounces off.
static func _armor(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP)
	var stride := u * TAU * 2.0
	var foot := Vector2(84, FLOOR - absf(sin(stride)) * 0.8)
	var head := man(p, foot, PictoInk.GREY, stride, 1.15, 0.14)
	p.oval(foot + Vector2(2, -18), 4.6, 6.2, PictoInk.LIGHT)
	p.rect(Rect2(head + Vector2(-6, -6.5), Vector2(12, 12.5)), PictoInk.LIGHT)
	p.rect(Rect2(head + Vector2(-6, -2.8), Vector2(12, 1.8)), PictoInk.GOLD)
	p.rect(Rect2(head + Vector2(-0.9, -6.5), Vector2(1.8, 12.5)), PictoInk.GOLD)
	p.rect(Rect2(head + Vector2(1.6, 0.2), Vector2(3.6, 1.3)), PictoInk.DARK)
	for i in 3:
		var puff := fposmod(u * 4.0 + i / 3.0, 1.0)
		var breath := Color(PictoInk.LIGHT, 0.75 * (1.0 - puff))
		p.disc(head + Vector2(8.0 + puff * 11.0, 2.0 - puff * 4.0), 1.0 + puff * 2.4, breath)
	for i in 2:
		var fall := fposmod(u * 3.0 + i * 0.5, 1.0)
		p.disc(head + Vector2(-7.0 - 3.0 * i, -3.0 + fall * 12.0), 1.1, PictoInk.BLUE)
	stone(p, u, Vector2(196, 52), foot + Vector2(7, -18), 0.55)


## Three men: each one steps apart into two.
static func _twins(p: VignettePen, u: float) -> void:
	ground(p)
	var split := ramp(u, 0.22, 0.42) * (1.0 - ramp(u, 0.9, 0.99))
	for i in 3:
		var x := 50.0 + i * 46.0
		var hop := absf(sin(u * TAU * 3.0 + i)) * 2.5 * split
		star(p, Vector2(x, 82), 12.0 * pulse(u, 0.26, 0.07), PictoInk.LIGHT)
		man(p, Vector2(x + split * 10.0, FLOOR - hop), ARMY)
		man(p, Vector2(x - split * 10.0, FLOOR - hop), ARMY)


## A saucer hovers over the village and lifts a villager away in its beam.
static func _saucer(p: VignettePen, u: float) -> void:
	ground(p)
	house(p, Vector2(150, FLOOR))
	p.disc(Vector2(34, 34), 1.2, PictoInk.LIGHT)
	p.disc(Vector2(160, 44), 1.0, PictoInk.LIGHT)
	var hover := Vector2(88.0 + sin(u * TAU) * 3.0, 42.0 + sin(u * TAU * 2.0) * 1.5)
	var beam := ramp(u, 0.1, 0.18) * (1.0 - ramp(u, 0.8, 0.88))
	var lift := ramp(u, 0.2, 0.78)
	var drop := FLOOR - hover.y
	if beam > 0.0:
		p.poly([-8, 5, 8, 5, 24, drop, -24, drop], Color(PictoInk.LIGHT, 0.5 * beam), hover)
	if lift < 1.0:
		var size := 1.0 - 0.55 * lift
		var foot := Vector2(hover.x, lerpf(FLOOR, hover.y + 20.0, lift))
		var head := man(p, foot, FOLK, lift * 30.0, size)
		arm(p, head, head + Vector2(-6, -5) * size, FOLK, size)
		arm(p, head, head + Vector2(6, -5) * size, FOLK, size)
	p.oval(hover + Vector2(0, -5), 10, 8, PictoInk.VIOLET)
	p.oval(hover, 26, 6.5, PictoInk.GREY)
	for i in 3:
		var lit := fposmod(u * 6.0 + i / 3.0, 1.0) < 0.5
		p.disc(
			hover + Vector2(-16.0 + i * 16.0, 0.5), 2.0, PictoInk.GOLD if lit else PictoInk.SLATE
		)


## The stitched giant swats a villager clean off the stage.
static func _monster(p: VignettePen, u: float) -> void:
	ground(p)
	var swat := ramp(u, 0.4, 0.5)
	var head := man(p, Vector2(66, FLOOR), PictoInk.GREEN, 0.5, 2.0, 0.06 * swat)
	p.rect(Rect2(head + Vector2(-10.5, -11.5), Vector2(21, 6.5)), PictoInk.SLATE)
	p.line(head + Vector2(-7, -2), head + Vector2(7, -3), 0.9, PictoInk.DARK)
	for x: float in [-4.0, 0.0, 4.0]:
		p.line(head + Vector2(x, -4), head + Vector2(x + 0.4, -0.8), 0.9, PictoInk.DARK)
	p.disc(head + Vector2(3.5, 1.5), 1.5, PictoInk.LIGHT)
	var hand := head + Vector2(8, 15) + Vector2(20, 0).rotated(lerpf(-1.9, 0.5, swat))
	arm(p, head, hand, PictoInk.GREEN, 2.0)
	var come := ramp(u, 0.0, 0.36)
	var fly := ramp(u, 0.46, 0.92)
	if fly <= 0.0:
		man(p, Vector2(lerpf(190.0, 104.0, come), FLOOR), FOLK, come * 20.0)
	else:
		var at := Vector2(104.0 + fly * 120.0, FLOOR - 13.0 - sin(fly * PI) * 62.0)
		tumble(p, at, FOLK, fly * TAU * 1.5)
	star(p, Vector2(100, 84), 11.0 * pulse(u, 0.48, 0.07), PictoInk.GOLD)


## A villager runs for it, arms in the air, a cloud of wasps right behind.
static func _wasps(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP * 3.0)
	var stride := u * TAU * 5.0
	var foot := Vector2(128, FLOOR - absf(sin(stride)) * 2.0)
	var head := man(p, foot, FOLK, stride, 1.0, 0.24)
	arm(p, head, head + Vector2(-5.0, -7.0 + sin(stride) * 2.0), FOLK)
	arm(p, head, head + Vector2(7.0, -8.0 - sin(stride) * 2.0), FOLK)
	for i in 7:
		var phase := u * TAU * (2.0 + i % 3) + i * 1.7
		var at := Vector2(
			96.0 - i * 9.0 + sin(phase) * 5.0, 66.0 + (i % 3) * 8.0 + cos(phase) * 5.0
		)
		wasp(p, at, u * TAU * 12.0 + i)


## A man is down; a medic walks up, a green cross, and he is on his feet again.
static func _medics(p: VignettePen, u: float) -> void:
	ground(p)
	var come := ramp(u, 0.0, 0.34)
	var cure := ramp(u, 0.4, 0.5) * (1.0 - ramp(u, 0.72, 0.8))
	var rise := ramp(u, 0.52, 0.72)
	man(p, Vector2(124, FLOOR - 4.0 * (1.0 - rise)), ARMY, 0.0, 1.0, (1.0 - rise) * 1.5)
	var foot := Vector2(lerpf(-10.0, 98.0, come), FLOOR)
	var head := man(p, foot, ARMY, come * 22.0 * float(come < 1.0))
	p.rect(Rect2(foot + Vector2(-9.5, -17), Vector2(8, 7)), PictoInk.LIGHT)
	plus(p, foot + Vector2(-5.5, -13.5), 2.2, PictoInk.GREEN)
	arm(p, head, head + Vector2(9.0, 10.0 - 4.0 * cure), ARMY)
	plus(p, Vector2(118, 62.0 - cure * 5.0), 8.0 * cure, PictoInk.GREEN)
	heart(p, Vector2(124, 66.0 - rise * 8.0), 4.5 * ramp(u, 0.7, 0.8))
