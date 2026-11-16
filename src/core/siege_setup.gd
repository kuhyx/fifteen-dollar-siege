class_name SiegeSetup
extends RefCounted
## Builds one siege from the seed: the village and its buildings, its 2,000
## people, the army in its marching order with the loadout's specials, and the
## night-before beats (abduction, pep talk) that happen before the first tick.

const T = preload("res://src/core/siege_tuning.gd")
const B = preload("res://src/core/buff_tuning.gd")
const K := SiegeSnapshot.Kind
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE
const ROW := 5
const ROW_GAP := Vector2(12.0, 16.0)


static func build(s: SiegeState) -> void:
	_map(s)
	_army(s)
	_specials(s)
	_village(s)
	_night_before(s)


static func _map(s: SiegeState) -> void:
	var m := s.map
	var c := m.village_center
	m.centre_radius = T.CENTRE_R
	m.church = Rect2(c + Vector2(-8.0, -58.0), Vector2(16.0, 26.0))
	m.bell = m.church.get_center()
	m.buildings.append(m.church)
	# The lord's hall, east of the plaza.
	m.buildings.append(Rect2(c + Vector2(30.0, -9.0), Vector2(22.0, 18.0)))
	for i in SiegeSim.BUILDINGS - 2:
		var at := _village_point(s, 0.35, 0.85)
		var size := Vector2(s.rng.randf_range(8.0, 18.0), s.rng.randf_range(8.0, 18.0))
		m.buildings.append(Rect2(at - size / 2.0, size))


static func _village_point(s: SiegeState, near: float, far: float) -> Vector2:
	var reach := s.rng.randf_range(near, far) * s.map.village_radius
	return s.map.village_center + Vector2.from_angle(s.rng.randf() * TAU) * reach


static func _village(s: SiegeState) -> void:
	var m := s.map
	var hall := m.buildings[1].get_center()
	for i in T.CROWDS:
		var home := m.buildings[1 + i % (SiegeSim.BUILDINGS - 1)].get_center()
		var at := home + Vector2(s.rng.randf_range(-9.0, 9.0), s.rng.randf_range(-9.0, 9.0))
		var e := _villager(s, at, K.VILLAGERS, T.CROWD_HEADS)
		var east := Vector2(m.bounds.end.x - 8.0, clampf(at.y, 20.0, m.bounds.end.y - 20.0))
		s.slot[e] = m.bell if at.distance_to(m.bell) < 80.0 else east
	for i in T.MILITIA_SQUADS:
		_villager(s, _village_point(s, 0.2, 0.9), K.MILITIA, SiegeSim.SQUAD_SIZE)
	for i in T.ARCHER_SQUADS:
		_villager(s, _village_point(s, 0.2, 0.7), K.ARCHERS, SiegeSim.SQUAD_SIZE)
	for i in T.RETINUE_SQUADS:
		var e := _villager(s, hall + Vector2(0.0, 12.0 * i - 6.0), K.RETINUE, SiegeSim.SQUAD_SIZE)
		s.wait[e] = 0.0
		s.retinue.append(e)
		s.flag[e] &= ~SiegeState.F_DEAF
		s.morale[e] = minf(s.morale[e] + 0.1, 1.0)
		s.cap[e] = s.morale[e]


static func _villager(s: SiegeState, at: Vector2, kind: int, heads: int) -> int:
	var spirit := s.mods.village_morale + s.rng.randf_range(-T.MORALE_JITTER, T.MORALE_JITTER)
	var e := s.add(at, kind, VILLAGE, heads, clampf(spirit, 0.3, 1.0))
	s.fatigue[e] = s.mods.village_fatigue
	s.wait[e] = s.rng.randf_range(0.05, 1.0)
	s.reload[e] = s.rng.randf_range(B.DEAF_DELAY_MIN_S, B.DEAF_DELAY_MAX_S)
	if s.rng.randf() < s.mods.deaf_share:
		s.flag[e] |= SiegeState.F_DEAF
	var spot := Vector2(s.rng.randf_range(-18.0, 18.0), s.rng.randf_range(-18.0, 18.0))
	s.slot[e] = s.map.village_center + spot
	return e


