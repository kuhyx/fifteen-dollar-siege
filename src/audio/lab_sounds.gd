class_name LabSounds
extends RefCounted
## The Lab's sounds, for the director: a tick whenever the Lab has counted more
## sieges (high for a win, low for a loss) and a bell at the end, higher the
## more of them were won.

var _seen := Vector2i.ZERO


func reset() -> void:
	_seen = Vector2i.ZERO


## `result` is the Lab screen's running {runs, wins}.
func count(director: AudioDirector, result: Variant) -> void:
	if not result is Dictionary:
		return
	var now := Vector2i(int(result.get("runs", 0)), int(result.get("wins", 0)))
	if now.x > _seen.x:
		director.ui(&"ui_lab_tick", 1.12 if now.y > _seen.y else 0.9)
	_seen = now


func done(director: AudioDirector, result: Dictionary) -> void:
	var runs := maxi(int(result.get("runs", 0)), 1)
	director.ui(&"ui_lab_done", lerpf(0.84, 1.12, float(result.get("wins", 0)) / runs))
