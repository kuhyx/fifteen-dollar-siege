extends GutTest
## Dev feedback mode around the annotator: where the logs go, the session's
## structured log (the moments the recorder stamps on the video), and the dev
## tools node on the real main scene. Everything writes into this run's
## throwaway folder (R11).

const DevLog = preload("res://src/dev/dev_log.gd")
const DevTools = preload("res://src/dev/dev_tools.gd")
const Telemetry = preload("res://src/dev/telemetry.gd")
const RunTmp := preload("res://tests/run_tmp.gd")

var main: Main
var log: RefCounted
var _dir := RunTmp.path("dev_tools")


func before_each() -> void:
	SaveStore.clear(_dir)
	SaveStore.clear()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	log = DevLog.new()
	log.dir = _dir


func after_each() -> void:
	get_tree().paused = false


func _rows() -> Array:
	var rows := []
	for line in FileAccess.get_file_as_string(_dir.path_join("feedback.jsonl")).split("\n", false):
		rows.append(JSON.parse_string(line))
	return rows


func _events() -> Array:
	return _rows().map(func(row: Dictionary) -> String: return row.get("event", ""))


func _attached() -> RefCounted:
	var telemetry := Telemetry.new()
	telemetry.attach(log, main)
	return telemetry


func test_the_log_folder_follows_the_arguments() -> void:
	assert_eq(DevLog.default_dir(["--feedback-dir=/x/fb", "--save-dir=/y"]), "/x/fb")
	assert_eq(DevLog.default_dir(["--save-dir=/y/save"]), "/y/save/dev", "a bot logs in its save")
	assert_eq(DevLog.arg_value(["--dev-tag=v03"], "--dev-tag="), "v03")
	assert_eq(DevLog.arg_value([], "--dev-tag="), "")


func test_log_lines_and_entries_land_in_the_injected_folder() -> void:
	log.session = "s-1"
	log.write("first line")
	log.write("second line")
	assert_eq(log.tail(1), "%s\n" % log.tail(5).strip_edges().split("\n")[1])
	assert_string_contains(log.tail(5), "first line")
	log.entry({"event": "probe"})
	log.entry({"event": "probe"})
	var rows := _rows()
	assert_eq(rows.size(), 2)
	assert_eq(rows[1]["seq"], 2.0)
	assert_eq(rows[1]["session"], "s-1")
	for field: String in ["time", "ms", "frame"]:
		assert_true(rows[1].has(field), field)


func test_a_session_starts_with_a_start_and_an_exact_clock_pair() -> void:
	var telemetry := _attached()
	assert_eq(_events(), ["session_start", "recording_sync"])
	var sync: Dictionary = _rows()[1]
	assert_almost_eq(sync["unix_us"] / 1000000.0, Time.get_unix_time_from_system(), 5.0)
	assert_true(sync.has("ms"))
	assert_ne(telemetry.session_id, "")
	assert_eq(sync["session"], telemetry.session_id)
	telemetry.shutdown("test")


func test_a_whole_siege_is_logged_moment_by_moment() -> void:
	var telemetry := _attached()
	main.options.sim_seed = 5
	main.open_loadout(&"command")
	(main.screen as LoadoutScreen).toggle(&"double_men")
	(main.screen as LoadoutScreen).toggle(&"moose")
	(main.screen as LoadoutScreen).go_button.pressed.emit()
	var battle := main.screen as BattleScreen
	battle.order(SiegeSim.Command.RALLY, Vector2(120, 80))
	main.pause_menu.open()
	main.pause_menu.close()
	battle.speed = 400.0
	battle.payoff_s = 0.05
	battle.beats.skip_all()
	await wait_until(func() -> bool: return main.screen_name == &"result", 20.0)
	telemetry.shutdown("test")
	telemetry.shutdown("again")
	var events := _events()
	for wanted: String in ["buy", "game_start", "command", "pause_open", "pause_close", "game_end"]:
		assert_has(events, wanted)
	assert_eq(events.count("session_end"), 1, "a session ends once")
	var rows := _rows()
	var start: Dictionary = rows[events.find("game_start")]
	assert_eq(start["game"], "command")
	assert_eq(start["loadout"], ["double_men", "moose"])
	assert_eq(start["cost"], 8.0)
	assert_eq(start["men"], 200.0)
	assert_eq(start["seed"], 5.0)
	assert_eq(rows[events.find("command")]["order"], "rally")
	# The rally flag stands far from the village until the time cap: a loss.
	assert_eq(rows[events.find("game_end")]["outcome"], "lose")
	assert_eq(rows[events.find("buy")]["buff"], "double_men")


func test_engine_errors_become_entries() -> void:
	var telemetry := _attached()
	push_error("boom from the test")
	telemetry.tick()
	telemetry.shutdown("test")
	assert_push_error("boom from the test")
	var errors := _rows().filter(
		func(row: Dictionary) -> bool: return row["event"] == "engine_error"
	)
	assert_eq(errors.size(), 1)
	assert_string_contains(str(errors[0]), "boom from the test")


func test_the_dev_tools_join_the_main_scene() -> void:
	var tools: Node = DevTools.new()
	tools.dev_log.dir = _dir
	main.add_child(tools)
	assert_true(main.pause_menu.buttons.has("annotate"), "the pause menu gets a camera")
	assert_not_null(tools.hint)
	assert_has(_events(), "session_start")
	var target: Vector2 = tools.first_pickable()
	assert_ne(target, Vector2.INF, "the hub has something to select")
	assert_eq(main.pick_at(target)["kind"], "mode_button")
	assert_string_contains(log.tail(50), "dev tools on")


func test_f9_wipes_the_throwaway_save_only() -> void:
	var tools: Node = DevTools.new()
	tools.dev_log.dir = _dir
	main.add_child(tools)
	assert_true(SaveStore.write_json("last_loadout.json", {"watch": ["stew"]}))
	var press := InputEventKey.new()
	press.keycode = KEY_F9
	press.pressed = true
	tools._input(press)
	assert_eq(SaveStore.read_json("last_loadout.json"), {})
	assert_has(_events(), "reset_progress")


func test_no_dev_file_declares_a_class_name() -> void:
	for file_name in DirAccess.get_files_at("res://src/dev"):
		if file_name.ends_with(".gd"):
			var source := FileAccess.get_file_as_string("res://src/dev".path_join(file_name))
			assert_false(source.contains("\nclass_name "), file_name)
			assert_false(source.begins_with("class_name "), file_name)


func test_the_game_never_names_a_dev_file_except_by_path() -> void:
	for dir: String in ["res://src/core", "res://src/app", "res://src/ui", "res://src/view"]:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.ends_with(".gd"):
				var source := FileAccess.get_file_as_string(dir.path_join(file_name))
				assert_false(source.contains('preload("res://src/dev'), dir.path_join(file_name))
