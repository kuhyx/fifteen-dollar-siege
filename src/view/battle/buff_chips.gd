class_name BuffChips
extends Control
## What the army bought, as a row of buff pictograms under the meters strip.
## Every buff has a chip, so the ones that only change numbers (stew, the prep
## time, a sleepless or deaf village) are on screen too. At the start the row
## stands large above the army for a moment, then settles into the
## strip: the player sees what was bought before the first blow. Pictograms
## only, no word.

## Real seconds the row stands large, then takes to settle.
const SHOW_S := 1.2
const SETTLE_S := 0.6
const CHIP := 56.0
const BIG_CHIP := 112.0
## Where the large row stands, as a share of the height: above the army.
const BIG_AT := 0.27
const GAP := 10.0
## The first chip's top, under the meters strip.
const TOP := HudMeters.TOP + HudMeters.TALL + 12.0

var ids: Array[StringName] = []
## Real seconds since the first moment nothing else was staged.
var age := 0.0
## True while a staged beat plays: the chips wait small, out of its way.
var staged := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(loadout: Loadout) -> void:
	ids = loadout.ids.duplicate()
	queue_redraw()


## 0 = large above the army, 1 = settled in the strip.
func settled() -> float:
	if staged:
		return 1.0
	return clampf((age - SHOW_S) / SETTLE_S, 0.0, 1.0)


func advance(delta: float, p_staged: bool) -> void:
	var before := settled()
	staged = p_staged
	if not staged:
		age += delta
	if settled() < 1.0 or before < 1.0:
		queue_redraw()


## The box of chip `index` now, in this control's pixels.
func chip_box(index: int) -> Rect2:
	var settle := settled()
	var small := _row(index, CHIP, Vector2(size.x / 2.0, TOP + CHIP / 2.0))
	var big := _row(index, BIG_CHIP, Vector2(size.x / 2.0, size.y * BIG_AT))
	var smooth := settle * settle * (3.0 - 2.0 * settle)
	return Rect2(big.position.lerp(small.position, smooth), big.size.lerp(small.size, smooth))


func _row(index: int, side: float, middle: Vector2) -> Rect2:
	var width := ids.size() * side + (ids.size() - 1) * GAP
	return Rect2(
		Vector2(middle.x - width / 2.0 + index * (side + GAP), middle.y - side / 2.0),
		Vector2.ONE * side
	)


func _draw() -> void:
	for i in ids.size():
		var box := chip_box(i)
		draw_style_box(GlyphButton.box(Color(Palette.PANEL, 0.86)), box.grow(6.0))
		BuffPictograms.of(ids[i]).draw(self, box)
