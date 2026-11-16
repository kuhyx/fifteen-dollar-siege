class_name SiegeCombat
extends RefCounted
## One decision step of fighting. Every entity with an enemy either trades
## blows (within CONTACT_M) or shoots (slings, bows) when it is in range and
## loaded. Casualties are drawn from an expected value; each one shakes the
## squad that took it (SiegeState.jolt), and a routing squad is cut down faster.

const T = preload("res://src/core/siege_tuning.gd")
const B = preload("res://src/core/buff_tuning.gd")
const ST := SiegeSnapshot.State
const K := SiegeSnapshot.Kind
const ARMY := SiegeSnapshot.Team.ARMY
const VILLAGE := SiegeSnapshot.Team.VILLAGE
## Ticks between two MELEE_CLASH events of one squad.
const CLASH_TICKS := 15


static func run(s: SiegeState) -> void:
	var contact2 := T.CONTACT_M * T.CONTACT_M
	var foe := s.foe
	var count := s.count
	var reload := s.reload
	var pos := s.pos
	var state := s.state
	s.mobbed.fill(0)
	for i in pos.size():
		var wait := reload[i]
		if wait > 0.0:
			reload[i] = wait - T.THINK_S
		var e := foe[i]
		if e < 0 or count[i] <= 0 or count[e] <= 0 or state[i] == ST.FLEE:
			continue
		var d2 := pos[i].distance_squared_to(pos[e])
		if d2 <= contact2:
			_melee(s, i, e)
		elif wait <= T.THINK_S:
			_shoot(s, i, e, d2)


## Puts `heads` of entity e down: some only lightly wounded, the squad shaken
## by its losses, wiped when nobody is left. Crowds are never hit: they scatter.
static func hit(s: SiegeState, e: int, heads: int) -> void:
	if s.kind[e] == K.VILLAGERS:
		SiegeVillage.scatter(s, e)
		return
	heads = mini(heads, s.count[e])
	if heads <= 0:
		return
	s.count[e] -= heads
	s.hit[e] = s.tick
	s.hurt[e] += s.sample(heads * T.LIGHT_WOUND_SHARE)
	if s.team[e] == VILLAGE and s.flag[e] & SiegeState.F_ARMED == 0:
		# Caught at home: up in arms at once, and shaken.
		s.flag[e] |= SiegeState.F_ALERTED | SiegeState.F_ARMED
		s.reload[e] = 0.0
		s.jolt(e, T.SURPRISE_SHOCK)
	var dread := s.rng.randf_range(1.0 - T.SHOCK_SPREAD, 1.0 + T.SHOCK_SPREAD)
	if s.medics_up and s.team[e] == ARMY:
		dread *= B.MEDIC_CALM
	s.jolt(e, T.CAS_SHOCK * dread * heads / s.start[e])
	if s.count[e] <= 0:
		SiegeMorale.wiped(s, e)


## Factor on melee (ranged: `ranged`) damage entity e takes: its toughness, and
## for the army's men their armour.
static func hurt_factor(s: SiegeState, e: int, ranged: bool) -> float:
	var out := 1.0 / SiegeKinds.TOUGH[s.kind[e]]
	if s.team[e] != ARMY or s.flag[e] & SiegeState.F_WAVERS == 0:
		return out
	out *= s.mods.ranged_hurt if ranged else s.mods.melee_hurt
	if s.mods.cardboard:
		var soaked := s.contact_tick + SiegeState.ticks(B.CARDBOARD_S)
		if s.contact_tick < 0 or s.tick < soaked:
			out *= B.CARDBOARD_HURT
	return out


## Men entity i is expected to put down in `seconds` of melee with entity e.
static func blows(s: SiegeState, i: int, e: int, seconds: float) -> float:
	var power := SiegeKinds.MELEE[s.kind[i]] * (1.0 - T.FATIGUE_WEAK * s.fatigue[i])
	if s.team[i] == ARMY:
		power *= s.mods.melee
	if s.daze[i] > s.tick:
		power *= B.WASP_DAZE
	var engaged := minf(s.count[i], s.count[e] * T.FRONTAGE)
	var expected := engaged * power * T.MELEE_RATE * seconds * hurt_factor(s, e, false)
	if s.state[e] == ST.FLEE:
		expected *= T.ROUT_DAMAGE
	return expected


