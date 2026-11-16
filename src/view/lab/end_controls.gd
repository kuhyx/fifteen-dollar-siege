class_name EndControls
extends Control
## The ways on after a siege or a Lab batch, as picture buttons in a row: the
## same loadout again (green: the quick way), change the loadout, back to the
## hub, and (a siege's result only) the dice: a random new fifteen dollars.
## Each shows its key (1 to 4; a pad's accept button on the one in focus;
## nothing on touch). No words.

signal again_pressed
signal edit_pressed
signal hub_pressed
signal dice_pressed

const BUTTON := Vector2(170, 120)
const GAP := 30.0
const AGAIN_FILL := Palette.GO

var again: PictoButton
var edit: PictoButton
var hub: PictoButton
## Null unless made `with_dice`.
var dice: PictoButton


static func wide(count := 3) -> float:
	return count * BUTTON.x + (count - 1) * GAP


func _init(with_dice := false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(wide(4 if with_dice else 3), BUTTON.y)
	size = custom_minimum_size
	again = _button(0, &"retry", "The same loadout again", AGAIN_FILL)
	edit = _button(1, &"edit", "Change the loadout", Palette.PANEL)
	hub = _button(2, &"hub", "Back to the hub", Palette.PANEL)
	again.pressed.connect(func() -> void: again_pressed.emit())
	edit.pressed.connect(func() -> void: edit_pressed.emit())
	hub.pressed.connect(func() -> void: hub_pressed.emit())
	if with_dice:
		dice = _button(3, &"dice", "A random new fifteen dollars", Palette.PANEL)
		dice.pressed.connect(func() -> void: dice_pressed.emit())


## Every button, by what it does.
func buttons() -> Dictionary:
	var out := {"again": again, "edit": edit, "hub": hub}
	if dice != null:
		out["dice"] = dice
	return out


func _button(index: int, picture: StringName, spoken: String, fill: Color) -> PictoButton:
	var button := PictoButton.make(UiPictograms.of(picture), spoken, BUTTON, fill)
	button.position = Vector2(index * (BUTTON.x + GAP), 0.0)
	add_child(button)
	KeyHint.attach(button, MenuKeys.PICKS[index])
	return button
