extends GutTest
## The crowd: every head of every entity is one drawn figure with its own
## place; the fallen stay where they fell; the map plan has a church, fields,
## a path and the army's camp.

var crowd: CrowdLayer
var tween: SnapshotTween
var _last_clock := 0.0


func before_each() -> void:
	crowd = CrowdLayer.new()
	add_child_autofree(crowd)
	crowd.setup(Rect2(0, 0, 600, 400), FigureLook.new())
	tween = SnapshotTween.new()
	_last_clock = 0.0


func _shot(rows: Array) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	for row: Array in rows:
		shot.ent_kind.append(row[0])
		var village: bool = row[0] in [SiegeSnapshot.Kind.VILLAGERS, SiegeSnapshot.Kind.MILITIA]
		shot.ent_team.append(SiegeSnapshot.Team.VILLAGE if village else SiegeSnapshot.Team.ARMY)
		shot.ent_count.append(row[1])
		shot.ent_state.append(row[2])
		shot.ent_pos.append(row[3])
		shot.ent_facing.append(0.0)
	return shot


func _show(shot: SiegeSnapshot, zoom := 3.0) -> void:
	if shot.clock_s <= _last_clock:
		shot.clock_s = _last_clock + SiegeSim.STEP_S
	_last_clock = shot.clock_s
	tween.push(shot, SiegeSim.STEP_S)
	crowd.sync(shot)
	crowd.draw_frame(tween, shot, 0.0, 10.0, zoom)


func test_every_head_of_the_siege_is_a_drawn_figure() -> void:
	var sim := SiegeSim.create(Loadout.of([&"double_men", &"fifty_men"]), 3)
	var shot := sim.snapshot()
	_show(shot)
	assert_eq(crowd.squads.size(), shot.entity_count())
	assert_eq(crowd.figures(), 2300, "300 men and 2,000 villagers, one figure each")
	var made := crowd.allocations
	var built := FigureLibrary.builds
	for i in 30:
		sim.step(SiegeSim.STEP_S)
		_show(sim.snapshot())
	assert_eq(crowd.allocations, made, "nothing is allocated while the siege runs")
	assert_eq(FigureLibrary.builds, built, "no figure is built on first sight")


func test_the_fallen_stay_where_they_fell() -> void:
	var men := SiegeSnapshot.Kind.MEN
	var move := SiegeSnapshot.State.MOVE
	_show(_shot([[men, 10, move, Vector2(100, 100)]]))
	var squad := crowd.squads[0]
	assert_eq(squad.alive, 10)
	_show(_shot([[men, 7, move, Vector2(100, 100)]]))
	assert_eq(squad.alive, 7)
	assert_eq(squad.fallen(), 3)
	var bodies := {}
	for j in squad.capacity:
		if squad.is_down(j):
			bodies[j] = squad.place(j)
	assert_eq(bodies.size(), 3)
	var standing := squad.place(_first_standing(squad))
	for step in 6:
		_show(_shot([[men, 7, move, Vector2(180, 100)]]))
	for j: int in bodies:
		assert_eq(squad.place(j), bodies[j], "a body does not walk on with the squad")
	assert_gt(squad.place(_first_standing(squad)).x, standing.x + 30.0, "the living do")
	_show(_shot([[men, 9, move, Vector2(180, 100)]]))
	assert_eq(squad.fallen(), 1, "a healed man stands up again")
	assert_eq(crowd.figures(), 10, "bodies still count as drawn figures")


func _first_standing(squad: SquadVisual) -> int:
	for j in squad.capacity:
		if not squad.is_down(j):
			return j
	return -1


func test_a_squad_that_is_down_lies_in_place_and_flight_scatters_it() -> void:
	var men := SiegeSnapshot.Kind.MEN
	_show(_shot([[men, 10, SiegeSnapshot.State.IDLE, Vector2(100, 100)]]))
	var squad := crowd.squads[0]
	var tight := squad.spread_goal()
	_show(_shot([[men, 10, SiegeSnapshot.State.FLEE, Vector2(100, 100)]]))
	assert_gt(squad.spread_goal(), tight * 1.3, "a routed squad scatters")
	_show(_shot([[men, 10, SiegeSnapshot.State.DOWN, Vector2(100, 100)]]))
	assert_eq(squad.material.get_shader_parameter("pose"), float(SiegeSnapshot.State.DOWN))
	assert_eq(squad.fallen(), 0, "the whole squad lies down by its pose, heads unchanged")


func test_an_entity_that_grows_or_changes_kind_is_built_anew() -> void:
	var idle := SiegeSnapshot.State.IDLE
	_show(_shot([[SiegeSnapshot.Kind.MEN, 4, idle, Vector2(100, 100)]]))
	var first := crowd.squads[0]
	_show(_shot([[SiegeSnapshot.Kind.MEN, 9, idle, Vector2(100, 100)]]))
	assert_ne(crowd.squads[0], first, "more heads than it was built for")
	assert_eq(crowd.squads[0].capacity, 9)
	assert_eq(crowd.figures(), 9)
	_show(_shot([[SiegeSnapshot.Kind.MOOSE, 3, idle, Vector2(100, 100)]]))
	assert_eq(crowd.squads[0].kind, SiegeSnapshot.Kind.MOOSE, "the index became another kind")
	_show(_shot([[SiegeSnapshot.Kind.ROCK_BAND, 1, idle, Vector2(100, 100)]]))
	assert_eq(crowd.squads[0].spec.meshes(false, 1).size(), 1, "one head: the whole band at once")
	assert_eq(crowd.squads[0].spec.meshes(true, 4).size(), 4, "four heads: four players")
	_show(_shot([[SiegeSnapshot.Kind.UFO, 0, idle, Vector2(100, 100)]]))
	assert_eq(crowd.figures(), 0, "an entity without heads draws nothing")
	_show(_shot([]))
	assert_eq(crowd.squads.size(), 1, "a shorter snapshot is harmless")


