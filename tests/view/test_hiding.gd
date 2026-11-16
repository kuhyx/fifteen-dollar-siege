extends GutTest
## Where the villagers went: a squad of villagers in hiding is not drawn in
## the open, so the nearest house shows eyes in a window, one pair per few
## people (at most a handful per house), and they stay legible when far.

var crowd: CrowdLayer
var plan: MapPlan
var tween := SnapshotTween.new()


func before_each() -> void:
	var map := SiegeSim.create(Loadout.new(), 3).map()
	plan = MapPlan.of(map)
	crowd = CrowdLayer.new()
	add_child_autofree(crowd)
	crowd.setup(map.bounds, FigureLook.new())


func _show(rows: Array) -> void:
	var shot := SiegeSnapshot.new()
	shot.clock_s = SiegeSim.STEP_S
	for row: Array in rows:
		shot.ent_kind.append(row[4] if row.size() > 4 else SiegeSnapshot.Kind.VILLAGERS)
		shot.ent_team.append(row[0])
		shot.ent_count.append(row[1])
		shot.ent_state.append(row[2])
		shot.ent_pos.append(row[3])
		shot.ent_facing.append(0.0)
	tween.push(shot, SiegeSim.STEP_S)
	crowd.sync(shot)
	crowd.draw_frame(tween, shot, 0.0, 10.0, 6.0)


func test_hiding_villagers_show_eyes_in_the_nearest_house() -> void:
	var house := plan.houses[0]
	var hidden := SiegeSnapshot.State.HIDDEN
	_show([[SiegeSnapshot.Team.VILLAGE, 40, hidden, house.get_center() + Vector2(3, 2)]])
	var seen := FxHiding.tally(crowd, plan)
	assert_eq(seen.keys(), [0], "the house the squad stands nearest")
	assert_eq(seen[0], 40)
	var windows := FxHiding.windows(crowd, plan)
	assert_gt(windows.size(), 0)
	for window in windows:
		assert_true(house.grow(0.5).encloses(window["rect"]), "the window is on the roof")


func test_more_people_hide_more_eyes_but_never_more_than_the_cap() -> void:
	assert_eq(FxHiding.pairs_for(1), 1)
	assert_gte(FxHiding.pairs_for(60), FxHiding.pairs_for(12))
	assert_eq(FxHiding.pairs_for(100000), FxHiding.MAX_PAIRS)


func test_nobody_in_hiding_no_eyes() -> void:
	_show([[SiegeSnapshot.Team.VILLAGE, 40, SiegeSnapshot.State.IDLE, plan.houses[0].get_center()]])
	assert_true(FxHiding.windows(crowd, plan).is_empty())
	assert_false(FxHiding.any(crowd))
	var men := SiegeSnapshot.Kind.MEN
	_show(
		[
			[
				SiegeSnapshot.Team.ARMY,
				40,
				SiegeSnapshot.State.HIDDEN,
				plan.houses[0].get_center(),
				men
			]
		]
	)
	assert_true(FxHiding.windows(crowd, plan).is_empty(), "the army's hiding is not the village's")


func test_the_eyes_are_big_enough_on_screen_at_every_zoom() -> void:
	for zoom: float in [1.66, 3.0, 6.0, BattleCamera.MAX_ZOOM]:
		assert_gte(FxHiding.eye_m(zoom) * zoom, FxHiding.EYE_PX, "zoom %.1f" % zoom)
