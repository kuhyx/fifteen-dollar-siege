extends SceneTree
## "A siege in 20 seconds": a scripted siege played through the REAL
## AudioDirector, so the recording is the game's own mix (its buses, its
## stems, its rate limiter, its panning), not a model of it.
## tools/audio/demo.sh runs this under Movie Maker: Godot mixes offline into
## the movie file and nothing reaches a sound card.
## The story: hub and shop, go, the sneak, the alarm and its bell, volleys
## and clubs from both sides, every special once, the army wavers, the
## village breaks, the band plays, the centre is held, victory.

const MAP := Rect2(0.0, 0.0, 600.0, 400.0)
const END_S := 23.0
const GO_S := 2.1
const WIN_S := 17.6
## Seconds, event kind, x on the map (0 = far left, 600 = far right).
const SPECIALS := [
	[2.4, &"pep_talk", 80.0],
	[3.6, &"ufo_abduct", 420.0],
	[5.0, &"alarm", 380.0],
	[5.6, &"bell_ring", 450.0],
	[7.6, &"shotgun_blast", 240.0],
	[8.2, &"pumpkin_launch", 120.0],
	[9.2, &"pumpkin_splat", 430.0],
	[9.6, &"bell_ring", 450.0],
	[10.0, &"wasp_swarm", 400.0],
	[10.8, &"moose_charge", 330.0],
	[11.5, &"cart_crash", 360.0],
	[12.1, &"monster_smash", 390.0],
	[12.6, &"reveal", 300.0],
	[12.9, &"trumpet_call", 150.0],
	[13.4, &"heal", 180.0],
	[13.8, &"band_riff", 140.0],
	[15.0, &"centre_held", 450.0],
	[15.6, &"centre_held", 450.0],
	[16.2, &"centre_held", 450.0],
	[16.8, &"centre_held", 450.0],
	[WIN_S, &"victory", 450.0],
]
## Seconds, menu cue, pitch.
const MENU := [
	[0.6, &"ui_mode", 1.0],
	[1.0, &"ui_buy", 0.95],
	[1.3, &"ui_buy", 1.02],
	[1.6, &"ui_buy", 1.1],
	[GO_S, &"ui_go", 1.0],
]
## Steady streams: first second, last second, seconds apart, kind, x from, x to.
const STREAMS := [
	[6.0, 16.5, 0.07, &"sling_volley", 100.0, 300.0],
	[6.8, 15.5, 0.31, &"arrow_volley", 380.0, 520.0],
	[8.4, 17.0, 0.05, &"melee_clash", 260.0, 420.0],
	[11.0, 16.0, 1.3, &"squad_rout", 400.0, 520.0],
	[9.0, 11.0, 1.1, &"squad_wiped", 200.0, 300.0],
]

var _director: AudioDirector
var _clock := 0.0
var _done := {}
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 20
	_director = AudioDirector.new()
	root.add_child(_director)
	# The demo uses the default levels, whatever a save says.
	_director.settings = AudioSettings.new()
	AudioBuses.apply(_director.settings, false)
	_director.music.show_hub()


func _process(delta: float) -> bool:
	var before := _clock
	_clock += delta
	for entry: Array in MENU:
		if _due(entry[0], before):
			_director.ui(entry[1], entry[2])
	if _due(GO_S, before):
		_director.music.show_battle()
	if _clock >= GO_S and _clock < WIN_S + 0.5:
		AudioDirector.on_snapshot(_snapshot(before), MAP)
	if _due(WIN_S, before):
		_director.music.ending(true)
	return _clock >= END_S


func _due(at: float, before: float) -> bool:
	return before < at and _clock >= at


func _snapshot(before: float) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	shot.clock_s = _clock - GO_S
	shot.alarm = clampf((_clock - 5.0) / 3.0, 0.0, 1.0)
	# The army wavers around second 10 and recovers; the village breaks.
	shot.army_morale = 1.0 - 0.6 * clampf(1.0 - absf(_clock - 10.0) / 2.0, 0.0, 1.0)
	shot.village_morale = 1.0 - 0.85 * clampf((_clock - 11.0) / 5.0, 0.0, 1.0)
	for entry: Array in SPECIALS:
		if _due(entry[0], before):
			var event := {"kind": entry[1], "pos": Vector2(entry[2], 200.0)}
			event["progress"] = clampf((_clock - 15.0) / 1.8, 0.0, 1.0)
			event["team"] = SiegeSnapshot.Team.VILLAGE
			shot.events.append(event)
	for stream: Array in STREAMS:
		if _clock < stream[0] or _clock > stream[1]:
			continue
		var gap: float = stream[2]
		if floorf(before / gap) == floorf(_clock / gap):
			continue
		var x := _rng.randf_range(stream[4], stream[5])
		var team := (
			SiegeSnapshot.Team.ARMY if stream[3] == &"squad_wiped" else SiegeSnapshot.Team.VILLAGE
		)
		shot.events.append({"kind": stream[3], "pos": Vector2(x, 200.0), "team": team})
	return shot
