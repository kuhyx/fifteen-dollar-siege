extends GutTest
## A man stays legible at the widest zoom: below a minimum on screen he is
## drawn bigger than life (the figures overlap, the crowd stays readable, team
## by colour AND outline), and the auto camera never zooms out past a floor.

const MIN_MAN_PX := 14.0
## Real pixels per canvas unit of a 1280x720 window (canvas 1920x1080).
const WINDOW_720P := 1280.0 / 1920.0


func _whole_map_zoom() -> float:
	var camera := BattleCamera.new()
	camera.setup(SiegeMap.new().bounds, Rect2(0, 0, 1920, 1080))
	camera.fit_screen(Vector2(1920, 1080), BattleHud.TOP_CLEAR, BattleHud.BOTTOM_CLEAR)
	return camera.fit_zoom() * BattleCamera.MIN_FIT * WINDOW_720P


func test_a_man_is_never_smaller_than_the_minimum_on_screen() -> void:
	for zoom: float in [_whole_map_zoom(), 1.5, 2.5, 4.0, 8.0, BattleCamera.MAX_ZOOM]:
		var man_px := CrowdLayer.MAN_M * zoom * CrowdLayer.boost_for(zoom)
		assert_gte(man_px, MIN_MAN_PX, "man %.1f px at zoom %.2f" % [man_px, zoom])


func test_close_up_figures_are_life_size_and_the_boost_is_capped() -> void:
	assert_eq(CrowdLayer.boost_for(BattleCamera.MAX_ZOOM), 1.0)
	assert_eq(CrowdLayer.boost_for(0.01), CrowdLayer.MAX_BOOST, "a speck is not blown up forever")
	var last := 99.0
	for zoom: float in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0]:
		var boost := CrowdLayer.boost_for(zoom)
		assert_lte(boost, last, "the boost only falls as the camera comes closer")
		last = boost


func _shot_with(army: Vector2, village: Array) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	var spots: Array = [army] + village
	for i in spots.size():
		shot.ent_pos.append(spots[i])
		shot.ent_kind.append(SiegeSnapshot.Kind.MEN)
		shot.ent_team.append(SiegeSnapshot.Team.ARMY if i == 0 else SiegeSnapshot.Team.VILLAGE)
		shot.ent_count.append(10)
		shot.ent_state.append(SiegeSnapshot.State.FIGHT)
		shot.ent_facing.append(0.0)
	return shot


func test_the_auto_camera_stays_on_the_action_when_the_fight_is_spread_wide() -> void:
	var map := SiegeMap.new()
	var camera := BattleCamera.new()
	camera.setup(map.bounds, Rect2(0, 0, 1920, 1080))
	camera.fit_screen(Vector2(1920, 1080), BattleHud.TOP_CLEAR, BattleHud.BOTTOM_CLEAR)
	var shot := _shot_with(
		Vector2(300, 200), [Vector2(120, 60), Vector2(520, 340), Vector2(480, 80)]
	)
	camera.follow(BattleCamera.action_box(shot, map), BattleCamera.action_anchor(shot, map))
	camera.snap()
	assert_gte(camera.zoom, BattleCamera.AUTO_MIN_ZOOM, "no zooming out to the whole map")
	assert_true(camera.view.has_point(camera.to_canvas(Vector2(300, 200))), "the army is in view")


func test_a_small_action_is_still_framed_closely() -> void:
	var map := SiegeMap.new()
	var camera := BattleCamera.new()
	camera.setup(map.bounds, Rect2(0, 0, 1920, 1080))
	camera.fit_screen(Vector2(1920, 1080), BattleHud.TOP_CLEAR, BattleHud.BOTTOM_CLEAR)
	var shot := _shot_with(Vector2(100, 200), [])
	camera.follow(BattleCamera.action_box(shot, map), BattleCamera.action_anchor(shot, map))
	camera.snap()
	assert_gte(camera.zoom, 8.0, "a squad on the march fills the screen")
