class_name WebProbe
extends Node
## A read-only window for the browser smoke gate (scripts/test_web.sh). On the
## web, and only when the page's URL has `?probe`, it keeps `window.siegeProbe`
## up to date with a JSON string: the screen, the pause, the hub and battle
## music, the battle clock and where the buttons are on the canvas, in canvas
## pixels. It draws nothing, changes nothing and costs one small string a
## tenth of a second.

const EVERY_FRAMES := 6
const ASKED := "new URLSearchParams(window.location.search).has('probe')"

var _window: JavaScriptObject
var _main: Main


func _ready() -> void:
	_main = get_parent() as Main
	if _main == null or not OS.has_feature("web") or not bool(JavaScriptBridge.eval(ASKED)):
		set_process(false)
		return
	_window = JavaScriptBridge.get_interface("window")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % EVERY_FRAMES == 0:
		_window.siegeProbe = JSON.stringify(report())


## The whole probe as plain data.
func report() -> Dictionary:
	var out := {
		"screen": String(_main.screen_name),
		"paused": get_tree().paused,
		"menu_open": _main.pause_menu.is_open(),
		"frames": Engine.get_process_frames(),
		"targets": _targets(),
	}
	var director := AudioDirector.live()
	if director != null:
		var hub := director.music.hub
		out["music"] = {
			"scene": String(director.music.scene),
			"hub_playing": hub.playing,
			"hub_pos": hub.get_playback_position(),
			"battle_playing": director.music.battle.playing,
			"battle_pos": director.music.battle.get_playback_position(),
		}
	var battle := _main.screen as BattleScreen
	if battle != null:
		out["clock_s"] = battle.sim.clock_s()
	return out


## Where a finger goes for each button of the screen on show: name -> [x, y].
func _targets() -> Dictionary:
	var found := {"menu": _centre(_main.menu_button)}
	var screen := _main.screen
	if screen == null:
		return found
	var buttons: Variant = screen.get("buttons")
	if buttons is Dictionary:
		for key: Variant in buttons:
			found[str(key)] = _centre(buttons[key] as Control)
	for field in ["go_button", "back_button"]:
		var control := screen.get(field) as Control
		if control != null:
			found[field] = _centre(control)
	var cards: Variant = screen.get("cards")
	if cards is Dictionary:
		for key: Variant in cards:
			found["card_%s" % key] = _centre(cards[key] as Control)
	if _main.pause_menu.is_open():
		for key: Variant in _main.pause_menu.buttons:
			found["pause_%s" % key] = _centre(_main.pause_menu.buttons[key] as Control)
	return found


## The middle of `control` in canvas (window) pixels, after the stretch.
func _centre(control: Control) -> Array:
	var rect := control.get_global_rect()
	var at := get_viewport().get_screen_transform() * (rect.get_center())
	return [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]
