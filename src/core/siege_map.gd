class_name SiegeMap
extends RefCounted
## The battlefield, in metres (x right, y down). Plain data: the sim owns the
## numbers, the view only draws them.

## The whole playable area.
var bounds := Rect2(0.0, 0.0, 600.0, 400.0)
var village_center := Vector2(430.0, 200.0)
## Everything inside this circle counts as the village.
var village_radius := 110.0
## Building footprints (axis-aligned), all inside the village circle.
var buildings: Array[Rect2] = []
## Where the army starts.
var army_spawn := Vector2(60.0, 200.0)


func in_village(point: Vector2) -> bool:
	return point.distance_to(village_center) <= village_radius
