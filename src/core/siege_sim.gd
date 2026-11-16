class_name SiegeSim
extends RefCounted
## The siege, one deterministic simulation for all three modes (Watch,
## Command, Lab). No Node, no scene, no global RNG, no clock: the same loadout,
## seed and command sequence give the same state_hash() sequence on any run.
##
## STUB (scaffold): the army walks to its target, and at about STUB_DECIDE_S the
## siege is WIN when the loadout cost at least STUB_WIN_COST dollars, else LOSE.
## The sim agent replaces the body; the public signatures below are the contract
## (DOCS-design.md, "Core API") and only grow.

enum Outcome { RUNNING, WIN, LOSE }
enum Command { RALLY, CHARGE, RETREAT }

## Fixed internal timestep; step(dt) runs whole ticks only.
const STEP_S := 1.0 / 30.0
const BASE_MEN := 100
const EXTRA_MEN := 50
## Heads per army entity.
const SQUAD_SIZE := 10
const VILLAGER_GROUPS := 20
const VILLAGERS_PER_GROUP := 100
const BUILDINGS := 14
const STUB_WIN_COST := 8
const STUB_DECIDE_S := 20.0
const STUB_DECIDE_JITTER_S := 2.0
const STUB_SPEED_MPS := 18.0
const STUB_FLEE_MPS := 6.0
const ARRIVE_M := 2.0

var _map := SiegeMap.new()
var _loadout := Loadout.new()
var _rng := RandomNumberGenerator.new()
var _accumulator := 0.0
var _tick := 0
var _decide_tick := 0
var _outcome := Outcome.RUNNING
var _target := Vector2.ZERO
var _alarm := 0.0
var _alarm_raised := false
var _pos := PackedVector2Array()
var _offset := PackedVector2Array()
var _kind := PackedInt32Array()
var _team := PackedByteArray()
var _count := PackedInt32Array()
var _state := PackedByteArray()
var _facing := PackedFloat32Array()
var _events: Array[Dictionary] = []


## Men in the army for this loadout: "+50 men" applies before "double" (300).
static func army_size(loadout: Loadout) -> int:
	var men := BASE_MEN
	if loadout.has(&"fifty_men"):
		men += EXTRA_MEN
	if loadout.has(&"double_men"):
		men *= 2
	return men


## A fresh siege. The loadout is copied; pass a legal one (Loadout.is_legal).
static func create(loadout: Loadout, sim_seed: int) -> SiegeSim:
	var sim := SiegeSim.new()
	sim._loadout = loadout.duplicate()
	sim._rng.seed = sim_seed
	sim._build_map()
	sim._spawn_army()
	sim._spawn_village()
	sim._target = sim._map.village_center
	var jitter := sim._rng.randf_range(-STUB_DECIDE_JITTER_S, STUB_DECIDE_JITTER_S)
	sim._decide_tick = roundi((STUB_DECIDE_S + jitter) / STEP_S)
	return sim


func map() -> SiegeMap:
	return _map


## Advances the siege by `dt` seconds of sim time, in whole STEP_S ticks (the
## remainder waits for the next call).
func step(dt: float) -> void:
	_accumulator += maxf(dt, 0.0)
	while _accumulator >= STEP_S:
		_accumulator -= STEP_S
		_advance()


## A player order (Command mode). `kind` is a Command; `pos` is in map metres
## and only matters for RALLY. Ignored once the siege is decided.
func command(kind: int, pos: Vector2) -> void:
	if _outcome != Outcome.RUNNING:
		return
	match kind:
		Command.RALLY:
			_target = pos.clamp(_map.bounds.position, _map.bounds.end)
		Command.CHARGE:
			_target = _map.village_center
		Command.RETREAT:
			_target = _map.army_spawn
		_:
			return
	_events.append({"kind": &"command", "pos": _target, "command": kind})


## The current state for the view. Events are handed over once: a second
## snapshot of the same tick has none.
func snapshot() -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	var progress := minf(float(_tick) / float(maxi(_decide_tick, 1)), 1.0)
	shot.clock_s = clock_s()
	shot.outcome = _outcome
	shot.alarm = _alarm
	if _wins():
		shot.village_morale = 1.0 - progress
	else:
		shot.army_morale = 1.0 - progress
	shot.ent_pos = _pos.duplicate()
	shot.ent_kind = _kind.duplicate()
	shot.ent_team = _team.duplicate()
	shot.ent_count = _count.duplicate()
	shot.ent_state = _state.duplicate()
	shot.ent_facing = _facing.duplicate()
	shot.events = _events
	_events = []
	return shot


