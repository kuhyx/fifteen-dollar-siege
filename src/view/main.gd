class_name Main
extends Control
## The main scene: hub -> loadout -> battle (Watch, Command) or lab -> result
## -> hub, with the pause menu (Esc / pad B / the menu button) over all of it.
## It owns no rules: the sim (src/core) decides, the screens draw. Dev tools
## (--dev) and the bot (--autodrive=) are loaded by path, so a build without
## src/dev still runs. SCAFFOLD view: the view agent replaces the screens and
## keeps this flow, its signals, `pick_at` and `debug_state`.

signal screen_changed(screen: StringName)
signal siege_started(mode: StringName, loadout: Loadout, sim_seed: int)
signal siege_ended(outcome: int, clock_s: float)
signal lab_finished(result: Dictionary)
signal loadout_changed(id: StringName, bought: bool, cost: int)
signal command_given(kind: int, pos: Vector2)
signal quitting(reason: String)

const DEV_TOOLS := "res://src/dev/dev_tools.gd"
const AUTODRIVE := "res://src/autodrive/autodrive.gd"
const LAST_LOADOUT := "last_loadout.json"
const OVERLAY_LAYER := 40

var options := LaunchOptions.new()
var mode: StringName = &""
var loadout := Loadout.new()
var sim_seed := 0
## The screen on show and its name: hub, loadout, battle, lab or result.
var screen: Control
var screen_name: StringName = &""
var pause_menu: PauseMenu
var menu_button: GlyphButton
var last_outcome := SiegeSim.Outcome.RUNNING

var _holder: Control
## Buffs the last won siege put on the hub's shelf for the first time.
var _fresh: Array[StringName] = []


func _ready() -> void:
	options = LaunchOptions.parse()
	if options.save_dir != "":
		SaveStore.root = options.save_dir
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Palette.PANEL.darkened(0.4)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_holder = Control.new()
	_holder.name = "Screens"
	_holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_build_overlay()
	add_child(AudioDirector.new())
	if options.problem != "":
		printerr("fifteen-dollar-siege: %s" % options.problem)
		get_tree().quit(2)
		return
	_load_extra(DEV_TOOLS, "DevTools", options.dev)
	_load_extra(AUTODRIVE, "Autodrive", options.autodrive != &"")
	if options.mode != &"":
		mode = options.mode
		start_siege(options.loadout)
	else:
		open_hub()


func open_hub() -> void:
	mode = &""
	var hub := HubScreen.new()
	hub.mode_picked.connect(open_loadout)
	_show(hub, &"hub")


func open_loadout(p_mode: StringName) -> void:
	mode = p_mode
	var shop := LoadoutScreen.new()
	shop.preset(_last_loadout(p_mode))
	shop.start_pressed.connect(start_siege)
	shop.back_pressed.connect(open_hub)
	shop.changed.connect(
		func(id: StringName, bought: bool, cost: int) -> void:
			loadout_changed.emit(id, bought, cost)
	)
	_show(shop, &"loadout")


## Starts the current mode's siege with `p_loadout` (Lab: the whole batch).
func start_siege(p_loadout: Loadout) -> void:
	loadout = p_loadout.duplicate()
	_remember_loadout()
	sim_seed = options.sim_seed if options.sim_seed >= 0 else int(randi())
	siege_started.emit(mode, loadout, sim_seed)
	if mode == &"lab":
		var lab := LabScreen.new()
		lab.setup(loadout, options.lab_runs, sim_seed)
		lab.finished.connect(func(result: Dictionary) -> void: lab_finished.emit(result))
		lab.home_pressed.connect(open_hub)
		lab.again_pressed.connect(func() -> void: start_siege(loadout))
		lab.edit_pressed.connect(func() -> void: open_loadout(mode))
		_show(lab, &"lab")
		return
	open_battle(SiegeSim.create(loadout, sim_seed))


## Shows the battle screen for `sim` (the showcase bot brings its own).
func open_battle(sim: SiegeSim) -> void:
	var battle := BattleScreen.new()
	battle.loadout = loadout
	battle.setup(sim, mode, options.speed)
	battle.decided.connect(_on_decided.bind(battle))
	battle.finished.connect(open_result)
	battle.command_given.connect(
		func(kind: int, pos: Vector2) -> void: command_given.emit(kind, pos)
	)
	_show(battle, &"battle")


