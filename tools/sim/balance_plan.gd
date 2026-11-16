extends RefCounted
## What the balance search measures next, worked out from what is measured so
## far (so any call, on any shard, plans the same work):
##   1. the empty loadout, empty_runs sieges (the "no buffs" number)
##   2. the fixed random sample, sample_size loadouts (the "random" number)
##   3. more sieges for whatever ranks high (a rate from 8 sieges is a rumour)
##   4. hill-climbing: every neighbour of the best loadouts, and of the best
##      loadout holding each buff (so every buff's best home gets searched)
## A neighbour starts with FIRST_RUNS sieges and earns more only by winning.

const Space = preload("res://tools/sim/loadout_space.gd")
const Store = preload("res://tools/sim/balance_store.gd")

const FIRST_RUNS := 4
## Runs a loadout gets by rank among the measured ones: [ranks, runs].
const LADDER: Array[Vector2i] = [Vector2i(150, 16), Vector2i(60, 48), Vector2i(25, 96)]
## Rate a neighbour needs after FIRST_RUNS, relative to the best, to go on.
const KEEP_SHARE := 0.7
## Loadouts whose neighbours are searched: the top CLIMB and one per buff.
const CLIMB := 6
## Runs a loadout needs before it is ranked, and before it is climbed from.
const RANKED_RUNS := 8
const TRUSTED_RUNS := 48

## Sieges of the empty loadout, size of the random sample and sieges of each
## sample loadout. A tool may lower them for a quick look (--empty-runs,
## --sample, --sample-runs).
static var empty_runs := 300
static var sample_size := 300
static var sample_runs := 8


## Takes the three sizes from a tool's arguments, when given.
static func configure(args: Dictionary) -> void:
	empty_runs = int(args.get("empty-runs", empty_runs))
	sample_size = int(args.get("sample", sample_size))
	sample_runs = int(args.get("sample-runs", sample_runs))


## Keys of the measured loadouts with at least `min_runs`, best rate first.
static func ranking(store: RefCounted, min_runs: int) -> Array[String]:
	var keys: Array[String] = []
	for key: String in store.results:
		if store.runs(key) >= min_runs and key != "none":
			keys.append(key)
	keys.sort_custom(
		func(a: String, b: String) -> bool:
			var ra: float = store.rate(a)
			var rb: float = store.rate(b)
			if ra != rb:
				return ra > rb
			if store.runs(a) != store.runs(b):
				return store.runs(a) > store.runs(b)
			return a < b
	)
	return keys


## key -> runs wanted, for every loadout that should be measured (further).
static func targets(store: RefCounted, climb: bool) -> Dictionary:
	var want := {"none": empty_runs}
	for index in sample_size:
		want[Space.key(Space.sample(index))] = sample_runs
	var ranked := ranking(store, RANKED_RUNS)
	var best: float = store.rate(ranked[0]) if not ranked.is_empty() else 0.0
	for key: String in store.results:
		var done: int = store.runs(key)
		if done >= FIRST_RUNS and done < RANKED_RUNS and store.rate(key) >= best * KEEP_SHARE:
			_raise(want, key, RANKED_RUNS)
	if not climb:
		return want
	for rank in ranked.size():
		for step in LADDER:
			if rank < step.x:
				_raise(want, ranked[rank], step.y)
	for key in _climb_from(store):
		for neighbour: Loadout in Space.neighbours(Space.from_key(key)):
			_raise(want, Space.key(neighbour), FIRST_RUNS)
	return want


## The loadouts to climb from: the top CLIMB with a trusted rate, and for each
## buff the best trusted loadout that holds it.
static func _climb_from(store: RefCounted) -> Array[String]:
	var trusted := ranking(store, TRUSTED_RUNS)
	var out: Array[String] = []
	for key in trusted.slice(0, CLIMB):
		out.append(key)
	for def in BuffCatalog.all():
		for key in trusted:
			if key.split("+").has(String(def.id)):
				if not out.has(key):
					out.append(key)
				break
	return out


static func _raise(want: Dictionary, key: String, runs: int) -> void:
	want[key] = maxi(int(want.get(key, 0)), runs)
