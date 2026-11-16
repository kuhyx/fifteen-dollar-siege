class_name MapPlan
extends RefCounted
## What the view adds to the sim's SiegeMap so the battlefield reads as a
## place: a church with a bell tower at the village centre, fields around the
## village, a path from the army's camp, trees. All derived from the map's own
## numbers with a fixed seed: the same map always plans the same way, and the
## sim never needs to know.

const FIELD_TRIES := 60
const FIELDS := 9
const TREE_TRIES := 160
const PATH_STEPS := 14
const PATH_SWAY_M := 14.0

## Where the three tents stand, from the camp.
const TENTS: Array[Vector2] = [Vector2(-13, -11), Vector2(-15, 9), Vector2(2, 16)]
const TENT_SIZE := Vector2(10, 8)

var map: SiegeMap
## The church: nave (long, east-west), transept, and the bell tower.
var nave := Rect2()
var transept := Rect2()
var tower := Rect2()
var bell := Vector2.ZERO
## The sim's buildings, without those the church stands on.
var houses: Array[Rect2] = []
var fields: Array[Rect2] = []
var path := PackedVector2Array()
## Tree: x, y = where, z = crown radius.
var trees: Array[Vector3] = []
var camp := Vector2.ZERO


static func of(p_map: SiegeMap) -> MapPlan:
	var plan := MapPlan.new()
	plan.map = p_map
	plan.camp = p_map.army_spawn
	var c := p_map.village_center
	plan.nave = Rect2(c - Vector2(11.0, 5.5), Vector2(24.0, 11.0))
	plan.transept = Rect2(c + Vector2(3.0, -10.0), Vector2(7.0, 20.0))
	plan.tower = Rect2(c - Vector2(20.0, 5.0), Vector2(10.0, 10.0))
	plan.bell = plan.tower.get_center()
	var church := plan.nave.merge(plan.transept).merge(plan.tower).grow(1.5)
	for building in p_map.buildings:
		if not building.intersects(church):
			plan.houses.append(building)
	plan._lay_path()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_map.bounds, c, p_map.village_radius, p_map.army_spawn])
	plan._lay_fields(rng)
	plan._plant_trees(rng)
	return plan


## Every footprint nobody stands on, as (x, y, width, height): houses, the
## church and the tents. The crowd keeps its figures off them.
func blocks() -> PackedVector4Array:
	var rects: Array[Rect2] = houses.duplicate()
	rects.append_array([nave, transept, tower])
	for offset in TENTS:
		rects.append(Rect2(camp + offset - TENT_SIZE / 2.0, TENT_SIZE))
	var out := PackedVector4Array()
	for rect in rects.slice(0, CrowdScatter.MAX_BLOCKS):
		out.append(Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	return out


## Metres from `point` to the path's centre line.
func path_distance(point: Vector2) -> float:
	var best := INF
	for i in path.size() - 1:
		var on_path := Geometry2D.get_closest_point_to_segment(point, path[i], path[i + 1])
		best = minf(best, on_path.distance_to(point))
	return best


func _lay_path() -> void:
	var across := (map.village_center - map.army_spawn).orthogonal().normalized()
	for i in PATH_STEPS + 1:
		var along := float(i) / PATH_STEPS
		var sway := sin(along * TAU) * PATH_SWAY_M * (1.0 - along)
		path.append(map.army_spawn.lerp(map.village_center, along) + across * sway)
	path[PATH_STEPS] = Vector2(tower.position.x - 3.0, map.village_center.y)


func _lay_fields(rng: RandomNumberGenerator) -> void:
	var room := map.bounds.grow(-8.0)
	for attempt in FIELD_TRIES:
		if fields.size() >= FIELDS:
			return
		var size := Vector2(rng.randf_range(50.0, 95.0), rng.randf_range(34.0, 60.0))
		var corner := Vector2(
			rng.randf_range(room.position.x, room.end.x - size.x),
			rng.randf_range(room.position.y, room.end.y - size.y)
		)
		var field := Rect2(corner, size)
		if _field_fits(field):
			fields.append(field)


func _field_fits(field: Rect2) -> bool:
	var nearest := map.village_center.clamp(field.position, field.end)
	if nearest.distance_to(map.village_center) < map.village_radius + 8.0:
		return false
	if camp.clamp(field.position, field.end).distance_to(camp) < 45.0:
		return false
	for other in fields:
		if other.grow(5.0).intersects(field):
			return false
	for i in path.size():
		if field.grow(7.0).has_point(path[i]):
			return false
	return true


func _plant_trees(rng: RandomNumberGenerator) -> void:
	var room := map.bounds.grow(-4.0)
	for attempt in TREE_TRIES:
		var at := Vector2(
			rng.randf_range(room.position.x, room.end.x),
			rng.randf_range(room.position.y, room.end.y)
		)
		var crown := rng.randf_range(2.6, 5.2)
		if _tree_fits(at, crown):
			trees.append(Vector3(at.x, at.y, crown))


func _tree_fits(at: Vector2, crown: float) -> bool:
	if at.distance_to(map.village_center) < map.village_radius + crown + 4.0:
		return false
	if at.distance_to(camp) < 30.0 or path_distance(at) < 9.0 + crown:
		return false
	for field in fields:
		if field.grow(crown + 1.0).has_point(at):
			return false
	return true
