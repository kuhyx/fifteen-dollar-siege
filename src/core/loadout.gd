class_name Loadout
extends RefCounted
## The buffs bought for one siege. Rules: at most BUDGET dollars, each buff at
## most once, unspent dollars are lost (they carry no effect anywhere).

const BUDGET := 15

## Bought buff ids, in the order they were bought.
var ids: Array[StringName] = []


## A loadout holding `p_ids` as given, legal or not (check with is_legal).
static func of(p_ids: Array) -> Loadout:
	var out := Loadout.new()
	for id: Variant in p_ids:
		out.ids.append(StringName(str(id)))
	return out


## Dollars spent. An unknown id counts as 0 (and makes the loadout illegal).
func cost() -> int:
	var total := 0
	for id in ids:
		var def := BuffCatalog.by_id(id)
		if def != null:
			total += def.price
	return total


## Dollars left; negative for an over-budget loadout.
func remaining() -> int:
	return BUDGET - cost()


func has(id: StringName) -> bool:
	return ids.has(id)


## Known buffs only, none twice, within the budget.
func is_legal() -> bool:
	var seen: Dictionary = {}
	for id in ids:
		if BuffCatalog.by_id(id) == null or seen.has(id):
			return false
		seen[id] = true
	return cost() <= BUDGET


## Buys `id`, or sells it back when already bought. Returns true when the
## loadout changed; false (nothing changed) for an unknown id or a buy that
## would go over the budget.
func toggle(id: StringName) -> bool:
	if ids.has(id):
		ids.erase(id)
		return true
	var def := BuffCatalog.by_id(id)
	if def == null or cost() + def.price > BUDGET:
		return false
	ids.append(id)
	return true


func duplicate() -> Loadout:
	return Loadout.of(ids)
