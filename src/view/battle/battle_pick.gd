class_name BattlePick
extends RefCounted
## What is under a point of the battle screen, as plain data: the dev
## feedback's select tool and Main.debug_state() ask this.

const PICK_PX := 40.0
const STATE_NAMES: Array[String] = ["idle", "move", "fight", "flee", "down", "hidden"]


## The entity whose anchor is nearest `point` (canvas pixels), {} when none
## is within PICK_PX.
static func entity_at(shot: SiegeSnapshot, camera: BattleCamera, point: Vector2) -> Dictionary:
	var best := -1
	var best_px := PICK_PX
	for i in shot.entity_count():
		var px := camera.to_canvas(shot.ent_pos[i]).distance_to(point)
		if px < best_px:
			best = i
			best_px = px
	if best < 0:
		return {}
	var at := shot.ent_pos[best]
	return {
		"kind": "entity",
		"id": "entity_%d" % best,
		"team": "army" if shot.ent_team[best] == SiegeSnapshot.Team.ARMY else "village",
		"entity_kind": shot.ent_kind[best],
		"count": shot.ent_count[best],
		"state": STATE_NAMES[shot.ent_state[best]],
		"position": [snappedf(at.x, 0.1), snappedf(at.y, 0.1)],
	}
