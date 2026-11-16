extends RefCounted
## The orders the --autodrive bot gives in Command mode (src/autodrive/
## autodrive.gd `_give_orders`): a rally at RALLY_AT, then retreat, then
## charge. The bot counts frames, so the exact ticks depend on the frame
## step; TIMINGS covers the window, one row (rally, retreat, charge tick) each.

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
