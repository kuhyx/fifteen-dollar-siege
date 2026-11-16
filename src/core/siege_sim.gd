class_name SiegeSim
extends RefCounted
## The siege, one deterministic simulation for all three modes (Watch,
## Command, Lab). No Node, no scene, no global RNG, no clock: the same loadout,
## seed and command sequence give the same state_hash() sequence on any run.
##
## Squad-level: an entity is a squad of about ten or one special. Every tick
## (STEP_S) the entities move; every SiegeTuning.THINK_TICKS ticks the systems
## decide: SiegeAlarm (notice, bell, muster), SiegeArmy (default plan, orders),
## SiegeVillage, SiegeSpecials and SiegeBeasts (the buffs), SiegeCombat,
## SiegeMorale (rout, rally), SiegeReferee (win, lose). The model and every
## number: DOCS-design-sim.md. The public signatures are the contract
## (DOCS-design.md "Core API") and only grow.

enum Outcome { RUNNING, WIN, LOSE }
enum Command { RALLY, CHARGE, RETREAT }

## Fixed internal timestep; step(dt) runs whole ticks only.
const STEP_S := SiegeTuning.STEP_S
const BASE_MEN := 100
const EXTRA_MEN := 50
## Heads per army squad (and per village fighter squad).
const SQUAD_SIZE := 10
## Buildings on the map; buildings[0] is the church.
const BUILDINGS := 14

var _state := SiegeState.new()
var _loadout := Loadout.new()
var _accumulator := 0.0


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
	sim.setup(loadout, sim_seed)
	return sim


## Builds the siege (create() calls this once; do not call it again).
func setup(loadout: Loadout, sim_seed: int) -> void:
	_loadout = loadout.duplicate()
	_state.mods = SiegeMods.of(_loadout)
	_state.rng.seed = sim_seed
	SiegeSetup.build(_state)
	SiegeArmy.census(_state)
	SiegeMorale.baseline(_state)


func map() -> SiegeMap:
	return _state.map


## Advances the siege by `dt` seconds of sim time, in whole STEP_S ticks (the
## remainder waits for the next call).
func step(dt: float) -> void:
	_accumulator += maxf(dt, 0.0)
	var ticks := floori(_accumulator / STEP_S + 1e-6)
	_accumulator = maxf(_accumulator - ticks * STEP_S, 0.0)
	for i in ticks:
		_advance()


## Runs the siege to its decision without a view (Lab, tools): no events are
## recorded from here on. Returns the outcome.
func run_to_end() -> int:
	_state.quiet = true
	while _state.outcome == Outcome.RUNNING:
		_advance()
	return _state.outcome


## A player order (Command mode). `kind` is a Command; `pos` is in map metres
## and only matters for RALLY. Ignored once the siege is decided. The order
## stands until the next one; a drunk squad may ignore it (booze).
func command(kind: int, pos: Vector2) -> void:
	var s := _state
	if s.outcome != Outcome.RUNNING:
		return
	var at := s.map.village_center
	match kind:
		Command.RALLY:
			at = pos.clamp(s.map.bounds.position, s.map.bounds.end)
		Command.CHARGE:
			pass
		Command.RETREAT:
			at = s.map.army_spawn
		_:
			return
	s.order = kind
	s.order_pos = at
	for i in s.pos.size():
		if s.flag[i] & SiegeState.F_LINE == 0:
			continue
		s.flag[i] &= ~(SiegeState.F_IGNORE | SiegeState.F_CHARGING)
		if s.mods.ignore_orders > 0.0 and s.rng.randf() < s.mods.ignore_orders:
			s.flag[i] |= SiegeState.F_IGNORE
		elif kind == Command.CHARGE:
			s.flag[i] |= SiegeState.F_CHARGING
	s.emit_with(SiegeEvent.COMMAND, at, {"command": kind})


## The current state for the view. Events are handed over once: a second
## snapshot of the same tick has none.
func snapshot() -> SiegeSnapshot:
	var s := _state
	var shot := SiegeSnapshot.new()
	shot.clock_s = clock_s()
	shot.outcome = s.outcome
	shot.alarm = s.alarm
	shot.army_morale = SiegeReferee.shown(s.army_morale, SiegeTuning.ARMY_BREAK)
	shot.village_morale = SiegeReferee.shown(s.village_morale, SiegeTuning.VILLAGE_BREAK)
	shot.centre_hold = minf(s.hold_s / SiegeTuning.HOLD_S, 1.0)
	shot.ent_pos = s.pos.duplicate()
	shot.ent_kind = s.kind.duplicate()
	shot.ent_team = s.team.duplicate()
	shot.ent_count = s.count.duplicate()
	shot.ent_state = s.state.duplicate()
	shot.ent_facing = s.facing.duplicate()
	shot.ent_morale = s.morale.duplicate()
	shot.events = s.events
	s.events = []
	return shot


func outcome() -> int:
	return _state.outcome


## How close the army came: the lowest the village's morale has been so far, on
## the snapshot's scale (1 fresh, 0 broken; 0 after any win).
func village_low() -> float:
	return SiegeReferee.shown(_state.village_low, SiegeTuning.VILLAGE_BREAK)


## Sim seconds since the siege began.
func clock_s() -> float:
	return _state.clock_s()


## One number for the whole state: equal across two runs with the same loadout,
## seed and commands, tick for tick.
func state_hash() -> int:
	var s := _state
	return (
		[
			s.tick,
			s.outcome,
			s.order,
			s.order_pos,
			s.alarm,
			s.hold_s,
			s.pos,
			s.state,
			s.count,
			s.morale,
			s.fatigue,
			s.flag,
			s.rng.state
		]
		. hash()
	)


## One tick: a decision step when it is due, then everybody moves. After the
## decision only the movement goes on (the beaten village runs).
func _advance() -> void:
	var s := _state
	s.tick += 1
	if s.outcome == Outcome.RUNNING and s.tick % SiegeTuning.THINK_TICKS == 0:
		s.grid.rebuild(s)
		SiegeAlarm.run(s)
		SiegeArmy.run(s)
		SiegeVillage.run(s)
		SiegeSpecials.run(s)
		SiegeCombat.run(s)
		SiegeMorale.run(s)
		SiegeReferee.run(s)
	SiegeMove.run(s)
