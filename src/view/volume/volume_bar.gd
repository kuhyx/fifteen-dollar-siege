class_name VolumeBar
extends Control
## The level as a row of steps, lit up to the current one. A click or tap on a
## step sets it. No words and no numbers: the bar is the readout.

signal picked(step: int)

const GAP := 6.0
const HEIGHT := 56.0

var steps := AudioSettings.STEPS
var level := 0:
	set(value):
		level = clampi(value, 0, steps)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## The rect of step `index` (0-based) in this control's own pixels.
func step_rect(index: int) -> Rect2:
	var width := (size.x - GAP * (steps - 1)) / steps
	return Rect2(index * (width + GAP), 0.0, width, size.y)


func _draw() -> void:
	for index in steps:
		var lit := index < level
		var rect := step_rect(index)
		# Taller toward the loud end, like the bars of a signal meter.
		var grow := 0.4 + 0.6 * float(index + 1) / steps
		rect = Rect2(rect.position.x, size.y * (1.0 - grow), rect.size.x, size.y * grow)
		draw_style_box(GlyphButton.box(Palette.COIN if lit else Palette.PANEL_PRESSED), rect)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for index in steps:
		var rect := step_rect(index)
		rect = Rect2(rect.position.x - GAP / 2.0, 0.0, rect.size.x + GAP, size.y)
		if rect.has_point(click.position):
			picked.emit(index + 1)
			accept_event()
			return
