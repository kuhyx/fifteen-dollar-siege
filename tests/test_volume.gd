extends GutTest
## The pause menu's volume control: speaker buttons and a bar of steps for the
## music and the effects, no words. Every move reaches the bus and the save, and
## a restart (the whole scene freed and built again) brings the volumes back.
## RED without AudioDirector's save call or its boot-time apply.

var main: Main


func before_each() -> void:
	SaveStore.clear()
	InputDevice.device = InputDevice.Device.KEYS
	_start()


func _start() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(main):
		main.free()
	SaveStore.clear()


func _row(channel: StringName) -> VolumeRow:
	return main.pause_menu.volume[channel] as VolumeRow


func _bus_db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func test_the_speaker_buttons_move_the_level_the_bus_and_the_save() -> void:
	var row := _row(VolumeRow.MUSIC)
	var start := row.level()
	assert_eq(start, AudioSettings.step_of(AudioSettings.DEFAULT_MUSIC))
	row.quieter.pressed.emit()
	assert_eq(row.level(), start - 1)
	assert_eq(row.bar.level, start - 1)
	var linear := AudioSettings.linear_of(start - 1)
	assert_almost_eq(_bus_db(AudioBuses.MUSIC), linear_to_db(linear), 0.01)
	assert_almost_eq(AudioSettings.load_saved().music, linear, 0.001)
	row.louder.pressed.emit()
	assert_eq(row.level(), start)


func test_the_effects_have_their_own_row_and_stop_at_both_ends() -> void:
	var row := _row(VolumeRow.EFFECTS)
	for i in AudioSettings.STEPS + 3:
		row.louder.pressed.emit()
	assert_eq(row.level(), AudioSettings.STEPS)
	assert_almost_eq(_bus_db(AudioBuses.SFX), 0.0, 0.01)
	for i in AudioSettings.STEPS + 3:
		row.quieter.pressed.emit()
	assert_eq(row.level(), 0)
	assert_eq(_bus_db(AudioBuses.SFX), AudioBuses.SILENT_DB)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioBuses.SFX)))
	assert_eq(_row(VolumeRow.MUSIC).level(), AudioSettings.step_of(AudioSettings.DEFAULT_MUSIC))


func test_a_pick_on_the_bar_sets_that_step() -> void:
	var row := _row(VolumeRow.MUSIC)
	row.bar.picked.emit(3)
	assert_eq(row.level(), 3)
	assert_almost_eq(AudioSettings.load_saved().music, 0.3, 0.001)


func test_the_volume_survives_a_restart() -> void:
	_row(VolumeRow.MUSIC).set_step(3)
	_row(VolumeRow.EFFECTS).set_step(6)
	main.free()
	# The buses of a fresh process start at 0 dB.
	for bus: StringName in [AudioBuses.MUSIC, AudioBuses.SFX]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), 0.0)
	_start()
	assert_almost_eq(_bus_db(AudioBuses.MUSIC), linear_to_db(0.3), 0.01)
	assert_almost_eq(_bus_db(AudioBuses.SFX), linear_to_db(0.6), 0.01)
	main.pause_menu.open()
	assert_eq(_row(VolumeRow.MUSIC).bar.level, 3, "the menu shows the saved step")
	assert_eq(_row(VolumeRow.EFFECTS).bar.level, 6)


func test_every_control_is_a_picture_with_a_spoken_name_and_a_key() -> void:
	for channel: StringName in main.pause_menu.volume:
		var row := _row(channel)
		for button: GlyphButton in [row.quieter, row.louder]:
			assert_eq(button.text, "", "no words")
			assert_ne(button.accessibility_name, "")
			assert_not_null(button.icon)
			var hint := button.find_child("KeyHint", false, false) as KeyHint
			assert_not_null(hint, "a key hint")
			assert_false(hint.unknown(), "the key has a picture")
			assert_not_null(hint.glyph_event())
		assert_ne(row.get_child(0).accessibility_name, "", "the channel has a spoken name")
	for action in VolumeKeys.actions():
		assert_true(InputMap.has_action(action), str(action))
		assert_true(KeyGlyph.can_draw(InputMap.action_get_events(action)[0]), str(action))


func test_the_keys_work_while_the_menu_is_open_and_not_before() -> void:
	var row := _row(VolumeRow.MUSIC)
	var start := row.level()
	InputSynth.key_tap(KEY_4)
	assert_eq(row.level(), start, "a shut menu ignores the key")
	main.pause_menu.open()
	await wait_frames(2)
	InputSynth.key_tap(KEY_4)
	assert_eq(row.level(), start - 1)
	InputSynth.key_tap(KEY_5)
	assert_eq(row.level(), start)


func test_the_controls_sit_on_the_card_inside_the_screen() -> void:
	main.pause_menu.open()
	await wait_frames(2)
	var view := get_viewport().get_visible_rect()
	assert_true(view.encloses(main.pause_menu.card.get_global_rect()))
	for channel: StringName in main.pause_menu.volume:
		var row := _row(channel)
		for part: Control in [row.quieter, row.louder, row.bar]:
			assert_true(main.pause_menu.card.is_ancestor_of(part))
			assert_true(main.pause_menu.card.get_global_rect().encloses(part.get_global_rect()))


func test_without_a_game_the_rows_do_nothing() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	var row := menu.volume[VolumeRow.MUSIC] as VolumeRow
	main.free()
	row.quieter.pressed.emit()
	assert_eq(row.level(), 0)
