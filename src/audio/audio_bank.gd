class_name AudioBank
extends RefCounted
## Every stream on the cue sheet, loaded once at boot (a missing file is
## listed in `missing` and plays nothing: a fresh clone without ./install.sh
## is silent, never broken). Loops get their loop mode checked again here:
## the import sidecar is the first place it is set, this is the second.

var root := AudioCues.ROOT
## File key ("sfx/bell") -> AudioStream.
var streams := {}
var missing := PackedStringArray()


func load_all() -> void:
	streams.clear()
	missing.clear()
	var loops := AudioCues.loops()
	for file in AudioCues.files():
		var path := root + file + ".wav"
		var found: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if found == null:
			missing.append(file)
			continue
		if file in loops:
			_loop(found as AudioStreamWAV)
		streams[file] = found


## The stream of a file key, null when it was not there.
func stream(file: String) -> AudioStream:
	return streams.get(file)


## Forward loop over the whole file. Godot plays the last frame and goes on
## from frame 1, so the renderer ends a loop with its first frame again and
## `loop_end` is the last frame's index (tools/audio/wavio.py).
static func _loop(wav: AudioStreamWAV) -> void:
	if wav == null or wav.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / (4 if wav.stereo else 2) - 1
