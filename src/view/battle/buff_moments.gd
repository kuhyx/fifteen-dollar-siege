class_name BuffMoments
extends RefCounted
## The signature moments of the buffs that used to show only a chip: stew
## (a bowl and steam), the two prep times (a sweeping clock), the men buffs
## (the army number rolls up) and the village buffs (their badges at the alarm,
## sleepless first, deaf a beat later). Real seconds, view only.

## Real seconds after the start: the chips have settled by then.
const START_AT_S := 1.5
## Per prep buff: turns of the clock's long hand, and the clock's size.
const CLOCKS := {&"prep_hour": [3.0, 1.0], &"prep_ten_minutes": [0.5, 0.7]}
const BASE_MEN := 100
## The village buffs that show at the alarm, and the real seconds between two badges.
const VILLAGE_BUFFS: Array[StringName] = [&"sleepless_village", &"deaf_villagers"]
const BADGE_GAP_S := 0.9

var _loadout := Loadout.new()
var _age := 0.0
var _started := false
var _rung := {}
## [real second, cue, pitch] still to sound.
var _later: Array[Array] = []
## [real second, buff id, where, slot] of the village badges still to pop.
var _badges: Array[Array] = []


func setup(loadout: Loadout) -> void:
	_loadout = loadout
	_age = 0.0
	_started = false
	_rung.clear()
	_later.clear()
	_badges.clear()


func advance(delta: float, shot: SiegeSnapshot, effects: BattleEffects) -> void:
	_age += delta
	if not _started and _age >= START_AT_S and shot.entity_count() > 0:
		_started = true
		_start(shot, effects)
	for item in _badges.filter(func(it: Array) -> bool: return it[0] <= _age):
		_badge(item[1], item[2], effects, item[3])
	_badges = _badges.filter(func(it: Array) -> bool: return it[0] > _age)
	for item in _later.filter(func(it: Array) -> bool: return it[0] <= _age):
		FunCue.play(item[1], item[2])
	_later = _later.filter(func(it: Array) -> bool: return it[0] > _age)


## A village buff answers the alarm, once, where the alarm rose (the church
## bell itself is usually off screen): sleepless first, deaf a beat later.
func on_event(event: Dictionary) -> void:
	if event.get("kind") != SiegeEvent.ALARM:
		return
	var slot := 0
	for id: StringName in VILLAGE_BUFFS:
		if _loadout.has(id) and not _rung.has(id):
			_rung[id] = true
			_badges.append([_age + slot * BADGE_GAP_S, id, event.get("pos", Vector2.ZERO), slot])
			slot += 1


func _start(shot: SiegeSnapshot, effects: BattleEffects) -> void:
	var middle := _army_middle(shot)
	if _loadout.has(&"stew"):
		_badge(&"stew", middle, effects)
		effects.flourish(&"steam", FxSigns.steam, 6.0, middle, {})
	var slot := 0
	for id: StringName in CLOCKS:
		if _loadout.has(id):
			var data := {"turns": CLOCKS[id][0], "scale": CLOCKS[id][1], "slot": slot}
			effects.flourish(&"clock", FxSigns.clock, 3.2, middle, data)
			for tick in 4:
				_later.append([_age + 0.3 + tick * 0.5, &"fun_tick", 0.9 + 0.1 * tick])
			slot += 1
	if _loadout.has(&"double_men") or _loadout.has(&"fifty_men"):
		var data := {"from": BASE_MEN, "to": _army_heads(shot)}
		effects.flourish(&"count", FxSigns.count, 2.6, middle, data)
		_later.append([_age + 0.1, &"fun_toll", 0.8])


func _badge(id: StringName, at: Vector2, effects: BattleEffects, slot := 0) -> void:
	effects.flourish(&"badge", FxSigns.badge, BattleFlair.KEEP_S, at, {"id": id, "slot": slot})
	FunCue.play(&"fun_star", 1.0, at)


static func _army_heads(shot: SiegeSnapshot) -> int:
	var heads := 0
	for i in shot.entity_count():
		if (
			shot.ent_team[i] == SiegeSnapshot.Team.ARMY
			and shot.ent_kind[i] == SiegeSnapshot.Kind.MEN
		):
			heads += shot.ent_count[i]
	return heads


static func _army_middle(shot: SiegeSnapshot) -> Vector2:
	var sum := Vector2.ZERO
	var heads := 0
	for i in shot.entity_count():
		if (
			shot.ent_team[i] == SiegeSnapshot.Team.ARMY
			and shot.ent_kind[i] == SiegeSnapshot.Kind.MEN
		):
			sum += shot.ent_pos[i] * shot.ent_count[i]
			heads += shot.ent_count[i]
	return sum / heads if heads > 0 else Vector2.ZERO
