class_name ShowcaseSim
extends SiegeSim
## A scripted stand-in for the sim, for `--autodrive=showcase`: it answers
## the same calls the battle screen makes (map, step, command, snapshot,
## outcome, clock) from a script instead of from rules, so every Kind, State
## and event can be put on screen and looked at, whatever the real sim can
## emit today. Scenes are written in ShowcaseScript. Not a test double: the
## real BattleScreen draws it through the real main scene.

var scene: StringName = &""
var show_map := SiegeMap.new()
var show_clock := 0.0
var show_outcome := SiegeSim.Outcome.RUNNING
var show_army_morale := 0.8
var show_village_morale := 0.6
var show_alarm := 0.4
## Parallel arrays, as in SiegeSnapshot.
var show_pos := PackedVector2Array()
var show_kind := PackedInt32Array()
var show_team := PackedByteArray()
var show_count := PackedInt32Array()
var show_state := PackedByteArray()
var show_facing := PackedFloat32Array()
## Where each entity circles around (the crowd scene) and how wide.
var show_home := PackedVector2Array()
var show_orbit := PackedFloat32Array()
## Events to come: {at: sim seconds, event: Dictionary}.
var show_script: Array[Dictionary] = []
## Sim second the outcome becomes `show_verdict` (INF: never).
var show_decide_at := INF
var show_verdict := SiegeSim.Outcome.WIN
## Orders received (the bot checks them).
var show_orders := 0
## True for the crowd scene: entities move, change state and lose heads.
var show_alive := false

var _rest := 0.0
var _ticks := 0
var _due: Array[Dictionary] = []


static func make(p_scene: StringName) -> ShowcaseSim:
	var sim := ShowcaseSim.new()
	sim.scene = p_scene
	ShowcaseScript.build(sim, p_scene)
	return sim


## Adds one entity; returns its index.
func add(kind: int, team: int, heads: int, state: int, at: Vector2, facing := 0.0) -> int:
	show_pos.append(at)
	show_home.append(at)
	show_orbit.append(0.0)
	show_kind.append(kind)
	show_team.append(team)
	show_count.append(heads)
	show_state.append(state)
	show_facing.append(facing)
	return show_pos.size() - 1


## Schedules an event for sim second `at_s` (0 = the first snapshot).
func fire(at_s: float, kind: StringName, pos: Vector2, data: Dictionary = {}) -> void:
	var event := {"kind": kind, "pos": pos}
	event.merge(data)
	show_script.append({"at": maxf(at_s, 0.0), "event": event})


## Heads on the field (what the crowd must draw).
func heads() -> int:
	var total := 0
	for count in show_count:
		total += count
	return total


func map() -> SiegeMap:
	return show_map


func step(dt: float) -> void:
	_rest += maxf(dt, 0.0)
	while _rest >= SiegeSim.STEP_S:
		_rest -= SiegeSim.STEP_S
		_ticks += 1
		show_clock = _ticks * SiegeSim.STEP_S
		_collect()
		if show_alive and show_outcome == SiegeSim.Outcome.RUNNING:
			ShowcaseScript.stir(self, _ticks)
		if show_clock >= show_decide_at and show_outcome == SiegeSim.Outcome.RUNNING:
			show_outcome = show_verdict


## Orders come back as the sim's own `command` event, as the real sim does.
func command(kind: int, pos: Vector2) -> void:
	if show_outcome != SiegeSim.Outcome.RUNNING:
		return
	show_orders += 1
	var target := pos
	if kind == SiegeSim.Command.CHARGE:
		target = show_map.village_center
	elif kind == SiegeSim.Command.RETREAT:
		target = show_map.army_spawn
	_due.append({"kind": SiegeEvent.COMMAND, "pos": target, "command": kind})


func snapshot() -> SiegeSnapshot:
	_collect()
	var shot := SiegeSnapshot.new()
	shot.clock_s = show_clock
	shot.outcome = show_outcome
	shot.army_morale = show_army_morale
	shot.village_morale = show_village_morale
	shot.alarm = show_alarm
	shot.ent_pos = show_pos.duplicate()
	shot.ent_kind = show_kind.duplicate()
	shot.ent_team = show_team.duplicate()
	shot.ent_count = show_count.duplicate()
	shot.ent_state = show_state.duplicate()
	shot.ent_facing = show_facing.duplicate()
	shot.events = _due
	_due = []
	return shot


func outcome() -> int:
	return show_outcome


func clock_s() -> float:
	return show_clock


func state_hash() -> int:
	return [scene, _ticks, show_outcome, show_pos, show_state, show_count].hash()


## Moves the scripted events whose time has come into the next snapshot.
func _collect() -> void:
	var later: Array[Dictionary] = []
	for entry in show_script:
		if entry["at"] <= show_clock:
			_due.append(entry["event"])
		else:
			later.append(entry)
	show_script = later
