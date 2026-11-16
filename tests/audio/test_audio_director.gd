extends GutTest
## The audio director inside the real main scene, under the Dummy driver:
## music at boot, the bed and the stingers around a siege, a cue per menu
## action, snapshot events on the right voices, repeats capped, and the
## saved volume. Sound itself is never judged here (tools/audio/analyze.py
## measures the files; the listening is kuhy's).

const MAP := Rect2(0.0, 0.0, 600.0, 400.0)

var main: Main
var director: AudioDirector


func before_each() -> void:
	SaveStore.clear()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.options.speed = 400.0
	main.options.sim_seed = 5
	main.options.lab_runs = 6
	director = AudioDirector.live()


func after_each() -> void:
	get_tree().paused = false


func _snapshot(events: Array[Dictionary]) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	shot.events = events
	return shot


func _volley(count: int) -> SiegeSnapshot:
	var events: Array[Dictionary] = []
	for index in count:
		events.append({"kind": SiegeEvent.SLING_VOLLEY, "pos": Vector2(index * 6.0, 200.0)})
	return _snapshot(events)


func _start_siege() -> void:
	main.open_loadout(&"watch")
	(main.screen as LoadoutScreen).toggle(&"double_men")
	(main.screen as LoadoutScreen).toggle(&"fifty_men")
	(main.screen as LoadoutScreen).go_button.pressed.emit()


func test_boot_starts_the_hub_music_and_a_test_run_is_muted() -> void:
	assert_not_null(director, "Main owns an AudioDirector")
	assert_eq(AudioServer.get_driver_name(), "Dummy")
	assert_eq(director.music.scene, &"hub")
	assert_not_null(director.music.hub.stream)
	assert_eq(director.music.hub.stream, director.bank.stream(AudioCues.HUB))
	assert_true(director.music.hub.playing, "the hub loop plays at boot")
	assert_eq(director.music.hub.bus, AudioBuses.MUSIC)
	assert_true(director.silent, "a GUT run never makes sound")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioBuses.MUSIC)))
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioBuses.SFX)))


func test_a_siege_plays_the_bed_then_the_stinger_then_the_hub_again() -> void:
	_start_siege()
	assert_eq(director.music.scene, &"battle")
	assert_true(director.music.battle.playing, "the bed starts with the siege")
	assert_eq(director.ui_log.back(), &"ui_go")
	(main.screen as BattleScreen).payoff_s = 0.05
	(main.screen as BattleScreen).beats.skip_all()
	await wait_until(func() -> bool: return main.screen_name == &"result", 20.0)
	assert_eq(director.music.scene, &"ending")
	assert_true(director.music.stinger.playing)
	assert_eq(director.music.stinger.stream, director.bank.stream(AudioCues.WIN))
	main.open_hub()
	assert_eq(director.music.scene, &"hub")
	assert_true(director.music.hub.playing)


func test_a_lost_siege_gets_the_other_stinger() -> void:
	main.siege_ended.emit(SiegeSim.Outcome.LOSE, 12.0)
	assert_eq(director.music.stinger.stream, director.bank.stream(AudioCues.LOSE))


func test_each_menu_action_has_its_own_cue() -> void:
	((main.screen as HubScreen).buttons[&"watch"] as Button).pressed.emit()
	await wait_process_frames(2)
	assert_eq(director.ui_log.back(), &"ui_mode", "picking a mode is not a plain click")
	var shop := main.screen as LoadoutScreen
	shop.toggle(&"stew")
	assert_eq(director.ui_log.back(), &"ui_buy")
	shop.toggle(&"stew")
	assert_eq(director.ui_log.back(), &"ui_unbuy")
	for id: StringName in [&"double_men", &"knight_armor", &"wasps"]:
		director.clock_s += 1.0
		shop.toggle(id)
	shop.toggle(&"moose")
	assert_eq(director.ui_log.back(), &"ui_refuse")
	main.pause_menu.open()
	assert_eq(director.ui_log.back(), &"ui_pause")
	assert_true(director.music.ducked)
	main.pause_menu.close()
	assert_eq(director.ui_log.back(), &"ui_resume")
	assert_false(director.music.ducked)
	director.clock_s += 1.0
	await wait_process_frames(1)
	shop.back_button.pressed.emit()
	await wait_process_frames(2)
	assert_eq(director.ui_log.back(), &"ui_button", "any other button clicks")
	assert_eq(director.ui_log.count(&"ui_button"), 1, "cued actions did not click as well")


func test_the_lab_ticks_while_it_counts_and_rings_when_done() -> void:
	main.open_loadout(&"lab")
	(main.screen as LoadoutScreen).go_button.pressed.emit()
	await wait_until(func() -> bool: return (main.screen as LabScreen).done, 20.0)
	await wait_process_frames(2)
	assert_gt(director.ui_log.count(&"ui_lab_tick"), 0)
	assert_eq(director.ui_log.count(&"ui_lab_done"), 1)


