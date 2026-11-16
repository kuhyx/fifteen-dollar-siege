class_name LoadoutDice
extends RefCounted
## A random legal loadout: the buffs in a shuffle, each bought when the
## dollars left still reach it, until nothing more fits. Used by the shop's
## dice and by the result's "try a new fifteen dollars".


## The ids of one roll. `avoid` is the loadout it should not repeat.
static func roll(rng: RandomNumberGenerator, avoid: Array = []) -> Array[StringName]:
	var out: Array[StringName] = []
	for attempt in 6:
		var order: Array[StringName] = []
		for def in BuffCatalog.all():
			order.append(def.id)
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var held := order[i]
			order[i] = order[j]
			order[j] = held
		var loadout := Loadout.new()
		for id in order:
			loadout.toggle(id)
		out = loadout.ids
		if not _same(out, avoid):
			break
	return out


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for id: Variant in a:
		if not b.has(id):
			return false
	return true
