class_name KeyHint
extends Control
## The key (or pad button) that presses a control, drawn on the control's
## corner as a shape: the glyph is read from the InputMap for the device in
## use, and the same action is the control's shortcut, so what is shown is
## what works. Touch shows nothing: the control itself is the target.

const PX := 46.0
## The share of the hint that hangs outside the control's corner.
const OVERHANG := 0.2

var action: StringName

var _button: Button
var _shown := -1


## Draws `action`'s glyph on the corner of `button`, and (with `shortcut`)
## binds the action to the button too. The battle HUD passes false: the
## screen already handles those actions itself.
static func attach(button: Button, p_action: StringName, px := PX, shortcut := true) -> KeyHint:
	MenuKeys.ensure()
	var hint := KeyHint.new()
	hint.action = p_action
	hint._button = button
	hint.name = "KeyHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -px * (1.0 - OVERHANG)
	hint.offset_top = -px * (1.0 - OVERHANG)
	hint.offset_right = px * OVERHANG
	hint.offset_bottom = px * OVERHANG
	if shortcut:
		var press := InputEventAction.new()
		press.action = p_action
		press.pressed = true
		button.shortcut = Shortcut.new()
		button.shortcut.events = [press]
		button.shortcut_in_tooltip = false
	button.add_child(hint)
	button.focus_entered.connect(hint.queue_redraw)
	button.focus_exited.connect(hint.queue_redraw)
	return hint


## The event this hint draws now (null: nothing, e.g. on touch).
func glyph_event() -> InputEvent:
	return InputDevice.event_for(action, -1, _button != null and _button.has_focus())


## True when the control's binding has no picture: the placeholder a test
## must never find on a screen (lesson L6).
func unknown() -> bool:
	var event := glyph_event()
	return event != null and not KeyGlyph.can_draw(event)


func _input(event: InputEvent) -> void:
	if InputDevice.note(event) or _shown != InputDevice.device:
		queue_redraw()


func _draw() -> void:
	_shown = InputDevice.device
	var event := glyph_event()
	if event != null:
		KeyGlyph.draw(self, event, Rect2(Vector2.ZERO, size))
