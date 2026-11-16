class_name BuffLooks
extends RefCounted
## The looks the army wears, kept alive on screen: every so often a figure of
## a dressed squad that is in view glints (knight armour, helmets), flakes
## (cardboard), hiccups (booze) or pings (metal bats). The picks are cosmetic
## and use their own seeded generator.

## Look id -> [effect, real seconds between two, life, cue, pitch].
const LOOKS := {
	&"knight_armor": [&"glint", 0.5, 0.6, &"fun_glint", 1.0],
	&"football_helmets": [&"glint", 0.65, 0.6, &"fun_glint", 1.2],
	&"cardboard_armor": [&"scrap", 0.55, 1.0, &"", 1.0],
	&"booze": [&"hic", 1.2, 1.2, &"fun_hic", 1.0],
	&"metal_bats": [&"ping", 0.8, 0.5, &"fun_glint", 0.7],
}

var _ids: Array[StringName] = []
var _due := {}
var _rng := RandomNumberGenerator.new()


func setup(loadout: Loadout) -> void:
	_ids.clear()
	_due.clear()
	_rng.seed = 1100
	for id: StringName in LOOKS:
		if loadout.has(id):
			_ids.append(id)
			_due[id] = 0.5 + _rng.randf() * 0.5


## `view` is the part of the map on screen, in metres.
func advance(delta: float, crowd: CrowdLayer, view: Rect2, effects: BattleEffects) -> void:
	for id in _ids:
		_due[id] -= delta
		if _due[id] > 0.0:
			continue
		var look: Array = LOOKS[id]
		_due[id] = look[1] * (0.7 + 0.6 * _rng.randf())
		var at := _spot(id, crowd, view)
		if at != Vector2.INF:
			effects.flourish(look[0], _painter(look[0]), look[2], at, {})
			if look[3] != &"":
				FunCue.play(look[3], look[4], at)


static func _painter(kind: StringName) -> Callable:
	match kind:
		&"glint":
			return FxGlints.glint
		&"scrap":
			return FxGlints.scrap
		&"hic":
			return FxGlints.hic
	return FxGlints.ping


## A living figure of a squad that wears the look and stands in view.
func _spot(id: StringName, crowd: CrowdLayer, view: Rect2) -> Vector2:
	var kind := SiegeSnapshot.Kind.BAT_MEN if id == &"metal_bats" else SiegeSnapshot.Kind.MEN
	var squads := crowd.squads.filter(
		func(s: SquadVisual) -> bool:
			return (
				s.kind == kind
				and s.team == SiegeSnapshot.Team.ARMY
				and s.alive > 0
				and view.has_point(s.anchor)
			)
	)
	if squads.is_empty():
		return Vector2.INF
	var squad: SquadVisual = squads[_rng.randi() % squads.size()]
	for attempt in 6:
		var who := _rng.randi() % squad.capacity
		if not squad.is_down(who):
			return squad.place(who)
	return squad.anchor
