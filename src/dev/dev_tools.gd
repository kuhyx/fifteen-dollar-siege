extends Node
## Main loads this by path only with --dev. It mounts the shared dev feedback
## mode (kuhyx/utils godot_dev_tools, at res://addons/dev_tools: F12 annotate,
## F9 reset, the session log) with this game's host. Exported builds hold
## neither this file nor the addon. Without the mount (install.sh not run) the
## game says so once on stderr and plays on.
## No class_name (dev files reach each other with preload).

const Host = preload("res://src/dev/siege_host.gd")
const ADDON := "res://addons/dev_tools/dev_tools.gd"

## The addon's node once mounted: its hint, annotator and log.
var tools: Node = null
## Where the addon lives (a test points it at a path that is not there).
var addon_path := ADDON


func _ready() -> void:
	if not ResourceLoader.exists(addon_path):
		printerr("fifteen-dollar-siege: dev mode is unavailable (%s is not mounted)" % addon_path)
		return
	tools = (load(addon_path) as GDScript).new()
	tools.name = "DevToolsAddon"
	tools.call("setup", Host.new(get_parent() as Main))
	add_child(tools)
