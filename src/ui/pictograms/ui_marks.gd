class_name UiMarks
extends RefCounted
## The small marks of the menu screens (UiPictograms hands them out): the
## coin and its empty slot, the bought check, the army figure, the result's
## flag and flame.


static func paint(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"check":
			b.ink(PictoInk.GREEN)
			b.path([20, 66, 50, 96, 108, 30], 18)
		&"coin":  # a dollar is a coin with a star struck into it
			b.ink(PictoInk.GOLD)
			b.disc(64, 64, 58)
			b.ink(PictoInk.DEEP_GOLD)
			b.ring(64, 64, 44, 7)
			b.star(64, 64, 24, 10, 4)
		&"slot":  # where a coin goes
			b.ink(PictoInk.SLATE)
			b.ring(64, 64, 50, 12)
		&"men":  # one of ours, with his club
			b.ink(PictoInk.WOOD)
			b.bar(96, 24, 86, 78, 13)
			b.ink(PictoInk.BLUE)
			b.man(56, 72, 1.1)
			b.bar(74, 74, 90, 66, 12)
		&"pawn":  # one figure of a crowd
			b.ink(PictoInk.BLUE)
			b.man(64, 70, 1.25)
		&"clock":
			b.ink(PictoInk.LIGHT)
			b.ring(64, 64, 48, 10)
			b.bar(64, 64, 64, 36, 9)
			b.bar(64, 64, 86, 64, 9)
		&"flag":  # the village is yours
			b.ink(PictoInk.WOOD)
			b.bar(32, 12, 32, 118, 9)
			b.ink(PictoInk.GREEN)
			b.poly([36, 14, 110, 40, 36, 66])
		&"flame":
			b.ink(PictoInk.RED)
			b.poly(
				[64, 4, 82, 34, 100, 58, 104, 86, 88, 112, 64, 122, 40, 112, 24, 86, 30, 56, 46, 66]
			)
			b.ink(PictoInk.GOLD)
			b.poly([64, 52, 80, 80, 78, 102, 64, 112, 50, 102, 48, 84])
		&"spark":  # new on the shelf
			b.ink(PictoInk.GOLD)
			b.star(64, 64, 58, 18, 4)
		_:
			return false
	return true
