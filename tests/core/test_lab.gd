extends GutTest
## Lab: N headless sieges of one loadout, reproducible from the base seed.

const WIN_IDS: Array[StringName] = [&"double_men", &"fifty_men"]
const LOSE_IDS: Array[StringName] = [&"stew"]


func test_a_batch_reports_wins_runs_and_mean_seconds() -> void:
	var result := Lab.run_batch(Loadout.of(WIN_IDS), 12, 100)
	assert_eq(result.keys(), ["wins", "runs", "mean_seconds"])
	assert_eq(result["runs"], 12)
	assert_eq(result["wins"], 12, "the stub always wins at 9 dollars")
	assert_between(result["mean_seconds"], 18.0, 22.0)


func test_a_losing_loadout_never_wins() -> void:
	var result := Lab.run_batch(Loadout.of(LOSE_IDS), 12, 100)
	assert_eq(result["wins"], 0)
	assert_eq(result["runs"], 12)


func test_the_same_base_seed_gives_the_same_batch() -> void:
	var loadout := Loadout.of(WIN_IDS)
	assert_eq(Lab.run_batch(loadout, 8, 7), Lab.run_batch(loadout, 8, 7))
	var other := Lab.run_batch(loadout, 8, 8000)
	assert_ne(other["mean_seconds"], Lab.run_batch(loadout, 8, 7)["mean_seconds"])


func test_an_empty_batch_is_all_zeros() -> void:
	for runs: int in [0, -3]:
		var result := Lab.run_batch(Loadout.new(), runs, 1)
		assert_eq(result, {"wins": 0, "runs": 0, "mean_seconds": 0.0})


func test_run_one_matches_a_hand_stepped_siege() -> void:
	var loadout := Loadout.of(WIN_IDS)
	var one := Lab.run_one(loadout, 55)
	var sim := SiegeSim.create(loadout, 55)
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		sim.step(SiegeSim.STEP_S)
	assert_eq(one["outcome"], sim.outcome())
	assert_almost_eq(float(one["seconds"]), sim.clock_s(), 0.0001)


func test_a_batch_is_the_sum_of_its_single_runs() -> void:
	var loadout := Loadout.of(WIN_IDS)
	var seconds := 0.0
	for i in 5:
		seconds += Lab.run_one(loadout, 300 + i)["seconds"]
	assert_almost_eq(float(Lab.run_batch(loadout, 5, 300)["mean_seconds"]), seconds / 5.0, 0.0001)
