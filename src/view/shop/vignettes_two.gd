class_name VignettesTwo
extends VignetteKit
## The four 2-dollar buffs as looping scenes (BuffVignettes hands them out).
## `u` runs 0..1 over one loop.


static func paint(id: StringName, p: VignettePen, u: float) -> bool:
	match id:
		&"metal_bats":
			_bat(p, u)
		&"sleepless_village":
			_sleepless(p, u)
		&"trumpet_boy":
			_trumpet(p, u)
		&"booze":
			_booze(p, u)
		_:
			return false
	return true


## A man winds up a gleaming bat and sends a villager out of the picture.
static func _bat(p: VignettePen, u: float) -> void:
	ground(p)
	var swing := ramp(u, 0.3, 0.42)
	var head := man(p, Vector2(72, FLOOR), ARMY, 0.7, 1.1, lerpf(-0.14, 0.2, swing))
	var hand := head + Vector2(7, 9)
	var tip := hand + Vector2.from_angle(lerpf(-2.3, 0.35, swing)) * 19.0
	arm(p, head, hand, ARMY, 1.1)
	p.line(hand, hand.lerp(tip, 0.4), 2.0, PictoInk.GREY)
	p.line(hand.lerp(tip, 0.4), tip, 3.8, PictoInk.LIGHT)
	star(p, tip + Vector2(0, -3), 6.0 * pulse(u, 0.14, 0.1), PictoInk.GOLD)
	var come := ramp(u, 0.0, 0.28)
	var fly := ramp(u, 0.4, 0.86)
	if fly <= 0.0:
		man(p, Vector2(lerpf(150.0, 100.0, come), FLOOR), FOLK, come * 16.0)
	else:
		var at := Vector2(100.0 + fly * 150.0, FLOOR - 13.0 - sin(fly * PI * 0.85) * 70.0)
		tumble(p, at, FOLK, fly * TAU * 2.0)
	star(p, Vector2(96, 82), 13.0 * pulse(u, 0.42, 0.07), PictoInk.GOLD)


## Under the moon a villager yawns, nods off on his feet and jerks awake.
static func _sleepless(p: VignettePen, u: float) -> void:
	p.disc(Vector2(154, 42), 12, PictoInk.GOLD)
	p.disc(Vector2(160, 37), 10.5, VignetteStage.SKY)
	star(p, Vector2(34, 38), 3.0, PictoInk.LIGHT)
	star(p, Vector2(98, 30), 2.2, PictoInk.LIGHT)
	ground(p)
	house(p, Vector2(52, FLOOR), 1.2)
	var yawn := pulse(u, 0.2, 0.16)
	var nod := ramp(u, 0.42, 0.84) * (1.0 - ramp(u, 0.9, 0.95))
	var head := man(p, Vector2(118, FLOOR), FOLK, 0.4, 1.4, nod * 0.34 - yawn * 0.1)
	arm(p, head, head + Vector2(5.0, 14.0 - yawn * 11.0), FOLK, 1.4)
	p.disc(head + Vector2(1.6, 2.4), 2.6 * yawn, PictoInk.DARK)
	for side: float in [-1.0, 1.0]:
		var eye := head + Vector2(side * 2.4 + 0.6, -1.2)
		p.line(eye + Vector2(-1.2, 0), eye + Vector2(1.2, 0), 0.9, PictoInk.DARK)
		p.arc(eye + Vector2(0, 0.6), 1.7, 20.0, 160.0, 0.6, PictoInk.SLATE)
	for i in 3:
		var grow := fposmod(u * 2.0 + i / 3.0, 1.0)
		var bubble := Color(PictoInk.LIGHT, nod * (1.0 - grow))
		var at := head + Vector2(8.0 + grow * 12.0, -8.0 - grow * 18.0)
		p.arc(at, 1.2 + grow * 3.2, 0.0, 360.0, 0.9, bubble)


## A boy with a trumpet plays out in front; hearts rise over the men behind.
static func _trumpet(p: VignettePen, u: float) -> void:
	ground(p, u * TUFT_GAP)
	var stride := u * TAU * 2.0
	var hop := absf(sin(stride))
	for i in 3:
		var mate := man(p, Vector2(28.0 + i * 24.0, FLOOR - hop * 1.6), ARMY, stride)
		p.line(mate + Vector2(5, 9), mate + Vector2(9, -6), 2.0, PictoInk.WOOD)
		var lift := fposmod(u * 2.0 + i * 0.3, 1.0)
		heart(p, mate + Vector2(-2.0, -12.0 - lift * 16.0), 3.6 * (1.0 - lift))
	var foot := Vector2(128, FLOOR - hop * 1.2)
	var head := man(p, foot, ARMY, stride, 0.72)
	var bell := head + Vector2(15, -1.5)
	arm(p, head, head + Vector2(8, 1), ARMY, 0.72)
	p.line(head + Vector2(3.5, 0.8), bell, 1.9, PictoInk.GOLD)
	p.poly([-1, -2, 6, -6, 6, 6, -1, 2], PictoInk.GOLD, bell)
	for i in 3:
		var grow := fposmod(u * 4.0 + i / 3.0, 1.0)
		var wave := Color(PictoInk.LIGHT, 0.9 * (1.0 - grow))
		p.arc(bell + Vector2(4, 0), 4.0 + grow * 22.0, -38.0, 38.0, 1.6, wave)
	var drift := fposmod(u * 2.0, 1.0)
	note(p, bell + Vector2(10.0 + drift * 10.0, -10.0 - drift * 16.0), 1.6, PictoInk.GOLD)


## A swig from the canteen, then he weaves off, fizzing and fearless.
static func _booze(p: VignettePen, u: float) -> void:
	ground(p)
	man(p, Vector2(30, FLOOR), ARMY)
	var sip := pulse(u, 0.15, 0.13)
	var walk := ramp(u, 0.3, 1.0)
	var drunk := float(u > 0.3)
	var weave := sin(u * TAU * 3.0) * drunk
	var foot := Vector2(lerpf(62.0, 222.0, walk) + weave * 4.0, FLOOR)
	var head := man(p, foot, ARMY, walk * 26.0, 1.0, weave * 0.3)
	var hand := head + Vector2(6.5, 10.0 - 8.0 * sip)
	arm(p, head, hand, ARMY)
	p.rect(Rect2(hand + Vector2(0.4, -5.6), Vector2(2.2, 3.0)), PictoInk.GREY)
	p.disc(hand + Vector2(1.5, 0), 3.4, PictoInk.WOOD)
	for i in 4:
		var grow := fposmod(u * 3.0 + i / 4.0, 1.0)
		var fizz := Color(PictoInk.GOLD, drunk * (1.0 - grow))
		var at := head + Vector2(sin(i * 2.1) * 6.0, -8.0 - grow * 14.0)
		p.arc(at, 1.0 + grow * 1.8, 0.0, 360.0, 0.9, fizz)
	heart(p, head + Vector2(-9, -9), 3.4 * pulse(u, 0.34, 0.1))
