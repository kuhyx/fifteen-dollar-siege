extends GutTest
## The touch bot's promise: it fails on any key, pad or real mouse event that
## reaches the game, and lets the mouse the engine makes from a touch pass.


func _bot() -> TouchBot:
	var bot := TouchBot.new()
	autofree(bot)
	return bot


func test_a_key_a_pad_button_or_a_real_mouse_click_is_foreign() -> void:
	var bot := _bot()
	bot._input(InputEventKey.new())
	bot._input(InputEventJoypadButton.new())
	var click := InputEventMouseButton.new()
	bot._input(click)
	assert_eq(bot.foreign, 3)


func test_touch_and_the_mouse_made_from_it_are_not() -> void:
	var bot := _bot()
	bot._input(InputEventScreenTouch.new())
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	bot._input(emulated)
	assert_eq(bot.foreign, 0)
