extends GutTest
## The view's own arithmetic: where each individual of a squad stands, how a
## figure moves between two snapshots, and what the camera shows.

const STEP := SiegeSim.STEP_S


func _shot(clock: float, points: Array, teams: Array = []) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	shot.clock_s = clock
	for i in points.size():
		shot.ent_pos.append(points[i])
		shot.ent_kind.append(SiegeSnapshot.Kind.MEN)
		shot.ent_team.append(teams[i] if i < teams.size() else SiegeSnapshot.Team.ARMY)
		shot.ent_count.append(10)
		shot.ent_state.append(SiegeSnapshot.State.MOVE)
		shot.ent_facing.append(0.0)
	return shot


func test_every_individual_has_a_stable_place_inside_the_squad() -> void:
	var homes := CrowdScatter.homes(3, 100)
	assert_eq(homes.size(), 100)
	assert_eq(homes, CrowdScatter.homes(3, 100), "the same squad scatters the same way")
	assert_ne(homes, CrowdScatter.homes(4, 100), "another squad scatters its own way")
	var nearest := INF
	for i in homes.size():
		assert_lte(homes[i].length(), 1.0, "inside the unit disc")
		if i > 0:
			assert_gte(
				homes[i].y, homes[i - 1].y, "back to front, so near figures overlap far ones"
			)
		for j in i:
			nearest = minf(nearest, homes[i].distance_to(homes[j]))
	assert_gt(nearest * sqrt(100.0), 0.6, "evenly spread: nobody stands on another")
	assert_eq(CrowdScatter.homes(0, 1)[0], Vector2.ZERO, "a single figure stands on the anchor")
	assert_almost_eq(CrowdScatter.radius(1.5, 100), 15.0, 0.001)


func test_the_fall_order_is_a_stable_shuffle() -> void:
	var order := CrowdScatter.fall_order(7, 50)
	assert_eq(order, CrowdScatter.fall_order(7, 50))
	var seen := {}
	for index in order:
		seen[index] = true
	assert_eq(seen.size(), 50, "everybody is in it once")
	assert_ne(Array(order), range(50), "not simply the back row first")
	var phases := CrowdScatter.phases(7, 50)
	assert_eq(phases.size(), 50)
	assert_between(phases[0], 0.0, 1.0)


func test_figures_glide_between_snapshots_at_any_frame_rate() -> void:
	for frames_per_tick: float in [0.25, 1.0, 2.5, 4.0]:
		var tween := SnapshotTween.new()
		var dt := STEP / frames_per_tick
		var sim_time := 0.0
		var ticks := 0
		tween.push(_shot(0.0, [Vector2.ZERO]), 0.0)
		var last_x := 0.0
		var worst := 0.0
		for frame in 200:
			sim_time += dt
			ticks = int(floor(sim_time / STEP + 0.00001))
			tween.push(_shot(ticks * STEP, [Vector2(ticks * STEP * 30.0, 0.0)]), dt)
			var x := tween.position(0).x
			assert_gte(x, last_x - 0.0001, "never backwards (%s frames per tick)" % frames_per_tick)
			worst = maxf(worst, x - last_x)
			last_x = x
		assert_lt(worst, 30.0 * dt * 1.6 + 0.001, "no jump at %s frames per tick" % frames_per_tick)
		assert_gt(last_x, sim_time * 30.0 - 30.0 * STEP * 2.1, "at most two ticks behind")
		assert_almost_eq(tween.velocity(0).x, 30.0, 0.5)


func test_a_teleport_and_a_new_entity_do_not_slide_across_the_map() -> void:
	var tween := SnapshotTween.new()
	tween.push(_shot(0.0, [Vector2.ZERO]), 0.0)
	tween.push(_shot(STEP, [Vector2(500, 0), Vector2(90, 90)]), STEP)
	assert_eq(tween.position(0), Vector2(500, 0), "a jump this big is a teleport")
	assert_eq(tween.position(1), Vector2(90, 90), "a new entity appears in place")
	assert_eq(tween.position(9), Vector2.ZERO, "an index out of range is harmless")


