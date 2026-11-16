class_name BattleToll
extends RefCounted
## Counts the fallen from snapshot to snapshot (the sim stays untouched): a
## squad that lost heads pops where it stood, and every ten villagers that
## fall ring a gold tally. Pops are throttled per squad and capped per
## snapshot, so a storm of deaths is one burst a squad, never a flood.

## Villagers fallen per tally bell (a whole siege fells about a hundred: the
## sim wins by morale, so every fallen head counts).
const MILESTONE := 10
## Real seconds one squad waits between pops; the most pops one snapshot gives.
const POP_GAP_S := 0.25
const MAX_POPS := 8

## Heads fallen so far, by SiegeSnapshot.Team.
var fallen: Array[int] = [0, 0]

var _count := {}
var _kind := {}
var _owed := {}
var _last := {}


## Reads one snapshot taken at real time `now`: {pops: [{pos, team, n}],
## tolls: [{team, total, pos}]}. The first snapshot only sets the baseline.
func feed(shot: SiegeSnapshot, now: float) -> Dictionary:
	var pops: Array[Dictionary] = []
	var tolls: Array[Dictionary] = []
	for i in shot.entity_count():
		var heads := shot.ent_count[i]
		var team := int(shot.ent_team[i])
		if _kind.get(i, -1) == shot.ent_kind[i] and _count.has(i) and heads < _count[i]:
			var lost: int = _count[i] - heads
			_owed[i] = int(_owed.get(i, 0)) + lost
			var before: int = fallen[team] / MILESTONE
			fallen[team] += lost
			if team == SiegeSnapshot.Team.VILLAGE:
				for step in range(before + 1, fallen[team] / MILESTONE + 1):
					tolls.append({"team": team, "total": step * MILESTONE, "pos": shot.ent_pos[i]})
		_kind[i] = shot.ent_kind[i]
		_count[i] = heads
		if int(_owed.get(i, 0)) > 0 and now - float(_last.get(i, -INF)) >= POP_GAP_S:
			if pops.size() < MAX_POPS:
				pops.append({"pos": shot.ent_pos[i], "team": team, "n": _owed[i]})
				_owed[i] = 0
				_last[i] = now
	return {"pops": pops, "tolls": tolls}
