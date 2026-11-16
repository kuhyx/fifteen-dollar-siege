class_name SiegeSnapshot
extends RefCounted
## What the view needs to draw one moment of the siege. Entities are parallel
## packed arrays (index = entity). An entity is a squad or a special; the view
## scatters `ent_count` individual figures around `ent_pos`.

enum Team { ARMY, VILLAGE }
## What an entity is. Frozen contract between sim and view: append at the END
## only. MEN = ordinary army squad, VILLAGERS = non-combatants (flee, hide).
## Village fighters: MILITIA (farm tools), RETINUE (the lord's mailed men),
## ARCHERS. The rest are buff specials on the army side; UFO is neutral.
enum Kind {
	MEN,
	VILLAGERS,
	MILITIA,
	RETINUE,
	ARCHERS,
	BAT_MEN,
	SHOTGUNNER,
	EMPEROR,
	TRUMPET_BOY,
	MEDICS,
	MONSTER,
	MOOSE,
	WASPS,
	GOLF_CARTS,
	CATAPULT,
	ROCK_BAND,
	UFO,
}
enum State { IDLE, MOVE, FIGHT, FLEE, DOWN, HIDDEN }

## Sim seconds since the siege began.
var clock_s := 0.0
## SiegeSim.Outcome.
var outcome := 0
## 0 (broken) .. 1 (fresh).
var army_morale := 1.0
var village_morale := 1.0
## 0 (asleep) .. 1 (the whole village knows).
var alarm := 0.0
## 0 .. 1: how much of the 30 s the army has held the plaza (1 = won by it).
var centre_hold := 0.0

## Position in map metres.
var ent_pos := PackedVector2Array()
## Kind.
var ent_kind := PackedInt32Array()
## Team.
var ent_team := PackedByteArray()
## Heads alive in the squad / entity.
var ent_count := PackedInt32Array()
## State.
var ent_state := PackedByteArray()
## Facing, radians (0 = +x).
var ent_facing := PackedFloat32Array()
## The squad's own morale, 0 .. 1 (it routs near 0.2; specials stay at 1).
var ent_morale := PackedFloat32Array()

## What happened since the previous snapshot: {kind: StringName, pos: Vector2,
## ...optional data}. Drained once per snapshot; drives VFX and SFX.
var events: Array[Dictionary] = []


func entity_count() -> int:
	return ent_pos.size()
