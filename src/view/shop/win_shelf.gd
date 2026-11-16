class_name WinShelf
extends RefCounted
## The progress a player keeps: which buffs have been part of a siege that was
## won (Watch or Command). The hub shows them as a shelf of 25 slots. Saved
## through SaveStore, so it survives a restart and tests never touch the real
## file.

const FILE := "shelf.json"


## The buffs won with so far, in catalogue order.
static func won() -> Array[StringName]:
	var saved: Variant = SaveStore.read_json(FILE).get("won", [])
	var out: Array[StringName] = []
	if not saved is Array:
		return out
	for def in BuffCatalog.all():
		if (saved as Array).has(String(def.id)):
			out.append(def.id)
	return out


## Puts the buffs of a winning loadout on the shelf and saves it. Returns the
## ones that are new there (the result screen celebrates those).
static func record(loadout: Loadout) -> Array[StringName]:
	var have := won()
	var fresh: Array[StringName] = []
	for id in loadout.ids:
		if BuffCatalog.by_id(id) != null and not have.has(id) and not fresh.has(id):
			fresh.append(id)
	if fresh.is_empty():
		return fresh
	var all := have + fresh
	SaveStore.write_json(FILE, {"won": all.map(func(id: StringName) -> String: return String(id))})
	return fresh
