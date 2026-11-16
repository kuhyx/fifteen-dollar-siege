class_name BattleImpact
extends RefCounted
## Weight for the big blows. A heavy event kicks `trauma` (squared into the
## shake, the "Art of Screenshake" way: small hits whisper, big ones slam) and
## holds the world for a few frames (hit pause). Common events (clashes,
## volleys) never shake: they would never stop. See DOCS-design-fun.md.

## Largest shake in canvas pixels, and the longest hold in real seconds.
const MAX_PX := 16.0
const MAX_HOLD_S := 0.12
## Trauma lost per real second.
const CALM_PER_S := 1.7
## Shake frequency, radians per real second.
const BUZZ := 70.0

## Event name -> [trauma, hold seconds] [design guess].
const HEAVY := {
	&"monster_smash": [0.6, 0.07],
	&"cart_crash": [0.5, 0.06],
	&"shotgun_blast": [0.35, 0.04],
	&"moose_charge": [0.4, 0.05],
	&"pumpkin_splat": [0.3, 0.04],
	&"squad_wiped": [0.18, 0.0],
	&"reveal": [0.25, 0.05],
	&"victory": [0.5, 0.1],
	&"combust": [0.7, 0.12],
}

var trauma := 0.0
var hold := 0.0


func on_event(event: Dictionary) -> void:
	var kick: Array = HEAVY.get(event.get("kind", &""), [])
	if kick.is_empty():
		return
	trauma = minf(trauma + float(kick[0]), 1.0)
	hold = minf(maxf(hold, float(kick[1])), MAX_HOLD_S)


## True while the world is held for a blow.
func frozen() -> bool:
	return hold > 0.0


func update(delta: float) -> void:
	trauma = maxf(trauma - CALM_PER_S * delta, 0.0)
	hold = maxf(hold - delta, 0.0)


## The view's shift in canvas pixels at real time `clock`.
func offset(clock: float) -> Vector2:
	if trauma <= 0.0:
		return Vector2.ZERO
	var power := trauma * trauma * MAX_PX
	return Vector2(sin(clock * BUZZ), cos(clock * BUZZ * 1.31 + 1.7)) * power
