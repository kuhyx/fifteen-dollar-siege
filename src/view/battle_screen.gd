class_name BattleScreen
extends Control
## The siege as dots: one per sim entity, sized by its head count, coloured by
## team, with the village circle, the buildings and three meters (army morale,
## village morale, alarm). Command mode adds a rally flag on click / tap and a
## charge and a retreat button. When the sim decides, the payoff (flag on the
## village, or flames on the army) plays BEFORE `finished` opens the result.
## SCAFFOLD view: the view agent replaces it and keeps the signals, `sim`,
## `commands_sent`, `payoff_active`, `map_to_canvas` / `canvas_to_map`, `pick_at`.

signal decided(outcome: int)
signal finished(outcome: int)
signal command_given(kind: int, pos: Vector2)

const HUD_H := 150.0
const MARGIN := 40.0
const PAYOFF_S := 1.2
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

var _payoff_left := 0.0
var _rally := Vector2.INF
var _flashes: Array[Dictionary] = []


func setup(p_sim: SiegeSim, p_mode: StringName, p_speed: float) -> void:
	sim = p_sim
	mode = p_mode
	speed = p_speed
	shot = sim.snapshot()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode == &"command":
		charge_button = _order(&"charge", "Charge the village", SiegeSim.Command.CHARGE, 300.0)
		retreat_button = _order(&"retreat", "Retreat to the start", SiegeSim.Command.RETREAT, 160.0)


func _process(delta: float) -> void:
	if sim == null:
		return
	var was := sim.outcome()
	sim.step(delta * speed)
	shot = sim.snapshot()
	for event in shot.events:
		_flashes.append({"pos": event["pos"], "left": 0.6, "kind": event["kind"]})
	for flash in _flashes:
		flash["left"] -= delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f["left"] > 0.0)
	if was == SiegeSim.Outcome.RUNNING and sim.outcome() != was:
		payoff_active = true
		_payoff_left = payoff_s
		decided.emit(sim.outcome())
	elif payoff_active:
		_payoff_left -= delta
		if _payoff_left <= 0.0:
			payoff_active = false
			finished.emit(sim.outcome())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if mode == &"command" and _map_rect().has_point(button.position):
		order(SiegeSim.Command.RALLY, canvas_to_map(button.position))
		accept_event()


## Sends one order to the sim (the buttons, a map click and the bot all land here).
func order(kind: int, pos: Vector2) -> void:
	if sim == null or sim.outcome() != SiegeSim.Outcome.RUNNING:
		return
	sim.command(kind, pos)
	commands_sent += 1
	_rally = pos if kind == SiegeSim.Command.RALLY else Vector2.INF
	command_given.emit(kind, pos)


func map_to_canvas(point: Vector2) -> Vector2:
	var box := _map_rect()
	var bounds := sim.map().bounds
	return box.position + (point - bounds.position) / bounds.size * box.size


func canvas_to_map(point: Vector2) -> Vector2:
	var box := _map_rect()
	var bounds := sim.map().bounds
	return bounds.position + (point - box.position) / box.size * bounds.size


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


## The map's box on the canvas: under the HUD strip, the map's aspect kept.
func _map_rect() -> Rect2:
	var room := Rect2(MARGIN, HUD_H, size.x - 2.0 * MARGIN, size.y - HUD_H - MARGIN)
	var bounds := sim.map().bounds.size
	var scale_by := minf(room.size.x / bounds.x, room.size.y / bounds.y)
	var fitted := bounds * scale_by
	return Rect2(room.position + (room.size - fitted) / 2.0, fitted)


func _draw() -> void:
	if sim == null:
		return
	var box := _map_rect()
	var px_per_m := box.size.x / sim.map().bounds.size.x
	draw_rect(box, Palette.GROUND)
	var centre := map_to_canvas(sim.map().village_center)
	draw_circle(centre, sim.map().village_radius * px_per_m, Palette.VILLAGE_GROUND)
	for building in sim.map().buildings:
		var corner := map_to_canvas(building.position)
		draw_rect(Rect2(corner, building.size * px_per_m), Palette.BUILDING)
	for i in shot.entity_count():
		_draw_entity(i, px_per_m)
	for flash in _flashes:
		var grow: float = (0.6 - flash["left"]) * 160.0
		draw_arc(map_to_canvas(flash["pos"]), 12.0 + grow, 0.0, TAU, 32, Palette.INK, 4.0)
	if _rally != Vector2.INF:
		_stamp(&"rally", map_to_canvas(_rally) - Vector2(0, 30), 60.0, Palette.INK)
	_draw_hud()
	if payoff_active or sim.outcome() != SiegeSim.Outcome.RUNNING:
		_draw_payoff(centre)


func _draw_entity(index: int, px_per_m: float) -> void:
	var state := shot.ent_state[index]
	if state == SiegeSnapshot.State.HIDDEN:
		return
	var army := shot.ent_team[index] == SiegeSnapshot.Team.ARMY
	var tint := Palette.ARMY if army else Palette.VILLAGE
	if state == SiegeSnapshot.State.DOWN:
		tint = Palette.BAD.darkened(0.3)
	elif state == SiegeSnapshot.State.FLEE:
		tint = tint.lightened(0.45)
	var at := map_to_canvas(shot.ent_pos[index])
	var radius := maxf(4.0, sqrt(float(shot.ent_count[index])) * 0.9 * px_per_m)
	draw_circle(at, radius, tint)
	draw_line(at, at + Vector2.from_angle(shot.ent_facing[index]) * (radius + 6.0), tint, 3.0)


func _draw_hud() -> void:
	_meter(Vector2(320, 40), &"morale", Palette.ARMY, shot.army_morale)
	_meter(Vector2(760, 40), &"morale", Palette.VILLAGE, shot.village_morale)
	_meter(Vector2(1200, 40), &"alarm", Palette.COIN, shot.alarm)
	_stamp(&"clock", Vector2(1640, 75), 56.0, Palette.DIM)
	SevenSegment.draw_number(self, int(shot.clock_s), Vector2(1680, 50), 50.0, Palette.INK)


## An icon and a bar filled to `value` (0..1): a level, never a word.
func _meter(at: Vector2, glyph: StringName, tint: Color, value: float) -> void:
	_stamp(glyph, at + Vector2(35, 35), 70.0, tint)
	var bar := Rect2(at + Vector2(86, 20), Vector2(280, 30))
	draw_rect(bar, Palette.PANEL)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y)), tint)
	draw_rect(bar, Palette.DIM, false, 2.0)


func _draw_payoff(centre: Vector2) -> void:
	var pulse := 1.0 + 0.15 * sin(_payoff_left * 12.0)
	if sim.outcome() == SiegeSim.Outcome.WIN:
		_stamp(&"win", centre - Vector2(0, 60), 220.0 * pulse, Palette.GOOD)
		return
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY:
			_stamp(&"combust", map_to_canvas(shot.ent_pos[i]), 70.0 * pulse, Palette.BAD)


## Draws a glyph `px` wide, centred on `at`.
func _stamp(glyph: StringName, at: Vector2, px: float, tint: Color) -> void:
	var box := Rect2(at - Vector2.ONE * px / 2.0, Vector2.ONE * px)
	draw_texture_rect(Glyphs.texture(glyph), box, false, tint)
