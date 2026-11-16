extends GutTest
## Delights on the hub: the mode buttons swell under the pointer, and a wave
## of light crosses the shelf, brightening the waiting slots and lifting the
## won ones. Fails when either stops.


func test_a_mode_button_swells_under_the_pointer_and_settles_back() -> void:
	var hub := HubScreen.new()
	add_child_autofree(hub)
	var button := hub.buttons[&"lab"] as Control
	assert_eq(button.scale, Vector2.ONE)
	_play_new_tweens(func() -> void: button.mouse_entered.emit(), HubScreen.SWELL_S * 2.0)
	assert_almost_eq(button.scale.x, HubScreen.HOVER_SCALE, 0.001, "it ends at the hover size")
	_play_new_tweens(func() -> void: button.mouse_exited.emit(), HubScreen.SWELL_S * 2.0)
	assert_almost_eq(button.scale.x, 1.0, 0.001, "and settles back")


## Runs `action`, then drives the tweens it started by `seconds` on the test's
## own clock (they are paused first), so no frame timing can change the result.
func _play_new_tweens(action: Callable, seconds: float) -> void:
	var before := get_tree().get_processed_tweens()
	action.call()
	for tween: Tween in get_tree().get_processed_tweens():
		if not before.has(tween):
			tween.pause()
			tween.custom_step(seconds)


func test_the_wave_crosses_the_shelf_then_rests() -> void:
	var first := TrophyShelf.glow(0, 0.0)
	var peak_by_slot := []
	for i in TrophyShelf.PER_ROW:
		var peak := 0.0
		for step in 90:
			peak = maxf(peak, TrophyShelf.glow(i, step * TrophyShelf.SWEEP_S / 90.0))
		peak_by_slot.append(peak)
	for peak: float in peak_by_slot:
		assert_gt(peak, 0.8, "the wave lights every slot of the row")
	assert_lt(first, 0.5, "it starts off the left edge")
	assert_lt(TrophyShelf.glow(6, TrophyShelf.SWEEP_S + 1.0), 0.02, "and rests between waves")


func test_the_shelf_redraws_every_frame_for_the_wave() -> void:
	var shelf := TrophyShelf.new()
	add_child_autofree(shelf)
	shelf.won = [&"stew"]
	assert_true(shelf.is_processing(), "it needs a frame each for the wave")
