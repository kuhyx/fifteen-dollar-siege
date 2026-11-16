class_name LabBook
extends RefCounted
## Every loadout the Lab has tried and how it did: wins and runs, added up over
## all its batches. The Lab ranks them, the hub shows the best. Saved through
## SaveStore, so the ranking survives a restart and tests never touch the real
## file. A loadout is keyed by its sorted buff ids: the order bought in does
## not matter.

const FILE := "lab_book.json"
## The key of the loadout with nothing bought.
const EMPTY_KEY := "-"


static func key_of(loadout: Loadout) -> String:
	var names: Array[String] = []
	for id in loadout.ids:
		names.append(String(id))
	names.sort()
	return EMPTY_KEY if names.is_empty() else ",".join(names)


## Adds one finished batch to the loadout's line and saves the book.
static func record(loadout: Loadout, wins: int, runs: int) -> void:
	if runs <= 0:
		return
	var book := SaveStore.read_json(FILE)
	var lines: Dictionary = book.get("entries", {}) if book.get("entries") is Dictionary else {}
	var key := key_of(loadout)
	var line: Dictionary = lines.get(key, {}) if lines.get(key) is Dictionary else {}
	lines[key] = {"wins": int(line.get("wins", 0)) + wins, "runs": int(line.get("runs", 0)) + runs}
	SaveStore.write_json(FILE, {"entries": lines})


## Every loadout tried, best first: {key, ids, wins, runs, rate}. Ties go to
## the one with more runs behind it, then by key (a stable order).
static func ranked() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lines: Variant = SaveStore.read_json(FILE).get("entries", {})
	if not lines is Dictionary:
		return out
	for key: String in lines:
		var line: Variant = lines[key]
		if not line is Dictionary or int(line.get("runs", 0)) <= 0:
			continue
		var runs := int(line["runs"])
		var wins := clampi(int(line.get("wins", 0)), 0, runs)
		var ids := [] if key == EMPTY_KEY else Array(key.split(",", false))
		var bought := Loadout.of(ids).ids
		var rate := float(wins) / runs
		out.append({"key": key, "ids": bought, "wins": wins, "runs": runs, "rate": rate})
	out.sort_custom(_better)
	return out


## The best line so far, {} when the Lab has not run yet.
static func best() -> Dictionary:
	var all := ranked()
	return all[0] if not all.is_empty() else {}


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(a["rate"], b["rate"]):
		return a["rate"] > b["rate"]
	if a["runs"] != b["runs"]:
		return a["runs"] > b["runs"]
	return a["key"] < b["key"]
