extends GutTest
## Wasps read as a buzzing cloud at every zoom, not as dots: the cloud grows
## with the far-zoom boost and a haze with swirling strokes is drawn on it.

const MIN_CLOUD_PX := 40.0
const WINDOW_720P := 1280.0 / 1920.0

var crowd: CrowdLayer
var tween := SnapshotTween.new()


func before_each() -> void:
	crowd = CrowdLayer.new()
	add_child_autofree(crowd)
	crowd.setup(Rect2(0, 0, 600, 400), FigureLook.new())


func _swarm(heads: int) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	shot.clock_s = SiegeSim.STEP_S
	shot.ent_kind.append(SiegeSnapshot.Kind.WASPS)
	shot.ent_team.append(SiegeSnapshot.Team.ARMY)
	shot.ent_count.append(heads)
	shot.ent_state.append(SiegeSnapshot.State.FIGHT)
	shot.ent_pos.append(Vector2(200, 200))
	shot.ent_facing.append(0.0)
	return shot


func _cloud_px(heads: int, zoom_px: float) -> float:
	var shot := _swarm(heads)
	tween.push(shot, SiegeSim.STEP_S)
	crowd.sync(shot)
	crowd.draw_frame(tween, shot, 0.0, 10.0, zoom_px)
	return FxSwarm.radius_m(crowd.squads[0], zoom_px) * zoom_px


func test_a_swarm_is_a_cloud_tens_of_pixels_wide_at_every_zoom() -> void:
	for zoom: float in [1.1, 2.0, 4.0, 10.0, BattleCamera.MAX_ZOOM]:
		for heads in [4, 30]:
			var radius := _cloud_px(heads, zoom)
			assert_gte(
				radius, MIN_CLOUD_PX, "%d wasps at zoom %.1f: %.0f px" % [heads, zoom, radius]
			)


func test_the_wasps_themselves_spread_over_a_cloud_on_screen() -> void:
	for zoom: float in [1.1, 2.0, 4.0, 10.0, BattleCamera.MAX_ZOOM]:
		_cloud_px(30, zoom)
		var squad := crowd.squads[0]
		var wide := squad.spread * squad.grow * zoom
		assert_gte(wide, 10.0, "30 wasps spread %.0f px at zoom %.1f" % [wide, zoom])


func test_the_cloud_grows_with_the_swarm() -> void:
	var small := _cloud_px(4, BattleCamera.MAX_ZOOM)
	var big := _cloud_px(30, BattleCamera.MAX_ZOOM)
	assert_gt(big, small)


func test_only_wasps_make_a_cloud() -> void:
	var shot := _swarm(10)
	shot.ent_kind[0] = SiegeSnapshot.Kind.MEN
	tween.push(shot, SiegeSim.STEP_S)
	crowd.sync(shot)
	crowd.draw_frame(tween, shot, 0.0, 10.0, 4.0)
	assert_false(crowd.has_swarm())
	assert_eq(crowd.squads[0].grow, 1.0)
