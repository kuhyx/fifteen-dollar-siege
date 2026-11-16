extends SceneTree
## What a player hears at boot, checked without a bot and without GUT: the
## real main scene, the way kuhy's ./run.sh starts it, under the Dummy
## driver. tests/audio covers the muted runs; this covers the audible one.
## Passes when the buses are open, the hub loop plays, every file is there
## and loading them did not hold the first frame up. Prints one AUDIO BOOT
## line; exit 0 or 1.   tools/audio/check.sh runs it with --save-dir=<tmp>.

## Build-game lesson L9: every transition, boot included, takes under a second.
const BOOT_LIMIT_MS := 1000


func _initialize() -> void:
	_probe.call_deferred()


func _probe() -> void:
	var started := Time.get_ticks_msec()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var boot_ms := Time.get_ticks_msec() - started
	await process_frame
	var problems := PackedStringArray()
	var director := AudioDirector.live()
	if director == null:
		problems.append("Main has no AudioDirector")
	else:
		problems.append_array(_faults(director))
	if boot_ms > BOOT_LIMIT_MS:
		problems.append("boot took %d ms (limit %d)" % [boot_ms, BOOT_LIMIT_MS])
	var verdict := "ok" if problems.is_empty() else "FAIL: " + ", ".join(problems)
	print("AUDIO BOOT %s (main scene up in %d ms)" % [verdict, boot_ms])
	main.free()
	quit(0 if problems.is_empty() else 1)


func _faults(director: AudioDirector) -> PackedStringArray:
	var out := PackedStringArray()
	if director.silent:
		out.append("a normal run is muted")
	if not director.bank.missing.is_empty():
		out.append("%d audio files missing" % director.bank.missing.size())
	if not director.music.hub.playing:
		out.append("the hub loop is not playing")
	for bus: StringName in [AudioBuses.MUSIC, AudioBuses.SFX]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0 or AudioServer.is_bus_mute(index) != director.settings.muted:
			out.append("bus %s is not as the settings say" % bus)
	return out
