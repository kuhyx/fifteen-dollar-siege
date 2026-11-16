class_name ResultScene
extends VignetteKit
## The end of a siege as a scene, drawn with a VignettePen in stage units
## (the buff vignettes' cast and floor). Won: your flag climbs its pole over
## the village and the men jump for joy under falling sparks. Lost: the
## leader goes up in flames and burns down to a heap of ash, as the premise
## promised. `age` is seconds since the screen opened; it plays once and then
## keeps a gentle loop (the flag waves, the smoke rises). No words.

const FLAG_UP_S := 0.7
const BURN_S := 0.9


static func paint(p: VignettePen, won: bool, age: float) -> void:
	ground(p)
	if won:
		_village(p, 0.0)
		_flag(p, age)
		_cheer(p, age)
	else:
		_village(p, 0.45)
		_runaways(p, age)
		_pyre(p, age)


static func _village(p: VignettePen, dim: float) -> void:
	for spot: Array in [[38.0, 0.9], [150.0, 1.0], [124.0, 0.75]]:
		house(p, Vector2(spot[0], FLOOR), spot[1])
	if dim > 0.0:
		p.rect(Rect2(0, 0, 192, FLOOR), Color(VignetteStage.SKY, dim))


## The flag climbs the pole, then waves.
static func _flag(p: VignettePen, age: float) -> void:
	var up := ramp(age, 0.1, FLAG_UP_S)
	var foot := Vector2(96, FLOOR)
	p.line(foot, foot + Vector2(0, -66), 2.2, PictoInk.WOOD)
	var top := foot + Vector2(0, -22.0 - 42.0 * up)
	var wave := sin(age * 5.0) * 2.5 * up
	p.poly([0, 0, 30, 7.0 + wave, 0, 15], PictoInk.GREEN, top)
	for i in 8:
		var burst := ramp(age, FLAG_UP_S, FLAG_UP_S + 0.5)
		var way := Vector2.from_angle(TAU * i / 8.0)
		star(
			p,
			foot + Vector2(0, -66) + way * burst * 30.0,
			5.0 * pulse(burst, 0.5, 0.5),
			PictoInk.GOLD
		)


## Men jump with their clubs in the air while sparks drift down.
static func _cheer(p: VignettePen, age: float) -> void:
	for i in 8:
		var x := 44.0 + i * 15.0 + (10.0 if i >= 4 else -6.0)
		var jump := absf(sin(age * 6.0 + i * 0.9)) * 6.0 * ramp(age, 0.2, FLAG_UP_S)
		var head := man(p, Vector2(x, FLOOR - jump), ARMY, 0.6)
		arm(p, head, head + Vector2(5.5, -6), ARMY)
		p.line(head + Vector2(5.5, -6), head + Vector2(8, -17), 2.0, PictoInk.WOOD)
	for i in 14:
		var fall := fposmod(age * 0.35 + i * 0.173, 1.0)
		var at := Vector2(
			20.0 + fposmod(i * 47.0, 152.0) + sin(age * 2.0 + i) * 3.0, 24.0 + fall * 76.0
		)
		var tint: Color = [PictoInk.GOLD, PictoInk.GREEN, PictoInk.LIGHT][i % 3]
		p.rect(Rect2(at, Vector2(2.4, 1.6)), Color(tint, ramp(age, FLAG_UP_S, FLAG_UP_S + 0.3)))


## The men who are left run for it.
static func _runaways(p: VignettePen, age: float) -> void:
	for i in 4:
		var side := -1.0 if i < 2 else 1.0
		var x := 96.0 + side * (34.0 + i % 2 * 16.0 + age * 14.0)
		var head := man(p, Vector2(x, FLOOR), ARMY, age * 14.0 + i, 1.0, side * 0.22)
		arm(p, head, head + Vector2(side * 6.0, -6), ARMY)


## The leader catches fire, burns, and is a heap of ash under rising smoke.
static func _pyre(p: VignettePen, age: float) -> void:
	var burn := ramp(age, 0.1, BURN_S)
	var foot := Vector2(96, FLOOR)
	if burn < 1.0:
		var shake := sin(age * 60.0) * 1.2 * burn
		man(p, foot + Vector2(shake, 0), ARMY.lerp(PictoInk.DARK, burn), 0.5, 1.7 - 0.5 * burn)
	else:
		p.oval(foot + Vector2(0, -3), 15, 5, PictoInk.SLATE)
		p.oval(foot + Vector2(3, -6), 8, 3.5, PictoInk.GREY)
	var blaze := pulse(age, BURN_S * 0.6, BURN_S * 0.9) + 0.25 * float(burn >= 1.0)
	for i in 5:
		var lick := (18.0 + absf(sin(age * 9.0 + i * 1.9)) * 22.0) * blaze
		var base := foot + Vector2(-16.0 + i * 8.0, 0)
		p.poly([-6, 0, 0, -lick, 6, 0], PictoInk.RED, base)
		p.poly([-3, 0, 0, -lick * 0.55, 3, 0], PictoInk.GOLD, base)
	for i in 4:
		var rise := fposmod(age * 0.5 + i * 0.25, 1.0)
		var smoke := Color(PictoInk.GREY, 0.5 * (1.0 - rise) * burn)
		p.disc(
			foot + Vector2(sin(i * 2.0 + age) * 6.0, -14.0 - rise * 60.0), 3.0 + rise * 8.0, smoke
		)
