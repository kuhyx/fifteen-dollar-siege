class_name EndControls
extends Control
## The three ways on after a siege or a Lab batch, as picture buttons in a
## row: the same loadout again (green: the quick way), change the loadout,
## back to the hub. Each shows its key (1, 2, 3; a pad's accept button on the
## one in focus; nothing on touch). No words.

signal again_pressed
signal edit_pressed
signal hub_pressed

const BUTTON := Vector2(170, 120)
const GAP := 30.0
const AGAIN_FILL := Palette.GO

var again: PictoButton
var edit: PictoButton
var hub: PictoButton


static func wide() -> float:
	return 3.0 * BUTTON.x + 2.0 * GAP


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(wide(), BUTTON.y)
	size = custom_minimum_size
	again = _button(0, &"retry", "The same loadout again", AGAIN_FILL)
	edit = _button(1, &"edit", "Change the loadout", Palette.PANEL)
	hub = _button(2, &"hub", "Back to the hub", Palette.PANEL)
	again.pressed.connect(func() -> void: again_pressed.emit())
	edit.pressed.connect(func() -> void: edit_pressed.emit())
	hub.pressed.connect(func() -> void: hub_pressed.emit())


## Every button, by what it does.
func buttons() -> Dictionary:
	return {"again": again, "edit": edit, "hub": hub}


func _button(index: int, picture: StringName, spoken: String, fill: Color) -> PictoButton:
	var button := PictoButton.make(UiPictograms.of(picture), spoken, BUTTON, fill)
	button.position = Vector2(index * (BUTTON.x + GAP), 0.0)
	add_child(button)
	KeyHint.attach(button, MenuKeys.PICKS[index])
	return button
