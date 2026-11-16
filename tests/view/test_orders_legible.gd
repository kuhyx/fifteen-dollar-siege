extends GutTest
## Orders must read at a glance on the whole-map view of a 1280x720 window
## (canvas 1920x1080): the rally flag and the chevrons keep a minimum size in
## screen pixels however far the camera is. The bot measures the pixels they
## really change (BattleChecks.reads_at_a_glance).

const MIN_POLE_PX := 110.0
const MIN_CHEVRON_PX := 34.0
const MIN_LINE_PX := 3.0


func _far_zoom() -> float:
	var camera := BattleCamera.new()
	camera.setup(SiegeMap.new().bounds, Rect2(0, 0, 1920, 1080))
	camera.fit_screen(Vector2(1920, 1080), BattleHud.TOP_CLEAR, BattleHud.BOTTOM_CLEAR)
	return camera.fit_zoom() * BattleCamera.MIN_FIT


func test_the_rally_flag_pole_is_tall_on_screen_at_every_zoom() -> void:
	for zoom: float in [_far_zoom(), 4.0, BattleCamera.MAX_ZOOM]:
		var pole := FxMarks.RALLY_POLE_M * FxMarks.scale_for(zoom) * zoom
		assert_gte(pole, MIN_POLE_PX, "pole %.0f px at zoom %.1f" % [pole, zoom])


func test_the_flag_strokes_are_thick_on_screen() -> void:
	assert_gte(FxMarks.RALLY_LINE_PX, MIN_LINE_PX)


func test_the_chevrons_are_big_on_screen_at_every_zoom() -> void:
	for zoom: float in [_far_zoom(), 4.0, BattleCamera.MAX_ZOOM]:
		var wide := FxSignals.chevron_m(zoom) * zoom
		assert_gte(wide, MIN_CHEVRON_PX, "chevron %.0f px at zoom %.1f" % [wide, zoom])


func test_charge_and_retreat_differ_in_count_and_colour_not_only_hue() -> void:
	assert_gt(FxSignals.CHARGE_CHEVRONS, FxSignals.RETREAT_CHEVRONS)
	assert_ne(FxSignals.charge_fill(), FxSignals.retreat_fill())
