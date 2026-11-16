extends GutTest
## Dev mode through the real entry point: Main loads src/dev/dev_tools.gd by
## path, which mounts the shared addon with this game's host. F12 opens the
## annotator and a save writes a bundle with this game's context into this
## run's throwaway folder, never the real feedback folder (R11). Also the rules
## of the split: dev glue has no class_name, game code never names it, and a
## missing mount only costs the dev mode.

const RunTmp := preload("res://tests/run_tmp.gd")
const ADDON := "res://addons/dev_tools"

var main: Main
var _dir := ""


func before_each() -> void:
	_dir = RunTmp.path("dev_mode")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)


func after_each() -> void:
	get_tree().paused = false
	RunTmp.remove_tree(_dir)


## Main's own path for an optional part (what --dev triggers).
func _load_dev_mode() -> Node:
	main._load_extra(Main.DEV_TOOLS, "DevTools", true)
	return main.get_node("DevTools")


## Waits for process frames: a paused tree stops GUT's own wait_until.
func _until(done: Callable) -> void:
	for _i in 300:
		if done.call():
			return
		await get_tree().process_frame
	fail_test("never happened")


func test_main_mounts_the_shared_dev_tools_with_this_games_host() -> void:
	var glue := _load_dev_mode()
	assert_not_null(glue.tools, "the addon is mounted at %s (run install.sh)" % ADDON)
	assert_true(main.pause_menu.buttons.has("annotate"), "the pause menu gets a camera")
	assert_eq(glue.tools.dev_log.session, glue.tools.telemetry.session_id)


func test_f12_annotates_the_frozen_hub_and_saves_a_bundle_with_the_game_context() -> void:
	var tools: Node = _load_dev_mode().tools
	tools.dev_log.dir = _dir
	var press := InputEventKey.new()
	press.keycode = KEY_F12
	press.pressed = true
	tools._input(press)
	await _until(func() -> bool: return tools.annotator != null)
	assert_true(get_tree().paused, "the frame is frozen")
	assert_true(tools.annotator.add_shape("rect", Vector2(10, 10), Vector2(80, 60)))
	tools.annotator.note.text = "from the integration test"
	tools.annotator.save()
	await _until(func() -> bool: return tools.annotator == null)
	assert_false(get_tree().paused)
	var bundle := _dir.path_join(DirAccess.get_directories_at(_dir)[0])
	var report: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(bundle.path_join("report.json"))
	)
	assert_eq(report["game"], "fifteen-dollar-siege")
	assert_eq(report["screen"], "hub")
	assert_eq(report["note"], "from the integration test")
	for field: String in ["mode", "loadout", "variant", "settings", "player", "build", "session"]:
		assert_true(report.has(field), field)
	var md := FileAccess.get_file_as_string(
		_dir.path_join("feedback-%s.md" % Time.get_date_string_from_system())
	)
	assert_string_contains(md, "- Mode `")
	assert_string_contains(md, bundle.path_join("report.json"))


func test_a_missing_mount_costs_only_the_dev_mode() -> void:
	var glue: Node = (load(Main.DEV_TOOLS) as GDScript).new()
	glue.addon_path = "res://addons/not_mounted/dev_tools.gd"
	main.add_child(glue)
	assert_null(glue.tools, "no addon: no dev tools")
	assert_not_null(main.screen, "the game plays on")
	assert_eq(main.screen_name, &"hub")


func test_no_dev_file_declares_a_class_name() -> void:
	for file_name in DirAccess.get_files_at("res://src/dev"):
		if file_name.ends_with(".gd"):
			var source := FileAccess.get_file_as_string("res://src/dev".path_join(file_name))
			assert_false(source.contains("\nclass_name "), file_name)
			assert_false(source.begins_with("class_name "), file_name)


func test_the_game_never_names_a_dev_file_or_the_addon_except_by_path() -> void:
	for dir: String in ["res://src/core", "res://src/app", "res://src/ui", "res://src/view"]:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.ends_with(".gd"):
				var source := FileAccess.get_file_as_string(dir.path_join(file_name))
				var where := dir.path_join(file_name)
				assert_false(source.contains('preload("res://src/dev'), where)
				assert_false(source.contains('preload("res://addons/dev_tools'), where)
