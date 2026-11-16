extends RefCounted
## What the game shows when F12 froze it, as the fields of one feedback record:
## mode, screen, loadout, seed, what the player was doing, build, window sizes.
## The session id and tag come from the dev log (the telemetry's session).
## No class_name (dev files reach each other with preload).

const GAME := "fifteen-dollar-siege"

static var _build: Dictionary = {}


static func capture(main: Main, dev_log: RefCounted, was_paused: bool) -> Dictionary:
	var tree := main.get_tree()
	var window := DisplayServer.window_get_size()
	var canvas := tree.root.get_visible_rect().size
	var state := main.debug_state()
	var out := {
		"session": dev_log.session,
		"build": build_info(),
		"godot": Engine.get_version_info()["string"],
		"game": GAME,
		"mode": state["mode"],
		"screen": state["screen"],
		"loadout": state["loadout"],
		"variant":
		{
			"mode": state["mode"],
			"loadout": state["loadout"],
			"cost": state["cost"],
			"men": state["men"],
			"seed": state["seed"],
		},
		"settings": {"speed": state["speed"]},
		"player": player(state),
		"paused": was_paused,
		"scene": tree.current_scene.scene_file_path if tree.current_scene != null else "",
		"window": [window.x, window.y],
		"canvas": [canvas.x, canvas.y],
	}
	if dev_log.tag != "":
		out["tag"] = dev_log.tag
	return out


## What the player was doing: this game's stand-in for a player pose.
static func player(state: Dictionary) -> Dictionary:
	var siege: Dictionary = state.get("siege", {})
	return {
		"screen": state["screen"],
		"clock_s": siege.get("clock_s", 0.0),
		"outcome": siege.get("outcome", "NONE"),
		"commands_sent": siege.get("commands_sent", 0),
	}


## {id: the git commit of a source run ("export" in a build), version, debug}.
static func build_info() -> Dictionary:
	if _build.is_empty():
		var output: Array = []
		var id := "export"
		var root := ProjectSettings.globalize_path("res://")
		if not OS.has_feature("template") and root != "":
			if OS.execute("git", ["-C", root, "rev-parse", "--short", "HEAD"], output) == 0:
				id = str(output[0]).strip_edges()
		_build = {
			"id": id,
			"version": str(ProjectSettings.get_setting("application/config/version", "")),
			"debug": OS.is_debug_build(),
		}
	return _build
