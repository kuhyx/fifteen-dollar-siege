class_name FxAim
extends RefCounted
## Where an effect points, read from the latest snapshot.


## The nearest enemy within `reach`, else straight at the other side's ground
## (the village for the army, the camp for the village).
static func target(shot: SiegeSnapshot, plan: MapPlan, fx: BattleFx, reach: float) -> Vector2:
	if reach <= 0.0:
		return fx.pos
	var best := Vector2.INF
	for i in shot.entity_count():
		if shot.ent_team[i] == fx.team or shot.ent_count[i] <= 0:
			continue
		var gap := shot.ent_pos[i].distance_to(fx.pos)
		if gap <= reach and gap < best.distance_to(fx.pos):
			best = shot.ent_pos[i]
	if best != Vector2.INF:
		return best
	var home := Vector2.ZERO
	if plan != null:
		home = plan.map.village_center if fx.team == SiegeSnapshot.Team.ARMY else plan.camp
	return fx.pos + (home - fx.pos).limit_length(reach * 0.7)


## The middle of `team`'s entities (`fallback` when it has none).
static func middle(shot: SiegeSnapshot, team: int, fallback: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == team and shot.ent_count[i] > 0:
			sum += shot.ent_pos[i]
			count += 1
	return sum / count if count > 0 else fallback
