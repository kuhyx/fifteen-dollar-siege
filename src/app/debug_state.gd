class_name DebugState
extends RefCounted
## The whole visible state of `Main` as plain data: the dev feedback's
## snapshot.json and the hand-off checks read it (`Main.debug_state()`).


static func of(main: Main) -> Dictionary:
	var out := {
		"screen": String(main.screen_name),
		"mode": String(main.mode),
		"loadout": main.loadout.ids.map(func(id: StringName) -> String: return String(id)),
		"cost": main.loadout.cost(),
		"men": SiegeSim.army_size(main.loadout),
		"seed": main.sim_seed,
		"speed": main.options.speed,
		"paused": main.get_tree().paused,
	}
	var battle := main.screen as BattleScreen
	if battle != null:
		out["siege"] = _siege(battle)
	var lab := main.screen as LabScreen
	if lab != null:
		out["lab"] = lab.result.duplicate()
	return out


static func _siege(battle: BattleScreen) -> Dictionary:
	var shot := battle.shot
	var entities: Array[Dictionary] = []
	for i in shot.entity_count():
		entities.append(battle.pick_at(battle.map_to_canvas(shot.ent_pos[i])))
	return {
		"clock_s": snappedf(shot.clock_s, 0.001),
		"outcome": SiegeSim.Outcome.keys()[shot.outcome],
		"army_morale": shot.army_morale,
		"village_morale": shot.village_morale,
		"alarm": shot.alarm,
		"state_hash": battle.sim.state_hash(),
		"commands_sent": battle.commands_sent,
		"entities": entities,
	}
