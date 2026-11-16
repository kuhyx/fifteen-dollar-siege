class_name SiegeSnapshot
extends RefCounted
## What the view needs to draw one moment of the siege. Entities are parallel
## packed arrays (index = entity). An entity is a squad or a special; the view
## scatters `ent_count` individual figures around `ent_pos`.

enum Team { ARMY, VILLAGE }
## What an entity is. The sim agent adds kinds (specials, animals) at the END.
enum Kind { MEN, VILLAGERS }
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

## What happened since the previous snapshot: {kind: StringName, pos: Vector2,
## ...optional data}. Drained once per snapshot; drives VFX and SFX.
var events: Array[Dictionary] = []


func entity_count() -> int:
	return ent_pos.size()
