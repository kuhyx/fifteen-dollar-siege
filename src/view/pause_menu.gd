class_name PauseMenu
extends CanvasLayer
## Esc / pad B / the menu button: the tree pauses, the screen dims and one
## card of pictogram buttons appears: resume, back to the hub, quit. Resume
## has the focus and shows the key or pad button that closes the menu, read
## from the InputMap for the device in use. Under them sit the music and
## effects volume (`VolumeRow`: speaker buttons and a bar of steps). Dev mode
## adds its own entries with `add_entry` (the camera). No words.

signal toggled(open: bool)
signal hub_pressed
signal quit_pressed

const LAYER := 50
const SHADE := Palette.SHADE
const BUTTON_PX := 200.0
const BADGE_PX := 60.0
const PADDING := 44
const CLOSE_ACTION := &"ui_cancel"

## Button name -> button: "resume", "hub", "quit", plus dev entries.
var buttons: Dictionary = {}
var row: HBoxContainer
## The panel the buttons sit on.
var card: PanelContainer
## Channel (&"music", &"effects") -> its volume row.
var volume: Dictionary = {}
## The key picture in the corner of the resume button.
var close_hint: KeyHint

var _shade: ColorRect


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(middle)
	card = PanelContainer.new()
	var panel := GlyphButton.box(Palette.PANEL_HOVER.darkened(0.25), Palette.DIM.darkened(0.35))
	panel.set_content_margin_all(PADDING)
	panel.set_corner_radius_all(GlyphButton.RADIUS + PADDING / 2)
	card.add_theme_stylebox_override("panel", panel)
	middle.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", PADDING)
	card.add_child(column)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", PADDING)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var resume := add_entry("resume", &"resume", "Resume", close)
	add_entry("hub", &"home", "Back to the hub", _on_hub)
	add_entry("quit", &"quit", "Quit the game", func() -> void: quit_pressed.emit())
	close_hint = KeyHint.attach(resume, CLOSE_ACTION, BADGE_PX, false)
	for channel: StringName in [VolumeRow.MUSIC, VolumeRow.EFFECTS]:
		volume[channel] = VolumeRow.make(channel)
		column.add_child(volume[channel])
	_shade.hide()


## Adds one pictogram button to the menu (dev mode's camera uses this).
func add_entry(id: String, glyph: StringName, spoken: String, on_press: Callable) -> Button:
	var button := GlyphButton.make(glyph, spoken, BUTTON_PX)
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
	for channel: StringName in volume:
		(volume[channel] as VolumeRow).refresh()
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
