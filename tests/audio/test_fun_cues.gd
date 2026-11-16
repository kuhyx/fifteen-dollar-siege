extends GutTest
## The delights' cues (FunCue) follow the same rules as the battle's own sounds:
## they sit on the battle voices so a pause stops them, a cue with a position is
## placed left to right against the view the battle last gave, and every one is
## counted in `AudioDirector.heard` (the buffs bot reads that). Sound itself is
## never judged here; the voices and their positions are.

const VIEW := Rect2(0.0, 0.0, 600.0, 400.0)

var main: Main
var director: AudioDirector


func before_each() -> void:
	SaveStore.clear()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	director = AudioDirector.live()
	AudioDirector.on_snapshot(SiegeSnapshot.new(), VIEW)


func after_each() -> void:
	get_tree().paused = false


func _centre_x() -> float:
	return director.get_viewport().get_visible_rect().get_center().x


func test_a_fun_cue_is_counted_in_heard() -> void:
	assert_eq(int(director.heard.get(&"fun_toll", 0)), 0)
	FunCue.play(&"fun_toll")
	assert_eq(int(director.heard.get(&"fun_toll", 0)), 1)
	FunCue.play(&"fun_toll")
	assert_eq(int(director.heard.get(&"fun_toll", 0)), 2, "asked for twice, counted twice")
	FunCue.play(&"fun_dice")
	assert_eq(int(director.heard.get(&"fun_dice", 0)), 1, "menu delights count too")


func test_a_fun_cue_stops_with_the_pause() -> void:
	FunCue.play(&"fun_heartbeat")
	var voice: AudioStreamPlayer2D = director.pool.plays.back()["voice"]
	assert_eq(director.pool.plays.back()["cue"], &"fun_heartbeat", "on the battle voices")
	assert_true(director.pool.is_ancestor_of(voice))
	assert_false(director.ui_log.has(&"fun_heartbeat"), "not on the menu voices")
	assert_true(voice.can_process(), "it runs")
	get_tree().paused = true
	assert_false(voice.can_process(), "a paused tree holds it, as it holds the battle sounds")
	assert_true(director.ui_pool.can_process(), "the menu voices go on")


func test_a_fun_cue_with_a_position_is_placed_in_the_view() -> void:
	FunCue.play(&"fun_glint", 1.0, Vector2(30.0, 200.0))
	var left: float = director.pool.plays.back()["x"]
	director.limiter.reset()
	FunCue.play(&"fun_glint", 1.0, Vector2(570.0, 200.0))
	var right: float = director.pool.plays.back()["x"]
	director.limiter.reset()
	FunCue.play(&"fun_glint")
	var middle: float = director.pool.plays.back()["x"]
	assert_lt(left, _centre_x() - 200.0, "left on the map, left in the speakers")
	assert_gt(right, _centre_x() + 200.0, "right on the map, right in the speakers")
	assert_almost_eq(middle, _centre_x(), 0.5, "no position: the middle")


func test_a_fun_cue_past_the_edge_of_the_view_stays_on_its_side() -> void:
	FunCue.play(&"fun_firework", 1.0, Vector2(-900.0, 200.0))
	var far: float = director.pool.plays.back()["x"]
	assert_almost_eq(far, director.get_viewport().get_visible_rect().position.x, 0.5)