func _camera() -> BattleCamera:
	var camera := BattleCamera.new()
	camera.setup(Rect2(0, 0, 600, 400), Rect2(0, 0, 1920, 1080))
	return camera


func test_the_camera_starts_with_the_whole_map_and_maps_both_ways() -> void:
	var camera := _camera()
	assert_almost_eq(camera.zoom, 2.7, 0.001, "400 m fit 1080 px")
	assert_almost_eq(camera.to_canvas(Vector2(300, 200)), Vector2(960, 540), Vector2(0.01, 0.01))
	var point := Vector2(123, 321)
	assert_almost_eq(camera.to_map(camera.to_canvas(point)), point, Vector2(0.001, 0.001))
	assert_almost_eq(camera.transform() * point, camera.to_canvas(point), Vector2(0.01, 0.01))


func test_the_wheel_zooms_about_the_cursor_and_drag_pans() -> void:
	var camera := _camera()
	camera.hold(Rect2(200, 100, 200, 112))
	camera.resume_auto()
	var cursor := Vector2(700, 400)
	var under := camera.to_map(cursor)
	var before_zoom := camera.zoom
	camera.zoom_at(cursor, BattleCamera.WHEEL_STEP)
	assert_false(camera.auto, "a hand on the camera stops the auto framing")
	assert_gt(camera.zoom, before_zoom)
	assert_almost_eq(camera.to_map(cursor), under, Vector2(0.01, 0.01), "the spot stays put")
	var before := camera.to_map(Vector2(960, 540))
	camera.pan(Vector2(-100, 0))
	assert_gt(camera.to_map(Vector2(960, 540)).x, before.x, "dragging left shows more of the right")
	for i in 80:
		camera.zoom_at(cursor, BattleCamera.WHEEL_STEP)
	assert_almost_eq(camera.zoom, BattleCamera.MAX_ZOOM, 0.001, "zoom has a ceiling")
	camera.pan(Vector2(99999, 99999))
	assert_almost_eq(
		camera.to_map(Vector2.ZERO),
		Vector2.ZERO,
		Vector2(0.01, 0.01),
		"the map's corner stops at the screen's"
	)
	camera.pan(Vector2(-99999, -99999))
	assert_almost_eq(camera.to_map(Vector2(1920, 1080)), Vector2(600, 400), Vector2(0.01, 0.01))
	for i in 200:
		camera.zoom_at(cursor, 1.0 / BattleCamera.WHEEL_STEP)
	assert_gt(camera.zoom, 2.0, "and a floor near the whole map")
	assert_almost_eq(
		camera.center, Vector2(300, 200), Vector2(0.01, 0.01), "a small map sits in the middle"
	)


func test_auto_framing_glides_to_the_action_and_comes_back_on_request() -> void:
	var camera := _camera()
	camera.frame(Rect2(40, 150, 80, 100))
	assert_almost_eq(camera.zoom, 2.7, 0.001, "not there yet: it glides")
	for i in 240:
		camera.update(1.0 / 60.0)
	assert_gt(camera.zoom, 6.0)
	assert_almost_eq(camera.center.y, 200.0, 1.0)
	assert_almost_eq(camera.to_map(Vector2(0, 540)).x, 0.0, 1.0, "no void beside the map's edge")
	camera.pan(Vector2(-50, 0))
	var held := camera.center
	camera.frame(Rect2(300, 100, 200, 200))
	camera.update(1.0)
	assert_eq(camera.center, held, "manual: the auto framing is ignored")
	camera.resume_auto()
	assert_true(camera.auto)
	for i in 240:
		camera.update(1.0 / 60.0)
	assert_almost_eq(camera.center, Vector2(400, 200), Vector2(1, 1))


