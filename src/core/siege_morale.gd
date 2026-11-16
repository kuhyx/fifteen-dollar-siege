class_name SiegeMorale
extends RefCounted
## Fatigue, morale, rout and rally, once per decision step. A squad whose felt
## morale (its own plus its side's aura) falls under ROUT_AT runs; one that
## recovered to RALLY_AT with no enemy near comes back, each time with a lower
## ceiling, until it leaves for good. The side's morale is what its standing
## fighters still carry, relative to the start.

const T = preload("res://src/core/siege_tuning.gd")
const B = preload("res://src/core/buff_tuning.gd")
const ST := SiegeSnapshot.State
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE


static func run(s: SiegeState) -> void:
	_auras(s)
	var totals := _sweep(s, true)
	s.army_morale = totals[0] / s.army_base if s.army_base > 0.0 else 0.0
	s.village_morale = totals[1] / s.village_base if s.village_base > 0.0 else 0.0


## Sets the start values the side morales are measured against.
static func baseline(s: SiegeState) -> void:
	_auras(s)
	var totals := _sweep(s, false)
	s.army_base = totals[0]
	s.village_base = totals[1]


## Entity e lost its last head.
static func wiped(s: SiegeState, e: int) -> void:
	s.state[e] = ST.DOWN
	s.foe[e] = -1
	SiegeMove.stand(s, e)
	s.emit_with(SiegeEvent.SQUAD_WIPED, s.pos[e], {"team": s.team[e]})
	s.jolt_team(s.team[e], s.pos[e], T.CONTAGION_M, T.CONTAGION, e, false)
	if e == s.emperor:
		s.jolt_team(ARMY, s.pos[e], 0.0, B.EMPEROR_FALL_SHOCK, e, false)
	elif e == s.trumpet:
		s.jolt_team(ARMY, s.pos[e], 0.0, B.TRUMPET_FALL_SHOCK, e, false)


static func rout(s: SiegeState, i: int) -> void:
	if s.flag[i] & SiegeState.F_INVISIBLE != 0:
		SiegeSpecials.reveal(s, i, -1)
	s.state[i] = ST.FLEE
	s.cap[i] *= T.ROUT_CAP_SHARE
	s.flag[i] &= ~(SiegeState.F_HOLDING | SiegeState.F_CHARGING)
	var scared := s.team[i] == VILLAGE and s.fear > 0.0
	if s.cap[i] < T.RALLY_AT or scared:
		s.flag[i] |= SiegeState.F_NO_RALLY
	s.emit_with(SiegeEvent.SQUAD_ROUT, s.pos[i], {"team": s.team[i]})
	s.jolt_team(s.team[i], s.pos[i], T.CONTAGION_M, T.CONTAGION, i, false)
	SiegeCombat.parting_blows(s, i)
	if s.count[i] <= 0:
		return
	if s.team[i] == VILLAGE:
		SiegeVillage.flee(s, i)
	else:
		SiegeMove.go(s, i, s.map.army_spawn, SiegeMove.SPRINT)


## What the living leaders and the music give every squad of their side; the
## fall of the lord's retinue shakes the village once.
static func _auras(s: SiegeState) -> void:
	var aura := 0.0
	if s.emperor >= 0 and s.count[s.emperor] > 0:
		aura += B.EMPEROR_AURA
	if s.trumpet >= 0 and s.count[s.trumpet] > 0:
		aura += B.TRUMPET_AURA
	if s.band >= 0 and s.count[s.band] > 0:
		aura += B.BAND_AURA
	s.army_aura = aura
	s.medics_up = false
	if s.mods.medic_squads > 0:
		for e in s.specials:
			var medic := s.kind[e] == SiegeSnapshot.Kind.MEDICS
			if medic and s.count[e] > 0 and s.state[e] != ST.FLEE:
				s.medics_up = true
	if s.fear > 0.0:
		s.fear = maxf(s.fear - B.SHOTGUN_FEAR * T.THINK_S / B.SHOTGUN_FEAR_S, 0.0)
	if s.lord_fell:
		return
	for e in s.retinue:
		if s.count[e] > 0 and s.state[e] != ST.FLEE:
			s.village_aura = T.LORD_AURA
			return
	s.lord_fell = true
	s.village_aura = 0.0
	s.jolt_team(VILLAGE, s.map.village_center, 0.0, T.LORD_FALL_SHOCK, -1, false)


