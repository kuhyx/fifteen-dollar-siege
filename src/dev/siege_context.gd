extends RefCounted
## This game's fields of one feedback record (the shared addon adds session,
## build, engine, game, pause state, scene and window sizes): mode, screen,
## loadout, the variant (what the siege was built from), settings and the
## player's pose. `state` is Main.debug_state().
## No class_name (dev files reach each other with preload).


static func fields(state: Dictionary) -> Dictionary:
	return {
		"mode": state["mode"],
		"screen": state["screen"],
		"loadout": state["loadout"],
		"variant":
		{
			"mode": state["mode"],
			"loadout": state["loadout"],
			"cost": state["cost"],
			"men": state["men"],
			"seed": state["seed"],
		},
		"settings": {"speed": state["speed"]},
		"player": player(state),
	}


## What the player was doing: this game's stand-in for a player pose.
static func player(state: Dictionary) -> Dictionary:
	var siege: Dictionary = state.get("siege", {})
	return {
		"screen": state["screen"],
		"clock_s": siege.get("clock_s", 0.0),
		"outcome": siege.get("outcome", "NONE"),
		"commands_sent": siege.get("commands_sent", 0),
	}
