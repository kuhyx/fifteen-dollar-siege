class_name MenuClicks
extends RefCounted
## Every button under Main clicks (`ui_button`), unless its press already
## played a cue of its own that frame (the director's `ui_frame`).

var _director: AudioDirector
var _main: Main


func _init(director: AudioDirector, main: Main) -> void:
	_director = director
	_main = main
	director.get_tree().node_added.connect(_hook)
	for button in main.find_children("*", "BaseButton", true, false):
		_hook(button)


func _hook(node: Node) -> void:
	var button := node as BaseButton
	if button == null or not _main.is_ancestor_of(button):
		return
	if not button.pressed.is_connected(_on_button):
		button.pressed.connect(_on_button)


func _on_button() -> void:
	_click.call_deferred()


func _click() -> void:
	if _director.ui_frame != Engine.get_process_frames():
		_director.ui(&"ui_button")
