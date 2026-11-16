extends RefCounted
## The fixed three-order burst the pinned fixtures are held to: a rally at
## RALLY_AT, then retreat, then charge, at one row of TIMINGS (sim ticks since
## the start of the siege). It is NOT the Command bot of the autodrive: that is
## `BotCommander` (src/autodrive/bot_commander.gd), which reads the battle. Used
## by `find_fixtures.gd` (which loadouts and seeds survive every timing),
## `tests/core/test_siege_fixtures.gd`, and, as the order sequence a LOST Command
## siege gets, `SiegeRound.give_orders` (src/autodrive/siege_round.gd, whose
## `BURST_RALLY_AT` repeats RALLY_AT: shipped code never preloads tools/).
## Headless, outside the sim hash (which covers src/core/*.gd only).

const RALLY_AT := Vector2(200.0, 90.0)
const TIMINGS: Array[Vector3i] = [
	Vector3i(55, 120, 123),
	Vector3i(60, 128, 131),
	Vector3i(66, 135, 138),
	Vector3i(72, 142, 147),
	Vector3i(80, 150, 158),
]


## The outcome of the siege under the three orders given at `timing`.
static func play(loadout: Loadout, sim_seed: int, timing: Vector3i) -> int:
	var sim := SiegeSim.create(loadout, sim_seed)
	sim.step(timing.x * SiegeSim.STEP_S)
	sim.command(SiegeSim.Command.RALLY, RALLY_AT)
	sim.step((timing.y - timing.x) * SiegeSim.STEP_S)
	sim.command(SiegeSim.Command.RETREAT, Vector2.ZERO)
	sim.step((timing.z - timing.y) * SiegeSim.STEP_S)
	sim.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
	return sim.run_to_end()
