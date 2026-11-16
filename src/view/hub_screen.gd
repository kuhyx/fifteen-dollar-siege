class_name HubScreen
extends Control
## The hub: one pictogram button per mode (Watch = eye, Command = flag,
## Lab = bar chart). No words. SCAFFOLD view: the view agent replaces it and
## keeps `mode_picked`, `buttons` and `pick_at`.

signal mode_picked(mode: StringName)

const SPOKEN := {
	&"watch": "Watch: buy buffs, then the siege plays itself",
	&"command": "Command: buy buffs, then lead the army with a rally flag",
	&"lab": "Lab: run one loadout many times and see how often it wins",
}

## Mode id -> its button.
var buttons: Dictionary = {}


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 80)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	for mode in LaunchOptions.MODES:
		var button := GlyphButton.make(mode, SPOKEN[mode], 320.0)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func() -> void: mode_picked.emit(mode))
		row.add_child(button)
		buttons[mode] = button


func _ready() -> void:
	(buttons[LaunchOptions.MODES[0]] as Button).grab_focus()


## What is under a canvas point (dev feedback's select tool), {} for nothing.
func pick_at(point: Vector2) -> Dictionary:
	for mode: StringName in buttons:
		if (buttons[mode] as Control).get_global_rect().has_point(point):
			return {"kind": "mode_button", "id": String(mode), "state": "idle"}
	return {}
