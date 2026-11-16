class_name PictoThree
extends RefCounted
## The five 3-dollar buffs as pictograms (BuffPictograms hands them out).


static func paint(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"prep_hour":
			clock(b, 60.0)
		&"pumpkin_catapults":
			_catapult(b)
		&"rock_band":
			_band(b)
		&"football_helmets":
			_helmet(b)
		&"moose":
			_moose(b)
		_:
			return false
	return true


## A clock whose face is gold for the time gained: the whole face is an hour
## (with an arrow all the way round), a sixth of it is ten minutes.
static func clock(b: PictoBrush, minutes: float) -> void:
	var sweep := 360.0 * minutes / 60.0
	var whole := sweep >= 360.0
	b.ink(PictoInk.LIGHT)
	b.box(55, 4, 18, 18, 4)
	b.ring(64, 72, 45, 9)
	b.ink(PictoInk.GOLD)
	if whole:
		b.disc(64, 72, 38)
		b.ink(PictoInk.DARK)
		b.arc(64, 72, 24, -75.0, 240.0, 6)
		b.poly([46, 43, 57.5, 60, 63, 44.5])
		b.disc(64, 72, 6)
		return
	b.arc(64, 72, 20, -90.0, sweep - 90.0, 36)
	b.ink(PictoInk.LIGHT)
	var end := Vector2(64, 72) + Vector2.from_angle(deg_to_rad(sweep - 90.0)) * 34.0
	b.bar(64, 72, 64, 38, 6)
	b.bar(64, 72, end.x, end.y, 6)
	b.disc(64, 72, 7)


## A catapult with a pumpkin on its arm, and the way the pumpkin will fly.
static func _catapult(b: PictoBrush) -> void:
	b.ink(PictoInk.WOOD)
	b.bar(14, 100, 114, 100, 9)
	b.bar(70, 100, 70, 58, 9)
	b.bar(46, 100, 70, 64, 7)
	b.bar(98, 92, 32, 38, 8)
	b.disc(32, 108, 13)
	b.disc(98, 108, 13)
	b.disc(32, 108, 4, true)
	b.disc(98, 108, 4, true)
	b.ink(PictoInk.GREEN)
	b.box(24, 4, 7, 9, 2)
	b.ink(PictoInk.ORANGE)
	b.oval(27, 26, 17, 15)
	b.bar(21, 14, 20, 38, 2, true)
	b.bar(33, 14, 34, 38, 2, true)
	b.ink(PictoInk.LIGHT)
	b.bar(52, 12, 64, 12, 4.5)
	b.bar(78, 16, 89, 22, 4.5)
	b.bar(101, 32, 109, 44, 4.5)


## An electric guitar that is playing: a red body with pickups, a long neck and
## head, two gold notes above it and a gold lightning bolt below.
static func _band(b: PictoBrush) -> void:
	b.ink(PictoInk.WOOD)
	b.bar(66, 68, 106, 28, 9)
	b.poly([98, 12, 122, 24, 114, 38, 94, 26])
	b.ink(PictoInk.RED)
	b.disc(34, 96, 26)
	b.disc(58, 78, 20)
	b.disc(30, 70, 11)
	b.ink(PictoInk.DARK)
	b.bar(44, 74, 56, 86, 6)
	b.bar(32, 86, 44, 98, 6)
	b.ink(PictoInk.GOLD)
	b.disc(24, 106, 4.5)
	b.disc(18, 26, 7)
	b.bar(24, 26, 24, 8, 3.5)
	b.bar(24, 9, 38, 14, 3.5)
	b.disc(56, 20, 6)
	b.bar(61, 20, 61, 5, 3)
	b.poly([104, 74, 90, 100, 100, 100, 94, 124, 122, 90, 110, 90, 120, 74])


## A football helmet from the side: shell, stripe, ear hole, face mask.
static func _helmet(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.disc(54, 62, 46)
	b.poly([64, 56, 110, 56, 110, 114, 50, 114], true)
	b.box(0, 102, 128, 26, 0.0, true)
	b.disc(44, 78, 8, true)
	b.ink(PictoInk.LIGHT)
	b.arc(54, 62, 38, 190.0, 310.0, 7)
	b.ink(PictoInk.GREY)
	b.bar(66, 62, 114, 66, 5)
	b.bar(60, 82, 114, 84, 5)
	b.bar(56, 100, 110, 100, 5)
	b.bar(112, 62, 112, 100, 5)
	b.bar(90, 64, 88, 100, 5)


## A moose, head on: broad antlers, a long face.
static func _moose(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.oval(26, 36, 22, 12, 24.0)
	b.oval(102, 36, 22, 12, -24.0)
	for tine: Array in [[10, 32, 5, 14], [20, 26, 18, 7], [32, 26, 36, 7], [42, 34, 50, 18]]:
		b.bar(tine[0], tine[1], tine[2], tine[3], 6.5)
		b.bar(128 - tine[0], tine[1], 128 - tine[2], tine[3], 6.5)
	b.bar(40, 46, 54, 56, 9)
	b.bar(88, 46, 74, 56, 9)
	b.ink(PictoInk.WOOD)
	b.oval(38, 64, 12, 6, -20.0)
	b.oval(90, 64, 12, 6, 20.0)
	b.oval(64, 78, 18, 32)
	b.oval(64, 104, 23, 17)
	b.ink(PictoInk.DARK)
	b.disc(56, 72, 3.5)
	b.disc(72, 72, 3.5)
	b.oval(56, 106, 3.5, 5)
	b.oval(72, 106, 3.5, 5)
