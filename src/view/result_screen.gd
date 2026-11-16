class_name ResultScreen
extends Control
## The end of one siege. First the payoff, with nothing over it: your flag
## climbs over the village and the men cheer, or the leader goes up in flames
## (ResultScene). The buffs you bought line up under it, and the ones that are
## new on the hub's shelf get a spark. Then (after PAYOFF_S, or at once on any
## press) the ways on appear: the same loadout again, change the loadout, the
## hub, each with its key. No words.
## Kept for the bot, the tests and the dev tools: `outcome`, `home_button`,
## `home_pressed` and `pick_at`.

signal home_pressed
signal retry_pressed
signal edit_pressed

## Seconds the payoff plays before the controls come up. [design guess]
const PAYOFF_S := 1.4
const STAGE := Rect2(440, 24, 1040, 696)
const ICON_PX := 84.0
const STRIP_Y := 744.0
## The bought buffs drop in one after another from this moment on.
const STRIP_FROM_S := 0.5
const STRIP_STEP_S := 0.07

var outcome := SiegeSim.Outcome.RUNNING
var loadout := Loadout.new()
## Buffs this win put on the shelf for the first time.
var fresh: Array[StringName] = []
var home_button: PictoButton
var retry_button: PictoButton
var edit_button: PictoButton
var controls: EndControls
## False while the payoff plays alone.
var controls_shown := false
var payoff_s := PAYOFF_S

var _age := 0.0
var _frame: ScreenFrame
var _stage := Control.new()


func setup(p_outcome: int, p_loadout: Loadout = null, p_fresh: Array = []) -> void:
	outcome = p_outcome as SiegeSim.Outcome
	loadout = p_loadout.duplicate() if p_loadout != null else Loadout.new()
	fresh.assign(p_fresh)
	_frame = ScreenFrame.into(self)
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.place(_stage, STAGE)
	_stage.draw.connect(_draw_scene)
	_frame.draw.connect(_draw_strip)
	controls = EndControls.new()
	var corner := Vector2((ScreenFrame.SIZE.x - EndControls.wide()) / 2.0, 900.0)
	_frame.place(controls, Rect2(corner, Vector2(EndControls.wide(), EndControls.BUTTON.y)))
	controls.again_pressed.connect(func() -> void: retry_pressed.emit())
	controls.edit_pressed.connect(func() -> void: edit_pressed.emit())
	controls.hub_pressed.connect(func() -> void: home_pressed.emit())
	retry_button = controls.again
	edit_button = controls.edit
	home_button = controls.hub
	controls.hide()


func won() -> bool:
	return outcome == SiegeSim.Outcome.WIN


func _process(delta: float) -> void:
	_age += delta
	_stage.queue_redraw()
	if _frame != null:
		_frame.queue_redraw()
	if _age >= payoff_s:
		_show_controls()


## Any press during the payoff brings the controls up at once. A pointer
## press is used up by that: it must not land on a button it could not see.
func _input(event: InputEvent) -> void:
	MenuKeys.note(event)
	if controls_shown or not event.is_pressed() or event.is_echo():
		return
	var pointer := event is InputEventMouseButton or event is InputEventScreenTouch
	if pointer or event is InputEventKey or event is InputEventJoypadButton:
		_show_controls()
	if pointer:
		get_viewport().set_input_as_handled()


## What is under a canvas point (dev feedback's select tool).
func pick_at(_point: Vector2) -> Dictionary:
	var state := "controls" if controls_shown else "payoff"
	return {"kind": "result", "id": "win" if won() else "combust", "state": state}


func _show_controls() -> void:
	if controls_shown or controls == null:
		return
	controls_shown = true
	controls.show()
	controls.again.grab_focus()


func _draw_scene() -> void:
	var box := Rect2(Vector2.ZERO, _stage.size)
	_stage.draw_rect(box, VignetteStage.SKY)
	ResultScene.paint(VignettePen.fitted(_stage, box), won(), _age)
	_stage.draw_rect(box, Color(Palette.GOOD if won() else Palette.BAD, 0.07))


## The buffs bought, dropping in one by one; the new ones on the shelf spark.
func _draw_strip() -> void:
	var ids := loadout.ids
	var left := (ScreenFrame.SIZE.x - LoadoutStrip.width(ids.size(), ICON_PX)) / 2.0
	if ids.is_empty():
		LoadoutStrip.draw(_frame, ids, Vector2(left, STRIP_Y), ICON_PX)
	for i in ids.size():
		var grown := smoothstep(0.0, 0.16, _age - STRIP_FROM_S - i * STRIP_STEP_S)
		if grown <= 0.0:
			continue
		var centre := Vector2(left + i * ICON_PX * 1.12 + ICON_PX / 2.0, STRIP_Y + ICON_PX / 2.0)
		var px := ICON_PX * grown
		var box := Rect2(centre - Vector2.ONE * px / 2.0, Vector2.ONE * px)
		BuffPictograms.of(ids[i]).draw(_frame, box, 0.0 if won() else 0.6, Palette.PANEL)
		if fresh.has(ids[i]):
			var twinkle := (34.0 + sin(_age * 6.0 + i) * 5.0) * grown
			var spark := Rect2(box.position - Vector2(10, 10), Vector2.ONE * twinkle)
			UiPictograms.of(&"spark").draw(_frame, spark)
