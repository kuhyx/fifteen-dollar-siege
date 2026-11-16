class_name SiegeArmy
extends RefCounted
## The army's line squads (men, bat men, golf carts): the default plan and the
## player's orders, one decision per squad every decision step.
##   default  march on the village, walk and sling when a target is in range,
##            fight in melee, take the plaza
##   CHARGE   one rush: every squad sprints at the nearest enemy without
##            slinging, and its first exchange hits harder, the more the
##            fresher it is; after that it fights on as the default plan
##   RALLY    form up around the flag and hold there: morale and breath come
##            back faster, slings answer whoever comes near
##   RETREAT  the same at the start line, reached at a sprint
## A routed squad runs for the flag (RALLY) or the start line.

const T = preload("res://src/core/siege_tuning.gd")
const ST := SiegeSnapshot.State
const ARMY := SiegeSnapshot.Team.ARMY
const RALLY := 0
const CHARGE := 1
const RETREAT := 2
## Share of the marching formation's width kept at a flag or in the plaza.
const TIGHT := 0.5


static func run(s: SiegeState) -> void:
	census(s)
	var drill := s.clock_s() < s.mods.drill_s
	var spawn := s.map.army_spawn
	var flag := s.flag
	var count := s.count
	for i in s.pos.size():
		var f := flag[i]
		if f & SiegeState.F_LINE == 0 or count[i] <= 0 or f & SiegeState.F_GONE != 0:
			continue
		var enemy := s.grid.nearest(s, s.grid.village, s.pos[i], T.ACQUIRE_M, T.CHASE_M)
		if s.state[i] == ST.FLEE:
			_run_away(s, i, enemy)
			continue
		if f & SiegeState.F_INVISIBLE != 0:
			enemy = _quarry(s, i, enemy)
		var mode := SiegeState.NO_ORDER if f & SiegeState.F_IGNORE != 0 else s.order
		if drill or mode == RETREAT:
			_hold_at(s, i, spawn, enemy, SiegeMove.MARCH if drill else SiegeMove.SPRINT)
		elif mode == RALLY:
			_hold_at(s, i, s.order_pos, enemy, SiegeMove.MARCH)
		else:
			# A charge is one rush: once the squad has struck, it fights on as
			# the default plan would.
			_advance(s, i, enemy, mode == CHARGE and s.flag[i] & SiegeState.F_CHARGING != 0)
		if s.flag[i] & SiegeState.F_INVISIBLE != 0:
			s.state[i] = ST.HIDDEN


## The men nobody can see go for the lord: the nearest retinue squad that still
## stands, else `enemy`.
static func _quarry(s: SiegeState, i: int, enemy: int) -> int:
	var best := enemy
	var best_d := INF
	for e in s.retinue:
		if s.count[e] <= 0 or s.state[e] == ST.FLEE:
			continue
		var d := s.pos[i].distance_squared_to(s.pos[e])
		if d < best_d:
			best_d = d
			best = e
	return best


## Where the army stands: the middle of its standing line squads, the point
## its followers form up around, and the entity the village moves against.
static func census(s: SiegeState) -> void:
	var sum := Vector2.ZERO
	var heads := 0
	var squads := 0
	var centre := s.map.village_center
	var reach := s.map.village_radius + T.LEASH_M
	var nearest := reach * reach
	var runner := -1
	var runner_d := nearest
	s.threat = -1
	for i in s.pos.size():
		if s.team[i] != ARMY or s.count[i] <= 0 or s.flag[i] & SiegeState.F_GONE != 0:
			continue
		var st := s.state[i]
		var d := s.pos[i].distance_squared_to(centre)
		if st == ST.FLEE:
			if d < runner_d:
				runner_d = d
				runner = i
			continue
		if s.flag[i] & SiegeState.F_LINE != 0:
			sum += s.pos[i] * s.count[i]
			heads += s.count[i]
			squads += 1
		if st == ST.HIDDEN or s.flag[i] & SiegeState.F_TARGET == 0:
			continue
		if d < nearest:
			nearest = d
			s.threat = i
	if s.threat == -1:
		s.threat = runner  # nobody stands in reach: the village runs the routed down
	s.standing = squads
	s.front = sum / heads if heads > 0 else s.map.army_spawn
	s.anchor = s.front
	if s.order == RALLY:
		s.anchor = s.order_pos
	elif s.order == RETREAT or s.clock_s() < s.mods.drill_s or heads == 0:
		s.anchor = s.map.army_spawn


