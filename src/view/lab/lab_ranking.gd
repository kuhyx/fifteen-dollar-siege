class_name LabRanking
extends Control
## The loadouts the Lab has tried, best first: a place number, the loadout as
## its buff pictograms, and its win rate as a bar and a number. The loadout
## on the bench now is framed; if it ranks below the last row it takes that
## row, with its true place. Numbers and pictures only.

const ROWS := 8
const ROW_H := 88.0
const ROW_GAP := 8.0
const PLACE_H := 36.0
const ICON_PX := 44.0
const BAR := Vector2(130, 16)
const RATE_H := 34.0

## LabBook.ranked() lines.
var lines: Array[Dictionary] = []
## LabBook key of the loadout being tested ("" = none).
var current_key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_lines(p_lines: Array[Dictionary], p_current_key: String) -> void:
	lines = p_lines
	current_key = p_current_key
	queue_redraw()


## The places (0 = best) drawn on the rows, top to bottom.
func places() -> Array[int]:
	var out: Array[int] = []
	for i in mini(lines.size(), ROWS):
		out.append(i)
	for i in range(ROWS, lines.size()):
		if lines[i]["key"] == current_key:
			out[ROWS - 1] = i
	return out


func _draw() -> void:
	var shown := places()
	for row in shown.size():
		var line := lines[shown[row]]
		var box := Rect2(0, row * (ROW_H + ROW_GAP), size.x, ROW_H)
		var here: bool = line["key"] == current_key
		draw_style_box(GlyphButton.box(Palette.PANEL_HOVER if here else Palette.PANEL), box)
		if here:
			draw_style_box(GlyphButton.box(Palette.CLEAR, Palette.INK), box)
		var middle := box.get_center().y
		var place := shown[row] + 1
		var place_at := Vector2(22.0, middle - PLACE_H / 2.0)
		SevenSegment.draw_number(self, place, place_at, PLACE_H, Palette.DIM)
		var ids: Array = line["ids"]
		LoadoutStrip.draw(self, ids, Vector2(96.0, middle - ICON_PX / 2.0), ICON_PX)
		var rate: float = line["rate"]
		var bar := Rect2(Vector2(size.x - 290.0, middle - BAR.y / 2.0), BAR)
		draw_rect(bar, RateRing.LOST)
		draw_rect(Rect2(bar.position, Vector2(BAR.x * rate, BAR.y)), Palette.GOOD)
		var rate_at := Vector2(bar.end.x + 16.0, middle - RATE_H / 2.0)
		RateRing.percent(self, rate_at, RATE_H, rate, Palette.INK)