func test_the_hud_strips_stay_clear_of_the_action() -> void:
	var camera := _camera()
	camera.fit_screen(Vector2(1920, 1080), 118.0, 132.0)
	camera.hold(Rect2(250, 150, 100, 60))
	var top := camera.to_canvas(Vector2(300, 150)).y
	var bottom := camera.to_canvas(Vector2(300, 210)).y
	assert_gte(top, 118.0 - 0.01, "the top of the action is under the meters")
	assert_lte(bottom, 1080.0 - 132.0 + 0.01, "its bottom is above the buttons")
	camera.fit_screen(Vector2.ZERO, 118.0, 132.0)
	assert_eq(camera.screen.size, Vector2(1920, 1080), "no size yet: the base size")


func test_the_action_is_the_army_and_whoever_it_meets() -> void:
	var map := SiegeMap.new()
	var teams := [SiegeSnapshot.Team.ARMY, SiegeSnapshot.Team.ARMY, SiegeSnapshot.Team.VILLAGE]
	var far := _shot(0.0, [Vector2(60, 150), Vector2(70, 250), Vector2(430, 200)], teams)
	var box := BattleCamera.action_box(far, map)
	assert_true(box.has_point(Vector2(60, 150)) and box.has_point(Vector2(70, 250)))
	assert_false(box.has_point(Vector2(430, 200)), "the village is not in the fight yet")
	var near := _shot(0.0, [Vector2(380, 190), Vector2(390, 210), Vector2(430, 200)], teams)
	box = BattleCamera.action_box(near, map)
	assert_true(box.has_point(Vector2(430, 200)), "villagers the army reached are in the frame")
	assert_true(map.bounds.encloses(box), "the frame stays on the map")
	assert_gte(box.size.x, BattleCamera.MIN_SPAN_M.x, "never closer than a street")
	assert_eq(BattleCamera.action_box(SiegeSnapshot.new(), map), map.bounds, "nobody: the map")


func test_the_frame_meter_adds_up_the_stretches_of_a_frame() -> void:
	var meter := FrameMeter.new()
	meter.begin()
	OS.delay_usec(2000)
	meter.end()
	meter.begin()
	OS.delay_usec(1000)
	meter.end()
	meter.end()
	meter.next_frame()
	assert_between(meter.last_ms, 2.9, 60.0, "two stretches, one frame")
	assert_eq(meter.frames, 1)
	assert_eq(meter.worst_ms, meter.last_ms)
	assert_eq(meter.mean_ms(), meter.last_ms)
	meter.next_frame()
	assert_eq(meter.last_ms, 0.0, "an idle frame")
	assert_gt(meter.worst_ms, 2.9, "the worst is kept")
	meter.reset()
	assert_eq(meter.worst_ms, 0.0)
	assert_eq(meter.frames, 0)


func test_a_stall_of_the_machine_is_not_the_game_s_own_work() -> void:
	if FrameMeter.cpu_ms() < 0.0:
		pass_test("no per-thread CPU clock on this system: the wall clock judges")
		return
	var meter := FrameMeter.new()
	meter.cpu_clock = true
	meter.begin()
	OS.delay_usec(15000)
	meter.end()
	meter.next_frame()
	assert_gt(meter.worst_wall_ms, 14.0, "the wall clock saw the stall")
	assert_lt(meter.worst_ms, FrameStats.WORK_BUDGET_MS, "asleep is not work: the gate ignores it")
	meter.reset()
	meter.begin()
	var until := Time.get_ticks_usec() + 40000
	var busy := 0.0
	while Time.get_ticks_usec() < until:
		busy += sin(busy)
	meter.end()
	meter.next_frame()
	assert_gt(meter.worst_ms, FrameStats.WORK_BUDGET_MS, "real work fails the gate on both clocks")
	assert_ne(FrameStats.budget_problem(meter.worst_ms, 1), "")
	assert_eq(FrameStats.budget_problem(1.0, 10), "")
	assert_string_contains(FrameStats.budget_problem(0.0, 0), "no frame")
