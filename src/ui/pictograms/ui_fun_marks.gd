class_name UiFunMarks
extends RefCounted
## Pictograms of the fun pass's menu delights, in the menu palette: a pair of
## dice (roll a random loadout), a gold star and its empty outline (the win's
## rating). `UiPictograms.of` asks `paint` last.


static func paint(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"dice":  # one die behind another, five pips and two
			b.ink(PictoInk.GOLD)
			b.box(58, 8, 62, 62, 11)
			b.ink(PictoInk.DARK)
			b.disc(76, 26, 6)
			b.disc(102, 52, 6)
			b.ink(PictoInk.LIGHT)
			b.box(8, 50, 70, 70, 12)
			b.ink(PictoInk.DARK)
			for spot: Vector2 in [Vector2(26, 68), Vector2(60, 68), Vector2(43, 85)]:
				b.disc(spot.x, spot.y, 7)
			for spot: Vector2 in [Vector2(26, 102), Vector2(60, 102)]:
				b.disc(spot.x, spot.y, 7)
		&"star":  # a win's star
			b.ink(PictoInk.GOLD)
			b.star(64, 68, 60, 25, 5)
			b.ink(PictoInk.DEEP_GOLD)
			b.star(64, 68, 30, 13, 5)
		&"star_off":  # the one not won yet: an outline
			b.ink(PictoInk.GREY)
			b.star(64, 68, 60, 25, 5)
			b.ink(PictoInk.DARK)
			b.star(64, 68, 44, 18, 5)
		_:
			return false
	return true
