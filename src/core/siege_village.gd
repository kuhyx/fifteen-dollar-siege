class_name SiegeVillage
extends RefCounted
## The village's side of a decision step. A squad sleeps until it hears the
## alarm (at its own alarm level) or sees the enemy (the deaf only see); a
## fighter squad then arms, goes for the nearest enemy it can reach
## or musters in the plaza, and does not chase beyond the leash. Archers stand
## off and shoot. The crowds (everybody else) run for the church or out of the
## far side and hide.

const T = preload("res://src/core/siege_tuning.gd")
const ST := SiegeSnapshot.State
const K := SiegeSnapshot.Kind
const VILLAGE := SiegeSnapshot.Team.VILLAGE
const ALERT := SiegeState.F_ALERTED
const ARMED := SiegeState.F_ARMED


static func run(s: SiegeState) -> void:
	var leash := s.map.village_radius + T.LEASH_M
	var leash2 := leash * leash
	var centre := s.map.village_center
	var arrive2 := T.ARRIVE_M * T.ARRIVE_M
	var pos := s.pos
	var team := s.team
	var count := s.count
	var flag := s.flag
	var kind := s.kind
	var state := s.state
	var grid := s.grid
	# Nobody in reach of the village: nothing to see or to fight.
	var near := s.threat != -1
	for i in pos.size():
		if team[i] != VILLAGE or count[i] <= 0:
			continue
		var f := flag[i]
		if f & SiegeState.F_GONE != 0:
			continue
		if kind[i] == K.VILLAGERS:
			_crowd(s, i, near)
			continue
		if state[i] == ST.FLEE:
			_run_away(s, i)
			continue
		var p := pos[i]
		if f & ARMED == 0:
			_wake(s, i, grid.nearest(s, grid.army, p, T.SEE_M, T.SEE_M) if near else -1)
			continue
		var home := near and p.distance_squared_to(centre) <= leash2
		var enemy := grid.nearest(s, grid.army, p, T.ACQUIRE_M, T.CHASE_M) if home else -1
		s.foe[i] = enemy
		if enemy != -1:
			_engage(s, i, enemy)
		elif home:
			SiegeMove.go(s, i, pos[s.threat], SiegeMove.MARCH)
			state[i] = ST.MOVE
		elif p.distance_squared_to(s.slot[i]) > arrive2:
			SiegeMove.go(s, i, s.slot[i], SiegeMove.MARCH)
			state[i] = ST.MOVE
		else:
			SiegeMove.stand(s, i)
			state[i] = ST.IDLE


## A crowd runs for its refuge and hides. The army among their kin shakes the
## village fighters (once per crowd).
static func scatter(s: SiegeState, i: int) -> void:
	if s.state[i] == ST.FLEE or s.state[i] == ST.HIDDEN:
		return
	s.flag[i] |= ALERT
	s.state[i] = ST.FLEE
	SiegeMove.go(s, i, s.slot[i], SiegeMove.MARCH)
	s.jolt_team(VILLAGE, s.pos[i], 0.0, T.PANIC_SHOCK, -1, false)


## True once squad i has heard the alarm or seen the enemy (the deaf only see).
static func _alerted(s: SiegeState, i: int, enemy: int) -> bool:
	if s.flag[i] & ALERT != 0:
		return true
	var deaf := s.flag[i] & SiegeState.F_DEAF != 0
	var heard := s.alarm_on and not deaf and s.alarm >= s.wait[i]
	var seen := enemy != -1 and s.pos[i].distance_squared_to(s.pos[enemy]) <= T.SEE_M * T.SEE_M
	if not (heard or seen):
		return false
	s.flag[i] |= ALERT
	return true


## Not armed yet: wait for the alarm, then arm.
static func _wake(s: SiegeState, i: int, enemy: int) -> void:
	s.foe[i] = -1
	if s.flag[i] & ALERT == 0:
		if not _alerted(s, i, enemy):
			return
		var arm := s.rng.randf_range(T.ARM_MIN_S, T.ARM_MAX_S)
		if s.kind[i] == K.RETINUE:
			arm = T.RETINUE_ARM_S
		s.wait[i] = arm * s.mods.reaction
		return
	s.wait[i] -= T.THINK_S
	if s.wait[i] <= 0.0:
		s.flag[i] |= ARMED
		s.reload[i] = 0.0


static func _engage(s: SiegeState, i: int, enemy: int) -> void:
	var at := s.pos[enemy]
	var d2 := s.pos[i].distance_squared_to(at)
	var hold := T.CONTACT_M
	if s.kind[i] == K.ARCHERS:
		hold = T.BOW_HOLD_M
	if d2 <= hold * hold:
		SiegeMove.stand(s, i)
		SiegeMove.face(s, i, at)
		s.state[i] = ST.FIGHT
		return
	# A running enemy is run down: most men fall in the rout.
	var chase := s.state[enemy] == ST.FLEE
	SiegeMove.go(s, i, at, SiegeMove.SPRINT if chase else SiegeMove.MARCH)
	s.state[i] = ST.MOVE


static func _crowd(s: SiegeState, i: int, near: bool) -> void:
	if s.state[i] == ST.FLEE:
		if s.pos[i].distance_squared_to(s.goal[i]) <= T.ARRIVE_M * T.ARRIVE_M:
			SiegeMove.stand(s, i)
			s.state[i] = ST.HIDDEN
			s.flag[i] |= SiegeState.F_GONE
		return
	var enemy := -1
	if near:
		enemy = s.grid.nearest(s, s.grid.army, s.pos[i], T.SEE_M, T.SEE_M)
	if _alerted(s, i, enemy):
		s.state[i] = ST.FLEE
		SiegeMove.go(s, i, s.slot[i], SiegeMove.MARCH)
	if enemy != -1 and s.note[i] == 0:
		if s.pos[i].distance_squared_to(s.pos[enemy]) <= T.PANIC_M * T.PANIC_M:
			s.note[i] = 1
			s.jolt_team(VILLAGE, s.pos[i], 0.0, T.PANIC_SHOCK, -1, false)


## A routed squad runs out of the far side; at the map edge it is gone when it
## cannot rally again.
static func _run_away(s: SiegeState, i: int) -> void:
	s.foe[i] = s.grid.nearest(s, s.grid.army, s.pos[i], T.RALLY_CLEAR_M, T.RALLY_CLEAR_M)
	if s.pos[i].distance_squared_to(s.goal[i]) > T.ARRIVE_M * T.ARRIVE_M:
		return
	SiegeMove.stand(s, i)
	if s.flag[i] & SiegeState.F_NO_RALLY != 0:
		s.flag[i] |= SiegeState.F_GONE


## Sends a squad that just routed (or a beaten village) away from the army.
static func flee(s: SiegeState, i: int) -> void:
	var away := s.pos[i] - s.front
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var bounds := s.map.bounds.grow(-4.0)
	var exit := (s.pos[i] + away.normalized() * 170.0).clamp(bounds.position, bounds.end)
	SiegeMove.go(s, i, exit, SiegeMove.SPRINT)
