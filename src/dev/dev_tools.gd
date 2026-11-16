extends Node
## Dev feedback mode (R10), loaded by Main only with --dev (run.sh passes it);
## exported builds do not contain src/dev at all.
##   F12  freeze the frame and annotate it (rect/arrow/circle/pen/text/select
##        + note) -> a bundle folder + a Markdown entry + a jsonl line. The
##        camera glyph (top right) and the camera in the pause menu do the same.
##   F9   reset saved progress (the remembered loadouts)
##   always: every key / button press, screen, buy, order and outcome is logged
##   --dev-shot=/abs/out.png  scripted annotate-and-save into the folder
##        /abs/out/ (bundle + overlay.png), then quit (Xvfb proof)
## No class_name (dev files reach each other with preload).

const Annotator = preload("res://src/dev/annotator.gd")
const DevLog = preload("res://src/dev/dev_log.gd")
const FeedbackContext = preload("res://src/dev/feedback_context.gd")
const Glyph = preload("res://src/dev/dev_glyphs.gd")
const Hint = preload("res://src/dev/dev_hint.gd")
const Telemetry = preload("res://src/dev/telemetry.gd")
const SHOT_PREFIX := "--dev-shot="
const LAYER := 120
const PROBE_GRID := Vector2i(48, 27)

var dev_log := DevLog.new()
var telemetry := Telemetry.new()
var annotator: Control = null
var hint: Control
var main: Main

var _layer: CanvasLayer
var _shot_path := ""


func _ready() -> void:
	main = get_parent() as Main
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	hint = Hint.new()
	hint.pressed.connect(func() -> void: annotate())
	_layer.add_child(hint)
	main.pause_menu.add_texture_entry(
		"annotate", Glyph.texture("camera"), "Annotate this frame", _annotate_from_menu
	)
	dev_log.write("dev tools on; logs in %s" % dev_log.dir)
	telemetry.attach(dev_log, main)
	_shot_path = dev_log.arg_value(OS.get_cmdline_user_args(), SHOT_PREFIX)
	if _shot_path != "":
		_scripted_shot.call_deferred()


func _process(_delta: float) -> void:
	telemetry.tick()


func _input(event: InputEvent) -> void:
	_log_input(event)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F12:
		get_viewport().set_input_as_handled()
		annotate()
	elif key.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		var removed := SaveStore.clear()
		dev_log.write("reset progress: %d files removed" % removed)
		telemetry.entry("reset_progress", {"files": removed})


## The window's close button / Alt-F4 / SIGTERM reach every node in the tree.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		telemetry.shutdown("window_close")


func _exit_tree() -> void:
	telemetry.shutdown("exit")


## Freezes the game and opens the annotator over the frame as it was; the
## previous pause state comes back on close. `path` = scripted marks and save.
func annotate(path := "") -> void:
	if annotator != null:
		return
	var was_paused := get_tree().paused
	var context := FeedbackContext.capture(main, dev_log, was_paused)
	var state := main.debug_state()
	hint.hide()
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	annotator = Annotator.new()
	annotator.save_path = path
	_layer.add_child(annotator)
	annotator.open(frame, dev_log, context, state)
	annotator.picker = func(at: Vector2) -> Dictionary: return main.pick_at(at)
	if path != "":
		await _scripted_marks(path)
		annotator.save()
	await annotator.closed
	annotator.remove_from_group(&"annotator")  # Esc is the game's again now
	annotator.queue_free()
	annotator = null
	hint.show()
	get_tree().paused = was_paused


## The pause menu's camera: the menu goes away first, so the frame is the game.
func _annotate_from_menu() -> void:
	main.pause_menu.close()
	await get_tree().process_frame
	annotate()


func _scripted_shot() -> void:
	await get_tree().create_timer(1.5).timeout
	await annotate(_shot_path.get_basename())
	var png := _shot_path.get_basename().path_join("annotated.png")
	get_tree().quit(0 if FileAccess.file_exists(png) else 1)


## The marks a mouse would draw, and a frame of the overlay itself
## (<bundle>/overlay.png, toolbar visible) for a human to read, with a label
## and a select mark on the first thing the current screen lets you pick.
func _scripted_marks(dir: String) -> void:
	annotator.add_shape("rect", Vector2(260, 220), Vector2(760, 640))
	annotator.add_shape("arrow", Vector2(1100, 300), Vector2(820, 420))
	annotator.add_shape("circle", Vector2(1150, 600), Vector2(1500, 860))
	var squiggle := [Vector2(300, 800), Vector2(380, 760), Vector2(460, 820)]
	annotator.add_stroke(PackedVector2Array(squiggle))
	annotator.add_text(Vector2(300, 860), "wrong place?")
	var target := first_pickable()
	if target != Vector2.INF:
		annotator.select_at(target)
	await RenderingServer.frame_post_draw
	var overlay := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(dir)
	overlay.save_png(dir.path_join("overlay.png"))


## The first canvas point of a coarse grid where the screen has something to
## select (Vector2.INF when it has nothing).
func first_pickable() -> Vector2:
	var view := get_viewport().get_visible_rect().size
	for y in PROBE_GRID.y:
		for x in PROBE_GRID.x:
			var at := Vector2((x + 0.5) / PROBE_GRID.x, (y + 0.5) / PROBE_GRID.y) * view
			if not main.pick_at(at).is_empty():
				return at
	return Vector2.INF


func _log_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		dev_log.write("input %s" % event.as_text())
