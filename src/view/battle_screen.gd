class_name BattleScreen
extends Control
## The siege on screen: the map from above (MapLayer), every individual
## drawn (CrowdLayer), an effect for every event (BattleEffects), a camera
## that frames the action, and the HUD (BattleHud). Staged beats play before
## the first tick; the payoff (a flag on the church, or the army in flames)
## plays BEFORE `finished` opens the result.
## Contract kept for Main, the bot and the dev tools: the three signals,
## `sim`, `mode`, `speed`, `shot`, `commands_sent`, `payoff_active`,
## `payoff_s`, `charge_button`, `retreat_button`, `setup`, `order`,
## `map_to_canvas` / `canvas_to_map` and `pick_at`.

signal decided(outcome: int)
signal finished(outcome: int)
signal command_given(kind: int, pos: Vector2)

## Real seconds of payoff before the result opens [design guess].
const PAYOFF_S := 3.2
## Real seconds the HUD bell swings after a ring [design guess].
const RING_S := 1.5

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
## The HUD's pause: the sim stands still, the camera does not.
var held := false
var camera := BattleCamera.new()
var tween := SnapshotTween.new()
var beats := BattleBeats.new()
var pointer := CameraInput.new()
var plan: MapPlan
var world := Node2D.new()
var map_layer := MapLayer.new()
var crowd := CrowdLayer.new()
var effects := BattleEffects.new()
var hud := BattleHud.new()
## This screen's own work per frame (the frame gate reads it).
var meter := FrameMeter.new()
## Milliseconds `setup` took: the whole cost of entering the screen.
var setup_ms := 0.0

var _clock := 0.0


func setup(p_sim: SiegeSim, p_mode: StringName, p_speed: float) -> void:
	var started := Time.get_ticks_usec()
	sim = p_sim
	mode = p_mode
	speed = p_speed
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan = MapPlan.of(sim.map())
	camera.setup(sim.map().bounds, _view())
	pointer.camera = camera
	add_child(world)
	for layer: Node2D in [map_layer, crowd, effects]:
		world.add_child(layer)
	map_layer.setup(plan)
	crowd.setup(sim.map().bounds, FigureLook.of(loadout))
	effects.setup(plan, crowd, meter)
	hud.setup(mode == &"command")
	add_child(hud)
	charge_button = hud.charge_button
	retreat_button = hud.retreat_button
	_wire()
	_take(sim.snapshot(), 0.0)
	camera.frame(_focus())
	camera.snap()
	world.transform = camera.transform()
	setup_ms = (Time.get_ticks_usec() - started) / 1000.0


func _process(delta: float) -> void:
	if sim == null:
		return
	meter.next_frame()
	if beats.staging():
		beats.update(delta)
	elif not held:
		_step(delta * speed)
	meter.begin()
	if not held:
		_clock += delta
		effects.advance(delta)
	beats.tick_payoff(delta)
	camera.frame(_focus())
	if payoff_active or beats.staging():
		camera.resume_auto()
	camera.update(delta)
	world.transform = camera.transform()
	crowd.draw_frame(tween, shot, _clock, delta, camera.zoom * _pixel_scale())
	var state := {"speed": speed, "held": held, "auto": camera.auto}
	state["centre"] = effects.centre_progress
	state["staged"] = beats.staging()
	hud.show_state(shot, state, delta)
	meter.end()


func _input(event: InputEvent) -> void:
	if SiegeActions.note(event):
		hud.refresh_badges()


func _gui_input(event: InputEvent) -> void:
	var tap := pointer.feed(event)
	if tap == Vector2.INF:
		return
	accept_event()
	if beats.staging():
		beats.skip()
	elif mode == &"command":
		order(SiegeSim.Command.RALLY, canvas_to_map(tap))


func _unhandled_input(event: InputEvent) -> void:
	if beats.staging():
		if event.is_action_pressed(SiegeActions.SKIP):
			beats.skip()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(SiegeActions.PAUSE):
		held = not held
	elif event.is_action_pressed(SiegeActions.CAMERA_AUTO):
		camera.resume_auto()
	elif mode == &"command" and event.is_action_pressed(SiegeActions.CHARGE):
		order(SiegeSim.Command.CHARGE, Vector2.ZERO)
	elif mode == &"command" and event.is_action_pressed(SiegeActions.RETREAT):
		order(SiegeSim.Command.RETREAT, Vector2.ZERO)
	elif mode == &"command" and event is InputEventJoypadButton:
		if event.is_action_pressed(SiegeActions.RALLY):
			order(SiegeSim.Command.RALLY, canvas_to_map(camera.view.get_center()))
	for i in SiegeActions.SPEEDS.size():
		if event.is_action_pressed(SiegeActions.SPEEDS[i]):
			speed = SiegeActions.SPEED_VALUES[i]


