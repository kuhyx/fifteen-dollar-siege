extends RefCounted
## The space of legal loadouts for the balance tools: random ones, and the
## neighbours of one (for hill-climbing). A loadout is named by its key: its
## ids sorted and joined by "+", "none" for nothing bought.


## "A random legal loadout" (the 35 % target): the 25 buffs in a random order,
## each bought when it still fits, so the budget is spent as a player would.
static func random(rng: RandomNumberGenerator) -> Loadout:
	var ids: Array[StringName] = []
	for def in BuffCatalog.all():
		ids.append(def.id)
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var kept := ids[i]
		ids[i] = ids[j]
		ids[j] = kept
	var out := Loadout.new()
	for id in ids:
		out.toggle(id)
	return out


## The `index`-th loadout of the fixed random sample (the same on every run).
static func sample(index: int) -> Loadout:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_700_000 + index
	return random(rng)


static func key(loadout: Loadout) -> String:
	if loadout.ids.is_empty():
		return "none"
	var ids: Array[String] = []
	for id in loadout.ids:
		ids.append(String(id))
	ids.sort()
	return "+".join(ids)


static func from_key(text: String) -> Loadout:
	if text == "none":
		return Loadout.new()
	return Loadout.of(text.split("+", false))


## Every legal loadout one move away: one buff sold, then the freed dollars
## spent again in every way (one or two buys), so a neighbour also spends what
## it can. The loadout itself is not in the list.
static func neighbours(loadout: Loadout) -> Array[Loadout]:
	var seen := {key(loadout): true}
	var out: Array[Loadout] = []
	var bases: Array[Loadout] = [loadout]
	for id in loadout.ids:
		var sold := loadout.duplicate()
		sold.toggle(id)
		bases.append(sold)
	for base in bases:
		for first in BuffCatalog.all():
			if base.has(first.id) or first.price > base.remaining():
				continue
			var one := base.duplicate()
			one.toggle(first.id)
			_keep(one, seen, out)
			for second in BuffCatalog.all():
				if one.has(second.id) or second.price > one.remaining():
					continue
				var two := one.duplicate()
				two.toggle(second.id)
				_keep(two, seen, out)
	return out


## True when no further buff fits: the loadout spends all it can.
static func is_full(loadout: Loadout) -> bool:
	for def in BuffCatalog.all():
		if not loadout.has(def.id) and def.price <= loadout.remaining():
			return false
	return true


static func _keep(loadout: Loadout, seen: Dictionary, out: Array[Loadout]) -> void:
	var name := key(loadout)
	if seen.has(name) or not is_full(loadout):
		return
	seen[name] = true
	out.append(loadout)
