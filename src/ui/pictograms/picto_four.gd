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


## A sawn-off double barrel seen from the side, going off: a wooden stock, a
## grey receiver and two long barrels over a wooden fore-end, a flash and
## pellets at the muzzle, a shell below.
static func _shotgun(b: PictoBrush) -> void:
	b.ink(PictoInk.WOOD)
	b.poly([46, 40, 4, 52, 8, 92, 26, 90, 34, 66, 48, 64])
	b.box(62, 62, 42, 12, 5)
	b.ink(PictoInk.GREY)
	b.box(42, 34, 24, 34, 6)
	b.bar(52, 42, 104, 42, 12)
	b.bar(52, 56, 104, 56, 12)
	b.ink(PictoInk.LIGHT)
	b.arc(54, 72, 11, 10.0, 170.0, 4)
	b.bar(70, 38, 98, 38, 3)
	b.ink(PictoInk.GOLD)
	b.star(113, 49, 13, 5, 8)
	b.disc(122, 28, 3.2)
	b.disc(120, 70, 3.2)
	b.ink(PictoInk.RED)
	b.box(60, 86, 16, 30, 4)
	b.box(84, 86, 16, 30, 4)
	b.ink(PictoInk.GOLD)
	b.box(60, 106, 16, 10, 2)
	b.box(84, 106, 16, 10, 2)


## Napoleon from the front: a bicorne worn sideways (a gold-trimmed crescent
## with a cockade), a face with a lock of hair, the blue coat with white
## lapels, gold epaulettes and one hand tucked into the coat.
static func _emperor(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.box(30, 84, 68, 42, 14)
	b.ink(PictoInk.LIGHT)
	b.poly([44, 84, 64, 114, 84, 84, 74, 82, 64, 98, 54, 82])
	b.ink(PictoInk.ORANGE)
	b.box(56, 72, 16, 14, 3)
	b.oval(64, 100, 10, 7)
	b.disc(64, 60, 18)
	b.disc(46, 62, 4.5)
	b.disc(82, 62, 4.5)
	b.ink(PictoInk.GOLD)
	b.box(20, 84, 24, 10, 4)
	b.box(84, 84, 24, 10, 4)
	b.disc(54, 118, 2.5)
	b.disc(74, 118, 2.5)
	b.ink(PictoInk.DARK)
	b.disc(57, 62, 2.4)
	b.disc(71, 62, 2.4)
	b.bar(64, 64, 62, 70, 2.2)
	b.bar(57, 74, 71, 74, 2.2)
	b.ink(PictoInk.GOLD)
	b.oval(64, 38, 62, 28)
	b.oval(64, 52, 46, 22, 0.0, true)
	b.ink(PictoInk.SLATE)
	b.oval(64, 40, 56, 23)
	b.oval(64, 52, 46, 22, 0.0, true)
	b.ink(PictoInk.RED)
	b.disc(64, 20, 9)
	b.ink(PictoInk.LIGHT)
	b.disc(64, 20, 5)
	b.ink(PictoInk.BLUE)
	b.disc(64, 20, 2.2)


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
