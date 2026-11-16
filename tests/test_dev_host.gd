extends GutTest
## This game's side of the shared dev tools: the host object the addon is
## handed (context fields, F9 reset, the pause menu's camera, the Markdown
## lines) and the moments the session log gets. Nothing here needs the addon.

const Context = preload("res://src/dev/siege_context.gd")
const Host = preload("res://src/dev/siege_host.gd")
const Telemetry = preload("res://src/dev/siege_telemetry.gd")

var main: Main
var host: RefCounted
var recorder := Recorder.new()


## Stands in for the addon's telemetry: keeps every entry in order.
class Recorder:
	extends RefCounted
	var rows: Array[Dictionary] = []

	func entry(event: String, fields: Dictionary) -> void:
		var row := fields.duplicate(true)
		row["event"] = event
		rows.append(row)

	func events() -> Array:
		return rows.map(func(row: Dictionary) -> String: return row["event"])


func before_each() -> void:
	SaveStore.clear()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	host = Host.new(main)


func after_each() -> void:
	get_tree().paused = false


func test_the_host_names_the_game_and_its_feedback_variable() -> void:
	assert_eq(host.game, "fifteen-dollar-siege")
	assert_eq(host.feedback_env, "SIEGE_FEEDBACK_DIR")
	assert_eq(host.colors["mark"], Palette.BAD)
	assert_eq(host.colors["panel"], Palette.PANEL)


func test_context_says_what_the_player_was_doing() -> void:
	main.mode = &"command"
	main.start_siege(Loadout.of([&"double_men", &"pep_talk"]))
	var context: Dictionary = host.context(host.debug_state())
	assert_eq(context["mode"], "command")
	assert_eq(context["screen"], "battle")
	assert_eq(context["loadout"], ["double_men", "pep_talk"])
	assert_eq(context["variant"]["cost"], 6)
	assert_eq(context["variant"]["men"], 200)
	assert_eq(context["settings"]["speed"], main.options.speed)
	assert_eq(context["player"]["outcome"], "RUNNING")
	assert_true(context["player"].has("commands_sent"))


func test_the_context_off_a_battle_has_a_neutral_pose() -> void:
	var pose: Dictionary = Context.player({"screen": "hub"})
	assert_eq(pose, {"screen": "hub", "clock_s": 0.0, "outcome": "NONE", "commands_sent": 0})


func test_the_select_tool_asks_the_screen() -> void:
	var found := 0
	for x in 48:
		for y in 27:
			if not host.pick_at(Vector2(x + 0.5, y + 0.5) * 40.0).is_empty():
				found += 1
	assert_gt(found, 0, "the hub has something to select")
	assert_eq(host.pick_at(Vector2(-5, -5)), {})


func test_f9_wipes_the_throwaway_save_only() -> void:
	assert_true(SaveStore.write_json("last_loadout.json", {"watch": ["stew"]}))
	assert_gt(host.reset_progress(), 0)
	assert_eq(SaveStore.read_json("last_loadout.json"), {})


func test_the_pause_menu_gets_the_camera_and_closes_for_the_frame() -> void:
	var pressed := []
	host.add_menu_entry("annotate", Texture2D.new(), "annotate", func() -> void: pressed.append(1))
	assert_true(main.pause_menu.buttons.has("annotate"))
	main.pause_menu.open()
	host.close_menu()
	assert_false(main.pause_menu.is_open())


func test_the_markdown_lines_keep_their_shape() -> void:
	var record := {
		"mode": "watch",
		"screen": "hub",
		"loadout": ["a", "b"],
		"build": {"id": "abc"},
		"session": "s1",
	}
	assert_eq(
		host.summary_line(record),
		"- Mode `watch`, screen `hub`, loadout `a,b`, build abc, session `s1`"
	)
	var entity := {"kind": "mode_button", "id": "watch", "state": "idle", "at": [4, 5]}
	assert_eq(host.entity_line(entity), "- Selected mode_button `watch` (idle) at [4, 5]")
	entity["position"] = [1.0, 2.0]
	assert_eq(host.entity_line(entity), "- Selected mode_button `watch` (idle) at [1.0, 2.0]")


func test_a_whole_siege_is_logged_moment_by_moment() -> void:
	var events := Telemetry.new()
	events.attach(recorder, main)
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
	for wanted: String in ["buy", "game_start", "command", "pause_open", "pause_close", "game_end"]:
		assert_has(recorder.events(), wanted)
	var start: Dictionary = recorder.rows[recorder.events().find("game_start")]
	assert_eq(start["game"], "command")
	assert_eq(start["loadout"], ["double_men", "moose"])
	assert_eq(start["cost"], 8)
	assert_eq(start["men"], 200)
	assert_eq(start["seed"], 5)
	assert_eq(recorder.rows[recorder.events().find("command")]["order"], "rally")
	# The rally flag stands far from the village until the time cap: a loss.
	assert_eq(recorder.rows[recorder.events().find("game_end")]["outcome"], "lose")
	assert_eq(recorder.rows[recorder.events().find("buy")]["buff"], "double_men")
