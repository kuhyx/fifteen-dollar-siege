extends RefCounted
## The session's structured log: one JSON line per moment in
## <feedback dir>/feedback.jsonl (session start and end, screens, every buy,
## every siege start with its full loadout and seed, every order, the outcome,
## pause open and close, engine errors). The session recorder
## (tools/recording/) turns these into timestamps on the video.
## No class_name (dev files reach each other with preload).

const ErrorLogger = preload("res://src/dev/dev_logger.gd")
const SESSION_ARG := "--session-id="
const OUTCOMES: Array[String] = ["running", "win", "lose"]
const COMMANDS: Array[String] = ["rally", "charge", "retreat"]

var dev_log: RefCounted
var logger: Logger
var session_id := ""

var _start_ms := 0
var _paused_ms := 0
var _done := false


## Starts the run: writes session_start + recording_sync and begins listening.
func attach(p_log: RefCounted, main: Main) -> void:
	dev_log = p_log
	var args := OS.get_cmdline_user_args()
	session_id = dev_log.arg_value(args, SESSION_ARG)
	if session_id == "":
		session_id = "%d-%04x" % [Time.get_unix_time_from_system(), randi() & 0xffff]
	dev_log.session = session_id
	_start_ms = Time.get_ticks_msec()
	logger = ErrorLogger.new()
	OS.add_logger(logger)
	main.screen_changed.connect(_on_screen)
	main.siege_started.connect(_on_siege_started)
	main.siege_ended.connect(_on_siege_ended)
	main.lab_finished.connect(func(result: Dictionary) -> void: entry("lab_result", result))
	main.loadout_changed.connect(_on_buy)
	main.command_given.connect(_on_command)
	main.pause_menu.toggled.connect(_on_pause)
	main.quitting.connect(func(reason: String) -> void: entry("quit", {"reason": reason}))
	entry("session_start", {"args": Array(args), "godot": Engine.get_version_info()["string"]})
	# One exact (unix time, ms) pair: tools/recording/ places every entry on the
	# external recorder's timeline with it.
	entry("recording_sync", {"unix_us": int(Time.get_unix_time_from_system() * 1_000_000.0)})


## Once per frame: engine errors caught since the last frame become entries.
func tick() -> void:
	if logger == null:
		return
	for error: Dictionary in logger.drain():
		entry("engine_error", error)


## Ends the session once (window close, quit, tree exit).
func shutdown(reason: String) -> void:
	if _done or dev_log == null:
		return
	_done = true
	tick()
	var elapsed := (Time.get_ticks_msec() - _start_ms) / 1000.0
	entry("session_end", {"reason": reason, "elapsed_s": snappedf(elapsed, 0.001)})
	OS.remove_logger(logger)
	logger = null


func entry(event: String, fields: Dictionary) -> void:
	var row := fields.duplicate(true)
	row["event"] = event
	dev_log.entry(row)


func _on_screen(screen: StringName) -> void:
	entry("hub_open" if screen == &"hub" else "screen", {"screen": String(screen)})


func _on_siege_started(mode: StringName, loadout: Loadout, sim_seed: int) -> void:
	entry(
		"game_start",
		{
			"game": String(mode),
			"loadout": loadout.ids.map(func(id: StringName) -> String: return String(id)),
			"cost": loadout.cost(),
			"men": SiegeSim.army_size(loadout),
			"seed": sim_seed,
		}
	)


func _on_siege_ended(outcome: int, clock_s: float) -> void:
	entry("game_end", {"outcome": OUTCOMES[outcome], "elapsed_s": snappedf(clock_s, 0.001)})


func _on_buy(id: StringName, bought: bool, cost: int) -> void:
	entry("buy", {"buff": String(id), "bought": bought, "cost": cost})


func _on_command(kind: int, pos: Vector2) -> void:
	entry("command", {"order": COMMANDS[kind], "pos": [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1)]})


func _on_pause(open: bool) -> void:
	if open:
		_paused_ms = Time.get_ticks_msec()
		entry("pause_open", {})
	else:
		var paused := (Time.get_ticks_msec() - _paused_ms) / 1000.0
		entry("pause_close", {"paused_s": snappedf(paused, 0.001)})
