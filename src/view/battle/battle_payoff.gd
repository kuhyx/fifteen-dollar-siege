class_name BattlePayoff
extends RefCounted
## What the battle screen does the moment the siege is decided: at a loss the
## army catches fire, the village dims and the night falls; at a win the flag
## goes up on the church and the army stays bright. Then the payoff clock runs.


static func begin(battle: BattleScreen) -> void:
	if battle.sim.outcome() == SiegeSim.Outcome.LOSE:
		battle.crowd.ignite(SiegeSnapshot.Team.ARMY)
		battle.crowd.spotlight(SiegeSnapshot.Team.ARMY, CrowdLayer.DIM_LOSS)
		battle.effects.veil_goal = 1.0
	else:
		battle.effects.flag_up = true
		battle.flair.celebrate(battle)
		battle.crowd.spotlight(SiegeSnapshot.Team.ARMY, CrowdLayer.DIM_WIN)
	battle.beats.start_payoff(battle.payoff_s)
