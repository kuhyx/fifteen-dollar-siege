extends RefCounted
## Per-run throwaway folder of a GUT run. user:// is shared by every checkout and every
## concurrent run of this project, so a fixed "user://test_tmp_x" collided between agents'
## runs. Each run gets its own `user://test_run_<pid>_<rand>/` (made by tests/pre_run.gd,
## removed by tests/post_run.gd); tests ask for subfolders with `RunTmp.path("name")`.
## Load it with `const RunTmp := preload("res://tests/run_tmp.gd")` (no class_name).

const PREFIX := "test_run_"
const META := "fifteen_dollar_siege_test_run_dir"
## A run folder untouched this long belongs to a killed run (timeout, OOM) and is swept.
const STALE_SECONDS := 3600


## This run's folder, created on first use.
static func run_dir() -> String:
	if not Engine.has_meta(META):
		var dir := "user://%s%d_%d" % [PREFIX, OS.get_process_id(), randi()]
		DirAccess.make_dir_recursive_absolute(dir)
		Engine.set_meta(META, dir)
	return Engine.get_meta(META)


## A subfolder of this run's folder (made, so a test may write straight into it).
static func path(name: String) -> String:
	var dir := run_dir().path_join(name)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


## Removes this run's folder and forgets it.
static func cleanup() -> void:
	if Engine.has_meta(META):
		remove_tree(Engine.get_meta(META))
		Engine.remove_meta(META)


## Deletes run folders left by killed runs (never this run's, never a fresh one).
static func sweep_stale() -> void:
	var now := Time.get_unix_time_from_system()
	for name in DirAccess.get_directories_at("user://"):
		var dir := "user://" + name
		if not name.begins_with(PREFIX) or dir == run_dir():
			continue
		if now - FileAccess.get_modified_time(dir) > STALE_SECONDS:
			remove_tree(dir)


## Deletes `dir` with everything in it.
static func remove_tree(dir: String) -> void:
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	for sub in DirAccess.get_directories_at(dir):
		remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)
