class_name ResultScreen
extends Control
## The end of one siege: a green flag (the village is yours) or a red flame
## (you combust), and one button back to the hub. No words.
## SCAFFOLD view: the view agent replaces it and keeps `outcome`,
## `home_button`, `home_pressed` and `pick_at`.

signal home_pressed

var outcome := SiegeSim.Outcome.RUNNING
var home_button: GlyphButton

var _age := 0.0


func setup(p_outcome: int) -> void:
	outcome = p_outcome as SiegeSim.Outcome
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_button = GlyphButton.make(&"home", "Back to the hub", 160.0)
	home_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	home_button.offset_left = -80.0
	home_button.offset_right = 80.0
	home_button.offset_top = -240.0
	home_button.offset_bottom = -80.0
	home_button.pressed.connect(func() -> void: home_pressed.emit())
	add_child(home_button)


func _ready() -> void:
	home_button.grab_focus()


func won() -> bool:
	return outcome == SiegeSim.Outcome.WIN


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## What is under a canvas point (dev feedback's select tool).
func pick_at(_point: Vector2) -> Dictionary:
	return {"kind": "result", "id": "win" if won() else "combust", "state": "shown"}


func _draw() -> void:
	var tint := Palette.GOOD if won() else Palette.BAD
	draw_rect(Rect2(Vector2.ZERO, size), Color(tint, 0.12))
	var px := 420.0 * (1.0 + 0.04 * sin(_age * 5.0))
	var box := Rect2(Vector2(size.x / 2.0, size.y * 0.4) - Vector2.ONE * px / 2.0, Vector2.ONE * px)
	draw_texture_rect(Glyphs.texture(&"win" if won() else &"combust"), box, false, tint)
