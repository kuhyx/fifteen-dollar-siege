class_name SiegeReferee
extends RefCounted
## Decides the siege, once per decision step.
##   WIN   the village's morale broke, or the army held the plaza for HOLD_S
##   LOSE  the army's morale broke (dead or routed), or the time cap ran out
## A step that breaks both sides is a loss: nobody is left to take control.

const T = preload("res://src/core/siege_tuning.gd")
const ST := SiegeSnapshot.State
const ARMY := SiegeSnapshot.Team.ARMY
const WIN := 1
const LOSE := 2
## A CENTRE_HELD event every this many seconds of holding.
const HELD_EVERY_S := 3.0


static func run(s: SiegeState) -> void:
	_hold(s)
	s.village_low = minf(s.village_low, s.village_morale)
	if s.army_morale <= T.ARMY_BREAK or s.clock_s() >= T.TIME_CAP_S:
		_lose(s)
	elif s.village_morale <= T.VILLAGE_BREAK or s.hold_s >= T.HOLD_S:
		_win(s)


## Morale as the snapshot shows it: 1 fresh, 0 at the side's breaking point.
static func shown(ratio: float, break_at: float) -> float:
	return clampf((ratio - break_at) / (1.0 - break_at), 0.0, 1.0)


## The plaza is held while enough army heads stand in it and they outnumber
## the armed defenders there HOLD_RATIO to one; a contested plaza loses time.
static func _hold(s: SiegeState) -> void:
	var held := s.plaza_army >= T.HOLD_MIN_HEADS and s.plaza_army >= s.plaza_village * T.HOLD_RATIO
	var before := s.hold_s
	if not held:
		s.hold_s = maxf(before - T.THINK_S, 0.0)
		return
	s.hold_s = before + T.THINK_S
	if int(s.hold_s / HELD_EVERY_S) != int(before / HELD_EVERY_S):
		var progress := minf(s.hold_s / T.HOLD_S, 1.0)
		s.emit_with(SiegeEvent.CENTRE_HELD, s.map.village_center, {"progress": progress})


static func _win(s: SiegeState) -> void:
	s.outcome = WIN
	s.village_morale = 0.0
	s.village_low = 0.0
	for i in s.pos.size():
		if s.count[i] <= 0 or s.flag[i] & SiegeState.F_GONE != 0:
			continue
		if s.team[i] == ARMY:
			SiegeMove.stand(s, i)
			if s.state[i] != ST.HIDDEN:
				s.state[i] = ST.IDLE
		elif s.flag[i] & SiegeState.F_FIGHTER != 0:
			s.state[i] = ST.FLEE
			SiegeVillage.flee(s, i)
	s.emit(SiegeEvent.VICTORY, s.map.village_center)


## The army combusts where it stands.
static func _lose(s: SiegeState) -> void:
	s.outcome = LOSE
	s.army_morale = 0.0
	var sum := Vector2.ZERO
	var heads := 0
	for i in s.pos.size():
		SiegeMove.stand(s, i)
		if s.team[i] != ARMY:
			continue
		if s.count[i] > 0:
			sum += s.pos[i]
			heads += 1
		s.state[i] = ST.DOWN
	s.emit(SiegeEvent.COMBUST, sum / heads if heads > 0 else s.map.army_spawn)
