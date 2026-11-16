class_name BattleAim
extends RefCounted
## What the battle's camera shows now: a staged beat or the payoff is held as
## it is, the action is followed (never out past BattleCamera.AUTO_MIN_ZOOM).


static func aim(screen: BattleScreen) -> void:
	if screen.beats.staging() or screen.payoff_active:
		screen.camera.frame(focus(screen))
		return
	var anchor := BattleCamera.action_anchor(screen.shot, screen.sim.map())
	screen.camera.follow(focus(screen), anchor)


## The map box to show: the beat, the payoff (the church at a win, the army
## at a loss) or the action.
static func focus(screen: BattleScreen) -> Rect2:
	if screen.beats.staging():
		return screen.beats.beat_box()
	if screen.payoff_active:
		var won := screen.sim.outcome() == SiegeSim.Outcome.WIN
		return BattleBeats.payoff_box(won, screen.plan, screen.shot)
	return BattleCamera.action_box(screen.shot, screen.sim.map(), screen.effects.rally)
