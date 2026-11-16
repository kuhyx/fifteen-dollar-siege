class_name VignetteStage
extends Control
## A window onto one buff's looping vignette: sky, then the scene, clipped to
## the control. It plays while it is visible and holds no words.

const SKY := Palette.SKY

## The buff on show ("" = an empty stage).
var buff: StringName = &"":
	set(value):
		if value != buff:
			buff = value
			time = 0.0
			queue_redraw()
## Seconds into the loop.
var time := 0.0
var playing := true
## With no buff on show: the army itself marches, one figure per ten men.
var men := 0:
	set(value):
		men = value
		queue_redraw()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not playing or (buff == &"" and men <= 0) or not is_visible_in_tree():
		return
	time = fposmod(time + delta, BuffVignettes.LOOP_S)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	if buff != &"":
		BuffVignettes.draw(buff, self, Rect2(Vector2.ZERO, size), time)
	elif men > 0:
		BuffVignettes.draw_army(self, Rect2(Vector2.ZERO, size), time, men)
