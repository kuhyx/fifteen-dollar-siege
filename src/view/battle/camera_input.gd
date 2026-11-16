class_name CameraInput
extends RefCounted
## The pointer on the map: the wheel or a pinch zooms about the pointer, a
## drag pans (left button, middle button, right button or one finger), and a
## press released on the same spot is a TAP, which `feed` hands back to the
## screen (Command mode plants the rally flag there). So a drag never gives
## an order by accident, on a mouse or on a touch screen.

## A press that moves further than this is a drag, not a tap [design guess].
const DRAG_PX := 10.0
const PAN_BUTTONS: Array[MouseButton] = [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]

var camera: BattleCamera

var _press := Vector2.INF
var _dragged := false
var _panning := false
var _fingers: Dictionary = {}


## Takes one input event. Returns where a tap ended (canvas pixels), or
## Vector2.INF when the event was not the end of a tap.
func feed(event: InputEvent) -> Vector2:
	var button := event as InputEventMouseButton
	if button != null:
		return _button(button)
	var motion := event as InputEventMouseMotion
	if motion != null:
		_motion(motion)
	var pinch := event as InputEventMagnifyGesture
	if pinch != null:
		camera.zoom_at(pinch.position, pinch.factor)
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_fingers[touch.index] = touch.position
		else:
			_fingers.erase(touch.index)
	var drag := event as InputEventScreenDrag
	if drag != null:
		_two_fingers(drag)
	return Vector2.INF


func _button(button: InputEventMouseButton) -> Vector2:
	if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom_at(button.position, BattleCamera.WHEEL_STEP)
	elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom_at(button.position, 1.0 / BattleCamera.WHEEL_STEP)
	elif PAN_BUTTONS.has(button.button_index):
		_panning = button.pressed
	elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		_press = button.position
		_dragged = false
	elif button.button_index == MOUSE_BUTTON_LEFT:
		var tapped := _press != Vector2.INF and not _dragged
		_press = Vector2.INF
		if tapped:
			return button.position
	return Vector2.INF


func _motion(motion: InputEventMouseMotion) -> void:
	if _fingers.size() >= 2:
		return
	if _press != Vector2.INF and motion.position.distance_to(_press) > DRAG_PX:
		_dragged = true
	if _dragged or _panning:
		camera.pan(motion.relative)


## Two fingers: the gap between them zooms, their middle pans.
func _two_fingers(drag: InputEventScreenDrag) -> void:
	if _fingers.size() != 2 or not _fingers.has(drag.index):
		_fingers[drag.index] = drag.position
		return
	_dragged = true
	var other: Vector2 = _fingers[_other(drag.index)]
	var before: Vector2 = _fingers[drag.index]
	_fingers[drag.index] = drag.position
	var gap_before := maxf(before.distance_to(other), 1.0)
	var middle := (drag.position + other) / 2.0
	camera.zoom_at(middle, drag.position.distance_to(other) / gap_before)
	camera.pan(middle - (before + other) / 2.0)


func _other(index: int) -> int:
	for finger: int in _fingers:
		if finger != index:
			return finger
	return index