func test_a_snapshot_plays_each_event_where_it_happened() -> void:
	var shot := _snapshot(
		[
			{"kind": SiegeEvent.BELL_RING, "pos": Vector2(60.0, 200.0)},
			{"kind": SiegeEvent.SHOTGUN_BLAST, "pos": Vector2(540.0, 200.0)},
			{"kind": &"a_kind_from_the_future", "pos": Vector2.ZERO},
		]
	)
	AudioDirector.on_snapshot(shot, MAP)
	assert_eq(director.pool.plays.size(), 2, "unknown kinds are skipped")
	var centre := get_viewport().get_visible_rect().get_center().x
	var bell: Dictionary = director.pool.plays[0]
	var blast: Dictionary = director.pool.plays[1]
	assert_eq(bell["cue"], &"bell_ring")
	assert_eq((bell["voice"] as AudioStreamPlayer2D).stream, director.bank.stream("sfx/bell"))
	assert_true((bell["voice"] as AudioStreamPlayer2D).playing)
	assert_eq((bell["voice"] as AudioStreamPlayer2D).bus, AudioBuses.SFX)
	assert_lt((bell["voice"] as AudioStreamPlayer2D).position.x, centre - 300.0, "left of the view")
	assert_eq(blast["cue"], &"shotgun_blast")
	assert_eq((blast["voice"] as AudioStreamPlayer2D).stream, director.bank.stream("sfx/shotgun"))
	assert_gt((blast["voice"] as AudioStreamPlayer2D).position.x, centre + 300.0, "right of it")


func test_the_view_decides_left_and_right_and_how_far() -> void:
	var event := {"kind": SiegeEvent.MONSTER_SMASH, "pos": Vector2(300.0, 200.0)}
	AudioDirector.on_snapshot(_snapshot([event]), Rect2(280.0, 0.0, 100.0, 100.0))
	director.clock_s += 5.0
	AudioDirector.on_snapshot(_snapshot([event]), Rect2(900.0, 0.0, 100.0, 100.0))
	var near: Dictionary = director.pool.plays[0]
	var far: Dictionary = director.pool.plays[1]
	var centre := get_viewport().get_visible_rect().get_center().x
	assert_lt(
		(near["voice"] as AudioStreamPlayer2D).position.x, centre, "a fifth of the way across"
	)
	assert_lt(float(far["db"]), float(near["db"]) - 6.0, "out of view is quieter")


func test_hundreds_of_volleys_stay_a_few_voices() -> void:
	for round in 3:
		AudioDirector.on_snapshot(_volley(100), MAP)
	assert_eq(director.pool.plays.size(), 1, "300 volleys in one instant are one sound")
	for round in 60:
		director.clock_s += 1.0 / 60.0
		AudioDirector.on_snapshot(_volley(100), MAP)
		assert_lte(director.pool.sounding(&"sling_volley"), 3)
	assert_between(director.pool.plays.size(), 5, 10, "a second of volleys: under ten starts")
	assert_gt(float(director.pool.plays[0]["db"]), -3.0, "a crowd of slings is louder than one")


func test_the_bed_follows_alarm_morale_and_the_band() -> void:
	_start_siege()
	var shot := _snapshot([])
	shot.alarm = 1.0
	shot.village_morale = 0.15
	AudioDirector.on_snapshot(shot, MAP)
	assert_gt(director.music.layer_target[BattleMix.ALARM], 0.9)
	assert_gt(director.music.layer_target[BattleMix.HOPE], 0.8)
	assert_almost_eq(director.music.layer_target[BattleMix.ROCK], 0.0, 0.001)
	shot.events = [{"kind": SiegeEvent.BAND_RIFF, "pos": Vector2(100.0, 100.0)}]
	AudioDirector.on_snapshot(shot, MAP)
	assert_almost_eq(director.music.layer_target[BattleMix.ROCK], 1.0, 0.001)
	assert_lt(director.music.layer_target[BattleMix.HOPE], 0.25, "the band covers the bed")
	await wait_seconds(0.3)
	assert_gt(director.music.layer_gain[BattleMix.ROCK], 0.05, "and fades in, it does not jump")
	assert_lt(director.music.layer_gain[BattleMix.ROCK], 1.0)


func test_volume_and_mute_are_saved_and_reach_the_buses() -> void:
	director.set_music_volume(0.4)
	director.set_sfx_volume(0.6)
	assert_true(director.toggle_muted())
	var saved := AudioSettings.load_saved()
	assert_almost_eq(saved.music, 0.4, 0.001)
	assert_almost_eq(saved.sfx, 0.6, 0.001)
	assert_true(saved.muted)
	var music := AudioServer.get_bus_index(AudioBuses.MUSIC)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.4), 0.01)
	assert_false(director.toggle_muted())
	assert_false(AudioSettings.load_saved().muted)
