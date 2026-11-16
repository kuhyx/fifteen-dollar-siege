class_name SiegeBeasts
extends RefCounted
## The specials nobody commands: the stitched monster (strong, slow, sometimes
## turns on whoever is nearest), the moose (charge, bluff, wander off), the
## wasps (a cloud that hops from squad to squad, either side) and the UFO
## (leaves after the night's work). One decision each per decision step.

const T = preload("res://src/core/siege_tuning.gd")
const B = preload("res://src/core/buff_tuning.gd")
const ST := SiegeSnapshot.State
const K := SiegeSnapshot.Kind
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE
## Wasp `note` values: still in the carried nest, or loose.
const CARRIED := 0
const LOOSE := 1


static func act(s: SiegeState, i: int) -> void:
	match s.kind[i]:
		K.MONSTER:
			_monster(s, i)
		K.MOOSE:
			_moose(s, i)
		K.WASPS:
			_wasps(s, i)
		K.UFO:
			if s.pos[i].distance_squared_to(s.goal[i]) < 1.0:
				SiegeMove.stand(s, i)
				s.state[i] = ST.HIDDEN
				s.flag[i] |= SiegeState.F_GONE


## The nearest standing squad of either side within `reach` of entity i.
static func _anyone(s: SiegeState, i: int, reach: float, skip: int) -> int:
	var p := s.pos[i]
	var a := s.grid.nearest(s, s.grid.village, p, reach, 0.0, skip)
	var b := s.grid.nearest(s, s.grid.army, p, reach, 0.0, i if skip == -1 else skip)
	if b == i:
		b = -1
	if a == -1 or b == -1:
		return maxi(a, b)
	return a if p.distance_squared_to(s.pos[a]) <= p.distance_squared_to(s.pos[b]) else b


static func _monster(s: SiegeState, i: int) -> void:
	_spook(s, i)
	if s.wait[i] > 0.0:
		s.wait[i] -= T.THINK_S
	elif s.rng.randf() < B.MONSTER_BERSERK:
		s.wait[i] = B.MONSTER_BERSERK_S
	var enemy := -1
	if s.wait[i] > 0.0:
		enemy = _anyone(s, i, T.ACQUIRE_M, -1)
	else:
		enemy = s.grid.nearest(s, s.grid.village, s.pos[i], T.ACQUIRE_M, T.CHASE_M)
	s.foe[i] = enemy
	if enemy == -1:
		SiegeMove.go(s, i, s.map.village_center, SiegeMove.MARCH)
		s.state[i] = ST.MOVE
	elif s.pos[i].distance_squared_to(s.pos[enemy]) <= T.CONTACT_M * T.CONTACT_M:
		SiegeMove.stand(s, i)
		SiegeMove.face(s, i, s.pos[enemy])
		s.state[i] = ST.FIGHT
	else:
		SiegeMove.go(s, i, s.pos[enemy], SiegeMove.MARCH)
		s.state[i] = ST.MOVE


## Every village squad takes fright the first time the monster comes near.
static func _spook(s: SiegeState, i: int) -> void:
	var reach2 := B.MONSTER_FEAR_M * B.MONSTER_FEAR_M
	for e in s.pos.size():
		if s.team[e] != VILLAGE or s.flag[e] & SiegeState.F_SPOOKED != 0 or s.count[e] <= 0:
			continue
		if s.pos[i].distance_squared_to(s.pos[e]) <= reach2:
			s.flag[e] |= SiegeState.F_SPOOKED
			s.jolt(e, B.MONSTER_FEAR)


