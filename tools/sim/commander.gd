extends RefCounted
## A scripted player for Command mode, the "played well" that the balance gate
## and the tests compare Watch mode against. It reads only what a player sees
## (the snapshot and the map) and gives two of the three orders:
##   1. RALLY in the open, LURE_M short of the houses: the defenders come out
##      to the flag in ones and twos, away from their walls and their
##      neighbours' eyes, into rested men and their slings;
##   2. when the village's morale has sagged to CHARGE_BELOW (or the men have
##      waited MAX_WAIT_S), CHARGE: one rush to finish it among the houses.

const LURE_M := 25.0
const CHARGE_BELOW := 0.55
const MAX_WAIT_S := 75.0

## False: only the rally, never the charge (to tell the two apart).
var charges := true

var _flag_up := false
var _charged := false
var _since := 0.0


## Plays `sim` to its decision; returns the outcome.
static func play(sim: SiegeSim, with_charge := true) -> int:
	var commander := new()
	commander.charges = with_charge
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		commander.advise(sim)
		sim.step(SiegeSim.STEP_S * 5)
	return sim.outcome()


## Looks at the siege and gives an order when one is due.
func advise(sim: SiegeSim) -> void:
	if _charged:
		return
	var map := sim.map()
	if not _flag_up:
		_flag_up = true
		var back := (map.army_spawn - map.village_center).normalized()
		var flag := map.village_center + back * (map.village_radius + LURE_M)
		sim.command(SiegeSim.Command.RALLY, flag)
		return
	var shot := sim.snapshot()
	if shot.alarm < 1.0:
		_since = shot.clock_s
		return
	var waited := shot.clock_s - _since
	if charges and (shot.village_morale <= CHARGE_BELOW or waited >= MAX_WAIT_S):
		_charged = true
		sim.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
