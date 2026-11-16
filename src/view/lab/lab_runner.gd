class_name LabRunner
extends RefCounted
## A Lab batch run a slice at a time, so the frame never waits for a whole
## siege (the web build has one thread and no loading screen is allowed).
## It steps the same sims Lab.run_batch runs, in the same order, and stops
## when the frame's budget is used: run i uses seed base_seed + i and the
## result has Lab.run_batch's shape and numbers (tests/test_lab_screen.gd).

## Sim ticks between two looks at the clock.
const TICKS_PER_LOOK := 8

var loadout := Loadout.new()
var total := 0
var base_seed := 0
## {wins, runs, mean_seconds} so far.
var result := {"wins": 0, "runs": 0, "mean_seconds": 0.0}
## One byte per finished run, in order: 1 = won.
var outcomes := PackedByteArray()

var _sim: SiegeSim
var _seconds := 0.0


func _init(p_loadout: Loadout, p_total: int, p_base_seed: int) -> void:
	loadout = p_loadout.duplicate()
	total = maxi(p_total, 0)
	base_seed = p_base_seed


func is_done() -> bool:
	return result["runs"] >= total


## Runs sieges for about `budget_ms` milliseconds (always at least a few
## ticks, so a slow machine still gets there).
func work(budget_ms: int) -> void:
	var started := Time.get_ticks_msec()
	while not is_done():
		if _sim == null:
			_sim = SiegeSim.create(loadout, base_seed + int(result["runs"]))
		for i in TICKS_PER_LOOK:
			if _decided():
				break
			_sim.step(SiegeSim.STEP_S)
		if _decided():
			_count()
		if Time.get_ticks_msec() - started >= budget_ms:
			return


func _decided() -> bool:
	return _sim.outcome() != SiegeSim.Outcome.RUNNING or _sim.clock_s() >= Lab.MAX_SIM_S


func _count() -> void:
	var won := _sim.outcome() == SiegeSim.Outcome.WIN
	outcomes.append(1 if won else 0)
	if won:
		result["wins"] += 1
	_seconds += _sim.clock_s()
	result["runs"] += 1
	result["mean_seconds"] = _seconds / result["runs"]
	_sim = null