static func _moose(s: SiegeState, i: int) -> void:
	if s.note[i] <= 0:
		# Done with people: it wanders off the field.
		var edge := s.map.bounds.position.y + 2.0
		if s.pos[i].y > s.map.bounds.get_center().y:
			edge = s.map.bounds.end.y - 2.0
		s.flag[i] |= SiegeState.F_GONE
		s.state[i] = ST.FLEE
		SiegeMove.go(s, i, Vector2(s.pos[i].x, edge), SiegeMove.MARCH)
		return
	var target := s.foe[i]
	if target >= 0 and s.count[target] > 0:
		_moose_charge(s, i, target)
		return
	s.foe[i] = -1
	s.wait[i] -= T.THINK_S
	if s.wait[i] > 0.0:
		return
	s.wait[i] = B.MOOSE_PICK_S
	if s.rng.randf() < B.MOOSE_BLUFF:
		SiegeMove.stand(s, i)
		s.state[i] = ST.IDLE
		return
	var heads := s.grid.army if s.rng.randf() < B.MOOSE_FRIENDLY else s.grid.village
	target = s.grid.nearest(s, heads, s.pos[i], T.ACQUIRE_M, T.ACQUIRE_M, i)
	s.foe[i] = target
	if target == -1:
		SiegeSpecials.follow(s, i)  # nobody to charge: it trots along


## Runs at `target`; on reaching it tramples through and runs on.
static func _moose_charge(s: SiegeState, i: int, target: int) -> void:
	var to := s.pos[target] - s.pos[i]
	if to.length_squared() > T.CONTACT_M * T.CONTACT_M:
		SiegeMove.go(s, i, s.pos[target], SiegeMove.MARCH)
		s.state[i] = ST.MOVE
		return
	s.note[i] -= 1
	s.foe[i] = -1
	s.wait[i] = B.MOOSE_PICK_S
	s.emit(SiegeEvent.MOOSE_CHARGE, s.pos[target])
	s.jolt(target, B.MOOSE_SHOCK)
	var down := B.MOOSE_DOWN * SiegeCombat.hurt_factor(s, target, false)
	SiegeCombat.hit(s, target, s.sample(down))
	var onward := to.normalized() if to != Vector2.ZERO else Vector2.RIGHT
	SiegeMove.go(s, i, s.pos[i] + onward * 25.0, SiegeMove.MARCH)
	s.state[i] = ST.MOVE


static func _wasps(s: SiegeState, i: int) -> void:
	if s.note[i] == CARRIED:
		SiegeSpecials.follow(s, i)
		var first := s.grid.nearest(s, s.grid.village, s.pos[i], B.WASP_RELEASE_M, 0.0)
		if first == -1:
			return
		# The nest is thrown.
		s.note[i] = LOOSE
		s.foe[i] = first
		s.wait[i] = B.WASP_HOP_S
		s.pos[i] = s.pos[first]
	s.wait[i] -= T.THINK_S
	if s.tick % SiegeState.ticks(1.0) == 0:
		s.count[i] = maxi(s.count[i] - B.WASP_LOSS_PER_S, 0)
		s.emit(SiegeEvent.WASP_SWARM, s.pos[i])
	if s.count[i] <= 0:
		s.state[i] = ST.DOWN
		s.foe[i] = -1
		SiegeMove.stand(s, i)
		return
	_sting(s, i)
	var victim := s.foe[i]
	if s.wait[i] <= 0.0 or victim < 0 or s.count[victim] <= 0:
		# On to the nearest villagers; now and then to whoever is nearest.
		s.wait[i] = B.WASP_HOP_S
		var next := -1
		if s.rng.randf() < B.WASP_ANYONE:
			next = _anyone(s, i, B.WASP_HOP_M, victim)
		else:
			next = s.grid.nearest(s, s.grid.village, s.pos[i], B.WASP_HOP_M, 0.0, victim)
		if next != -1:
			victim = next
			s.foe[i] = next
	s.state[i] = ST.FIGHT
	if victim >= 0:
		SiegeMove.go(s, i, s.pos[victim], SiegeMove.MARCH)


## Everybody in the cloud is stung: shaken, and too busy swatting to fight.
static func _sting(s: SiegeState, i: int) -> void:
	var cloud2 := B.WASP_CLOUD_M * B.WASP_CLOUD_M
	var dazed := s.tick + T.THINK_TICKS + 1
	for e in s.pos.size():
		if e == i or s.count[e] <= 0 or s.flag[e] & SiegeState.F_GONE != 0:
			continue
		if s.pos[i].distance_squared_to(s.pos[e]) > cloud2:
			continue
		if s.kind[e] == K.VILLAGERS:
			SiegeVillage.scatter(s, e)
			continue
		s.jolt(e, B.WASP_STING)
		s.daze[e] = dazed
		s.hit[e] = s.tick
