extends SceneTree
## Fails closed on a blank, unreadable or missing PNG (works on any OS):
##   godot --headless --path . --script tools/frame_check.gd -- a.png b.png
## Arguments starting with "--" are skipped.
## Exit 0 only if every file is a readable, non-blank image.

const FrameStatsScript = preload("res://src/autodrive/frame_stats.gd")


func _init() -> void:
	var files: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			files.append(arg)
	var bad := 0
	if files.is_empty():
		printerr("frame_check: no files given")
		bad = 1
	for path in files:
		var image := Image.load_from_file(path)
		if image == null or FrameStatsScript.is_blank(image):
			printerr("frame_check: BLANK or unreadable: ", path)
			bad += 1
		else:
			var stats: Dictionary = FrameStatsScript.luminance(image)
			print("frame_check: ok %s stddev=%.1f" % [path.get_file(), stats["stddev"]])
	quit(1 if bad > 0 else 0)
