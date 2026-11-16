class_name PictoFour
extends RefCounted
## The five 4-dollar buffs as pictograms (BuffPictograms hands them out).


static func paint(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"deaf_villagers":
			_ear(b)
		&"shotgun":
			_shotgun(b)
		&"emperor":
			_emperor(b)
		&"fifty_men":
			_more_men(b)
		&"golf_carts":
			_cart(b)
		_:
			return false
	return true


## A villager's ear, struck through: the sound does not get in.
static func _ear(b: PictoBrush) -> void:
	b.ink(PictoInk.ORANGE)
	b.oval(58, 52, 32, 38)
	b.disc(50, 94, 16)
	b.poly([28, 62, 36, 100, 64, 98, 80, 74])
	b.arc(60, 50, 17, -170.0, 70.0, 7, true)
	b.bar(64, 66, 54, 84, 7, true)
	b.ink(PictoInk.LIGHT)
	b.arc(134, 52, 16, 140.0, 220.0, 5)
	b.arc(134, 52, 30, 145.0, 215.0, 5)
	b.ink(PictoInk.RED)
	b.bar(14, 114, 110, 12, 11)


## A sawn-off double barrel going off, and two shells.
static func _shotgun(b: PictoBrush) -> void:
	b.ink(PictoInk.WOOD)
	b.poly([40, 40, 14, 66, 6, 98, 24, 104, 34, 80, 54, 66])
	b.ink(PictoInk.GREY)
	b.bar(46, 44, 90, 44, 11)
	b.bar(46, 57, 90, 57, 11)
	b.ink(PictoInk.LIGHT)
	b.box(34, 36, 24, 30, 5)
	b.arc(52, 70, 9, 0.0, 180.0, 3.5)
	b.ink(PictoInk.GOLD)
	b.star(107, 50, 19, 8, 8)
	b.ink(PictoInk.RED)
	b.box(68, 86, 14, 28, 4)
	b.box(90, 86, 14, 28, 4)
	b.ink(PictoInk.GOLD)
	b.box(68, 105, 14, 9, 2)
	b.box(90, 105, 14, 9, 2)


## A small man under a very wide two-cornered hat, one hand in his coat.
static func _emperor(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.box(42, 78, 44, 46, 12)
	b.ink(PictoInk.LIGHT)
	b.disc(64, 62, 15)
	b.oval(67, 102, 8, 5)
	b.ink(PictoInk.GOLD)
	b.box(32, 78, 20, 9, 4)
	b.box(76, 78, 20, 9, 4)
	b.ink(PictoInk.SLATE)
	b.poly([4, 54, 22, 30, 64, 10, 106, 30, 124, 54, 96, 48, 64, 46, 32, 48])
	b.ink(PictoInk.GOLD)
	b.path([8, 52, 32, 46, 64, 44, 96, 46, 120, 52], 3.5)
	b.ink(PictoInk.RED)
	b.disc(64, 28, 7)
	b.ink(PictoInk.LIGHT)
	b.disc(64, 28, 3)


## A plus and a knot of men: more join the army.
static func _more_men(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.man(66, 54, 0.6)
	b.man(104, 54, 0.6)
	b.man(85, 90, 0.72, 4.0, true)
	b.ink(PictoInk.BLUE)
	b.man(85, 90, 0.72)
	b.ink(PictoInk.LIGHT)
	b.box(6, 36, 42, 14, 3)
	b.box(20, 22, 14, 42, 3)


## A golf cart with its roof, its driver and a bag of clubs.
static func _cart(b: PictoBrush) -> void:
	b.ink(PictoInk.GREY)
	b.bar(30, 26, 26, 70, 5)
	b.bar(92, 26, 98, 70, 5)
	b.bar(109, 46, 106, 30, 3.5)
	b.bar(114, 46, 118, 30, 3.5)
	b.bar(40, 68, 46, 52, 4.5)
	b.ink(PictoInk.WOOD)
	b.box(104, 42, 14, 30, 4)
	b.ink(PictoInk.BLUE)
	b.disc(62, 44, 10)
	b.box(53, 54, 18, 20, 6)
	b.ink(PictoInk.GREEN)
	b.box(72, 46, 9, 26, 4)
	b.ink(PictoInk.LIGHT)
	b.box(14, 16, 96, 10, 5)
	b.box(10, 68, 110, 26, 9)
	b.ink(PictoInk.SLATE)
	b.disc(36, 100, 17)
	b.disc(92, 100, 17)
	b.ink(PictoInk.LIGHT)
	b.disc(36, 100, 6)
	b.disc(92, 100, 6)