func open_result(outcome: int) -> void:
	var result := ResultScreen.new()
	result.setup(outcome, loadout, _fresh)
	result.home_pressed.connect(open_hub)
	result.retry_pressed.connect(func() -> void: start_siege(loadout))
	result.edit_pressed.connect(func() -> void: open_loadout(mode))
	_show(result, &"result")


func quit_game(reason: String) -> void:
	quitting.emit(reason)
	get_tree().quit()


## What is under a canvas point on the current screen ({} for nothing): the
## dev feedback's select tool asks this.
func pick_at(point: Vector2) -> Dictionary:
	if screen != null and screen.has_method("pick_at"):
		return screen.call("pick_at", point)
	return {}


## The whole visible state as plain data (dev feedback's snapshot.json).
func debug_state() -> Dictionary:
	var out := {
		"screen": String(screen_name),
		"mode": String(mode),
		"loadout": loadout.ids.map(func(id: StringName) -> String: return String(id)),
		"cost": loadout.cost(),
		"men": SiegeSim.army_size(loadout),
		"seed": sim_seed,
		"speed": options.speed,
		"paused": get_tree().paused,
	}
	var battle := screen as BattleScreen
	if battle != null:
		out["siege"] = _siege_state(battle)
	var lab := screen as LabScreen
	if lab != null:
		out["lab"] = lab.result.duplicate()
	return out


func _siege_state(battle: BattleScreen) -> Dictionary:
	var shot := battle.shot
	var entities: Array[Dictionary] = []
	for i in shot.entity_count():
		entities.append(battle.pick_at(battle.map_to_canvas(shot.ent_pos[i])))
	return {
		"clock_s": snappedf(shot.clock_s, 0.001),
		"outcome": SiegeSim.Outcome.keys()[shot.outcome],
		"army_morale": shot.army_morale,
		"village_morale": shot.village_morale,
		"alarm": shot.alarm,
		"state_hash": battle.sim.state_hash(),
		"commands_sent": battle.commands_sent,
		"entities": entities,
	}


func _on_decided(outcome: int, battle: BattleScreen) -> void:
	last_outcome = outcome as SiegeSim.Outcome
	_fresh.clear()
	if last_outcome == SiegeSim.Outcome.WIN:
		_fresh = WinShelf.record(loadout)
	siege_ended.emit(outcome, battle.sim.clock_s())


func _show(next: Control, next_name: StringName) -> void:
	if screen != null:
		_holder.remove_child(screen)
		screen.queue_free()
	screen = next
	screen_name = next_name
	_holder.add_child(next)
	screen_changed.emit(next_name)


func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = OVERLAY_LAYER
	add_child(overlay)
	# Touch has no Esc key: the menu is always one tap away.
	menu_button = GlyphButton.make(&"menu", "Menu", 96.0)
	menu_button.position = Vector2(20, 20)
	menu_button.focus_mode = Control.FOCUS_NONE
	overlay.add_child(menu_button)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	menu_button.pressed.connect(pause_menu.toggle)
	pause_menu.hub_pressed.connect(open_hub)
	pause_menu.quit_pressed.connect(quit_game.bind("menu"))


## Adds an optional part (dev tools, the bot) when asked for and present.
func _load_extra(path: String, node_name: String, wanted: bool) -> void:
	if not wanted:
		return
	if not ResourceLoader.exists(path):
		printerr("fifteen-dollar-siege: %s is not in this build" % path)
		return
	var extra: Node = (load(path) as GDScript).new()
	extra.name = node_name
	add_child(extra)


func _last_loadout(p_mode: StringName) -> Loadout:
	var saved: Variant = SaveStore.read_json(LAST_LOADOUT).get(String(p_mode), [])
	return Loadout.of(saved if saved is Array else [])


func _remember_loadout() -> void:
	var all := SaveStore.read_json(LAST_LOADOUT)
	all[String(mode)] = loadout.ids.map(func(id: StringName) -> String: return String(id))
	SaveStore.write_json(LAST_LOADOUT, all)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quitting.emit("window_close")
