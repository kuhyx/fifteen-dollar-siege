extends SceneTree
## The loadout search, one resumable slice of it: plans what to measure next
## (tools/sim/balance_plan.gd), runs the sieges of its own shard until the
## time budget is spent, saves, and stops. Call it again to go on; several
## shards may run side by side (scripts/balance_search.sh does).
##   godot --headless -s tools/sim/balance_search.gd -- [--shard=0] [--shards=1]
##       [--budget-s=45] [--no-climb] [--store=DIR]
##       [--empty-runs=300] [--sample=300] [--sample-runs=8] [--carry=HASH]
## --no-climb measures only the empty loadout and the random sample.
## Prints one RESULT line: sieges run now, loadouts and sieges in the store,
## and "left" (0 = the search has nothing more to do). Exit 0.

const Args = preload("res://tools/sim/sim_args.gd")
const Space = preload("res://tools/sim/loadout_space.gd")
const Store = preload("res://tools/sim/balance_store.gd")
const Plan = preload("res://tools/sim/balance_plan.gd")

var _deadline := 0
var _ran := 0
var _sample := {}


func _init() -> void:
	var args := Args.parse()
	var shard := int(args.get("shard", "0"))
	var shards := int(args.get("shards", "1"))
	_deadline = Time.get_ticks_msec() + int(float(args.get("budget-s", "45")) * 1000.0)
	Plan.configure(args)
	for index in Plan.sample_size:
		_sample[Space.key(Space.sample(index))] = true
	var store: RefCounted = Store.open(args.get("store", Store.default_root()))
	var left := 1
	while left > 0 and Time.get_ticks_msec() < _deadline:
		store.reload()
		left = _work(store, shard, shards, not args.has("no-climb"))
		store.save(shard, shards)
	var sieges := 0
	for key: String in store.results:
		sieges += store.runs(key)
	print(
		(
			"RESULT search sim=%s shard=%d/%d ran=%d loadouts=%d sieges=%d left=%d"
			% [store.sim_hash, shard, shards, _ran, store.results.size(), sieges, left]
		)
	)
	quit(0)


## Runs this shard's share of the plan, most promising first. Returns how many
## sieges of the plan it could not run before the deadline.
func _work(store: RefCounted, shard: int, shards: int, climb: bool) -> int:
	var want: Dictionary = Plan.targets(store, climb)
	var jobs: Array[String] = []
	for key: String in want:
		if store.runs(key) < int(want[key]) and Store.shard_of(key, shards) == shard:
			jobs.append(key)
	jobs.sort_custom(
		func(a: String, b: String) -> bool:
			var pa := _priority(store, a)
			var pb := _priority(store, b)
			return pa > pb if pa != pb else a < b
	)
	var left := 0
	for key in jobs:
		var loadout: Loadout = Space.from_key(key)
		var target := int(want[key])
		_ran += store.measure(loadout, key, target, _deadline)
		left += target - store.runs(key)
	return left


## The empty loadout first, then the random sample, then what already looks
## good, then the unknown.
func _priority(store: RefCounted, key: String) -> float:
	if key == "none":
		return 4.0
	if _sample.has(key) and store.runs(key) < Plan.sample_runs:
		return 3.0
	if store.runs(key) == 0:
		return 0.0
	return 1.0 + store.rate(key)
