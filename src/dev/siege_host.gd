extends RefCounted
## What the shared dev tools (kuhyx/utils godot_dev_tools, mounted at
## res://addons/dev_tools) ask of this game: its name, the feedback folder's
## environment variable, its colours, the state and the pick under a point, the
## context of a bundle, the F9 reset, the pause menu's camera and the moments
## of the session log. Every member is documented in the addon's dev_host.gd.
## No class_name (dev files reach each other with preload).

const Context = preload("res://src/dev/siege_context.gd")
const Telemetry = preload("res://src/dev/siege_telemetry.gd")

var game := "fifteen-dollar-siege"
## scripts/test.sh sets it: GUT never logs into the real feedback folder.
var feedback_env := "SIEGE_FEEDBACK_DIR"
var colors := {
	"mark": Palette.BAD,
	"armed": Palette.BAD,
	"panel": Palette.PANEL,
	"panel_pressed": Palette.PANEL_PRESSED,
	"ink": Palette.INK,
}

var _main: Main
var _events: RefCounted


func _init(main: Main) -> void:
	_main = main


func debug_state() -> Dictionary:
	return _main.debug_state()


func pick_at(at: Vector2) -> Dictionary:
	return _main.pick_at(at)


func context(state: Dictionary) -> Dictionary:
	return Context.fields(state)


## F9: the remembered loadouts go; returns the files removed.
func reset_progress() -> int:
	return SaveStore.clear()


func add_menu_entry(id: String, icon: Texture2D, spoken: String, on_press: Callable) -> void:
	_main.pause_menu.add_texture_entry(id, icon, spoken, on_press)


func close_menu() -> void:
	_main.pause_menu.close()


func attach_telemetry(telemetry: RefCounted) -> void:
	_events = Telemetry.new()
	_events.attach(telemetry, _main)


## The Markdown entry's line about where the game was (feedback_inbox reads the
## file paths of the entry, not this line).
func summary_line(record: Dictionary) -> String:
	var build: Dictionary = record.get("build", {})
	var loadout := ",".join(PackedStringArray(record.get("loadout", [])))
	return (
		"- Mode `%s`, screen `%s`, loadout `%s`, build %s, session `%s`"
		% [
			record.get("mode", "-"),
			record.get("screen", "-"),
			loadout,
			build.get("id", "?"),
			record.get("session", "")
		]
	)


func entity_line(entity: Dictionary) -> String:
	return (
		"- Selected %s `%s` (%s) at %s"
		% [
			entity.get("kind", "?"),
			entity.get("id", "?"),
			entity.get("state", "-"),
			entity.get("position", entity.get("at", [])),
		]
	)
