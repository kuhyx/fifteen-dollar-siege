extends RefCounted
## Writes one feedback as a bundle FOLDER:
##   screenshot.png  the frozen frame as it was
##   annotated.png   the same frame with the red marks burned in
##   report.json     the record (marks in annotated.png pixels, note, game,
##                   variant, player pose, settings, build, session id, files)
##   game.log        the tail of the run's dev.log
##   snapshot.json   the play state (every item and slot, judged)
## `dir` is injected, so tests use a temp dir and never the real feedback
## folder (R11). No class_name (dev files reach each other with preload).


## A file name base that two presses in one second still keep apart.
static func stamp() -> String:
	var ms := int(fmod(Time.get_unix_time_from_system(), 1.0) * 1000.0)
	return "%s-%03d" % [Time.get_datetime_string_from_system().replace(":", "-"), ms]


## A bundle folder under `root` that does not exist yet (a clash in the same
## millisecond gets a -2, -3... suffix).
static func bundle_dir(root: String) -> String:
	var base := root.path_join(stamp())
	var dir := base
	var n := 1
	while DirAccess.dir_exists_absolute(dir):
		n += 1
		dir = "%s-%d" % [base, n]
	return dir


## Writes the bundle into `dir` (either image may be null). Returns the record
## with its `files` (absolute paths of what was written) filled in.
static func save(
	dir: String,
	record: Dictionary,
	annotated: Image,
	raw: Image,
	game_log: String,
	snapshot: Dictionary
) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir)
	var files := {}
	if annotated != null and annotated.save_png(dir.path_join("annotated.png")) == OK:
		files["annotated"] = dir.path_join("annotated.png")
		record["image"] = [annotated.get_width(), annotated.get_height()]
	if raw != null and raw.save_png(dir.path_join("screenshot.png")) == OK:
		files["screenshot"] = dir.path_join("screenshot.png")
	if _write(dir.path_join("game.log"), game_log):
		files["game_log"] = dir.path_join("game.log")
	if _write(dir.path_join("snapshot.json"), JSON.stringify(snapshot, "\t")):
		files["snapshot"] = dir.path_join("snapshot.json")
	files["report"] = dir.path_join("report.json")
	record["files"] = files
	if not _write(files["report"], JSON.stringify(record, "\t")):
		push_warning("feedback: cannot write %s" % files["report"])
		files.erase("report")
	return record


## The feedback.jsonl line of one saved bundle (the recorder stamps it on the
## video as an "annotation" moment).
static func log_entry(dir: String, record: Dictionary, marks: int) -> Dictionary:
	var files: Dictionary = record.get("files", {})
	return {
		"event": "annotation",
		"bundle": dir,
		"image": files.get("annotated", ""),
		"report": files.get("report", ""),
		"marks": marks,
	}


static func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
