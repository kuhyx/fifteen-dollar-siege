class_name BattleFlair
extends RefCounted
## The view's own delights, driven by the snapshots (the sim never knows):
## the weight of heavy blows (BattleImpact) and the fallen's pops and tally
## (BattleToll). One `take` per snapshot, one `update` per frame.

var impact := BattleImpact.new()
var toll := BattleToll.new()


## Reads one snapshot taken at real time `now` and lets `effects` show it.
func take(shot: SiegeSnapshot, now: float, effects: BattleEffects) -> void:
	for event in shot.events:
		impact.on_event(event)
	var fallen := toll.feed(shot, now)
	for pop: Dictionary in fallen.pops:
		effects.flourish(&"pop", FxToll.pop, 0.55, pop.pos, pop)
	for ring: Dictionary in fallen.tolls:
		effects.flourish(&"toll", FxToll.toll, 1.9, ring.pos, ring)
		var nth := int(ring.total) / BattleToll.MILESTONE
		FunCue.play(&"fun_toll", minf(0.9 + 0.04 * nth, 1.5))
		impact.on_event({"kind": &"squad_wiped"})


func update(delta: float) -> void:
	impact.update(delta)


## Puts the camera's view on `world`, shaken by the blows.
func frame(world: Node2D, camera: BattleCamera, clock: float) -> void:
	world.transform = camera.transform()
	world.position += impact.offset(clock)
