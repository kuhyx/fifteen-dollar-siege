class_name PictoFive
extends RefCounted
## The seven 5-dollar buffs as pictograms (BuffPictograms hands them out).
## No words, no real person, no brand: each reads by shape and colour alone.


static func paint(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"invisibility_potions":
			_potion(b)
		&"knight_armor":
			_helm(b)
		&"double_men":
			_twins(b)
		&"abduction":
			_saucer(b)
		&"stitched_monster":
			_monster(b)
		&"wasps":
			_wasp(b)
		&"medics":
			_medkit(b)
		_:
			return false
	return true


## A flask of potion and the man who drank it: only a dashed outline is left.
static func _potion(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.disc(42, 86, 32)
	b.box(32, 22, 20, 40)
	b.box(26, 14, 32, 10, 4)
	b.ink(PictoInk.VIOLET)
	b.disc(42, 86, 25)
	b.box(10, 54, 64, 18, 0.0, true)
	b.ink(PictoInk.LIGHT)
	b.disc(50, 84, 4)
	b.disc(36, 96, 3)
	for turn: float in [0.0, 90.0, 180.0, 270.0]:
		b.arc(100, 40, 12, turn + 12.0, turn + 66.0, 4.5)
	for y: float in [68.0, 96.0]:
		b.bar(84, y, 84, y + 14.0, 4.5)
		b.bar(116, y, 116, y + 14.0, 4.5)
	b.bar(92, 62, 108, 62, 4.5)
	b.bar(92, 118, 108, 118, 4.5)


## A knight's great helm, seen from the front, with a plume.
static func _helm(b: PictoBrush) -> void:
	b.ink(PictoInk.RED)
	b.oval(72, 14, 28, 9, -14.0)
	b.ink(PictoInk.LIGHT)
	b.box(26, 24, 76, 98, 14)
	b.poly([18, 126, 18, 100, 46, 126], true)
	b.poly([110, 126, 110, 100, 82, 126], true)
	b.box(34, 64, 22, 9, 3, true)
	b.box(72, 64, 22, 9, 3, true)
	for hole: Array in [[42, 88], [50, 98], [42, 108], [86, 88], [78, 98], [86, 108]]:
		b.disc(hole[0], hole[1], 3, true)
	b.ink(PictoInk.GOLD)
	b.box(59, 24, 10, 96)
	b.box(26, 48, 76, 9)


## Twice the men: one man and his exact copy, split down a mirror line.
static func _twins(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.man(34, 80, 0.95)
	b.man(94, 80, 0.95)
	b.ink(PictoInk.LIGHT)
	for y: float in [40.0, 64.0, 88.0, 112.0]:
		b.bar(64, y, 64, y + 9.0, 4.5)
	b.poly([58, 6, 40, 18, 58, 30])
	b.poly([70, 6, 88, 18, 70, 30])


## A saucer lifts a villager off the ground in its beam.
static func _saucer(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.poly([46, 44, 82, 44, 106, 124, 22, 124])
	b.ink(PictoInk.ORANGE)
	b.man(64, 94, 0.5)
	b.bar(57, 86, 48, 72, 5.5)
	b.bar(71, 86, 80, 72, 5.5)
	b.ink(PictoInk.VIOLET)
	b.oval(64, 26, 22, 18)
	b.ink(PictoInk.GREY)
	b.oval(64, 38, 54, 13)
	b.ink(PictoInk.GOLD)
	for x: float in [30.0, 64.0, 98.0]:
		b.disc(x, 39, 4.5)


## A big stitched-together head: seams, mismatched eyes, a grim mouth.
static func _monster(b: PictoBrush) -> void:
	b.ink(PictoInk.GREEN)
	b.box(26, 26, 76, 84, 10)
	b.box(48, 104, 32, 20, 4)
	b.ink(PictoInk.SLATE)
	b.box(22, 10, 84, 28, 8)
	b.ink(PictoInk.LIGHT)
	b.disc(48, 64, 11)
	b.disc(84, 66, 7.5)
	b.ink(PictoInk.DARK)
	b.disc(50, 65, 4.5)
	b.disc(83, 67, 3)
	b.bar(46, 96, 84, 94, 4.5)
	b.bar(30, 47, 98, 45, 3)
	for x: float in [38.0, 51.0, 64.0, 77.0, 90.0]:
		b.bar(x, 41, x + 1.0, 51, 3)
	b.bar(70, 86, 96, 76, 3)
	for x: float in [76.0, 86.0]:
		b.bar(x - 2.0, 78 - (x - 76.0) * 0.4, x + 2.0, 88 - (x - 76.0) * 0.4, 3)


## A wasp, striped and stinging, and two more of the swarm.
static func _wasp(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.oval(60, 38, 28, 12, 28.0)
	b.oval(74, 28, 22, 9, 60.0)
	b.poly([16.8, 86.4, 6, 97, 20.8, 95.6])
	b.ink(PictoInk.GREY)
	b.bar(80, 74, 76, 94, 3.5)
	b.bar(88, 74, 92, 96, 3.5)
	b.bar(108, 44, 118, 30, 3.5)
	b.bar(102, 43, 104, 26, 3.5)
	b.ink(PictoInk.GOLD)
	b.oval(48, 78, 32, 20, -24.0)
	b.bar(26.2, 63.6, 44.2, 103.8, 6, true)
	b.bar(39, 57.9, 57, 98.1, 6, true)
	b.bar(51.8, 52.2, 69.8, 92.4, 6, true)
	b.disc(104.7, 52.8, 11)
	b.ink(PictoInk.ORANGE)
	b.disc(84.6, 61.7, 15)
	b.ink(PictoInk.DARK)
	b.disc(108, 50, 4.5)
	b.ink(PictoInk.GOLD)
	b.oval(104, 104, 9, 6, -24.0)
	b.oval(118, 84, 7, 4.5, -24.0)
	b.ink(PictoInk.LIGHT)
	b.oval(108, 96, 6, 3, 30.0)
	b.oval(121, 78, 5, 2.5, 30.0)


## A medic's case with a green cross.
static func _medkit(b: PictoBrush) -> void:
	b.ink(PictoInk.GREY)
	b.path([46, 42, 46, 24, 82, 24, 82, 42], 9)
	b.ink(PictoInk.LIGHT)
	b.box(10, 38, 108, 80, 12)
	b.ink(PictoInk.GREEN)
	b.box(53, 50, 22, 56, 3)
	b.box(36, 67, 56, 22, 3)
	b.ink(PictoInk.GREY)
	b.box(24, 34, 14, 10, 3)
	b.box(90, 34, 14, 10, 3)
