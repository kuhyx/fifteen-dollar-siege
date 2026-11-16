extends SceneTree
## What each buff adds to one loadout: the win rate and the mean push of
## `--base` alone and of base + each buff that still fits the budget, over the
## same seeds. Push (1 - SiegeSim.village_low) moves with far fewer sieges
## than the win rate does, so it shows a small buff's effect.
##   godot --headless -s tools/sim/buff_lift.gd -- --base=double_men [--runs=40]
##       [--shard=0] [--shards=1] [--budget-s=45] [--store=DIR]
## Resumable (same cache as the search): call it until it prints left=0.

const Args = preload("res://tools/sim/sim_args.gd")
const Space = preload("res://tools/sim/loadout_space.gd")
const Store = preload("res://tools/sim/balance_store.gd")


func _init() -> void:
	var args := Args.parse()
	var base: Loadout = Args.loadout(args.get("base", ""))
	var runs := int(args.get("runs", "40"))
	var shard := int(args.get("shard", "0"))
	var shards := int(args.get("shards", "1"))
	var deadline := Time.get_ticks_msec() + int(float(args.get("budget-s", "45")) * 1000.0)
	var store: RefCounted = Store.open(args.get("store", Store.default_root()))
	var arms: Array[Loadout] = [base]
	for def in BuffCatalog.all():
		if not base.has(def.id) and def.price <= base.remaining():
			var arm := base.duplicate()
			arm.toggle(def.id)
			arms.append(arm)
	var left := 0
	for arm in arms:
		var key: String = Space.key(arm)
		if Store.shard_of(key, shards) == shard:
			store.measure(arm, key, runs, deadline)
			left += runs - store.runs(key)
	store.save(shard, shards)
	store.reload()
	var base_key: String = Space.key(base)
	print("| + buff | $ | wins | push | win lift | push lift | sieges |")
	print("|---|---|---|---|---|---|---|")
	for arm in arms:
		var key: String = Space.key(arm)
		var id := "(base)" if arm == base else String(arm.ids[-1])
		var price := 0 if arm == base else BuffCatalog.by_id(arm.ids[-1]).price
		var rate: float = store.rate(key) * 100.0
		var push: float = store.mean_push(key) * 100.0
		var cells := [id, price, rate, push, rate - store.rate(base_key) * 100.0]
		cells.append(push - store.mean_push(base_key) * 100.0)
		cells.append(store.runs(key))
		print("| %s | %d | %.0f %% | %.0f | %+.0f | %+.0f | %d |" % cells)
	print("RESULT lift base=%s shard=%d/%d left=%d" % [base_key, shard, shards, left])
	quit(0)
