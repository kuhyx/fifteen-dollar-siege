class_name Lab
extends RefCounted
## Lab mode: the same siege, headless, many times. Run i uses seed
## base_seed + i, so a batch is reproducible and two batches with different
## base seeds are independent samples.

## Kept from the scaffold's API: every siege is decided long before this (the
## sim's own cap is SiegeTuning.TIME_CAP_S).
const MAX_SIM_S := 3600.0


## One whole siege with no player orders: {outcome: SiegeSim.Outcome,
## seconds: sim time when it was decided}. Every siege is decided by
## SiegeTuning.TIME_CAP_S at the latest.
static func run_one(loadout: Loadout, sim_seed: int) -> Dictionary:
	var sim := SiegeSim.create(loadout, sim_seed)
	sim.run_to_end()
	return {"outcome": sim.outcome(), "seconds": sim.clock_s()}


## `runs` sieges of one loadout: {wins, runs, mean_seconds}. mean_seconds is
## the mean sim time to the decision over all runs (0.0 for an empty batch).
static func run_batch(loadout: Loadout, runs: int, base_seed: int) -> Dictionary:
	var wins := 0
	var seconds := 0.0
	for i in maxi(runs, 0):
		var result := run_one(loadout, base_seed + i)
		if result["outcome"] == SiegeSim.Outcome.WIN:
			wins += 1
		seconds += result["seconds"]
	return {
		"wins": wins,
		"runs": maxi(runs, 0),
		"mean_seconds": seconds / runs if runs > 0 else 0.0,
	}
