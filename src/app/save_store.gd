class_name SaveStore
extends RefCounted
## Small JSON files under one save root. Play uses DEFAULT_ROOT (the player's
## real save); bots pass --save-dir; a GUT run starts on TEST_ROOT and can never
## read, write or wipe the real save: `blocked` refuses it whatever a hook or a
## test sets (tests/pre_run.gd is skippable, this guard is not).

const DEFAULT_ROOT := "user://save"
## The throwaway root of every GUT run (a sibling of the real save, not inside it).
const TEST_ROOT := "user://test_save"

## Decided at the first use of this class, before any file is read.
static var root: String = default_root()


## True when `args` (OS.get_cmdline_args()) start GUT: its command line script
## or runner scene lives under addons/gut/.
static func is_test_run(args: Array) -> bool:
	for arg: Variant in args:
		if "addons/gut/" in str(arg).replace("\\", "/"):
			return true
	return false


## This process runs GUT: its arguments say so, or its main loop is a GUT script.
static func running_tests() -> bool:
	if is_test_run(OS.get_cmdline_args()):
		return true
	var loop := Engine.get_main_loop()
	var script: Script = loop.get_script() if loop != null else null
	return script != null and is_test_run([script.resource_path])


## The save root for a process started with `args`: throwaway under GUT.
static func default_root(args: Array = OS.get_cmdline_args()) -> String:
	return TEST_ROOT if is_test_run(args) else DEFAULT_ROOT


## `path` is the player's real save folder, or inside it.
static func is_real_save(path: String) -> bool:
	var real := ProjectSettings.globalize_path(DEFAULT_ROOT).simplify_path().rstrip("/")
	var plain := ProjectSettings.globalize_path(path).simplify_path().rstrip("/")
	return plain == real or plain.begins_with(real + "/")


## A GUT run aimed at `path` in the real save: every read, write and delete refuses.
static func blocked(path: String) -> bool:
	if not is_real_save(path) or not running_tests():
		return false
	printerr("save guard: a test run must not touch the real save (%s)" % path)
	return true


## Writes `data` as <root>/<file_name> through a temp file; false on failure.
static func write_json(file_name: String, data: Dictionary) -> bool:
	if blocked(root):
		return false
	DirAccess.make_dir_recursive_absolute(root)
	var path := root.path_join(file_name)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	var wrote := file.get_error() == OK
	file.close()
	if not wrote:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):  # Windows cannot rename over an existing file
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## The file's dictionary, {} when missing, unreadable or refused.
static func read_json(file_name: String) -> Dictionary:
	if blocked(root):
		return {}
	var path := root.path_join(file_name)
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()  # parse() reports errors without engine noise
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data


## Deletes every file under the root (recursively); returns how many went.
static func clear(dir: String = root) -> int:
	var removed := 0
	if blocked(dir) or not DirAccess.dir_exists_absolute(dir):
		return removed
	for file_name in DirAccess.get_files_at(dir):
		if DirAccess.remove_absolute(dir.path_join(file_name)) == OK:
			removed += 1
	for sub in DirAccess.get_directories_at(dir):
		removed += clear(dir.path_join(sub))
		DirAccess.remove_absolute(dir.path_join(sub))
	return removed