func test_squads_are_drawn_back_to_front_and_the_fallen_underneath() -> void:
	var men := SiegeSnapshot.Kind.MEN
	var rows := [[men, 5, SiegeSnapshot.State.IDLE, Vector2(100, 300)]]
	rows.append([men, 5, SiegeSnapshot.State.IDLE, Vector2(100, 100)])
	rows.append([men, 5, SiegeSnapshot.State.DOWN, Vector2(100, 350)])
	_show(_shot(rows))
	assert_gt(crowd.squads[0].depth(), crowd.squads[1].depth(), "lower on the map: drawn later")
	assert_lt(crowd.squads[2].depth(), crowd.squads[1].depth(), "a fallen squad lies under all")


func test_hidden_army_shimmers_and_hidden_villagers_are_gone() -> void:
	var hidden := SiegeSnapshot.State.HIDDEN
	var rows := [[SiegeSnapshot.Kind.MEN, 10, hidden, Vector2(100, 100)]]
	rows.append([SiegeSnapshot.Kind.VILLAGERS, 50, hidden, Vector2(400, 200)])
	_show(_shot(rows))
	assert_eq(crowd.squads[0].material.get_shader_parameter("shimmer"), 1.0)
	assert_gt(crowd.squads[0].fade_goal(), 0.9, "the player still sees his invisible men")
	assert_eq(crowd.squads[1].material.get_shader_parameter("shimmer"), 0.0)
	assert_eq(crowd.squads[1].fade_goal(), 0.0, "villagers in hiding are indoors")


func test_two_levels_of_detail_follow_the_zoom() -> void:
	var rows := [[SiegeSnapshot.Kind.MEN, 10, SiegeSnapshot.State.IDLE, Vector2(100, 100)]]
	_show(_shot(rows), 2.7)
	assert_true(crowd.far, "the whole map: simplified figures")
	_show(_shot(rows), 14.0)
	assert_false(crowd.far, "close up: full figures")
	_show(_shot(rows), CrowdLayer.FAR_BELOW_PX / crowd.squads[0].spec.height * 1.02)
	assert_false(crowd.far, "no flicker at the threshold")


func test_the_look_dresses_the_army_and_wobbles_on_booze() -> void:
	var rows := [[SiegeSnapshot.Kind.MEN, 10, SiegeSnapshot.State.IDLE, Vector2(100, 100)]]
	rows.append([SiegeSnapshot.Kind.MILITIA, 10, SiegeSnapshot.State.IDLE, Vector2(400, 200)])
	_show(_shot(rows))
	var plain := crowd.squads[0].spec
	var militia := crowd.squads[1].spec
	crowd.dress(FigureLook.of(Loadout.of([&"knight_armor", &"booze"])))
	_show(_shot(rows))
	assert_ne(crowd.squads[0].spec, plain, "the men wear the armour")
	assert_same(crowd.squads[1].spec, militia, "the village does not")
	assert_eq(crowd.squads[0].material.get_shader_parameter("wobble"), 1.0)
	assert_eq(crowd.squads[1].material.get_shader_parameter("wobble"), 0.0)


func test_the_army_can_burn_and_a_rout_scatters_the_nearest_squad() -> void:
	var rows := [[SiegeSnapshot.Kind.MEN, 10, SiegeSnapshot.State.DOWN, Vector2(100, 100)]]
	rows.append([SiegeSnapshot.Kind.MILITIA, 10, SiegeSnapshot.State.IDLE, Vector2(400, 200)])
	_show(_shot(rows))
	crowd.ignite(SiegeSnapshot.Team.ARMY)
	assert_true(crowd.squads[0].burning)
	assert_false(crowd.squads[1].burning)
	var calm := crowd.squads[1].spread_goal()
	crowd.scatter(Vector2(395, 205), SiegeSnapshot.Team.VILLAGE)
	assert_gt(crowd.squads[1].spread_goal(), calm, "the rout throws them apart")


func test_the_map_plan_has_a_church_fields_a_path_and_a_camp() -> void:
	var map := SiegeSim.create(Loadout.new(), 7).map()
	var plan := MapPlan.of(map)
	assert_true(map.church.encloses(plan.nave), "the church stands where the map says")
	assert_true(map.church.encloses(plan.transept), "its transept too")
	assert_eq(plan.bell, map.bell, "the bell rings where the map says")
	assert_true(plan.tower.has_point(plan.bell), "in its tower")
	assert_gt(plan.fields.size(), 3)
	for field in plan.fields:
		assert_true(map.bounds.encloses(field), "fields lie on the map")
		assert_false(map.in_village(field.get_center()), "and outside the village")
	assert_eq(plan.path[0], map.army_spawn, "the path leaves the camp")
	assert_lte(plan.path[plan.path.size() - 1].distance_to(map.village_center), map.centre_radius)
	assert_eq(plan.camp, map.army_spawn)
	assert_lte(plan.houses.size(), map.buildings.size())
	for house in plan.houses:
		assert_false(house.intersects(map.church), "no house under the church")
	assert_eq(MapPlan.of(map).fields, plan.fields, "the same map plans the same way")
