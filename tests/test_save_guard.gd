extends GutTest
## The save guard (R11, lessons L10 and L11): a GUT run never reads or writes
## the player's real save. Two layers, both tested here:
##   1. tests/pre_run.gd moves the save root into this run's throwaway folder.
##      test_pre_run_hook_moved_the_save_root is RED when that line is removed.
##   2. SaveStore itself refuses the real save under GUT, hook or no hook.
##      scripts/test_save_guard.sh runs this file with the hook's redirect OFF
##      and a planted real save (SIEGE_SAVE_GUARD_PROBE=1).

const RunTmp := preload("res://tests/run_tmp.gd")
const PROBE_ENV := "SIEGE_SAVE_GUARD_PROBE"
const GUT_ARGS: Array[String] = ["-s", "res://addons/gut/gut_cmdln.gd"]


func _probing() -> bool:
	return OS.get_environment(PROBE_ENV) == "1"


func _real_dir() -> String:
	return OS.get_user_data_dir().path_join("save")


## The files of `dir`, [] when it does not exist (a fresh throwaway user://).
func _files(dir: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	return DirAccess.get_files_at(dir)


func test_detects_gut() -> void:
	assert_true(SaveStore.running_tests(), "this process runs GUT")
	assert_false(SaveStore.is_test_run(["--mode=watch", "--dev"]), "play is not a test run")
	assert_true(SaveStore.is_test_run(GUT_ARGS))
	assert_true(SaveStore.is_test_run(["res:\\addons\\gut\\gui\\GutRunner.tscn"]), "editor panel")


func test_default_root_is_throwaway_under_gut() -> void:
	assert_eq(SaveStore.default_root(["--dev"]), SaveStore.DEFAULT_ROOT, "play: the real save")
	assert_eq(SaveStore.default_root(GUT_ARGS), SaveStore.TEST_ROOT)
	assert_false(SaveStore.is_real_save(SaveStore.TEST_ROOT), "a sibling, not inside it")


func test_pre_run_hook_moved_the_save_root() -> void:
	if _probing():
		assert_eq(SaveStore.root, SaveStore.TEST_ROOT, "no hook: the game's own throwaway root")
		return
	assert_true(Engine.has_meta(RunTmp.META), "tests/pre_run.gd ran")
	var run_dir := RunTmp.run_dir()
	assert_true(
		SaveStore.root.begins_with(run_dir + "/"),
		"the save root %s is inside this run's folder %s" % [SaveStore.root, run_dir]
	)
	assert_false(SaveStore.is_real_save(SaveStore.root))


func test_the_real_save_is_recognised_however_it_is_spelled() -> void:
	for real: String in ["user://save", "user://save/", "user://x/../save", _real_dir()]:
		assert_true(SaveStore.is_real_save(real), real)
		assert_true(SaveStore.is_real_save(real.path_join("deeper")), real + "/deeper")
	for other: String in ["user://saved", "user://test_save", "user://dev"]:
		assert_false(SaveStore.is_real_save(other), other)


func test_a_test_run_aimed_at_the_real_save_is_refused_both_ways() -> void:
	var real := _real_dir()
	var before := _files(real)
	if _probing():
		assert_true(before.has("last_loadout.json"), "the planted save is there")
	var saved := SaveStore.root
	for real_root: String in ["user://save", real]:
		SaveStore.root = real_root
		assert_false(SaveStore.write_json("probe.json", {"x": 1}), real_root)
		assert_eq(SaveStore.read_json("last_loadout.json"), {}, real_root)
		assert_eq(SaveStore.clear(), 0, real_root)
	SaveStore.root = saved
	assert_eq(_files(real), before, "no file appeared or vanished")


func test_the_game_flow_cannot_write_the_real_save_either() -> void:
	var real := _real_dir()
	var before := _files(real)
	var saved := SaveStore.root
	SaveStore.root = "user://save"
	var main: Main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.mode = &"watch"
	main.start_siege(Loadout.of([&"stew"]))
	SaveStore.root = saved
	assert_eq(_files(real), before, "starting a siege saved nothing there")


func test_normal_test_traffic_lands_in_the_throwaway_root() -> void:
	assert_true(SaveStore.write_json("guard_probe.json", {"ok": true}))
	assert_eq(SaveStore.read_json("guard_probe.json"), {"ok": true})
	assert_false(SaveStore.is_real_save(SaveStore.root))
	assert_eq(SaveStore.read_json("missing.json"), {})
