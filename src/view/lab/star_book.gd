class_name StarBook
extends RefCounted
## The best star count a player has reached, per mode (Watch and Command; the
## Lab has no stars): 0 to 3, never lowered by a worse result. Saved through
## SaveStore, so it survives a restart and tests never touch the real file.
## The hub shows it as three stars under the mode's button.

const FILE := "stars.json"
const MODES: Array[StringName] = [&"watch", &"command"]
const MAX_STARS := 3


## The best so far for `mode` (0 for none, for the Lab and for a damaged file).
static func best(mode: StringName) -> int:
	var all: Variant = SaveStore.read_json(FILE).get("best", {})
	if not MODES.has(mode) or not all is Dictionary:
		return 0
	var kept: Variant = (all as Dictionary).get(String(mode), 0)
	if not (kept is int or kept is float):
		return 0
	return clampi(int(kept), 0, MAX_STARS)


## Keeps `stars` when it beats the best for `mode`; true when it was a new best.
static func record(mode: StringName, stars: int) -> bool:
	var earned := mini(stars, MAX_STARS)
	if not MODES.has(mode) or earned <= best(mode):
		return false
	var all := {}
	for kept in MODES:
		all[String(kept)] = best(kept)
	all[String(mode)] = earned
	return SaveStore.write_json(FILE, {"best": all})
