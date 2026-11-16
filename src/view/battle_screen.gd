class_name BattleScreen
extends Control
## The siege: the map from above, every individual drawn (CrowdLayer), a
## camera that frames the action, and the payoff (a flag on the church, or
## the army in flames) played BEFORE `finished` opens the result.
## Contract kept for Main, the bot and the dev tools: the three signals,
## `sim`, `mode`, `speed`, `shot`, `commands_sent`, `payoff_active`,
## `payoff_s`, `charge_button`, `retreat_button`, `setup`, `order`,
## `map_to_canvas` / `canvas_to_map` and `pick_at`.

signal decided(outcome: int)
signal finished(outcome: int)
signal command_given(kind: int, pos: Vector2)

## Real seconds of payoff before the result opens [design guess].
const PAYOFF_S := 3.2
const PICK_PX := 40.0
const STATE_NAMES: Array[String] = ["idle", "move", "fight", "flee", "down", "hidden"]

var sim: SiegeSim
var mode: StringName = &"watch"
var speed := 1.0
var shot := SiegeSnapshot.new()
var commands_sent := 0
## True between the decision and `finished`.
var payoff_active := false
## Real seconds the payoff plays before `finished`.
var payoff_s := PAYOFF_S
var charge_button: GlyphButton
var retreat_button: GlyphButton
## What the army bought: set before `setup`, it dresses the men.
var loadout := Loadout.new()
var camera := BattleCamera.new()
var tween := SnapshotTween.new()
var plan: MapPlan
var world := Node2D.new()
var map_layer := MapLayer.new()
var crowd := CrowdLayer.new()
var meter := FrameMeter.new()
## Milliseconds `setup` took: the whole cost of entering the screen.
var setup_ms := 0.0

var _clock := 0.0
var _payoff_left := 0.0


func setup(p_sim: SiegeSim, p_mode: StringName, p_speed: float) -> void:
	var started := Time.get_ticks_usec()
	sim = p_sim
	mode = p_mode
	speed = p_speed
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan = MapPlan.of(sim.map())
	camera.setup(sim.map().bounds, _view())
	add_child(world)
	world.add_child(map_layer)
	world.add_child(crowd)
	map_layer.setup(plan)
	crowd.setup(sim.map().bounds, FigureLook.of(loadout))
	shot = sim.snapshot()
	tween.push(shot, 0.0)
	crowd.sync(shot)
	camera.frame(BattleCamera.action_box(shot, sim.map()))
	camera.snap()
	resized.connect(func() -> void: camera.view = _view())
	if mode == &"command":
		charge_button = _order(&"charge", "Charge the village", SiegeSim.Command.CHARGE, 300.0)
		retreat_button = _order(&"retreat", "Retreat to the start", SiegeSim.Command.RETREAT, 160.0)
	setup_ms = (Time.get_ticks_usec() - started) / 1000.0


func _process(delta: float) -> void:
	if sim == null:
		return
	meter.next_frame()
	var was := sim.outcome()
	sim.step(delta * speed)
	shot = sim.snapshot()
	meter.begin()
	tween.push(shot, delta * speed)
	crowd.sync(shot)
	_clock += delta
	if was == SiegeSim.Outcome.RUNNING and sim.outcome() != was:
		payoff_active = true
		_payoff_left = payoff_s
		if sim.outcome() == SiegeSim.Outcome.LOSE:
			crowd.ignite(SiegeSnapshot.Team.ARMY)
		decided.emit(sim.outcome())
	elif payoff_active:
		_payoff_left -= delta
		if _payoff_left <= 0.0:
			payoff_active = false
			finished.emit(sim.outcome())
	camera.frame(BattleCamera.action_box(shot, sim.map()))
	camera.update(delta)
	world.transform = camera.transform()
	crowd.draw_frame(tween, shot, _clock, delta, camera.zoom * _pixel_scale())
	meter.end()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mode == &"command":
		order(SiegeSim.Command.RALLY, canvas_to_map(button.position))
		accept_event()


## Sends one order to the sim (the buttons, a map click and the bot all land here).
func order(kind: int, pos: Vector2) -> void:
	if sim == null or sim.outcome() != SiegeSim.Outcome.RUNNING:
		return
	sim.command(kind, pos)
	commands_sent += 1
	command_given.emit(kind, pos)


func map_to_canvas(point: Vector2) -> Vector2:
	return camera.to_canvas(point)


func canvas_to_map(point: Vector2) -> Vector2:
	return camera.to_map(point)


## The entity nearest a canvas point (dev feedback's select tool), {} for none.
func pick_at(point: Vector2) -> Dictionary:
	var best := -1
	var best_px := PICK_PX
	for i in shot.entity_count():
		var px := map_to_canvas(shot.ent_pos[i]).distance_to(point)
		if px < best_px:
			best = i
			best_px = px
	if best < 0:
		return {}
	var at := shot.ent_pos[best]
	return {
		"kind": "entity",
		"id": "entity_%d" % best,
		"team": "army" if shot.ent_team[best] == SiegeSnapshot.Team.ARMY else "village",
		"entity_kind": shot.ent_kind[best],
		"count": shot.ent_count[best],
		"state": STATE_NAMES[shot.ent_state[best]],
		"position": [snappedf(at.x, 0.1), snappedf(at.y, 0.1)],
	}


func _order(glyph: StringName, spoken: String, kind: int, from_right: float) -> GlyphButton:
	var button := GlyphButton.make(glyph, spoken, 120.0)
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -from_right
	button.offset_right = -from_right + 120.0
	button.offset_top = -160.0
	button.offset_bottom = -40.0
	button.pressed.connect(func() -> void: order(kind, Vector2.ZERO))
	add_child(button)
	return button


## The canvas rectangle the map may use (the whole screen; the HUD floats).
func _view() -> Rect2:
	var area := size if size.x > 1.0 else Vector2(1920.0, 1080.0)
	return Rect2(Vector2.ZERO, area)


## Real pixels per canvas unit (2 on a 4K screen): the level of detail and
## nothing else depends on it.
func _pixel_scale() -> float:
	return get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
