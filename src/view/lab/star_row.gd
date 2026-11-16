class_name StarRow
extends Control
## Three stars in a row, the first `earned` of them lit and the rest outlines:
## a mode's best result on the hub. A picture only; the spoken label says it.

const STAR_PX := 64.0
const GAP := 14.0
const HEIGHT := 72.0

var earned := 0:
	set(value):
		earned = clampi(value, 0, StarBook.MAX_STARS)
		accessibility_name = "Best result: %d of %d stars" % [earned, StarBook.MAX_STARS]
		queue_redraw()


static func wide() -> float:
	return StarBook.MAX_STARS * STAR_PX + (StarBook.MAX_STARS - 1) * GAP


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	earned = 0


func _draw() -> void:
	var top := (size.y - STAR_PX) / 2.0
	for i in StarBook.MAX_STARS:
		var box := Rect2(Vector2(i * (STAR_PX + GAP), top), Vector2.ONE * STAR_PX)
		UiPictograms.of(&"star" if i < earned else &"star_off").draw(self, box)
