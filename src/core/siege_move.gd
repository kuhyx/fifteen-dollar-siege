class_name SiegeMove
extends RefCounted
## Movement: the decision step picks a destination and a pace for an entity
## (go / stand); every tick each moving entity steps toward its destination.

const T = preload("res://src/core/siege_tuning.gd")
const WALK := 1
const MARCH := 2
const SPRINT := 3


## Sends entity i to `dest` (kept on the map) at `pace`: its kind's march speed,
## scaled for a walk or a sprint, slowed by fatigue and by the army's armour.
## Men still on their golf carts keep pace with the rest, sprint at cart speed
## and do not tire.
static func go(s: SiegeState, i: int, dest: Vector2, pace: int) -> void:
	var v := SiegeKinds.SPEED[s.kind[i]]
	var f := s.flag[i]
	if f & SiegeState.F_RIDING != 0 and pace >= SPRINT:
		v = BuffTuning.CART_SPEED
	elif f & SiegeState.F_RIDING != 0:
		v *= s.mods.speed if pace == MARCH else T.WALK_SHARE  # driving beside the men
	else:
		if pace == WALK:
			v *= T.WALK_SHARE
		elif pace == SPRINT:
			v *= T.SPRINT_SHARE
		v *= 1.0 - T.FATIGUE_SLOW * s.fatigue[i]
		if f & SiegeState.F_WAVERS != 0 and s.team[i] == SiegeSnapshot.Team.ARMY:
			v *= s.mods.speed
	var bounds := s.map.bounds
	s.goal[i] = dest.clamp(bounds.position, bounds.end)
	s.pace[i] = pace
	s.speed[i] = v


static func stand(s: SiegeState, i: int) -> void:
	s.speed[i] = 0.0
	s.pace[i] = 0


## Turns entity i toward `at` without moving it.
static func face(s: SiegeState, i: int, at: Vector2) -> void:
	var to := at - s.pos[i]
	if to != Vector2.ZERO:
		s.facing[i] = to.angle()


## One tick: every entity with a speed steps toward its destination.
static func run(s: SiegeState) -> void:
	var pos := s.pos
	var goal := s.goal
	var speed := s.speed
	var facing := s.facing
	var dt := T.STEP_S
	for i in pos.size():
		var v := speed[i]
		if v <= 0.0:
			continue
		var to := goal[i] - pos[i]
		var d2 := to.length_squared()
		if d2 < 0.01:
			continue
		var d := sqrt(d2)
		var step := v * dt
		if step >= d:
			pos[i] = goal[i]
		else:
			pos[i] += to * (step / d)
		facing[i] = to.angle()
