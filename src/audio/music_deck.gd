class_name MusicDeck
extends Node
## The music: what plays now and how it gets from one thing to the next.
##   hub      the hub loop (also in the shop, the Lab and after a stinger)
##   battle   the bed: five loops in one AudioStreamSynchronized (sample
##            locked), each stem's level gliding to BattleMix's target
##   ending   a stinger over the fading bed; the hub loop returns after it
## Players use STREAM playback on every platform: the web's default sample
## playback cannot run a synchronized stream or change a level while playing.
## Times and levels are [design guess]es (DOCS-audio.md).

## Seconds for the hub, the bed or a stinger to fade in or out.
const FADE_S := 0.6
## Seconds for one stem to glide from silent to full.
const LAYER_S := 1.2
## Music level under the pause menu.
const DUCKED := 0.35
const SILENT_DB := -80.0

## off, hub, battle or ending.
var scene: StringName = &"off"
var hub := AudioStreamPlayer.new()
var battle := AudioStreamPlayer.new()
var stinger := AudioStreamPlayer.new()
## Linear level of each stem (AudioCues.STEMS order): where it is going, and
## where it is now.
var layer_target := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
var layer_gain := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
var ducked := false

var _bank: AudioBank
var _sync: AudioStreamSynchronized
var _gain := {&"hub": 0.0, &"battle": 0.0, &"ending": 0.0}
var _siege := Vector3(0.0, 1.0, 1.0)
var _rock_left := 0.0


func setup(bank: AudioBank) -> void:
	_bank = bank
	for player: AudioStreamPlayer in [hub, battle, stinger]:
		player.bus = AudioBuses.MUSIC
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.volume_db = SILENT_DB
		add_child(player)
	hub.stream = bank.stream(AudioCues.HUB)
	var stems: Array[AudioStream] = []
	for file in AudioCues.STEMS:
		stems.append(bank.stream(file))
	if not stems.has(null):
		_sync = AudioStreamSynchronized.new()
		_sync.stream_count = stems.size()
		for index in stems.size():
			_sync.set_sync_stream(index, stems[index])
		battle.stream = _sync
	stinger.finished.connect(_on_stinger_finished)


func show_hub() -> void:
	scene = &"hub"
	if hub.stream == null:
		return
	hub.stream_paused = false
	if not hub.playing:
		hub.play()


## Starts the bed from its first bar with only the sneak sounding.
func show_battle() -> void:
	scene = &"battle"
	_siege = Vector3(0.0, 1.0, 1.0)
	_rock_left = 0.0
	_retarget()
	layer_gain = layer_target.duplicate()
	if battle.stream != null:
		battle.play(0.0)


## The snapshot's alarm and morale: the stems follow them.
func steer(alarm: float, army_morale: float, village_morale: float) -> void:
	_siege = Vector3(alarm, army_morale, village_morale)
	_retarget()


## The rock band plays: its riff covers the bed for `hold_s` more seconds.
func band(hold_s: float) -> void:
	_rock_left = hold_s
	_retarget()


## The siege is decided: the bed fades under the win or the lose stinger.
func ending(win: bool) -> void:
	var file := AudioCues.WIN if win else AudioCues.LOSE
	stinger.stream = _bank.stream(file) if _bank != null else null
	if stinger.stream == null:
		show_hub()
		return
	scene = &"ending"
	_gain[&"ending"] = 1.0
	stinger.volume_db = _db(1.0)
	stinger.play()


## The pause menu is open: the music steps back.
func duck(on: bool) -> void:
	ducked = on


func _process(delta: float) -> void:
	if _rock_left > 0.0 and not get_tree().paused:
		_rock_left -= delta
		if _rock_left <= 0.0:
			_retarget()
	for part: StringName in _gain:
		_gain[part] = move_toward(_gain[part], 1.0 if scene == part else 0.0, delta / FADE_S)
	hub.volume_db = _db(_gain[&"hub"])
	battle.volume_db = _db(_gain[&"battle"])
	stinger.volume_db = _db(_gain[&"ending"])
	if scene != &"hub" and _gain[&"hub"] <= 0.0 and hub.playing:
		hub.stream_paused = true
	if scene != &"battle" and _gain[&"battle"] <= 0.0 and battle.playing:
		battle.stop()
	if scene != &"ending" and _gain[&"ending"] <= 0.0 and stinger.playing:
		stinger.stop()
	for index in layer_gain.size():
		layer_gain[index] = move_toward(layer_gain[index], layer_target[index], delta / LAYER_S)
		if _sync != null:
			_sync.set_sync_stream_volume(index, _db(layer_gain[index], 1.0))


func _retarget() -> void:
	layer_target = BattleMix.targets(_siege.x, _siege.y, _siege.z, _rock_left > 0.0)


func _db(level: float, under_menu: float = DUCKED) -> float:
	var heard := level * (under_menu if ducked else 1.0)
	return linear_to_db(heard) if heard > 0.0001 else SILENT_DB


func _on_stinger_finished() -> void:
	if scene == &"ending":
		show_hub()
