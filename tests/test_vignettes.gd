extends GutTest
## The buff vignettes: every buff has one, it draws a real scene inside the
## stage, it moves, and it loops. A buff without a vignette fails here before
## it reaches the shop.

## Not multiples of a beat: a scene that repeats twice a loop still differs.
const MOMENTS: Array[float] = [0.0, 0.13, 0.37, 0.61, 0.89]
## Actors may walk off the stage sideways; nothing leaves it far.
const ROOM := Rect2(-80, -20, 352, 168)


func _dry(id: StringName, u: float) -> VignettePen:
	var pen := VignettePen.new()
	BuffVignettes.paint(id, pen, u)
	return pen


func test_every_buff_has_a_vignette_that_draws_a_scene() -> void:
	for def in BuffCatalog.all():
		assert_true(BuffVignettes.has(def.id), "%s has a vignette" % def.id)
		for u in MOMENTS:
			var pen := _dry(def.id, u)
			assert_gt(pen.count, 8, "%s draws a scene at %s" % [def.id, u])
			assert_eq(pen.broken, 0, "%s has a polygon that cannot be filled at %s" % [def.id, u])
			assert_true(ROOM.encloses(pen.reach), "%s at %s reaches %s" % [def.id, u, pen.reach])


func test_no_vignette_ever_draws_a_broken_polygon() -> void:
	for def in BuffCatalog.all():
		var broken := 0
		for step in 48:
			broken += _dry(def.id, step / 48.0).broken
		assert_eq(broken, 0, "%s over its whole loop" % def.id)


func test_every_vignette_moves() -> void:
	for def in BuffCatalog.all():
		var seen: Dictionary = {}
		for u in MOMENTS:
			seen[_dry(def.id, u).digest] = true
		assert_gt(seen.size(), 3, "%s shows different frames over its loop" % def.id)


func test_no_two_vignettes_are_the_same_scene() -> void:
	var seen: Dictionary = {}
	for def in BuffCatalog.all():
		var digest := _dry(def.id, 0.37).digest
		assert_false(seen.has(digest), "%s repeats %s" % [def.id, seen.get(digest, "")])
		seen[digest] = def.id


func test_an_unknown_buff_has_no_vignette() -> void:
	assert_false(BuffVignettes.has(&"no_such_buff"))
	assert_eq(_dry(&"no_such_buff", 0.3).count, 0)


func test_the_stage_loops_and_only_plays_a_known_buff() -> void:
	var stage := VignetteStage.new()
	add_child_autofree(stage)
	stage.size = Vector2(384, 256)
	stage.buff = &"wasps"
	stage.time = BuffVignettes.LOOP_S - 0.01
	stage._process(0.05)
	assert_almost_eq(stage.time, 0.04, 0.001, "the loop wraps")
	stage.buff = &"moose"
	assert_eq(stage.time, 0.0, "a new buff starts its vignette from the top")
	stage.playing = false
	stage._process(0.5)
	assert_eq(stage.time, 0.0, "a stopped stage holds its frame")


func test_the_pen_fits_the_stage_into_any_box() -> void:
	var canvas := Control.new()
	autofree(canvas)
	var pen := VignettePen.fitted(canvas, Rect2(10, 20, 384, 300))
	var view := VignettePen.VIEW
	assert_almost_eq(pen.xform * view.position, Vector2(10, 63.2), Vector2(0.01, 0.01))
	assert_almost_eq(pen.xform * view.end, Vector2(394, 320), Vector2(0.01, 0.01), "on its floor")
