class_name BuffPictograms
extends RefCounted
## One vector pictogram per buff id, drawn once and kept. The four painter
## files hold the shapes by price. A buff's source sentence is never drawn:
## the pictogram alone has to say what it is.

static var _cache: Dictionary = {}


## The pictogram of a buff; an unknown id is an error and an empty picture.
static func of(id: StringName) -> Pictogram:
	if not _cache.has(id):
		_cache[id] = _paint(id)
		if _cache[id].is_empty():
			push_error("no pictogram for buff %s" % id)
	return _cache[id]


static func has(id: StringName) -> bool:
	if _cache.has(id):
		return not _cache[id].is_empty()
	return not _paint(id).is_empty()


static func _paint(id: StringName) -> Pictogram:
	var brush := PictoBrush.new()
	var done := (
		PictoFive.paint(id, brush)
		or PictoFour.paint(id, brush)
		or PictoThree.paint(id, brush)
		or PictoCheap.paint(id, brush)
	)
	return brush.picture if done else Pictogram.new()
