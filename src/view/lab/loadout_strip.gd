class_name LoadoutStrip
extends RefCounted
## A loadout shown as its buffs' pictograms in a row (the Lab's ranking, the
## hub's best line, the result screen). Nothing bought is one empty slot, so
## an empty loadout is still something to see.

const GAP_SHARE := 0.12


static func width(count: int, px: float) -> float:
	var shown := maxi(count, 1)
	return shown * px + (shown - 1) * px * GAP_SHARE


## Draws the pictograms `px` tall from `at` (top-left); `fade` 0..1 dims them.
static func draw(canvas: CanvasItem, ids: Array, at: Vector2, px: float, fade := 0.0) -> void:
	if ids.is_empty():
		var hole := Rect2(at, Vector2.ONE * px).grow(-px * 0.12)
		UiPictograms.of(&"slot").draw(canvas, hole, 0.3, Palette.PANEL)
		return
	for i in ids.size():
		var corner := at + Vector2(i * px * (1.0 + GAP_SHARE), 0.0)
		var picture := BuffPictograms.of(StringName(str(ids[i])))
		picture.draw(canvas, Rect2(corner, Vector2.ONE * px), fade, Palette.PANEL)
