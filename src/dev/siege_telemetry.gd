extends RefCounted
## This game's moments in the dev session log (feedback.jsonl): screens, every
## buy, every siege start with its full loadout and seed, every order, the
## outcome, pause open and close, lab results, quitting. The shared addon
## writes the rest (session start and end, engine errors). The session
## recorder (tools/recording/) turns these into timestamps on the video.
## No class_name (dev files reach each other with preload).

const OUTCOMES: Array[String] = ["running", "win", "lose"]
const COMMANDS: Array[String] = ["rally", "charge", "retreat"]

var _log: RefCounted
var _paused_ms := 0


## `telemetry` is the addon's (entry(event, fields)); `main` the game's flow.
func attach(telemetry: RefCounted, main: Main) -> void:
	_log = telemetry
	main.screen_changed.connect(_on_screen)
	main.siege_started.connect(_on_siege_started)
	main.siege_ended.connect(_on_siege_ended)
	main.lab_finished.connect(func(result: Dictionary) -> void: _log.entry("lab_result", result))
	main.loadout_changed.connect(_on_buy)
	main.command_given.connect(_on_command)
	main.pause_menu.toggled.connect(_on_pause)
	main.quitting.connect(func(reason: String) -> void: _log.entry("quit", {"reason": reason}))


func _on_screen(screen: StringName) -> void:
	_log.entry("hub_open" if screen == &"hub" else "screen", {"screen": String(screen)})


func _on_siege_started(mode: StringName, loadout: Loadout, sim_seed: int) -> void:
	_log.entry(
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
	_log.entry("game_end", {"outcome": OUTCOMES[outcome], "elapsed_s": snappedf(clock_s, 0.001)})


func _on_buy(id: StringName, bought: bool, cost: int) -> void:
	_log.entry("buy", {"buff": String(id), "bought": bought, "cost": cost})


func _on_command(kind: int, pos: Vector2) -> void:
	var at := [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1)]
	_log.entry("command", {"order": COMMANDS[kind], "pos": at})


func _on_pause(open: bool) -> void:
	if open:
		_paused_ms = Time.get_ticks_msec()
		_log.entry("pause_open", {})
	else:
		var paused := (Time.get_ticks_msec() - _paused_ms) / 1000.0
		_log.entry("pause_close", {"paused_s": snappedf(paused, 0.001)})
