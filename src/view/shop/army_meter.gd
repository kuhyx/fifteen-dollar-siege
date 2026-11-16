class_name ArmyMeter
extends Control
## How many men march: one of them with his club, the count as a seven-segment
## number, and a row of small figures (one per ten men) that grows when more
## men are bought. A number and a picture, no word.

const NUMBER_H := 72.0
const FIGURE_PX := 30.0
const PER_FIGURE := 10
const POP_S := 0.25

var men := 100:
	set(value):
		if value != men and is_inside_tree():
			_pop = POP_S
			set_process(true)
		men = value
		queue_redraw()

var _pop := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta, 0.0)
	if _pop <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var swell := 1.0 + 0.18 * (_pop / POP_S)
	var height := NUMBER_H * swell
	var icon := Rect2(Vector2(0, 0), Vector2.ONE * 96.0)
	UiPictograms.of(&"men").draw(self, icon)
	var corner := Vector2(icon.end.x + 18.0, 48.0 - height / 2.0)
	SevenSegment.draw_number(self, men, corner, height, Palette.INK)
	var figure := UiPictograms.of(&"pawn")
	var count := men / PER_FIGURE
	var per_row := 15
	for i in count:
		var at := Vector2(
			(i % per_row) * (FIGURE_PX + 4.0), 104.0 + (i / per_row) * (FIGURE_PX + 2.0)
		)
		figure.draw(self, Rect2(at, Vector2.ONE * FIGURE_PX))
