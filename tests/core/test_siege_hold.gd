extends GutTest
## The second way to win: the army holds the plaza for HOLD_S (30 s) while the
## village's morale has not broken (src/core/siege_referee.gd, DOCS-design-sim.md
## section 4). Only the public API is used: the hold is the snapshot's
## centre_hold (0..1), the village's nerve is village_morale (0 = broken).
## Watch mode never takes the plaza unseen; the 50 invisible men of
## `invisibility_potions` do, so one potion loadout and one seed carry both
## tests. Red after a tuning change: find a seed with a probe that prints
## centre_hold and village_morale of the snapshot before the siege ends.

const WIN := SiegeSim.Outcome.WIN
const IDS: Array[StringName] = [&"invisibility_potions"]
## Seed 5 holds the plaza the full 30 s and wins; cut short by a retreat it does not.
const HOLD_SEED := 5
## One decision step of the sim: the hold moves by this fraction each step.
const STEP_HOLD := SiegeTuning.THINK_S / SiegeTuning.HOLD_S


## One snapshot per decision step. `retreat_at` >= 0 orders a retreat at the first
## step whose hold is that full.
class Run:
	extends RefCounted
	var sim: SiegeSim
	var holds: Array[float] = []
	var morales: Array[float] = []
	var clocks: Array[float] = []
	var events: Array[Dictionary] = []


func _run(retreat_at := -1.0) -> Run:
	var run := Run.new()
	run.sim = SiegeSim.create(Loadout.of(IDS), HOLD_SEED)
	while run.sim.outcome() == SiegeSim.Outcome.RUNNING:
		run.sim.step(SiegeTuning.THINK_S)
		var shot := run.sim.snapshot()
		run.holds.append(shot.centre_hold)
		run.morales.append(shot.village_morale)
		run.clocks.append(run.sim.clock_s())
		run.events.append_array(shot.events)
		if retreat_at >= 0.0 and shot.centre_hold >= retreat_at:
			run.sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
			retreat_at = -1.0
	return run


func _kinds(run: Run, kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in run.events:
		if event["kind"] == kind:
			out.append(event)
	return out


func test_holding_the_plaza_for_30_s_wins_with_the_village_unbroken() -> void:
	var run := _run()
	var last := run.holds.size() - 1
	assert_eq(run.sim.outcome(), WIN)
	assert_eq(run.holds[last], 1.0, "the hold is full at the winning step")
	assert_almost_eq(run.holds[last - 1], 1.0 - STEP_HOLD, 1e-4, "one step short before it")
	assert_gt(run.morales[last - 1], 0.5, "the village had not broken: the hold won it")
	var first := run.holds.find_custom(func(hold: float) -> bool: return hold > 0.0)
	assert_gt(first, 0, "the hold starts after the siege does")
	var held_s := run.clocks[last] - run.clocks[first]
	assert_almost_eq(held_s, SiegeTuning.HOLD_S - SiegeTuning.THINK_S, 0.01, "30 s of holding")
	for step in range(first + 1, last + 1):
		assert_almost_eq(run.holds[step] - run.holds[step - 1], STEP_HOLD, 1e-4, "never lets go")


func test_the_win_raises_victory_after_the_last_centre_held_cue() -> void:
	var run := _run()
	var cues := _kinds(run, SiegeEvent.CENTRE_HELD)
	assert_eq(run.sim.outcome(), WIN)
	assert_eq(_kinds(run, SiegeEvent.VICTORY).size(), 1)
	assert_eq(cues.size(), 10, "one cue every 3 s of holding")
	assert_eq(cues.back()["progress"], 1.0, "the last cue is the full hold")


func test_leaving_the_plaza_bleeds_the_hold_and_it_never_wins() -> void:
	var run := _run(0.5)
	var top := run.holds.find(run.holds.max())
	assert_gte(run.holds.max(), 0.5, "the hold was building")
	assert_lt(run.holds.max(), 1.0, "and was never completed")
	assert_ne(run.sim.outcome(), WIN, "the same seed wins when nobody leaves")
	assert_lt(run.holds[top + 1], run.holds[top], "it stops growing right after the peak")
	var step := top + 1
	while run.holds[step] > 0.0:
		var drop := run.holds[step - 1] - run.holds[step]
		assert_almost_eq(drop, STEP_HOLD, 1e-4, "each step off the plaza costs THINK_S")
		step += 1