## Squad i just broke: everybody in melee with it strikes as it turns to run.
static func parting_blows(s: SiegeState, i: int) -> void:
	var contact2 := T.CONTACT_M * T.CONTACT_M
	for e in s.pos.size():
		if s.foe[e] != i or s.count[e] <= 0 or s.state[e] == ST.FLEE:
			continue
		if s.team[e] == s.team[i] or s.pos[e].distance_squared_to(s.pos[i]) > contact2:
			continue
		hit(s, i, s.sample(blows(s, e, i, T.PARTING_S)))


static func _melee(s: SiegeState, i: int, e: int) -> void:
	if SiegeKinds.MELEE[s.kind[i]] <= 0.0:
		return
	s.mobbed[e] += 1
	var expected := blows(s, i, e, T.THINK_S)
	if s.contact_tick < 0:
		s.contact_tick = s.tick
	var f := s.flag[i]
	if f & SiegeState.F_CHARGING != 0:
		s.flag[i] = f & ~SiegeState.F_CHARGING
		if f & SiegeState.F_RIDING != 0:
			SiegeSpecials.crash(s, i, e)
		else:
			var fresh := 1.0 - s.fatigue[i]
			expected *= 1.0 + (T.CHARGE_IMPACT - 1.0) * fresh
			s.jolt(e, T.CHARGE_SHOCK * fresh)
	if f & SiegeState.F_INVISIBLE != 0:
		expected += blows(s, i, e, B.AMBUSH_S)
		SiegeSpecials.reveal(s, i, e)
	if s.tick - s.note[i] >= CLASH_TICKS and s.kind[i] != K.MOOSE:
		s.note[i] = s.tick
		s.emit_with(SiegeEvent.MELEE_CLASH, (s.pos[i] + s.pos[e]) * 0.5, {"team": s.team[i]})
	var heads := s.sample(expected)
	if heads <= 0 or s.count[e] <= 0:
		return
	if s.kind[i] == K.MONSTER:
		s.emit(SiegeEvent.MONSTER_SMASH, s.pos[e])
	hit(s, e, heads)


static func _shoot(s: SiegeState, i: int, e: int, d2: float) -> void:
	var kind := s.kind[i]
	if kind == K.ARCHERS:
		if d2 <= T.BOW_RANGE_M * T.BOW_RANGE_M:
			_arrows(s, i, e)
		return
	var reach := s.mods.sling_range
	var blocked := SiegeState.F_RIDING | SiegeState.F_INVISIBLE
	if s.flag[i] & SiegeState.F_SLINGS == 0 or s.ammo[i] <= 0 or d2 > reach * reach:
		return
	if s.pace[i] > SiegeMove.WALK or s.flag[i] & blocked != 0:
		return
	_stones(s, i, e)


static func _arrows(s: SiegeState, i: int, e: int) -> void:
	var acc := T.BOW_ACC * s.mods.bow_acc
	if s.state[e] == ST.FIGHT and s.foe[e] >= 0:
		acc *= T.BOW_INTO_MELEE
	s.reload[i] = T.BOW_RELOAD_S
	s.hit[e] = s.tick
	s.emit_with(SiegeEvent.ARROW_VOLLEY, s.pos[i], {"team": VILLAGE, "to": s.pos[e]})
	var heads := s.sample(s.count[i] * acc * T.BOW_DOWN * hurt_factor(s, e, true))
	if heads > 0:
		hit(s, e, heads)


static func _stones(s: SiegeState, i: int, e: int) -> void:
	var hits := s.count[i] * T.SLING_ACC * s.mods.sling_acc
	if s.map.in_village(s.pos[e]):
		hits *= T.COVER
	var down := T.SLING_DOWN / SiegeKinds.TOUGH[s.kind[e]]
	if s.kind[e] == K.RETINUE:
		down *= T.SLING_VS_MAIL
	s.ammo[i] -= 1
	s.reload[i] = T.SLING_RELOAD_S
	s.hit[e] = s.tick
	s.emit_with(SiegeEvent.SLING_VOLLEY, s.pos[i], {"team": ARMY, "to": s.pos[e]})
	s.jolt(e, T.SLING_STING * hits)
	var heads := s.sample(hits * down)
	if heads > 0:
		hit(s, e, heads)
	# A volley into a melee can find a friend's head.
	var friend := s.foe[e]
	if friend < 0 or friend == i or s.team[friend] != ARMY or s.count[friend] <= 0:
		return
	var reach := T.CONTACT_M + 2.0
	if s.pos[friend].distance_squared_to(s.pos[e]) > reach * reach:
		return
	if s.rng.randf() >= s.mods.friendly_fire:
		return
	s.jolt(friend, T.SLING_STING * 2.0)
	if s.rng.randf() < T.SLING_DOWN * s.mods.friendly_hurt:
		hit(s, friend, 1)
