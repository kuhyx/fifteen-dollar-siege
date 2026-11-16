class_name SiegeAlarm
extends RefCounted
## "They will notice as your men draw near": until somebody sees the army the
## village sleeps. A noticed army raises the alarm once; from then it spreads by
## shouting, and faster once the church bell rings. Each village squad hears it
## at its own level (SiegeVillage), then needs time to arm.

const T = preload("res://src/core/siege_tuning.gd")


static func run(s: SiegeState) -> void:
	if not s.alarm_on:
		_watch(s)
		return
	var rate := T.THINK_S / (T.ALARM_SPREAD_S * s.mods.spread)
	if s.tick >= s.bell_tick:
		rate *= T.BELL_BOOST
		var since := s.tick - s.bell_tick
		if s.alarm < 1.0 and since % SiegeState.ticks(T.BELL_PERIOD_S) == 0:
			s.emit(SiegeEvent.BELL_RING, s.map.bell)
	s.alarm = minf(s.alarm + rate, 1.0)


## The alarm goes up (once): `seen_at` is where the army was noticed.
static func raise(s: SiegeState, seen_at: Vector2) -> void:
	if s.alarm_on:
		return
	s.alarm_on = true
	s.alarm_tick = s.tick
	s.bell_tick = s.tick + SiegeState.ticks(T.BELL_DELAY_S)
	var centre := s.map.village_center
	var toward := (seen_at - centre).normalized()
	s.emit(SiegeEvent.ALARM, centre + toward * s.map.village_radius)


## Looks for the nearest army entity the village can see or hear. A band on the
## field is heard at once.
static func _watch(s: SiegeState) -> void:
	if s.band >= 0:
		raise(s, s.pos[s.band])
		return
	var centre := s.map.village_center
	var nearest := INF
	var where := Vector2.ZERO
	var seen := SiegeState.F_TARGET | SiegeState.F_WAVERS
	for i in s.pos.size():
		if s.team[i] != SiegeSnapshot.Team.ARMY or s.count[i] <= 0 or s.flag[i] & seen == 0:
			continue
		if s.state[i] == SiegeSnapshot.State.HIDDEN and s.kind[i] != SiegeSnapshot.Kind.UFO:
			continue
		var d := s.pos[i].distance_squared_to(centre)
		if d < nearest:
			nearest = d
			where = s.pos[i]
	var gap := sqrt(nearest) - s.map.village_radius
	var reach := T.DETECT_M * s.mods.noise * s.mods.detect
	if gap >= reach:
		return
	var near := 1.0 - maxf(gap, 0.0) / reach
	var chance := T.DETECT_PER_S * T.THINK_S * (1.0 + 2.0 * near)
	if gap < T.SEE_M or s.rng.randf() < chance:
		raise(s, where)
