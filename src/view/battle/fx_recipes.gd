class_name FxRecipes
extends RefCounted
## Which painter draws which sim event, for how long, and how far it looks
## for a target. One row per name in SiegeEvent.ALL: a name without a row
## has no effect, and tests/view/test_effects.gd fails on it.
## Lives and reaches are [design guess], tuned on the showcase frames.

static var _recipes: Dictionary = {}


## Event name -> [painter, life in real seconds, reach in metres].
static func all() -> Dictionary:
	if _recipes.is_empty():
		_recipes = {
			SiegeEvent.COMMAND: [FxSignals.order, 1.8, 0.0],
			SiegeEvent.ALARM: [FxSignals.alarm, 1.6, 0.0],
			SiegeEvent.BELL_RING: [FxSignals.bell, 1.2, 0.0],
			SiegeEvent.SLING_VOLLEY: [FxShots.sling, 0.7, 70.0],
			SiegeEvent.ARROW_VOLLEY: [FxShots.arrows, 1.1, 110.0],
			SiegeEvent.MELEE_CLASH: [FxBursts.clash, 0.45, 0.0],
			SiegeEvent.SQUAD_ROUT: [FxBursts.rout, 1.2, 0.0],
			SiegeEvent.SQUAD_RALLY: [FxBursts.rally, 1.0, 0.0],
			SiegeEvent.SQUAD_WIPED: [FxBursts.wiped, 1.6, 0.0],
			SiegeEvent.SHOTGUN_BLAST: [FxShots.shotgun, 0.9, 30.0],
			SiegeEvent.PUMPKIN_LAUNCH: [FxShots.pumpkin_launch, 0.8, 120.0],
			SiegeEvent.PUMPKIN_SPLAT: [FxShots.pumpkin_splat, 2.6, 0.0],
			SiegeEvent.HEAL: [FxSignals.heal, 1.1, 0.0],
			SiegeEvent.WASP_SWARM: [FxBursts.wasp_swarm, 2.2, 0.0],
			SiegeEvent.MOOSE_CHARGE: [FxBursts.moose_charge, 1.2, 45.0],
			SiegeEvent.CART_CRASH: [FxBursts.cart_crash, 1.4, 0.0],
			SiegeEvent.MONSTER_SMASH: [FxBursts.monster_smash, 1.0, 0.0],
			SiegeEvent.TRUMPET_CALL: [FxSignals.trumpet, 1.2, 60.0],
			SiegeEvent.BAND_RIFF: [FxSignals.riff, 1.4, 0.0],
			SiegeEvent.REVEAL: [FxSignals.reveal, 1.0, 0.0],
			SiegeEvent.UFO_ABDUCT: [FxSpecials.abduct, 3.0, 0.0],
			SiegeEvent.PEP_TALK: [FxSpecials.pep, 2.6, 0.0],
			SiegeEvent.CENTRE_HELD: [FxSignals.centre, 0.6, 0.0],
			SiegeEvent.VICTORY: [FxSpecials.victory, 3.0, 0.0],
			SiegeEvent.COMBUST: [FxSpecials.combust, 2.5, 0.0],
		}
	return _recipes
