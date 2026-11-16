class_name VolumeBeat
extends RefCounted
## The bot's turn at the pause menu's volume control (the menu is open): a
## click on each speaker button, a key, a click on a step of the bar. After
## every move the bus must sit at the level the row shows and the save must
## hold it; at the end the buses are reset and restored from the save, which is
## what a restart does (tests/test_volume.gd frees and rebuilds the whole
## scene). The bot's run is muted, but the bus volume is still set.


static func run(bot: BotBase) -> bool:
	var menu := bot.main.pause_menu
	var director := AudioDirector.live()
	if not bot.check(director != null, "the game has an audio director"):
		return false
	for channel: StringName in [VolumeRow.MUSIC, VolumeRow.EFFECTS]:
		var row := menu.volume[channel] as VolumeRow
		var parts := {"quieter": row.quieter, "louder": row.louder, "bar": row.bar}
		if not bot.all_inside(parts, "%s volume control" % channel):
			return false
	var music := menu.volume[VolumeRow.MUSIC] as VolumeRow
	var effects := menu.volume[VolumeRow.EFFECTS] as VolumeRow
	var steps := AudioSettings.STEPS
	var start := music.level()
	await bot.click(music.quieter)
	var ok := _is(bot, music, start - 1, "a click on quieter lowers the music")
	await bot.click(music.quieter)
	ok = ok and _is(bot, music, start - 2, "a second click lowers it again")
	InputSynth.key_tap(KEY_5)
	await bot.frames(2)
	ok = ok and _is(bot, music, start - 1, "the key on louder raises the music")
	await bot.click_at(
		effects.bar.get_global_rect().position + effects.bar.step_rect(5).get_center()
	)
	ok = ok and _is(bot, effects, 6, "a click on the sixth step sets the effects")
	await bot.click(effects.louder)
	ok = ok and _is(bot, effects, 7, "louder raises the effects")
	await bot.click(effects.louder)
	await bot.click(effects.louder)
	await bot.click(effects.louder)
	await bot.click(effects.louder)
	ok = ok and _is(bot, effects, steps, "louder stops at full")
	await bot.click(effects.quieter)
	ok = ok and _is(bot, effects, steps - 1, "and quieter comes back")
	return ok and _restored(bot)


## The row, the bus and the save all say `step`.
static func _is(bot: BotBase, row: VolumeRow, step: int, what: String) -> bool:
	var bus := AudioBuses.MUSIC if row.channel == VolumeRow.MUSIC else AudioBuses.SFX
	var want_db := linear_to_db(AudioSettings.linear_of(step)) if step > 0 else AudioBuses.SILENT_DB
	var saved := AudioSettings.load_saved()
	var saved_linear := saved.music if row.channel == VolumeRow.MUSIC else saved.sfx
	return (
		bot.check(
			row.level() == step and row.bar.level == step, "%s: the row shows %d" % [what, step]
		)
		and bot.check(
			is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)), want_db),
			"%s: the %s bus is at %.1f dB" % [what, bus, want_db]
		)
		and bot.check(
			AudioSettings.step_of(saved_linear) == step, "%s: the save holds step %d" % [what, step]
		)
	)


## A restart: the buses go back to their start-up level, then the boot's own
## two calls (the saved settings, put on the buses) must bring the volumes back.
static func _restored(bot: BotBase) -> bool:
	var want := {}
	for bus: StringName in [AudioBuses.MUSIC, AudioBuses.SFX]:
		var index := AudioServer.get_bus_index(bus)
		want[bus] = AudioServer.get_bus_volume_db(index)
		AudioServer.set_bus_volume_db(index, 0.0)
	AudioBuses.apply(AudioSettings.load_saved(), true)
	var ok := true
	for bus: StringName in want:
		var got := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
		ok = (
			ok
			and bot.check(is_equal_approx(got, want[bus]), "a restart restores the %s volume" % bus)
		)
	return ok
