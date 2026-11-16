extends GutTest
## Delights on the hub: the mode buttons swell under the pointer, and a wave
## of light crosses the shelf, brightening the waiting slots and lifting the
## won ones. Fails when either stops.


func test_a_mode_button_swells_under_the_pointer_and_settles_back() -> void:
	var hub := HubScreen.new()
	add_child_autofree(hub)
	var button := hub.buttons[&"watch"] as Control
	assert_eq(button.scale, Vector2.ONE)
	button.mouse_entered.emit()
	await wait_until(func() -> bool: return button.scale.x > 1.05, 2.0)
	assert_gt(button.scale.x, HubScreen.HOVER_SCALE - 0.01)
	button.mouse_exited.emit()
	await wait_until(func() -> bool: return is_equal_approx(button.scale.x, 1.0), 2.0)
	assert_eq(button.scale, Vector2.ONE)


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
