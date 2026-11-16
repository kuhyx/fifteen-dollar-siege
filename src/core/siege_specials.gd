class_name SiegeSpecials
extends RefCounted
## The army's specials with a routine of their own, once per decision step:
## the followers (emperor, trumpet boy, medics, shotgunner, catapult crews),
## the band, the pumpkins in the air and the invisibility potions. The beasts
## (monster, moose, wasps) and the UFO are in SiegeBeasts.

const T = preload("res://src/core/siege_tuning.gd")
const B = preload("res://src/core/buff_tuning.gd")
const ST := SiegeSnapshot.State
const K := SiegeSnapshot.Kind
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE


static func run(s: SiegeState) -> void:
	for i in s.specials:
		if s.count[i] <= 0 or s.flag[i] & SiegeState.F_GONE != 0:
			continue
		match s.kind[i]:
			K.SHOTGUNNER:
				_shotgunner(s, i)
			K.CATAPULT:
				_catapult(s, i)
			K.MEDICS:
				_medics(s, i)
			K.TRUMPET_BOY:
				_trumpet(s, i)
			K.ROCK_BAND:
				_band(s, i)
			K.EMPEROR:
				follow(s, i)
			_:
				SiegeBeasts.act(s, i)
	_pumpkins_land(s)
	_potions(s)


## An invisible squad shows itself: by striking `victim` (an ambush that shakes
## everyone near, friends included) or, with -1, because the potion ran out.
static func reveal(s: SiegeState, i: int, victim: int) -> void:
	s.flag[i] &= ~SiegeState.F_INVISIBLE
	s.state[i] = ST.FIGHT if victim >= 0 else ST.IDLE
	s.emit(SiegeEvent.REVEAL, s.pos[i])
	if victim < 0:
		return
	s.jolt(victim, B.AMBUSH_SHOCK)
	s.jolt_team(VILLAGE, s.pos[i], B.REVEAL_M, B.REVEAL_FOE_SHOCK, victim, false)
	s.jolt_team(ARMY, s.pos[i], B.REVEAL_M, B.REVEAL_FRIEND_SHOCK, i, false)


## Golf carts ram squad e at speed: it loses men and nerve, and now and then a
## driver goes over the handlebars. The riders stay on their carts: every new
## run at an enemy is another ram.
static func crash(s: SiegeState, i: int, e: int) -> void:
	s.emit(SiegeEvent.CART_CRASH, s.pos[e])
	s.jolt(e, B.CART_CRASH_SHOCK)
	SiegeCombat.hit(s, e, s.sample(B.CART_CRASH_DOWN))
	SiegeCombat.hit(s, i, s.sample(B.CART_CRASH_SELF * s.mods.friendly_hurt))


## Keeps entity i at its place around the army; a routed one runs for the start.
## Returns false when it is running.
static func follow(s: SiegeState, i: int) -> bool:
	if s.state[i] == ST.FLEE:
		SiegeMove.go(s, i, s.map.army_spawn + s.slot[i], SiegeMove.SPRINT)
		return false
	var bounds := s.map.bounds
	var dest := (s.anchor + s.slot[i]).clamp(bounds.position, bounds.end)
	if s.pos[i].distance_squared_to(dest) > T.ARRIVE_M * T.ARRIVE_M:
		SiegeMove.go(s, i, dest, SiegeMove.MARCH)
		s.state[i] = ST.MOVE
	else:
		SiegeMove.stand(s, i)
		s.state[i] = ST.IDLE
	return true


static func _shotgunner(s: SiegeState, i: int) -> void:
	if not follow(s, i) or s.ammo[i] <= 0 or s.reload[i] > T.THINK_S:
		return
	var e := s.grid.nearest(s, s.grid.village, s.pos[i], B.SHOTGUN_FAR_M, 0.0)
	if e == -1:
		return
	SiegeMove.stand(s, i)
	SiegeMove.face(s, i, s.pos[e])
	s.state[i] = ST.FIGHT
	s.ammo[i] -= 1
	s.reload[i] = B.SHOTGUN_RELOAD_S
	s.emit_with(SiegeEvent.SHOTGUN_BLAST, s.pos[i], {"to": s.pos[e]})
	if s.blast_tick < 0:
		# Thunder nobody here has heard before: everyone knows, and fears it.
		s.blast_tick = s.tick
		s.fear = B.SHOTGUN_FEAR
		SiegeAlarm.raise(s, s.pos[i])
		s.alarm = 1.0
	var near := s.pos[i].distance_squared_to(s.pos[e]) <= B.SHOTGUN_NEAR_M * B.SHOTGUN_NEAR_M
	s.jolt(e, B.SHOTGUN_FEAR_FLOOR)
	SiegeCombat.hit(s, e, s.sample(B.SHOTGUN_NEAR_DOWN if near else B.SHOTGUN_FAR_DOWN))


## The crew sets up when an armed squad is in range and lobs a pumpkin at it.
static func _catapult(s: SiegeState, i: int) -> void:
	var best := -1
	var best_d := B.CATAPULT_MAX_M * B.CATAPULT_MAX_M
	var low := B.CATAPULT_MIN_M * B.CATAPULT_MIN_M
	if s.state[i] != ST.FLEE:
		for e in s.pos.size():
			if s.team[e] != VILLAGE or s.count[e] <= 0 or s.state[e] == ST.FLEE:
				continue
			if s.flag[e] & SiegeState.F_ARMED == 0:
				continue
			var d := s.pos[i].distance_squared_to(s.pos[e])
			if d >= low and d < best_d and not _friends_near(s, e):
				best_d = d
				best = e
	if best == -1:
		follow(s, i)
		return
	SiegeMove.stand(s, i)
	SiegeMove.face(s, i, s.pos[best])
	s.state[i] = ST.FIGHT
	if s.reload[i] > T.THINK_S:
		return
	s.reload[i] = B.CATAPULT_RELOAD_S
	var miss := Vector2.from_angle(s.rng.randf() * TAU) * s.rng.randf() * B.PUMPKIN_SCATTER_M
	var land := s.pos[best] + miss
	var due := s.tick + SiegeState.ticks(B.PUMPKIN_FLIGHT_S)
	s.pumpkins.append({"tick": due, "pos": land, "from": s.pos[i]})
	s.emit_with(SiegeEvent.PUMPKIN_LAUNCH, s.pos[i], {"to": land})


