class_name SfxPool
extends Node
## A fixed pool of voices for one-shot sounds. A voice is an
## AudioStreamPlayer2D: Godot pans it by where it sits on the canvas, so an
## event on the left of the view sounds on the left. Distance does not change
## the level here (the director sets it): `max_distance` is far away.
## A cue never holds more than its `voices`: a new start takes its own oldest
## voice. A full pool drops the new sound unless it outranks one playing.

const VOICES := 20
const LOG_SIZE := 64
## 1 would pan a sound at the screen edge about 62 : 38; this gives 80 : 20
## [design guess: clearly sided, never one ear only].
const PAN_STRENGTH := 2.4
const FAR := 1.0e6

## Every start, newest last: {cue, voice, x, db, pitch}. Tests and the dev
## tools read it; it keeps the last LOG_SIZE.
var plays: Array[Dictionary] = []

var _voices: Array[AudioStreamPlayer2D] = []
var _cues: Array[StringName] = []
var _ranks := PackedInt32Array()
var _since := PackedFloat64Array()


func _init() -> void:
	for index in VOICES:
		var voice := AudioStreamPlayer2D.new()
		voice.bus = AudioBuses.SFX
		voice.max_distance = FAR
		voice.attenuation = 1.0
		voice.panning_strength = PAN_STRENGTH
		add_child(voice)
		_voices.append(voice)
		_cues.append(&"")
		_ranks.append(0)
		_since.append(0.0)


## Starts `stream` for `cue`. `how` may hold x (canvas pixels; default: the
## centre), db, pitch, rank, voices (the cue's cap) and now (seconds, to tell
## the oldest voice). Returns the voice, or null when nothing was started.
func play(cue: StringName, stream: AudioStream, how: Dictionary = {}) -> AudioStreamPlayer2D:
	if stream == null or not is_inside_tree():
		return null
	var rank := int(how.get("rank", 0))
	var index := _pick(cue, rank, int(how.get("voices", VOICES)))
	if index < 0:
		return null
	var centre := get_viewport().get_visible_rect().get_center()
	var voice := _voices[index]
	voice.stop()
	voice.stream = stream
	voice.position = Vector2(float(how.get("x", centre.x)), centre.y)
	voice.volume_db = float(how.get("db", 0.0))
	voice.pitch_scale = float(how.get("pitch", 1.0))
	voice.play()
	_cues[index] = cue
	_ranks[index] = rank
	_since[index] = float(how.get("now", 0.0))
	(
		plays
		. append(
			{
				"cue": cue,
				"voice": voice,
				"x": voice.position.x,
				"db": voice.volume_db,
				"pitch": voice.pitch_scale,
			}
		)
	)
	if plays.size() > LOG_SIZE:
		plays.pop_front()
	return voice


## How many voices are playing `cue` right now.
func sounding(cue: StringName) -> int:
	var count := 0
	for index in VOICES:
		if _cues[index] == cue and _voices[index].playing:
			count += 1
	return count


## The voice a new sound gets: the cue's own oldest when the cue is at its
## cap, else a free one, else the oldest voice of the lowest rank under
## `rank`; -1 when there is none.
func _pick(cue: StringName, rank: int, cap: int) -> int:
	var free := -1
	var own := -1
	var own_count := 0
	var weakest := -1
	for index in VOICES:
		if not _voices[index].playing:
			free = index if free < 0 else free
			continue
		if _cues[index] == cue:
			own_count += 1
			if own < 0 or _since[index] < _since[own]:
				own = index
		if _ranks[index] < rank and _older(index, weakest):
			weakest = index
	if own_count >= cap and own >= 0:
		return own
	return free if free >= 0 else weakest


## `index` should give way before `other`: lower rank first, then the older.
func _older(index: int, other: int) -> bool:
	if other < 0 or _ranks[index] < _ranks[other]:
		return true
	return _ranks[index] == _ranks[other] and _since[index] < _since[other]
