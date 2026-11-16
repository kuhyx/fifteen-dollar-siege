extends RefCounted
## Aggressive dev logging: every line goes to stdout (prefix DEV) and is
## appended to <dir>/dev.log. Feedback entries go to <dir>/feedback.jsonl.
## No class_name: dev files reach each other with preload.

var dir: String = default_dir(OS.get_cmdline_user_args())
## Joins the entries of one run: random id, set by the telemetry (`--session-id=` wins).
var session: String = ""
## Which build/playtest this run is (`--dev-tag=v01`), stamped on every entry.
var tag: String = arg_value(OS.get_cmdline_user_args(), "--dev-tag=")

var _seq := 0
var _start_ms := Time.get_ticks_msec()


## The value of the first `<prefix>value` argument, "" when absent.
static func arg_value(args: Array, prefix: String) -> String:
	for arg: String in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""


## Where the logs go, first match wins: `--feedback-dir=` (the recorder passes
## it); an unattended run's own save dir (`--save-dir=`); the environment
## variable SIEGE_FEEDBACK_DIR (scripts/test.sh: GUT never logs into a real
## folder); kuhy's feedback folder (~/data/fifteen-dollar-siege_binaries/feedback)
## on an explicit --dev (run.sh) when that folder's parent exists; else the user
## folder.
static func default_dir(args: Array) -> String:
	var forced := arg_value(args, "--feedback-dir=")
	if forced != "":
		return forced
	for arg: String in args:
		if arg.begins_with("--save-dir="):
			return arg.trim_prefix("--save-dir=").path_join("dev")
	forced = OS.get_environment("SIEGE_FEEDBACK_DIR")
	if forced != "":
		return forced
	var home := OS.get_environment("HOME")
	var binaries := home.path_join("data/fifteen-dollar-siege_binaries")
	if "--dev" in args and home != "" and DirAccess.dir_exists_absolute(binaries):
		return binaries.path_join("feedback")
	return "user://dev"


func write(message: String) -> void:
	var line := "%s %s" % [Time.get_datetime_string_from_system(), message]
	print("DEV ", line)
	_append("dev.log", line)


## The last `lines` lines of dev.log (the run's own log), "" when there is none.
func tail(lines: int) -> String:
	var path := dir.path_join("dev.log")
	if not FileAccess.file_exists(path):
		return ""
	var all := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	return "\n".join(all.slice(maxi(0, all.size() - lines))) + "\n"


## One feedback entry as a JSON line (screenshot path, scene, game, time). Every
## entry also gets the run's session id, a sequence number, milliseconds since
## the log opened, the frame and the build tag, so a log can be ordered and joined.
func entry(fields: Dictionary) -> void:
	_seq += 1
	fields["time"] = Time.get_datetime_string_from_system()
	fields["session"] = session
	fields["seq"] = _seq
	fields["ms"] = Time.get_ticks_msec() - _start_ms
	fields["frame"] = Engine.get_process_frames()
	if tag != "":
		fields["tag"] = tag
	_append("feedback.jsonl", JSON.stringify(fields))


func _append(file_name: String, line: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(file_name)
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	var file := FileAccess.open(path, mode)
	if file == null:
		push_warning("dev log: cannot open %s" % path)
		return
	file.seek_end()
	file.store_line(line)
	file.close()