## March (or sprint) on the nearest enemy, else on the plaza.
static func _advance(s: SiegeState, i: int, enemy: int, charge: bool) -> void:
	s.flag[i] &= ~SiegeState.F_HOLDING
	s.foe[i] = enemy
	var p := s.pos[i]
	var fast := charge
	if enemy == -1:
		var dest := s.map.village_center + s.slot[i] * TIGHT
		if p.distance_squared_to(dest) <= T.ARRIVE_M * T.ARRIVE_M:
			SiegeMove.stand(s, i)
			s.state[i] = ST.IDLE
		else:
			SiegeMove.go(s, i, dest, SiegeMove.SPRINT if fast else SiegeMove.MARCH)
			s.state[i] = ST.MOVE
		return
	var at := s.pos[enemy]
	var d2 := p.distance_squared_to(at)
	if d2 <= T.CONTACT_M * T.CONTACT_M:
		SiegeMove.stand(s, i)
		SiegeMove.face(s, i, at)
		s.state[i] = ST.FIGHT
		return
	var pace := SiegeMove.MARCH
	if s.flag[i] & SiegeState.F_RIDING != 0:
		pace = SiegeMove.SPRINT  # golf carts ram home on every run
		s.flag[i] |= SiegeState.F_CHARGING
	elif fast:
		pace = SiegeMove.SPRINT
	elif s.state[enemy] == ST.FLEE:
		pace = SiegeMove.SPRINT  # run a routed enemy down
	elif _may_sling(s, i, enemy, d2):
		pace = SiegeMove.WALK
	SiegeMove.go(s, i, at, pace)
	s.state[i] = ST.MOVE


## True when squad i would stop to sling at `enemy`: stones left, in range, and
## not against archers (they outrange a slingshot: close with them instead).
static func _may_sling(s: SiegeState, i: int, enemy: int, d2: float) -> bool:
	var reach := s.mods.sling_range
	return (
		s.ammo[i] > 0
		and d2 <= reach * reach
		and s.flag[i] & SiegeState.F_INVISIBLE == 0
		and s.kind[enemy] != SiegeSnapshot.Kind.ARCHERS
	)


## Form up around `anchor` and hold: fight or sling at whoever comes near.
static func _hold_at(s: SiegeState, i: int, anchor: Vector2, enemy: int, pace: int) -> void:
	var bounds := s.map.bounds
	var home := (anchor + s.slot[i] * TIGHT).clamp(bounds.position, bounds.end)
	if s.pos[i].distance_squared_to(home) > 36.0:
		s.flag[i] &= ~(SiegeState.F_HOLDING | SiegeState.F_CHARGING)
		s.foe[i] = -1
		SiegeMove.go(s, i, home, pace)
		s.state[i] = ST.MOVE
		return
	s.flag[i] |= SiegeState.F_HOLDING
	s.foe[i] = enemy
	SiegeMove.stand(s, i)
	s.state[i] = ST.IDLE
	if enemy == -1:
		return
	var at := s.pos[enemy]
	SiegeMove.face(s, i, at)
	var reach := maxf(s.mods.sling_range, T.CONTACT_M)
	if s.pos[i].distance_squared_to(at) <= reach * reach:
		s.state[i] = ST.FIGHT


## A routed squad sprints for the flag or the start line; one that will not
## rally again leaves by the edge behind the start line.
static func _run_away(s: SiegeState, i: int, enemy: int) -> void:
	s.foe[i] = enemy
	var refuge := s.map.army_spawn
	var ordered := s.order == RALLY or s.order == RETREAT
	if s.order == RALLY:
		refuge = s.order_pos
	refuge += s.slot[i] * TIGHT
	if s.flag[i] & SiegeState.F_NO_RALLY != 0:
		refuge = Vector2(s.map.bounds.position.x + 2.0, s.pos[i].y)
	if s.pos[i].distance_squared_to(refuge) > 36.0:
		s.flag[i] &= ~SiegeState.F_HOLDING
		SiegeMove.go(s, i, refuge, SiegeMove.SPRINT)
		return
	SiegeMove.stand(s, i)
	if s.flag[i] & SiegeState.F_NO_RALLY != 0:
		s.flag[i] |= SiegeState.F_GONE
	elif ordered:
		s.flag[i] |= SiegeState.F_HOLDING
