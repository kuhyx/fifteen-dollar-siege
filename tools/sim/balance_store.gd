extends RefCounted
## Where the balance search keeps what it measured, so every call can stop
## after a minute and the next one carries on. One folder per sim hash (a hash
## of every src/core/*.gd file: any change to the sim or a constant starts a
## fresh folder), one JSON file per shard:
##   ~/data/claude-scratch/fifteen-dollar-siege/balance/<sim hash>/shard-K-of-N.json
##   {"results": {"<loadout key>": [wins, runs, sim seconds summed, push summed]}}
## (push of one siege = 1 - SiegeSim.village_low(): how close the army came)
## Run r of a loadout always uses seed SEED0 + r, so a result never depends on
## which call or shard produced it.

const SEED0 := 1000
const CORE_DIR := "res://src/core"

## key -> [wins, runs, seconds], every shard merged.
var results := {}
var sim_hash := ""
var _dir := ""


static func open(root: String) -> RefCounted:
	var store := new()
	store.sim_hash = hash_of_sim()
	store.attach(root.path_join(store.sim_hash))
	return store


## The default folder (override with --store=DIR).
static func default_root() -> String:
	var home := OS.get_environment("HOME")
	return home.path_join("data/claude-scratch/fifteen-dollar-siege/balance")


## 12 hex digits over the text of every core script, in name order.
static func hash_of_sim() -> String:
	var files := Array(DirAccess.get_files_at(CORE_DIR))
	files.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for file: String in files:
		if file.ends_with(".gd"):
			context.update(FileAccess.get_file_as_bytes(CORE_DIR.path_join(file)))
	return context.finish().hex_encode().substr(0, 12)


## Shard of a loadout key (0 .. shards-1): stable across runs and machines.
static func shard_of(key: String, shards: int) -> int:
	return key.md5_buffer().decode_u32(0) % maxi(shards, 1)


## Points the store at `dir` (made when missing) and reads what is there.
func attach(dir: String) -> void:
	_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	reload()


func wins(key: String) -> int:
	return int(results[key][0]) if results.has(key) else 0


func runs(key: String) -> int:
	return int(results[key][1]) if results.has(key) else 0


func rate(key: String) -> float:
	var done := runs(key)
	return float(wins(key)) / done if done > 0 else 0.0


func mean_seconds(key: String) -> float:
	var done := runs(key)
	return float(results[key][2]) / done if done > 0 else 0.0


## Mean of 1 - village_low over the loadout's sieges: 1 = it always won.
func mean_push(key: String) -> float:
	var done := runs(key)
	return float(results[key][3]) / done if done > 0 else 0.0


func add(key: String, won: bool, seconds: float, push: float) -> void:
	var row: Array = results.get(key, [0, 0, 0.0, 0.0])
	results[key] = [
		int(row[0]) + int(won), int(row[1]) + 1, float(row[2]) + seconds, float(row[3]) + push
	]


## Runs sieges of `loadout` until it has `target` of them or `deadline_ms`
## (Time.get_ticks_msec) passes. Returns how many it ran.
func measure(loadout: Loadout, key: String, target: int, deadline_ms: int) -> int:
	var ran := 0
	while runs(key) < target and Time.get_ticks_msec() < deadline_ms:
		var sim := SiegeSim.create(loadout, SEED0 + runs(key))
		var won := sim.run_to_end() == SiegeSim.Outcome.WIN
		add(key, won, sim.clock_s(), 1.0 - sim.village_low())
		ran += 1
	return ran


## Reads every shard file of this sim hash again (other shards may have written).
func reload() -> void:
	results = {}
	for file in DirAccess.get_files_at(_dir):
		if file.ends_with(".json"):
			_merge(_dir.path_join(file))


## Writes the results that belong to `shard` of `shards`.
func save(shard: int, shards: int) -> void:
	var mine := {}
	for key: String in results:
		if shard_of(key, shards) == shard:
			mine[key] = results[key]
	var path := _dir.path_join("shard-%d-of-%d.json" % [shard, shards])
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"sim_hash": sim_hash, "results": mine}))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)


## Adds one file's rows; a loadout measured in two files keeps the longer run.
func _merge(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var rows: Dictionary = parsed.get("results", {})
	for key: String in rows:
		var row: Array = rows[key]
		if int(row[1]) > runs(key):
			results[key] = [int(row[0]), int(row[1]), float(row[2]), float(row[3])]
