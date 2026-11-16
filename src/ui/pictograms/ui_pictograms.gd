class_name UiPictograms
extends RefCounted
## The menu screens' own pictograms (modes, controls, coins, marks), in the
## same vector style and palette as the buffs. An unknown id is an error and
## an empty picture, never a silent blank.

const IDS: Array[StringName] = [
	&"watch",
	&"command",
	&"lab",
	&"go",
	&"back",
	&"retry",
	&"edit",
	&"hub",
	&"check",
	&"coin",
	&"slot",
	&"men",
	&"pawn",
	&"clock",
	&"flag",
	&"flame",
	&"spark",
]

static var _cache: Dictionary = {}


static func ids() -> Array[StringName]:
	return IDS


static func of(id: StringName) -> Pictogram:
	if not _cache.has(id):
		var brush := PictoBrush.new()
		if not (_modes(id, brush) or _controls(id, brush) or UiMarks.paint(id, brush)):
			push_error("no pictogram for %s" % id)
		_cache[id] = brush.picture
	return _cache[id]


static func _modes(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"watch":  # an eye: you only look
			b.ink(PictoInk.LIGHT)
			b.poly([4, 64, 28, 40, 64, 28, 100, 40, 124, 64, 100, 88, 64, 100, 28, 88])
			b.ink(PictoInk.BLUE)
			b.disc(64, 64, 25)
			b.ink(PictoInk.DARK)
			b.disc(64, 64, 12)
			b.ink(PictoInk.LIGHT)
			b.disc(72, 56, 5)
		&"command":  # a rally flag and the hand that points where it goes
			b.ink(PictoInk.WOOD)
			b.bar(30, 12, 30, 116, 8)
			b.ink(PictoInk.BLUE)
			b.poly([34, 14, 96, 34, 34, 58])
			b.ink(PictoInk.LIGHT)
			b.bar(100, 104, 62, 78, 13)
			b.disc(104, 106, 17)
			b.bar(92, 118, 78, 106, 10)
			b.ink(PictoInk.DARK)
			b.bar(96, 96, 110, 110, 2.5)
		&"lab":  # a flask inside a ring that shows a share won
			b.ink(PictoInk.RED)
			b.arc(64, 64, 55, 180.0, 270.0, 10)
			b.ink(PictoInk.GREEN)
			b.arc(64, 64, 55, -90.0, 180.0, 10)
			b.ink(PictoInk.LIGHT)
			b.poly([55, 30, 73, 30, 73, 52, 94, 96, 34, 96, 55, 52])
			b.box(50, 25, 28, 8, 3)
			b.ink(PictoInk.GREEN)
			b.poly([46, 74, 82, 74, 91, 92, 37, 92])
			b.ink(PictoInk.LIGHT)
			b.disc(58, 84, 3.5)
			b.disc(70, 80, 2.5)
		_:
			return false
	return true


static func _controls(id: StringName, b: PictoBrush) -> bool:
	match id:
		&"go":  # start the siege
			b.ink(PictoInk.LIGHT)
			b.poly([40, 20, 108, 64, 40, 108])
		&"back":
			b.ink(PictoInk.LIGHT)
			b.poly([12, 64, 58, 22, 58, 106])
			b.box(54, 50, 60, 28, 6)
		&"retry":  # the same again
			b.ink(PictoInk.LIGHT)
			b.arc(64, 66, 38, -50.0, 250.0, 13)
			b.poly([44.8, 13.4, 57.2, 47.2, 73.6, 22.1])
		&"edit":  # change what was bought: a card and a pencil
			b.ink(PictoInk.GREY)
			b.box(12, 18, 66, 92, 10)
			b.ink(PictoInk.GOLD)
			b.star(45, 52, 20, 7, 4)
			b.disc(33, 92, 8)
			b.disc(57, 92, 8)
			b.ink(PictoInk.LIGHT)
			b.poly([76, 108, 70, 122, 86, 116, 122, 58, 110, 50])
			b.ink(PictoInk.RED)
			b.poly([110, 50, 122, 58, 126, 50, 114, 42])
		&"hub":  # home
			b.ink(PictoInk.LIGHT)
			b.poly([64, 10, 120, 62, 8, 62])
			b.box(24, 60, 80, 56, 4)
			b.box(54, 80, 20, 36, 0.0, true)
		_:
			return false
	return true
