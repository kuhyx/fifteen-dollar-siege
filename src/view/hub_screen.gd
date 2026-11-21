class_name HubScreen
extends Control
## The hub: one big picture button per mode (Watch = an eye, Command = a rally
## flag and a pointing hand, Lab = a flask in a win-rate ring), each with its
## key. Under them, what the player has built up: the best Lab win rate so far
## with its loadout, and a shelf of 25 slots that fills with every buff a won
## siege was won with, and under Watch and Command the best stars won in that
## mode (`StarBook`). No words.
## Kept for the bot, the tests and the dev tools: `mode_picked`, `buttons`,
## `pick_at`.

signal mode_picked(mode: StringName)

const SPOKEN := {
	&"watch": "Watch: buy buffs, then the siege plays itself",
	&"command": "Command: buy buffs, then lead the army with a rally flag",
	&"lab": "Lab: run one loadout many times and see how often it wins",
}
const BUTTON := Vector2(360, 360)
const BUTTON_GAP := 90.0
const BUTTONS_TOP := 100.0
## A button under the pointer (or in focus) swells to this, springily.
const HOVER_SCALE := 1.07
const SWELL_S := 0.22

## Mode id -> its button.
var buttons: Dictionary = {}
var shelf := TrophyShelf.new()
var best_lab := BestLab.new()
## Mode id -> its best stars (Watch and Command only), under the mode's button.
var stars: Dictionary = {}


func _init() -> void:
	var frame := ScreenFrame.into(self)
	var modes := LaunchOptions.MODES
	var row := modes.size() * (BUTTON.x + BUTTON_GAP) - BUTTON_GAP
	for i in modes.size():
		var mode := modes[i]
		var button := PictoButton.make(UiPictograms.of(mode), SPOKEN[mode], BUTTON)
		var x := (ScreenFrame.SIZE.x - row) / 2.0 + i * (BUTTON.x + BUTTON_GAP)
		frame.place(button, Rect2(Vector2(x, BUTTONS_TOP), BUTTON))
		button.pressed.connect(func() -> void: mode_picked.emit(mode))
		KeyHint.attach(button, MenuKeys.PICKS[i], 64.0)
		buttons[mode] = button
		button.pivot_offset = BUTTON / 2.0
		button.mouse_entered.connect(_swell.bind(button, HOVER_SCALE))
		button.focus_entered.connect(_swell.bind(button, HOVER_SCALE))
		button.mouse_exited.connect(_swell.bind(button, 1.0))
		button.focus_exited.connect(_swell.bind(button, 1.0))
	for kept in StarBook.MODES:
		var star_row := StarRow.new()
		var from := (buttons[kept] as Control).position
		var at := Vector2(from.x + (BUTTON.x - StarRow.wide()) / 2.0, from.y + BUTTON.y + 22.0)
		frame.place(star_row, Rect2(at, Vector2(StarRow.wide(), StarRow.HEIGHT)))
		stars[kept] = star_row
	var lab := buttons[&"lab"] as Control
	var under := Rect2(
		lab.position.x - 140.0, BUTTONS_TOP + BUTTON.y + 20.0, BUTTON.x + 280.0, 84.0
	)
	frame.place(best_lab, under)
	var left := (ScreenFrame.SIZE.x - TrophyShelf.wide()) / 2.0
	frame.place(shelf, Rect2(left, 650.0, TrophyShelf.wide(), TrophyShelf.high()))


func _swell(button: Control, to: float) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * to, SWELL_S).set_trans(Tween.TRANS_BACK)


func _ready() -> void:
	shelf.won = WinShelf.won()
	best_lab.show_line(LabBook.best())
	for kept: StringName in stars:
		(stars[kept] as StarRow).earned = StarBook.best(kept)
	(buttons[LaunchOptions.MODES[0]] as Button).grab_focus()
	const CREDIT := "res://addons/kuhy_credit/kuhy_credit.tscn"
	if ResourceLoader.exists(CREDIT):
		var credit: Control = (load(CREDIT) as PackedScene).instantiate()
		credit.name = "KuhyCredit"
		credit.light = false
		credit.align_start = true
		add_child(credit)
		_place_credit()
		get_viewport().size_changed.connect(_place_credit)


func _place_credit() -> void:
	var credit: Control = get_node_or_null("KuhyCredit") as Control
	if credit == null:
		return
	var view := get_viewport_rect().size
	credit.position = Vector2(16.0, view.y - float(credit.logo_size) - 16.0)


## What is under a canvas point (dev feedback's select tool), {} for nothing.
func pick_at(point: Vector2) -> Dictionary:
	for mode: StringName in buttons:
		if (buttons[mode] as Control).get_global_rect().has_point(point):
			return {"kind": "mode_button", "id": String(mode), "state": "idle"}
	var defs := BuffCatalog.all()
	for i in defs.size():
		if (shelf.get_global_transform() * shelf.slot(i)).has_point(point):
			var state := "won with" if shelf.won.has(defs[i].id) else "not yet"
			return {"kind": "shelf_slot", "id": String(defs[i].id), "state": state}
	return {}
