class_name BotReport
extends RefCounted
## What every bot owes its caller: a refusal to run against the player's real
## save (R11) and a verdict file the gate script reads, so the pass criterion
## does not hang on a log line or on the exit code of whatever wraps the engine.


## "" when the bot may write saves, else why it must not run: a bot overwrites
## saved choices, so it only runs against an explicit root of its own, never
## the player's (SaveStore.DEFAULT_ROOT) and never inside the project.
static func save_dir_problem(save_dir: String) -> String:
	if save_dir == "":
		return "refusing to run: pass --save-dir=<throwaway dir> (a bot writes saves)"
	if not save_dir.is_absolute_path() or save_dir.begins_with("res://"):
		return (
			"refusing to run: --save-dir must be an absolute or user:// path, got '%s'" % save_dir
		)
	if SaveStore.is_real_save(save_dir) or save_dir.simplify_path().rstrip("/") == "user:":
		return "refusing to run: --save-dir is the player's real save (%s)" % save_dir
	return ""


## Writes the verdict atomically ("PASS ..." or "FAIL ..."); a path of "" skips.
static func write_verdict(path: String, verdict: String) -> bool:
	if path == "":
		return true
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if FileAccess.file_exists(path):  # Windows cannot rename over an existing file
		DirAccess.remove_absolute(path)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(verdict + "\n")
	file.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## "" when the window is the size the gate asked for (`expected` "WxH"; "" = no
## check), else why not: a gate that silently ran at another size proves nothing.
static func window_problem(expected: String, actual: Vector2i) -> String:
	if expected == "":
		return ""
	var parts := expected.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return "cannot read --expect-window=%s" % expected
	var want := Vector2i(int(parts[0]), int(parts[1]))
	if want != actual:
		return "window is %s, the gate asked for %s" % [actual, want]
	return ""
