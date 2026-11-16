class_name AudioBuses
extends RefCounted
## The two volume buses, Music and Sfx, both into Master, and a limiter on
## Master. Made in code at boot instead of a bus layout file, so the audio
## owns no project file.

const MUSIC := &"Music"
const SFX := &"Sfx"
const SILENT_DB := -80.0
## Twenty voices and five stems can add up past full scale; the limiter
## holds the sum just under it instead of letting the driver clip. It does
## nothing below the ceiling. (The web's sample playback ignores effects.)
const CEILING_DB := -0.5


## Adds the buses and the limiter that are not there yet (asking twice adds
## nothing).
static func ensure() -> void:
	if not _limited():
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = CEILING_DB
		AudioServer.add_bus_effect(0, limiter)
	for bus: StringName in [MUSIC, SFX]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")


## Master already carries a hard limiter.
static func _limited() -> bool:
	for index in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, index) is AudioEffectHardLimiter:
			return true
	return false


## Puts the saved volumes on the buses. `silent` (a bot or a test run)
## mutes both whatever the player saved.
static func apply(settings: AudioSettings, silent: bool) -> void:
	_level(MUSIC, settings.music, settings.muted or silent)
	_level(SFX, settings.sfx, settings.muted or silent)


static func _level(bus: StringName, linear: float, mute: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(linear) if linear > 0.0 else SILENT_DB)
	AudioServer.set_bus_mute(index, mute or linear <= 0.0)
