class_name PauseMenu
extends CanvasLayer
## Esc / pad B / the menu button: the tree pauses and three pictogram buttons
## appear: resume, back to the hub, quit. Dev mode adds its own entries with
## `add_entry` (the camera). No words.
## SCAFFOLD view: the view agent restyles it and keeps the API.

signal toggled(open: bool)
signal hub_pressed
signal quit_pressed

const LAYER := 50
const SHADE := Color(0, 0, 0, 0.6)

## Button name -> button: "resume", "hub", "quit", plus dev entries.
var buttons: Dictionary = {}
var row: HBoxContainer

var _shade: ColorRect


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(row)
	add_entry("resume", &"resume", "Resume", close)
	add_entry("hub", &"home", "Back to the hub", _on_hub)
	add_entry("quit", &"quit", "Quit the game", func() -> void: quit_pressed.emit())
	_shade.hide()


## Adds one pictogram button to the menu (dev mode's camera uses this).
func add_entry(id: String, glyph: StringName, spoken: String, on_press: Callable) -> Button:
	var button := GlyphButton.make(glyph, spoken, 220.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_press)
	row.add_child(button)
	buttons[id] = button
	return button


## The same, with any Texture2D (the dev tools bring their own glyphs).
func add_texture_entry(id: String, icon: Texture2D, spoken: String, on_press: Callable) -> Button:
	var button := add_entry(id, &"menu", spoken, on_press)
	button.icon = icon
	return button


func is_open() -> bool:
	return _shade.visible


func open() -> void:
	if is_open():
		return
	_shade.show()
	get_tree().paused = true
	(buttons["resume"] as Button).grab_focus()
	toggled.emit(true)


func close() -> void:
	if not is_open():
		return
	_shade.hide()
	get_tree().paused = false
	toggled.emit(false)


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _on_hub() -> void:
	close()
	hub_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# The dev annotator owns Esc while it is open.
	if get_tree().get_first_node_in_group(&"annotator") != null:
		return
	get_viewport().set_input_as_handled()
	toggle()
