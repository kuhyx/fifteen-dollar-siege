class_name StateDump
extends Node
## For the hand-off checks (scripts/handoff/*.sh --check): with
## `--check-state=PATH` it waits WAIT_S real seconds on whatever screen came
## up, writes `Main.debug_state()` to PATH as JSON (and the frame to PATH.png
## when there is one), then quits 0 (1 when the file could not be written).
## Without the option it does nothing at all.

const WAIT_S := 1.5

var _main: Main
var _age := 0.0


## Writes the state (and the frame) of `main`; false when PATH is not writable.
static func write(main: Main, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(DebugState.of(main)))
	file.close()
	if DisplayServer.get_name() != "headless":  # no renderer, no frame
		main.get_viewport().get_texture().get_image().save_png(path + ".png")
	return true


func _ready() -> void:
	_main = get_parent() as Main
	set_process(_main != null and _main.options.check_state != "")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_age += delta
	if _age >= WAIT_S:
		set_process(false)
		get_tree().quit(0 if write(_main, _main.options.check_state) else 1)
