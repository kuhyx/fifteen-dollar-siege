class_name PictoCheap
extends RefCounted
## The 2-dollar and 1-dollar buffs as pictograms (BuffPictograms hands them
## out). The pep-talk man is a generic tough guy: a square head and a headband.


static func paint(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"metal_bats":
			_bat(b)
		&"sleepless_village":
			_tired_eye(b)
		&"trumpet_boy":
			_trumpet(b)
		&"booze":
			_canteen(b)
		&"pep_talk":
			_pep_talk(b)
		&"cardboard_armor":
			_cardboard(b)
		&"stew":
			_stew(b)
		&"prep_ten_minutes":
			PictoThree.clock(b, 10.0)
		_:
			return false
	return true


## A metal bat: it gleams.
static func _bat(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.poly([32, 104, 24, 96, 84, 24, 108, 46])
	b.disc(96, 35, 16.3)
	b.ink(PictoInk.GREY)
	b.bar(26, 102, 46, 80, 10)
	b.disc(20, 108, 9)
	b.ink(PictoInk.GOLD)
	b.star(104, 22, 18, 5, 4)
	b.star(58, 34, 10, 3, 4)


## A villager's tired eye under a heavy lid, the moon still up.
static func _tired_eye(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.poly([8, 86, 30, 68, 58, 60, 86, 68, 108, 86, 86, 102, 58, 108, 30, 102])
	b.ink(PictoInk.ORANGE)
	b.disc(58, 86, 17)
	b.ink(PictoInk.DARK)
	b.disc(58, 86, 8)
	b.ink(PictoInk.SLATE)
	b.poly([6, 86, 30, 66, 58, 58, 86, 66, 110, 86, 86, 80, 58, 77, 30, 80])
	b.ink(PictoInk.GREY)
	b.arc(58, 62, 56, 62.0, 118.0, 4)
	b.ink(PictoInk.GOLD)
	b.disc(98, 28, 20)
	b.disc(108, 21, 17, true)
	b.star(28, 24, 9, 3, 4)
	b.star(56, 38, 6, 2, 4)


## A boy blowing a trumpet.
static func _trumpet(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.disc(22, 54, 15)
	b.box(8, 72, 28, 44, 12)
	b.bar(30, 84, 52, 64, 9)
	b.ink(PictoInk.GOLD)
	b.bar(36, 54, 84, 54, 8)
	b.poly([78, 47, 108, 28, 108, 80, 78, 61])
	for x: float in [50.0, 60.0, 70.0]:
		b.bar(x, 42, x, 62, 6)
	b.arc(60, 64, 12, 0.0, 180.0, 5)
	b.ink(PictoInk.LIGHT)
	b.arc(100, 54, 18, -40.0, 40.0, 5)
	b.arc(96, 54, 29, -38.0, 38.0, 5)


## Booze: a green bottle with a cork behind a mug of amber beer, foam spilling
## over the rim and bubbles rising in it.
static func _canteen(b: PictoBrush) -> void:
	b.ink(PictoInk.GREEN)
	b.box(8, 56, 38, 64, 10)
	b.box(18, 24, 18, 40, 5)
	b.ink(PictoInk.WOOD)
	b.box(19, 10, 16, 16, 4)
	b.ink(PictoInk.LIGHT)
	b.box(12, 80, 30, 22, 3)
	b.box(54, 44, 50, 76, 11)
	b.ring(108, 82, 15, 8)
	b.disc(64, 40, 13)
	b.disc(80, 32, 15)
	b.disc(96, 40, 13)
	b.ink(PictoInk.GOLD)
	b.box(60, 62, 38, 52, 7)
	b.disc(27, 91, 6)
	b.ink(PictoInk.DEEP_GOLD)
	b.box(60, 62, 10, 52, 5)
	b.ink(PictoInk.LIGHT)
	b.disc(82, 100, 3.5)
	b.disc(90, 84, 3)
	b.disc(78, 74, 2.5)


## A raised fist in a speech bubble, said by a tough guy in a headband.
static func _pep_talk(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	b.box(28, 6, 94, 78, 20)
	b.poly([46, 78, 32, 102, 66, 82])
	b.ink(PictoInk.BLUE)
	for x: float in [57.0, 69.0, 81.0, 93.0]:
		b.disc(x, 30, 7)
	b.box(50, 30, 50, 28, 8)
	b.box(60, 54, 30, 18, 3)
	b.bar(58, 45, 82, 47, 3, true)
	b.ink(PictoInk.GREY)
	b.box(6, 92, 30, 32, 9)
	b.ink(PictoInk.RED)
	b.box(4, 98, 34, 7, 2)
	b.poly([38, 99, 49, 93, 47, 105])
	b.ink(PictoInk.DARK)
	b.bar(13, 112, 18, 113, 3)
	b.bar(25, 113, 30, 112, 3)


## A man wearing a cardboard box: flaps open, taped, "this way up".
static func _cardboard(b: PictoBrush) -> void:
	b.ink(PictoInk.BLUE)
	b.disc(64, 22, 14)
	b.bar(34, 62, 14, 80, 10)
	b.bar(94, 62, 114, 80, 10)
	b.bar(52, 100, 50, 120, 11)
	b.bar(76, 100, 78, 120, 11)
	b.ink(PictoInk.WOOD)
	b.box(30, 42, 68, 62, 3)
	b.poly([30, 42, 12, 34, 18, 26, 40, 36])
	b.poly([98, 42, 116, 34, 110, 26, 88, 36])
	b.ink(PictoInk.LIGHT)
	b.box(60, 42, 8, 62)
	b.ink(PictoInk.DARK)
	b.poly([44, 58, 37, 70, 51, 70])
	b.box(42, 70, 4, 12)
	b.poly([84, 58, 77, 70, 91, 70])
	b.box(82, 70, 4, 12)


## A steaming bowl of vegetable stew and a spoon.
static func _stew(b: PictoBrush) -> void:
	b.ink(PictoInk.LIGHT)
	for x: float in [42.0, 64.0, 86.0]:
		b.path([x, 54, x + 5.0, 44, x - 3.0, 34, x + 3.0, 22], 4.5)
	b.ink(PictoInk.GREY)
	b.bar(92, 76, 120, 44, 5.5)
	b.ink(PictoInk.LIGHT)
	b.disc(64, 74, 46)
	b.box(0, 20, 128, 54, 0.0, true)
	b.box(10, 66, 108, 10, 5)
	b.box(46, 116, 36, 7, 3)
	b.ink(PictoInk.ORANGE)
	b.oval(64, 70, 44, 7)
	b.ink(PictoInk.GREEN)
	b.disc(48, 68, 5)
	b.disc(82, 67, 5)
	b.disc(66, 72, 4)
