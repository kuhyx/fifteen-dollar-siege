extends GutTest
## Lab: N headless sieges of one loadout, reproducible from the base seed.

## A small army: its sieges are short, so the batches below stay cheap.
const IDS: Array[StringName] = [&"metal_bats", &"stew"]


func test_a_batch_reports_wins_runs_and_mean_seconds() -> void:
	var result := Lab.run_batch(Loadout.of(IDS), 12, 100)
	assert_eq(result.keys(), ["wins", "runs", "mean_seconds"])
	assert_eq(result["runs"], 12)
	assert_between(result["wins"], 0, 12)
	assert_gt(result["mean_seconds"], 0.0)
	assert_lte(float(result["mean_seconds"]), SiegeTuning.TIME_CAP_S, "every siege is decided")


func test_the_same_base_seed_gives_the_same_batch() -> void:
	var loadout := Loadout.of(IDS)
	var batch := Lab.run_batch(loadout, 5, 7)
	assert_eq(batch, Lab.run_batch(loadout, 5, 7))
	var other := Lab.run_batch(loadout, 5, 8000)
	assert_ne(other["mean_seconds"], batch["mean_seconds"])


func test_an_empty_batch_is_all_zeros() -> void:
	for runs: int in [0, -3]:
		var result := Lab.run_batch(Loadout.new(), runs, 1)
		assert_eq(result, {"wins": 0, "runs": 0, "mean_seconds": 0.0})


func test_run_one_matches_a_hand_stepped_siege() -> void:
	var loadout := Loadout.of(IDS)
	var one := Lab.run_one(loadout, 55)
	var sim := SiegeSim.create(loadout, 55)
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		sim.step(SiegeSim.STEP_S)
	assert_eq(one["outcome"], sim.outcome())
	assert_almost_eq(float(one["seconds"]), sim.clock_s(), 0.0001)


func test_a_batch_is_the_sum_of_its_single_runs() -> void:
	var loadout := Loadout.of(IDS)
	var seconds := 0.0
	for i in 5:
		seconds += Lab.run_one(loadout, 300 + i)["seconds"]
	assert_almost_eq(float(Lab.run_batch(loadout, 5, 300)["mean_seconds"]), seconds / 5.0, 0.0001)


func test_a_lab_siege_equals_a_watched_one() -> void:
	var loadout := Loadout.of(IDS)
	var watched := SiegeSim.create(loadout, 77)
	while watched.outcome() == SiegeSim.Outcome.RUNNING:
		watched.step(0.5)
		watched.snapshot()
	var lab := Lab.run_one(loadout, 77)
	assert_eq(lab["outcome"], watched.outcome(), "recording events changes nothing")
	assert_almost_eq(float(lab["seconds"]), watched.clock_s(), 0.0001)