## One pass over every squad that can waver: tire or rest, recover, rout or
## rally (when `live`), and add up what each side's standing fighters carry.
## Also counts the heads in the plaza. Returns [army, village].
static func _sweep(s: SiegeState, live: bool) -> Array[float]:
	var army := 0.0
	var village := 0.0
	var quiet := s.tick - SiegeState.ticks(T.QUIET_S)
	var pep_step := 0.0
	if live and s.mods.pep > 0.0 and s.clock_s() <= B.PEP_FADE_S:
		pep_step = s.mods.pep * T.THINK_S / B.PEP_FADE_S
	var centre := s.map.village_center
	var plaza2 := T.CENTRE_R * T.CENTRE_R
	var plaza_army := 0.0
	var plaza_village := 0
	var flag := s.flag
	var count := s.count
	var team := s.team
	var state := s.state
	var morale := s.morale
	var cap := s.cap
	var pos := s.pos
	var fear := s.fear
	var skip := SiegeState.F_GONE
	for i in pos.size():
		var f := flag[i]
		if count[i] <= 0 or f & skip != 0 or f & SiegeState.F_WAVERS == 0:
			continue
		var side := team[i]
		if live:
			_tire(s, i, f)
			_recover(s, i, quiet, pep_step)
		var felt := morale[i]
		if side == ARMY:
			# A leader steadies men who still have some nerve of their own.
			felt += s.army_aura * minf(felt / B.AURA_NEEDS, 1.0)
		else:
			felt += s.village_aura
		if side == VILLAGE and f & SiegeState.F_DEAF == 0:
			felt -= fear
		var st := state[i]
		if live and st == ST.FLEE:
			if felt >= T.RALLY_AT and f & SiegeState.F_NO_RALLY == 0 and _clear(s, i):
				state[i] = ST.IDLE
				st = ST.IDLE
				s.emit_with(SiegeEvent.SQUAD_RALLY, pos[i], {"team": side})
		elif live and felt < T.ROUT_AT:
			rout(s, i)
			st = ST.FLEE
			f = flag[i]
		if f & SiegeState.F_FIGHTER == 0 or count[i] <= 0:
			continue
		var weight := count[i] * clampf(felt, 0.0, 1.0)
		if st == ST.FLEE:
			# Running, but it may come back: half of what it could still carry.
			if f & SiegeState.F_NO_RALLY != 0:
				continue
			weight = count[i] * cap[i] * T.ROUTED_WEIGHT
		var inside := st != ST.FLEE and pos[i].distance_squared_to(centre) <= plaza2
		if side == ARMY:
			# The unseen hold the plaza but not the line: an army whose visible
			# men are gone is routed.
			if st != ST.HIDDEN:
				army += weight
			if inside:
				plaza_army += count[i] * (B.UNSEEN_HOLD if st == ST.HIDDEN else 1.0)
		else:
			village += weight
			if inside and f & SiegeState.F_ARMED != 0:
				plaza_village += count[i]
	s.plaza_army = int(plaza_army)
	s.plaza_village = plaza_village
	return [army, village]


static func _tire(s: SiegeState, i: int, f: int) -> void:
	var pace := s.pace[i]
	var rate := -T.REST
	if s.state[i] == ST.FIGHT:
		rate = T.TIRE_FIGHT
	elif pace == SiegeMove.SPRINT:
		rate = T.TIRE_SPRINT
	elif pace == SiegeMove.MARCH:
		rate = T.TIRE_MARCH
	elif pace == SiegeMove.WALK:
		rate = 0.0
	if f & SiegeState.F_RIDING != 0 and pace >= SiegeMove.WALK:
		rate = -T.REST * 0.5
	if rate > 0.0 and s.team[i] == ARMY:
		rate *= s.mods.tire
	s.fatigue[i] = clampf(s.fatigue[i] + rate * T.THINK_S, 0.0, 1.0)


## Squad i's morale after this step: the fading pep talk, being mobbed, and
## recovery when nobody has hit it for a while.
static func _recover(s: SiegeState, i: int, quiet: int, pep_step: float) -> void:
	var ceiling := s.cap[i]
	if pep_step > 0.0 and s.team[i] == ARMY:
		ceiling -= pep_step
		s.cap[i] = ceiling
	if s.mobbed[i] >= 2:
		s.jolt(i, T.GANG_SHOCK * T.THINK_S * (s.mobbed[i] - 1))
	var m := s.morale[i]
	if m < ceiling and s.hit[i] < quiet and s.state[i] != ST.FIGHT:
		var rate := T.RECOVER_PER_S * T.THINK_S
		if s.flag[i] & SiegeState.F_HOLDING != 0:
			rate *= T.FLAG_RECOVER
		m = minf(m + rate, ceiling)
	s.morale[i] = minf(m, maxf(ceiling, 0.0))


## No enemy near enough to stop squad i from rallying.
static func _clear(s: SiegeState, i: int) -> bool:
	var e := s.foe[i]
	if e < 0 or s.count[e] <= 0:
		return true
	return s.pos[i].distance_squared_to(s.pos[e]) > T.RALLY_CLEAR_M * T.RALLY_CLEAR_M
