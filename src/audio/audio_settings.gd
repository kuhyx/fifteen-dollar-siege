class_name AudioSettings
extends RefCounted
## The player's volumes and mute, kept in the save (audio.json) through
## SaveStore, so a GUT run or a bot can never write the real one.

const FILE := "audio.json"
## Music sits under the effects by default: it is the bed, they are the news.
const DEFAULT_MUSIC := 0.7
const DEFAULT_SFX := 1.0

## Linear, 0 (off) .. 1 (the files' own level).
var music := DEFAULT_MUSIC
var sfx := DEFAULT_SFX
var muted := false


static func load_saved() -> AudioSettings:
	var out := AudioSettings.new()
	var saved := SaveStore.read_json(FILE)
	out.music = _volume(saved.get("music"), DEFAULT_MUSIC)
	out.sfx = _volume(saved.get("sfx"), DEFAULT_SFX)
	out.muted = saved.get("muted") is bool and saved["muted"]
	return out


func save() -> bool:
	return SaveStore.write_json(FILE, {"music": music, "sfx": sfx, "muted": muted})


static func _volume(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return fallback
