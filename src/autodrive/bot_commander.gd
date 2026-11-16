class_name BotCommander
extends RefCounted
## The Command-mode bot's orders, read from what a player sees (the snapshot
## and the map), one decision per call:
##   1. RALLY in the open, LURE_M short of the houses: the defenders come out
##      to the flag in ones and twos, into rested men and their slings;
##   2. RETREAT when the army's morale has sunk to RETREAT_BELOW while the
##      village still stands (VILLAGE_STANDS): the men recover out of reach,
##      and rally again once they are back at RALLY_AGAIN;
##   3. CHARGE when the village's morale has sagged to CHARGE_BELOW, or the
##      men have waited MAX_WAIT_S since the alarm: one rush among the houses.
## (tools/sim/commander.gd is the balance gate's own player: rally and charge.)

const LURE_M := 25.0
const CHARGE_BELOW := 0.55
const MAX_WAIT_S := 75.0
const RETREAT_BELOW := 0.3
const VILLAGE_STANDS := 0.6
const RALLY_AGAIN := 0.6

## True: never retreat (a test tells the retreat's part apart).
var never_retreats := false

var _stage := 0
var _since := 0.0
var _retreated := false


## {kind, pos} of the order due now ({} for none).
func advise(shot: SiegeSnapshot, map: SiegeMap) -> Dictionary:
	var kind := _due(shot)
	if kind < 0:
		return {}
	var at := Vector2.ZERO
	if kind == SiegeSim.Command.RALLY:
		at = flag_for(map)
	return {"kind": kind, "pos": at}


## The order due now (-1 for none); moves the plan on when it gives one.
func _due(shot: SiegeSnapshot) -> int:
	if _stage == 0 or (_stage == 2 and shot.army_morale >= RALLY_AGAIN):
		_stage = 1
		return SiegeSim.Command.RALLY
	if _stage != 1 or shot.alarm < 1.0:
		if shot.alarm < 1.0:
			_since = shot.clock_s
		return -1
	if shot.village_morale <= CHARGE_BELOW or shot.clock_s - _since >= MAX_WAIT_S:
		_stage = 3
		return SiegeSim.Command.CHARGE
	var worn := shot.army_morale <= RETREAT_BELOW and shot.village_morale >= VILLAGE_STANDS
	if worn and not _retreated and not never_retreats:
		_retreated = true
		_stage = 2
		return SiegeSim.Command.RETREAT
	return -1


## The rally flag: on the line from the village to the army's camp, outside
## the houses by LURE_M.
static func flag_for(map: SiegeMap) -> Vector2:
	var back := (map.army_spawn - map.village_center).normalized()
	return map.village_center + back * (map.village_radius + LURE_M)
