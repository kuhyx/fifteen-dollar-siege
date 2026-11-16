class_name BattleFlair
extends RefCounted
## The view's own delights, driven by the snapshots and the clock (the sim
## never knows): the weight of heavy blows (BattleImpact), the fallen's pops
## and tally (BattleToll), the signature moments of buffs (BuffMoments) and
## the life of the army's looks (BuffLooks). One `take` per snapshot, one
## `update` per frame. It follows the screen's loadout by itself.

var impact := BattleImpact.new()
var toll := BattleToll.new()
var moments := BuffMoments.new()
var looks := BuffLooks.new()

var _loadout: Loadout


## Reads one snapshot taken at real time `now` and lets the screen show it.
func take(shot: SiegeSnapshot, now: float, screen: BattleScreen) -> void:
	_follow(screen)
	var effects := screen.effects
	for event in shot.events:
		impact.on_event(event)
		moments.on_event(event, effects)
	var fallen := toll.feed(shot, now)
	for pop: Dictionary in fallen.pops:
		effects.flourish(&"pop", FxToll.pop, 0.55, pop.pos, pop)
	for ring: Dictionary in fallen.tolls:
		effects.flourish(&"toll", FxToll.toll, 1.9, ring.pos, ring)
		var nth := int(ring.total) / BattleToll.MILESTONE
		FunCue.play(&"fun_toll", minf(0.9 + 0.04 * nth, 1.5))
		impact.on_event({"kind": &"squad_wiped"})


func update(delta: float, screen: BattleScreen) -> void:
	_follow(screen)
	impact.update(delta)
	moments.advance(delta, screen.shot, screen.effects)
	var view := Rect2(screen.camera.to_map(Vector2.ZERO), screen.size / screen.camera.zoom)
	looks.advance(delta, screen.crowd, view, screen.effects)


## Puts the camera's view on `world`, shaken by the blows.
func frame(world: Node2D, camera: BattleCamera, clock: float) -> void:
	world.transform = camera.transform()
	world.position += impact.offset(clock)


func _follow(screen: BattleScreen) -> void:
	if _loadout != screen.loadout:
		_loadout = screen.loadout
		moments.setup(_loadout)
		looks.setup(_loadout)
