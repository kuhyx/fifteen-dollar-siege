class_name BattleFlair
extends RefCounted
## The view's own delights, driven by the snapshots and the clock (the sim
## never knows): the weight of heavy blows (BattleImpact), the fallen's pops
## and tally (BattleToll), the signature moments of buffs (BuffMoments) and
## the life of the army's looks (BuffLooks). One `take` per snapshot, one
## `update` per frame. It follows the screen's loadout by itself.

## Real seconds the rare moments live: past BattleEffects.SHED_BELOW_S, so a
## busy frame never sheds a tally, a badge or a rocket (the little ones may go).
const KEEP_S := 2.5
## Rockets fired at a win, the real seconds between two, and between two unmaskings.
const ROCKETS := 8
const ROCKET_GAP_S := 0.32
const UNMASK_GAP_S := 0.18

var impact := BattleImpact.new()
var toll := BattleToll.new()
var moments := BuffMoments.new()
var looks := BuffLooks.new()

var _loadout: Loadout
var _celebrated := false
var _rockets := 0
## [seconds to go, where] of the invisible men the flag unmasks, one by one.
var _unmask: Array[Array] = []
var _rocket_in := 0.0
var _rng := RandomNumberGenerator.new()


## Reads one snapshot taken at real time `now` and lets the screen show it.
func take(shot: SiegeSnapshot, now: float, screen: BattleScreen) -> void:
	_follow(screen)
	var effects := screen.effects
	for event in shot.events:
		impact.on_event(event)
		moments.on_event(event, effects)
		if event.get("kind") == SiegeEvent.VICTORY:
			celebrate(screen)
	var fallen := toll.feed(shot, now)
	for pop: Dictionary in fallen.pops:
		effects.flourish(&"pop", FxToll.pop, 0.55, pop.pos, pop)
	for ring: Dictionary in fallen.tolls:
		effects.flourish(&"toll", FxToll.toll, BattleFlair.KEEP_S, ring.pos, ring)
		var nth := int(ring.total) / BattleToll.MILESTONE
		FunCue.play(&"fun_toll", minf(0.9 + 0.04 * nth, 1.5))
		impact.on_event({"kind": &"squad_wiped"})
		screen.crowd.cheer(0.6)


## The army won: a volley of rockets and a jump for joy, once (the payoff and
## the VICTORY event both call it; a decided siege may carry no event).
func celebrate(screen: BattleScreen) -> void:
	if _celebrated:
		return
	_celebrated = true
	_rockets = ROCKETS
	screen.crowd.cheer(1.5)
	var shot := screen.shot
	for i in shot.entity_count():
		var army := shot.ent_team[i] == SiegeSnapshot.Team.ARMY
		if army and shot.ent_state[i] == SiegeSnapshot.State.HIDDEN:
			_unmask.append([_unmask.size() * UNMASK_GAP_S, shot.ent_pos[i]])


func update(delta: float, screen: BattleScreen) -> void:
	_follow(screen)
	impact.update(delta)
	moments.advance(delta, screen.shot, screen.effects)
	var view := Rect2(screen.camera.to_map(Vector2.ZERO), screen.size / screen.camera.zoom)
	looks.advance(delta, screen.crowd, view, screen.effects)
	_fireworks(delta, screen)
	_unmasking(delta, screen)


## Puts the camera's view on `world`, shaken by the blows.
func frame(world: Node2D, camera: BattleCamera, clock: float) -> void:
	world.transform = camera.transform()
	world.position += impact.offset(clock)


## A volley of rockets over the church after a win.
func _fireworks(delta: float, screen: BattleScreen) -> void:
	_rocket_in -= delta
	if _rockets <= 0 or _rocket_in > 0.0:
		return
	_rockets -= 1
	_rocket_in = ROCKET_GAP_S
	var at: Vector2 = (
		screen.plan.bell + Vector2(_rng.randf_range(-45.0, 45.0), _rng.randf_range(0.0, 25.0))
	)
	screen.effects.flourish(&"firework", FxFireworks.burst, KEEP_S, at, {})
	FunCue.play(&"fun_firework", _rng.randf_range(0.9, 1.15))


## The potions wear off as the flag goes up: each unseen squad appears in a flash.
func _unmasking(delta: float, screen: BattleScreen) -> void:
	for item in _unmask:
		item[0] -= delta
		if item[0] <= 0.0:
			var event := {
				"kind": SiegeEvent.REVEAL, "pos": item[1], "team": SiegeSnapshot.Team.ARMY
			}
			screen.effects.spawn(event)
			screen.crowd.unmask(item[1])
			impact.on_event(event)
			FunCue.play(&"reveal")
	_unmask = _unmask.filter(func(item: Array) -> bool: return item[0] > 0.0)


func _follow(screen: BattleScreen) -> void:
	if _loadout != screen.loadout:
		_loadout = screen.loadout
		moments.setup(_loadout)
		looks.setup(_loadout)
