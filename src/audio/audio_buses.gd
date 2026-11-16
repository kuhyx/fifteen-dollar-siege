class_name AudioBuses
extends RefCounted
## The two volume buses, Music and Sfx, both into Master. Made in code at
## boot instead of a bus layout file, so the audio owns no project file.

const MUSIC := &"Music"
const SFX := &"Sfx"
const SILENT_DB := -80.0


## Adds the buses that are not there yet (asking twice adds nothing).
static func ensure() -> void:
	for bus: StringName in [MUSIC, SFX]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")


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
