class_name BattleHud
extends Control
## The battle's controls, floating over the map: the meters strip at the top,
## pause, the four speeds and the auto camera at the bottom left, and in
## Command mode rally, charge and retreat at the bottom right. Every control
## is a HudButton: a pictogram, its key or pad button, a spoken label, no
## word. During a staged beat only the skip button shows.

signal pause_pressed
signal speed_picked(value: float)
signal auto_pressed
signal rally_pressed
signal order_pressed(kind: int)
signal skip_pressed

const EDGE := 28.0
const GAP := 14
## Canvas pixels the meters strip and the button rows take at top and bottom.
const TOP_CLEAR := HudMeters.TOP + HudMeters.TALL + 8.0
const BOTTOM_CLEAR := EDGE + HudButton.SIZE + 8.0

var meters := HudMeters.new()
var pause_button: HudButton
## One per SiegeActions.SPEEDS entry (x1, x2, x4, x8).
var speed_buttons: Array[HudButton] = []
var auto_button: HudButton
var skip_button: HudButton
## Command mode only (null in Watch).
var rally_button: HudButton
var charge_button: HudButton
var retreat_button: HudButton

var _left := HBoxContainer.new()
var _right := HBoxContainer.new()


## The part of a screen of `area` the HUD leaves free. The camera frames the
## action inside it; the map itself still fills the whole screen.
static func map_rect(area: Vector2) -> Rect2:
	var whole := area if area.x > 1.0 else Vector2(1920.0, 1080.0)
	return Rect2(0.0, TOP_CLEAR, whole.x, whole.y - TOP_CLEAR - BOTTOM_CLEAR)


func setup(with_orders: bool) -> void:
	SiegeActions.ensure()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(meters)
	_row(_left, Control.PRESET_BOTTOM_LEFT, Control.GROW_DIRECTION_END)
	_row(_right, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN)
	pause_button = _add(_left, HudGlyphs.texture(HudGlyphs.PAUSE), "Pause", SiegeActions.PAUSE)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	for i in SiegeActions.SPEEDS.size():
		var value := SiegeActions.SPEED_VALUES[i]
		var spoken := "Speed times %d" % int(value)
		var picture := HudGlyphs.texture(HudGlyphs.SPEEDS[i])
		var button := _add(_left, picture, spoken, SiegeActions.SPEEDS[i])
		button.pressed.connect(func() -> void: speed_picked.emit(value))
		speed_buttons.append(button)
	var auto_spoken := "Camera follows the action"
	auto_button = _add(
		_left, HudGlyphs.texture(HudGlyphs.AUTO), auto_spoken, SiegeActions.CAMERA_AUTO
	)
	auto_button.pressed.connect(func() -> void: auto_pressed.emit())
	if with_orders:
		_add_orders()
	skip_button = HudButton.create(HudGlyphs.texture(HudGlyphs.SKIP), "Skip", SiegeActions.SKIP)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	skip_button.offset_left = -HudButton.SIZE / 2.0
	skip_button.offset_right = HudButton.SIZE / 2.0
	skip_button.offset_top = -EDGE - HudButton.SIZE
	skip_button.offset_bottom = -EDGE
	skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	skip_button.hide()
	add_child(skip_button)


## Every control, by action name.
func buttons() -> Dictionary:
	var out := {}
	for child: Node in _left.get_children() + _right.get_children() + [skip_button]:
		out[(child as HudButton).action] = child
	return out


## Shows the state of the screen on the controls and the meters.
func show_state(shot: SiegeSnapshot, state: Dictionary, delta: float) -> void:
	meters.show_levels(shot, state.get("centre", 0.0), delta)
	var staged: bool = state.get("staged", false)
	_left.visible = not staged
	_right.visible = not staged
	skip_button.visible = staged
	var paused: bool = state.get("held", false)
	if pause_button.lit != paused:
		pause_button.lit = paused
		pause_button.icon = HudGlyphs.texture(HudGlyphs.PLAY if paused else HudGlyphs.PAUSE)
	for i in speed_buttons.size():
		var chosen := is_equal_approx(state.get("speed", 1.0), SiegeActions.SPEED_VALUES[i])
		if speed_buttons[i].lit != chosen:
			speed_buttons[i].lit = chosen
	if auto_button.lit != state.get("auto", true):
		auto_button.lit = state.get("auto", true)


## Shows the glyphs of the device in use (call when it changes).
func refresh_badges() -> void:
	for button: HudButton in buttons().values():
		button.refresh_badge()


func _add_orders() -> void:
	var flag := Glyphs.texture(&"rally")
	rally_button = _add(_right, flag, "Rally: click the map to plant the flag", SiegeActions.RALLY)
	rally_button.pressed.connect(func() -> void: rally_pressed.emit())
	var charge := Glyphs.texture(&"charge")
	charge_button = _add(_right, charge, "Charge the village", SiegeActions.CHARGE)
	charge_button.pressed.connect(func() -> void: order_pressed.emit(SiegeSim.Command.CHARGE))
	var back := Glyphs.texture(&"retreat")
	retreat_button = _add(_right, back, "Retreat to the start", SiegeActions.RETREAT)
	retreat_button.pressed.connect(func() -> void: order_pressed.emit(SiegeSim.Command.RETREAT))


func _row(row: HBoxContainer, corner: Control.LayoutPreset, grows: Control.GrowDirection) -> void:
	var inset := EDGE if grows == Control.GROW_DIRECTION_END else -EDGE
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(corner)
	row.grow_horizontal = grows
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = inset
	row.offset_right = inset
	row.offset_top = -EDGE
	row.offset_bottom = -EDGE
	add_child(row)


func _add(row: HBoxContainer, picture: Texture2D, spoken: String, action: StringName) -> HudButton:
	var button := HudButton.create(picture, spoken, action)
	row.add_child(button)
	return button