## The line squads in rows of ROW: golf carts in front, then the bat men, then
## the rest; the first squads on foot drink the potions.
static func _army(s: SiegeState) -> void:
	var mods := s.mods
	var squads := floori(float(mods.men) / SiegeSim.SQUAD_SIZE)
	if mods.catapults > 0:
		squads -= 1  # their men crew the catapults
	var carts := mini(mods.cart_squads, squads)
	var bats := mini(mods.bat_squads, squads - carts)
	var unseen := mods.invisible_squads
	for index in squads:
		var kind := K.MEN
		if index < carts:
			kind = K.GOLF_CARTS
		elif index < carts + bats:
			kind = K.BAT_MEN
		var heads := SiegeSim.SQUAD_SIZE
		if mods.shotgun and index == squads - 1:
			heads -= 1  # one of them carries the shotgun
		var e := _soldier(s, kind, heads, _line_slot(index))
		s.ammo[e] = T.SLING_AMMO
		if kind == K.GOLF_CARTS:
			s.flag[e] |= SiegeState.F_RIDING
		elif unseen > 0:
			unseen -= 1
			s.flag[e] |= SiegeState.F_INVISIBLE
			s.state[e] = SiegeSnapshot.State.HIDDEN
			s.wait[e] = B.POTION_S
		if kind == K.BAT_MEN:
			s.morale[e] = minf(s.morale[e] + B.BAT_MORALE, 1.0)
			s.cap[e] = s.morale[e]


static func _line_slot(index: int) -> Vector2:
	var row := floori(float(index) / ROW)
	return Vector2(-row * ROW_GAP.x, (index % ROW - 2) * ROW_GAP.y)


static func _soldier(s: SiegeState, kind: int, heads: int, slot: Vector2) -> int:
	var jitter := s.rng.randf_range(-T.MORALE_JITTER, T.MORALE_JITTER)
	var spirit := clampf(s.mods.start_morale + s.mods.pep + jitter, 0.3, 1.0)
	var e := s.add(s.map.army_spawn + slot, kind, ARMY, heads, spirit)
	s.slot[e] = slot
	return e


static func _specials(s: SiegeState) -> void:
	var mods := s.mods
	var spawn := s.map.army_spawn
	if mods.shotgun:
		var e := _special(s, K.SHOTGUNNER, 1, Vector2(-6.0, 4.0))
		s.ammo[e] = B.SHOTGUN_SHELLS
	for i in mods.catapults:
		_special(s, K.CATAPULT, B.CATAPULT_CREW, Vector2(-42.0, 52.0 * i - 26.0))
	if mods.emperor:
		s.emperor = _special(s, K.EMPEROR, 1, Vector2(-30.0, 0.0))
	if mods.trumpet:
		s.trumpet = _special(s, K.TRUMPET_BOY, 1, Vector2(12.0, 0.0))
		s.wait[s.trumpet] = B.TRUMPET_PERIOD_S
	for i in mods.medic_squads:
		_special(s, K.MEDICS, SiegeSim.SQUAD_SIZE, Vector2(-22.0, 36.0 * i - 18.0))
	if mods.monster:
		_special(s, K.MONSTER, 1, Vector2(0.0, -48.0))
	for i in mods.moose:
		var e := _special(s, K.MOOSE, 1, Vector2(-25.0, 44.0 + 10.0 * i))
		s.note[e] = B.MOOSE_CHARGES
		s.wait[e] = B.MOOSE_PICK_S * (1.0 + 0.5 * i)
	if mods.wasps:
		_special(s, K.WASPS, B.WASPS, Vector2(4.0, 8.0))
	if mods.band:
		s.band = _special(s, K.ROCK_BAND, B.BAND_HEADS, Vector2(-70.0, 0.0))
	if mods.abducted > 0:
		var e := s.add(s.map.village_center + Vector2(0.0, -30.0), K.UFO, ARMY, 1, 1.0)
		s.specials.append(e)
		s.goal[e] = Vector2(spawn.x + 200.0, s.map.bounds.position.y + 2.0)
		s.speed[e] = B.UFO_SPEED
		s.state[e] = SiegeSnapshot.State.MOVE


static func _special(s: SiegeState, kind: int, heads: int, slot: Vector2) -> int:
	var e := _soldier(s, kind, heads, slot)
	s.specials.append(e)
	return e


## What happened before the first tick, as events in order: the abduction beams,
## then the pep talk.
static func _night_before(s: SiegeState) -> void:
	var left := s.mods.abducted
	var tries := 0
	while left > 0 and tries < 400:
		tries += 1
		var e := _random_villager(s)
		var take := mini(mini(left, B.ABDUCT_BEAM), s.count[e] - 1)
		if take <= 0:
			continue
		s.count[e] -= take
		s.start[e] = s.count[e]
		left -= take
		s.emit_with(SiegeEvent.UFO_ABDUCT, s.pos[e], {"heads": take})
	if s.mods.pep > 0.0:
		s.emit(SiegeEvent.PEP_TALK, s.map.army_spawn)


## A village entity picked with a chance equal to its share of the heads.
static func _random_villager(s: SiegeState) -> int:
	var total := 0
	for i in s.pos.size():
		if s.team[i] == VILLAGE:
			total += s.count[i]
	var pick := s.rng.randi_range(0, total - 1)
	for i in s.pos.size():
		if s.team[i] != VILLAGE:
			continue
		pick -= s.count[i]
		if pick < 0:
			return i
	return 0
