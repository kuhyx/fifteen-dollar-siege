extends GutTest
## Nobody stands on a roof: the individuals scattered around a squad's anchor
## are moved off every building (houses, the church, the army's tents), on
## the CPU (`place`, where the fallen lie) and in the crowd shader.

var crowd: CrowdLayer
var plan: MapPlan
var map: SiegeMap
var tween := SnapshotTween.new()


func before_each() -> void:
	map = SiegeSim.create(Loadout.new(), 3).map()
	plan = MapPlan.of(map)
	crowd = CrowdLayer.new()
	add_child_autofree(crowd)
	crowd.setup(map.bounds, FigureLook.new())
	crowd.set_blocks(plan.blocks())


func _inside(point: Vector2, block: Vector4) -> bool:
	var rect := Rect2(block.x, block.y, block.z, block.w)
	return rect.has_point(point)


func _squads_at(points: Array, state: int) -> Array[SquadVisual]:
	var shot := SiegeSnapshot.new()
	shot.clock_s = SiegeSim.STEP_S
	for at: Vector2 in points:
		shot.ent_kind.append(SiegeSnapshot.Kind.VILLAGERS)
		shot.ent_team.append(SiegeSnapshot.Team.VILLAGE)
		shot.ent_count.append(100)
		shot.ent_state.append(state)
		shot.ent_pos.append(at)
		shot.ent_facing.append(0.0)
	tween.push(shot, SiegeSim.STEP_S)
	crowd.sync(shot)
	crowd.draw_frame(tween, shot, 0.0, 10.0, 6.0)
	return crowd.squads


func test_the_plan_lists_every_house_the_church_and_the_tents() -> void:
	var blocks := plan.blocks()
	assert_lte(blocks.size(), plan.houses.size() + 3 + MapPlan.TENTS.size())
	assert_lte(blocks.size(), CrowdScatter.MAX_BLOCKS)
	for footprint: Rect2 in plan.houses + [plan.nave, plan.transept, plan.tower]:
		var held := false
		for block in blocks:
			held = held or _inside(footprint.get_center(), block)
		assert_true(held, "%s is inside a block" % footprint)
	for i in blocks.size():
		for j in range(i + 1, blocks.size()):
			var one := Rect2(blocks[i].x, blocks[i].y, blocks[i].z, blocks[i].w)
			var other := Rect2(blocks[j].x, blocks[j].y, blocks[j].z, blocks[j].w)
			assert_false(one.intersects(other), "blocks %d and %d overlap" % [i, j])


func test_a_point_on_a_roof_is_moved_to_its_edge_and_others_stay() -> void:
	var blocks := PackedVector4Array([Vector4(10, 10, 20, 10)])
	var moved := CrowdScatter.clear_of(Vector2(12, 15), blocks)
	assert_false(_inside(moved, blocks[0]), "off the roof")
	assert_lt(moved.distance_to(Vector2(12, 15)), 5.0, "by the shortest way")
	assert_eq(CrowdScatter.clear_of(Vector2(50, 50), blocks), Vector2(50, 50))


func test_no_individual_of_a_squad_on_a_house_stands_on_a_roof() -> void:
	var centres: Array = plan.houses.map(func(rect: Rect2) -> Vector2: return rect.get_center())
	var blocks := plan.blocks()
	for squad in _squads_at(centres, SiegeSnapshot.State.IDLE):
		for i in squad.capacity:
			for block in blocks:
				assert_false(_inside(squad.place(i), block), "figure %d on a roof" % i)


func test_the_fallen_do_not_lie_on_a_roof() -> void:
	var squad := _squads_at([plan.houses[0].get_center()], SiegeSnapshot.State.FIGHT)[0]
	squad.set_heads(40)
	var lying := 0
	for i in squad.capacity:
		if squad.is_down(i):
			lying += 1
			for block in plan.blocks():
				assert_false(_inside(squad.place(i), block))
	assert_eq(lying, 60)