## Sends one order to the sim (the buttons, a map click and the bot all land here).
func order(kind: int, pos: Vector2) -> void:
	if sim == null or sim.outcome() != SiegeSim.Outcome.RUNNING:
		return
	sim.command(kind, pos)
	commands_sent += 1
	effects.plant(pos if kind == SiegeSim.Command.RALLY else Vector2.INF)
	command_given.emit(kind, pos)


## Dresses the army for another loadout (the showcase walks through the looks).
func dress(p_loadout: Loadout) -> void:
	loadout = p_loadout.duplicate()
	crowd.dress(FigureLook.of(loadout))


## 0 at the decision, 1 when the result opens.
func payoff_progress() -> float:
	return beats.payoff_progress()


func map_to_canvas(point: Vector2) -> Vector2:
	return camera.to_canvas(point)


func canvas_to_map(point: Vector2) -> Vector2:
	return camera.to_map(point)


## The entity nearest a canvas point (dev feedback's select tool), {} for none.
func pick_at(point: Vector2) -> Dictionary:
	return BattlePick.entity_at(shot, camera, point)


func _wire() -> void:
	resized.connect(func() -> void: camera.view = _view())
	hud.pause_pressed.connect(func() -> void: held = not held)
	hud.speed_picked.connect(func(value: float) -> void: speed = value)
	hud.auto_pressed.connect(camera.resume_auto)
	hud.skip_pressed.connect(beats.skip)
	hud.order_pressed.connect(func(kind: int) -> void: order(kind, Vector2.ZERO))
	hud.rally_pressed.connect(
		func() -> void: effects.pulse(canvas_to_map(camera.view.get_center()))
	)
	beats.beat_began.connect(effects.spawn)
	beats.beat_ended.connect(func(kind: StringName, _cut: bool) -> void: effects.drop(kind))
	beats.payoff_done.connect(_on_payoff_done)


## One step of the sim, then everything the new snapshot changes.
func _step(dt_sim: float) -> void:
	var was := sim.outcome()
	sim.step(dt_sim)
	var next := sim.snapshot()
	meter.begin()
	_take(next, dt_sim)
	if was == SiegeSim.Outcome.RUNNING and sim.outcome() != was:
		payoff_active = true
		if sim.outcome() == SiegeSim.Outcome.LOSE:
			crowd.ignite(SiegeSnapshot.Team.ARMY)
		else:
			effects.flag_up = true
		beats.start_payoff(payoff_s)
		decided.emit(sim.outcome())
	meter.end()


func _take(next: SiegeSnapshot, dt_sim: float) -> void:
	shot = next
	tween.push(shot, dt_sim)
	crowd.sync(shot)
	effects.shot = shot
	for event in shot.events:
		if shot.clock_s <= 0.0 and BattleBeats.stages(event):
			beats.add(event)
			continue
		effects.spawn(event)
		if event.get("kind") in [SiegeEvent.BELL_RING, SiegeEvent.ALARM]:
			hud.meters.ringing = RING_S


func _on_payoff_done() -> void:
	payoff_active = false
	finished.emit(sim.outcome())


## What the camera should show now: the beat, the payoff or the action.
func _focus() -> Rect2:
	if beats.staging():
		return beats.beat_box()
	if payoff_active:
		return BattleBeats.payoff_box(sim.outcome() == SiegeSim.Outcome.WIN, plan, shot)
	return BattleCamera.action_box(shot, sim.map())


## The canvas rectangle the map may use (the whole screen; the HUD floats).
func _view() -> Rect2:
	var area := size if size.x > 1.0 else Vector2(1920.0, 1080.0)
	return Rect2(Vector2.ZERO, area)


## Real pixels per canvas unit (2 on a 4K screen): only the level of detail
## depends on it.
func _pixel_scale() -> float:
	return get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
