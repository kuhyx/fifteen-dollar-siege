class_name MapLayer
extends Node2D
## The battlefield, seen from above and drawn once in code: grass, striped
## fields, the path from the camp, the village yard, its houses as roofs, the
## church with its bell tower, trees. Lives inside the world node, so one unit
## is one metre and the picture is sharp at any zoom.

const FURROW_M := 3.2
const PATH_M := 5.5

var plan: MapPlan


func setup(p_plan: MapPlan) -> void:
	plan = p_plan
	queue_redraw()


func _draw() -> void:
	if plan == null:
		return
	var map := plan.map
	draw_rect(map.bounds, WorldPalette.GRASS)
	for i in plan.trees.size():
		if i % 5 == 0:
			var patch := Vector2(plan.trees[i].x, plan.trees[i].y)
			draw_circle(patch, plan.trees[i].z * 7.0, Color(WorldPalette.GRASS_LIGHT, 0.5))
	for i in plan.fields.size():
		_field(plan.fields[i], i)
	draw_circle(map.village_center, map.village_radius, WorldPalette.YARD)
	draw_arc(map.village_center, map.village_radius, 0.0, TAU, 96, WorldPalette.PATH, 1.2)
	draw_polyline(plan.path, WorldPalette.PATH, PATH_M)
	for point in plan.path:
		draw_circle(point, PATH_M / 2.0, WorldPalette.PATH)
	for tree in plan.trees:
		_tree(Vector2(tree.x, tree.y), tree.z)
	for house in plan.houses:
		_roof(house, WorldPalette.ROOF, WorldPalette.ROOF_SHADE, WorldPalette.RIDGE)
	_church()
	_camp(plan.camp)


func _field(field: Rect2, index: int) -> void:
	draw_rect(field, WorldPalette.FIELD_GOLD if index % 2 == 0 else WorldPalette.FIELD_GREEN)
	var upright := index % 3 == 0
	var length := field.size.x if upright else field.size.y
	var at := FURROW_M
	while at < length:
		if upright:
			draw_rect(
				Rect2(field.position + Vector2(at, 0), Vector2(0.9, field.size.y)),
				WorldPalette.FURROW
			)
		else:
			draw_rect(
				Rect2(field.position + Vector2(0, at), Vector2(field.size.x, 0.9)),
				WorldPalette.FURROW
			)
		at += FURROW_M


## A roof seen from above: two slopes, the far one in shade, and the ridge.
func _roof(house: Rect2, lit: Color, shade: Color, ridge: Color) -> void:
	draw_rect(house.grow(0.7), WorldPalette.SOOT.lerp(WorldPalette.YARD, 0.55))
	if house.size.x >= house.size.y:
		var half := Vector2(house.size.x, house.size.y / 2.0)
		draw_rect(Rect2(house.position, half), shade)
		draw_rect(Rect2(house.position + Vector2(0, half.y), half), lit)
		draw_rect(Rect2(house.position + Vector2(0, half.y - 0.35), Vector2(half.x, 0.7)), ridge)
		return
	var side := Vector2(house.size.x / 2.0, house.size.y)
	draw_rect(Rect2(house.position, side), lit)
	draw_rect(Rect2(house.position + Vector2(side.x, 0), side), shade)
	draw_rect(Rect2(house.position + Vector2(side.x - 0.35, 0), Vector2(0.7, side.y)), ridge)


## Stone, a cross plan, and a square tower with a brass bell under its cap.
func _church() -> void:
	var stone := WorldPalette.STONE
	_roof(plan.transept, stone, WorldPalette.STONE_SHADE, WorldPalette.WHITE)
	_roof(plan.nave, stone, WorldPalette.STONE_SHADE, WorldPalette.WHITE)
	var tower := plan.tower
	draw_rect(tower.grow(0.8), WorldPalette.SOOT.lerp(WorldPalette.YARD, 0.55))
	draw_rect(tower, WorldPalette.STONE_SHADE)
	var corners := [tower.position, Vector2(tower.end.x, tower.position.y), tower.end]
	corners.append(Vector2(tower.position.x, tower.end.y))
	for i in 4:
		var slope := PackedVector2Array([corners[i], corners[(i + 1) % 4], plan.bell])
		draw_colored_polygon(slope, stone.darkened(0.08 * i))
	draw_circle(plan.bell, 2.3, WorldPalette.SOOT)
	draw_circle(plan.bell, 1.7, WorldPalette.BRASS)


func _tree(at: Vector2, crown: float) -> void:
	draw_circle(at, crown, WorldPalette.TREE)
	draw_circle(at + Vector2(-0.25, -0.25) * crown, crown * 0.55, WorldPalette.TREE_LIGHT)


## The army's start: three tents around a fire and a pole with its colour.
func _camp(at: Vector2) -> void:
	draw_circle(at, 26.0, Color(WorldPalette.PATH, 0.45))
	for offset in MapPlan.TENTS:
		var tent := Rect2(at + offset - MapPlan.TENT_SIZE / 2.0, MapPlan.TENT_SIZE)
		_roof(tent, WorldPalette.TENT, WorldPalette.TENT.darkened(0.2), WorldPalette.WOOD_DARK)
	draw_circle(at + Vector2(-2, 0), 2.2, WorldPalette.STONE_SHADE)
	draw_circle(at + Vector2(-2, 0), 1.4, WorldPalette.FLAME_MID)
	draw_circle(at + Vector2(-2, 0), 0.7, WorldPalette.FLAME_CORE)
	var pole := at + Vector2(8, -14)
	draw_rect(Rect2(pole, Vector2(0.7, 9.0)), WorldPalette.WOOD_DARK)
	var flag := PackedVector2Array([pole, pole + Vector2(7.5, 2.2), pole + Vector2(0.7, 4.4)])
	draw_colored_polygon(flag, WorldPalette.ARMY)