func outcome() -> int:
	return _outcome


## Sim seconds since the siege began.
func clock_s() -> float:
	return _tick * STEP_S


## One number for the whole state: equal across two runs with the same loadout,
## seed and commands, tick for tick.
func state_hash() -> int:
	return [_tick, _outcome, _target, _pos, _state, _count, _rng.state].hash()


func _wins() -> bool:
	return _loadout.cost() >= STUB_WIN_COST


func _build_map() -> void:
	for i in BUILDINGS:
		var at := _village_point(0.15, 0.8)
		var size := Vector2(_rng.randf_range(8.0, 18.0), _rng.randf_range(8.0, 18.0))
		_map.buildings.append(Rect2(at - size / 2.0, size))


func _village_point(near: float, far: float) -> Vector2:
	var reach := _rng.randf_range(near, far) * _map.village_radius
	return _map.village_center + Vector2.from_angle(_rng.randf() * TAU) * reach


func _spawn_army() -> void:
	var men := army_size(_loadout)
	while men > 0:
		var heads := mini(men, SQUAD_SIZE)
		men -= heads
		var offset := Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-120.0, 120.0))
		_add(_map.army_spawn + offset, offset * 0.25, SiegeSnapshot.Team.ARMY, heads)


func _spawn_village() -> void:
	for i in VILLAGER_GROUPS:
		var at := _village_point(0.0, 0.9)
		_add(at, Vector2.ZERO, SiegeSnapshot.Team.VILLAGE, VILLAGERS_PER_GROUP)


func _add(at: Vector2, offset: Vector2, team: int, heads: int) -> void:
	_pos.append(at)
	_offset.append(offset)
	_team.append(team)
	var army := team == SiegeSnapshot.Team.ARMY
	_kind.append(SiegeSnapshot.Kind.MEN if army else SiegeSnapshot.Kind.VILLAGERS)
	_count.append(heads)
	_state.append(SiegeSnapshot.State.IDLE)
	_facing.append(0.0 if army else PI)


func _advance() -> void:
	_tick += 1
	if _outcome == Outcome.RUNNING:
		_march()
		_raise_alarm()
		if _tick >= _decide_tick:
			_decide()
	elif _outcome == Outcome.WIN:
		_flee()


func _march() -> void:
	for i in _pos.size():
		if _team[i] != SiegeSnapshot.Team.ARMY:
			continue
		var to := _target + _offset[i] - _pos[i]
		if to.length() <= ARRIVE_M:
			_state[i] = SiegeSnapshot.State.IDLE
			continue
		_pos[i] += to.limit_length(STUB_SPEED_MPS * STEP_S)
		_facing[i] = to.angle()
		_state[i] = SiegeSnapshot.State.MOVE


func _raise_alarm() -> void:
	var nearest := INF
	for i in _pos.size():
		if _team[i] == SiegeSnapshot.Team.ARMY:
			nearest = minf(nearest, _pos[i].distance_to(_map.village_center))
	var far := _map.army_spawn.distance_to(_map.village_center) - _map.village_radius
	_alarm = maxf(_alarm, clampf(1.0 - (nearest - _map.village_radius) / far, 0.0, 1.0))
	if _alarm >= 0.5 and not _alarm_raised:
		_alarm_raised = true
		_events.append({"kind": &"alarm", "pos": _map.village_center})


func _decide() -> void:
	_outcome = Outcome.WIN if _wins() else Outcome.LOSE
	var loser := SiegeSnapshot.Team.VILLAGE if _wins() else SiegeSnapshot.Team.ARMY
	var fate := SiegeSnapshot.State.FLEE if _wins() else SiegeSnapshot.State.DOWN
	var middle := Vector2.ZERO
	var losers := 0
	for i in _pos.size():
		if _team[i] == loser:
			_state[i] = fate
			middle += _pos[i]
			losers += 1
		else:
			_state[i] = SiegeSnapshot.State.IDLE
	var kind := &"victory" if _wins() else &"combust"
	_events.append({"kind": kind, "pos": middle / maxf(losers, 1.0)})


func _flee() -> void:
	for i in _pos.size():
		if _team[i] != SiegeSnapshot.Team.VILLAGE:
			continue
		var away := (_pos[i] - _map.village_center).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		_pos[i] = (_pos[i] + away * STUB_FLEE_MPS * STEP_S).clamp(
			_map.bounds.position, _map.bounds.end
		)
		_facing[i] = away.angle()
