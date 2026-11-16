extends GutTest
## The balance claim, from the repo alone: the sweep committed in
## tools/sim/data/<sim hash>/ was measured on THIS sim, and it meets kuhy's bar
## (no buffs under 5 %, a random loadout 25-45 %, the best 85 % or more, each of
## the 25 buffs in one of the top 50). Red after any change to src/core: search
## again and commit the new sweep (DOCS-design-sim.md section 9).

const Store = preload("res://tools/sim/balance_store.gd")
const Targets = preload("res://tools/sim/balance_targets.gd")

var _found := {}
var _store: RefCounted


func before_all() -> void:
	# Store.open makes a missing folder: never inside the tracked tree.
	if not DirAccess.dir_exists_absolute(Store.committed_root().path_join(Store.hash_of_sim())):
		return
	_store = Store.open(Store.committed_root())
	_found = Targets.evaluate(_store)


func test_the_committed_sweep_is_keyed_to_the_current_sim() -> void:
	var hashes := Array(DirAccess.get_directories_at(Store.committed_root()))
	assert_eq(hashes, [Store.hash_of_sim()], "exactly one sweep, the current sim's")
	var dir := Store.committed_root().path_join(Store.hash_of_sim())
	var files := 0
	for file in DirAccess.get_files_at(dir):
		var parsed: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(dir.path_join(file))
		)
		assert_eq(parsed["sim_hash"], Store.hash_of_sim(), file)
		files += 1
	assert_gt(files, 0, "the sweep has result files")


func test_the_empty_loadout_wins_under_5_percent() -> void:
	assert_false(_found.is_empty(), "a sweep for this sim is committed")
	assert_true(_found["measured"], "measured at least 100 times")
	assert_lt(_found["empty"], 0.05)


func test_a_random_loadout_wins_25_to_45_percent() -> void:
	assert_between(_found["sample"][0], 25.0, 45.0)
	assert_gt(_found["sample"][1], 100, "over a real sample")


func test_the_best_loadout_wins_85_percent_or_more() -> void:
	assert_gte(_found["best"], 0.85)


func test_every_buff_is_in_a_top_50_loadout() -> void:
	assert_eq(_found["missing"], [] as Array[String])
	assert_eq(_found["top"].size(), 50)
	assert_true(_found["ok"])