## True when an army entity stands too near village squad e to lob a pumpkin.
static func _friends_near(s: SiegeState, e: int) -> bool:
	var friend := s.grid.nearest(s, s.grid.army, s.pos[e], B.PUMPKIN_SAFE_M, B.PUMPKIN_SAFE_M)
	return friend != -1


## A pumpkin bursts on whoever stands there, friend or foe.
static func _pumpkins_land(s: SiegeState) -> void:
	var splash2 := B.PUMPKIN_SPLASH_M * B.PUMPKIN_SPLASH_M
	for index in range(s.pumpkins.size() - 1, -1, -1):
		var pumpkin := s.pumpkins[index]
		if pumpkin["tick"] > s.tick:
			continue
		s.pumpkins.remove_at(index)
		var at: Vector2 = pumpkin["pos"]
		s.emit_with(SiegeEvent.PUMPKIN_SPLAT, at, {"from": pumpkin["from"]})
		for e in s.pos.size():
			if s.count[e] <= 0 or s.flag[e] & SiegeState.F_GONE != 0:
				continue
			if at.distance_squared_to(s.pos[e]) > splash2:
				continue
			var down := B.PUMPKIN_DOWN / SiegeKinds.TOUGH[s.kind[e]]
			if s.team[e] == ARMY:
				down *= s.mods.friendly_hurt
			s.jolt(e, B.PUMPKIN_SHOCK)
			SiegeCombat.hit(s, e, s.sample(down))


## Doctors stay behind the line and run to whoever in reach needs them: the
## nearest squad with lightly wounded men (their oath does not ask which
## side), else the most shaken squad of their own army. A treatment puts one
## wounded man back on his feet and steadies the squad.
static func _medics(s: SiegeState, i: int) -> void:
	if not follow(s, i) or s.reload[i] > T.THINK_S:
		return
	var reach2 := B.MEDIC_REACH_M * B.MEDIC_REACH_M
	var wounded := -1
	var wounded_d := reach2
	var shaken := -1
	var worst := B.MEDIC_NERVES
	for e in s.pos.size():
		if e == i or s.count[e] <= 0 or s.flag[e] & SiegeState.F_GONE != 0:
			continue
		var d := s.pos[i].distance_squared_to(s.pos[e])
		if d > reach2:
			continue
		if s.hurt[e] > 0 and d < wounded_d:
			wounded_d = d
			wounded = e
		var nerves := s.cap[e] - s.morale[e]
		var ours := s.team[e] == ARMY and s.flag[e] & SiegeState.F_WAVERS != 0
		if ours and nerves > worst:
			worst = nerves
			shaken = e
	var patient := wounded if wounded != -1 else shaken
	if patient == -1:
		return
	s.reload[i] = B.HEAL_S
	var heads := mini(s.hurt[patient], 1)
	s.hurt[patient] -= heads
	s.count[patient] += heads
	s.cap[patient] = minf(s.cap[patient] + B.HEAL_CAP, 1.0)
	s.morale[patient] = minf(s.morale[patient] + B.HEAL_MORALE, s.cap[patient])
	var data := {"team": s.team[patient], "entity": patient, "heads": heads}
	s.emit_with(SiegeEvent.HEAL, s.pos[patient], data)


static func _trumpet(s: SiegeState, i: int) -> void:
	follow(s, i)
	s.wait[i] -= T.THINK_S
	if s.wait[i] > 0.0:
		return
	s.wait[i] = B.TRUMPET_PERIOD_S
	s.emit(SiegeEvent.TRUMPET_CALL, s.pos[i])
	var reach2 := B.TRUMPET_M * B.TRUMPET_M
	for e in s.pos.size():
		if s.team[e] != ARMY or s.count[e] <= 0 or s.flag[e] & SiegeState.F_WAVERS == 0:
			continue
		if s.pos[i].distance_squared_to(s.pos[e]) > reach2:
			continue
		var lift := B.TRUMPET_RALLY if s.state[e] == ST.FLEE else B.TRUMPET_CALL
		s.morale[e] = minf(s.morale[e] + lift, maxf(s.cap[e], s.morale[e]))


static func _band(s: SiegeState, i: int) -> void:
	s.wait[i] -= T.THINK_S
	if s.wait[i] > 0.0:
		return
	s.wait[i] = B.BAND_PERIOD_S
	s.state[i] = ST.FIGHT
	s.emit(SiegeEvent.BAND_RIFF, s.pos[i])


static func _potions(s: SiegeState) -> void:
	if s.mods.invisible_squads == 0 or s.clock_s() > B.POTION_S + 1.0:
		return
	for i in s.pos.size():
		if s.flag[i] & SiegeState.F_INVISIBLE == 0 or s.count[i] <= 0:
			continue
		s.wait[i] -= T.THINK_S
		if s.wait[i] <= 0.0:
			reveal(s, i, -1)
