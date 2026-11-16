extends GutTest
## The audio pieces on their own: the battle mix, the rate limiter, the voice
## pool, the saved settings, and a director with no files and no Main.


func _mix(alarm: float, army: float, village: float, rock: bool = false) -> PackedFloat32Array:
	return BattleMix.targets(alarm, army, village, rock)


func test_a_sleeping_village_hears_only_the_sneak() -> void:
	var mix := _mix(0.0, 1.0, 1.0)
	assert_eq(mix.size(), AudioCues.STEMS.size())
	assert_almost_eq(mix[BattleMix.BASE], 1.0, 0.001)
	for layer in [BattleMix.ALARM, BattleMix.HOPE, BattleMix.DREAD, BattleMix.ROCK]:
		assert_almost_eq(mix[layer], 0.0, 0.001, "layer %d is silent" % layer)


func test_the_drums_come_in_with_the_alarm_and_never_go_back() -> void:
	var last := -1.0
	for step in 11:
		var level := _mix(step / 10.0, 1.0, 1.0)[BattleMix.ALARM]
		assert_gte(level, last, "alarm %.1f" % (step / 10.0))
		last = level
	assert_almost_eq(last, 1.0, 0.001)
	assert_lt(_mix(1.0, 1.0, 1.0)[BattleMix.BASE], 1.0, "the sneak makes room for the drums")


func test_morale_decides_between_the_horn_and_the_dread() -> void:
	var winning := _mix(1.0, 0.9, 0.2)
	assert_gt(winning[BattleMix.HOPE], 0.8)
	assert_lt(winning[BattleMix.DREAD], 0.1)
	var losing := _mix(1.0, 0.2, 0.9)
	assert_gt(losing[BattleMix.DREAD], 0.8)
	assert_lt(losing[BattleMix.HOPE], 0.1)
	var both := _mix(1.0, 0.1, 0.1)
	assert_lt(both[BattleMix.HOPE] + both[BattleMix.DREAD], 1.2, "two stories do not both shout")


func test_the_band_takes_over_the_bed() -> void:
	var rocking := _mix(1.0, 0.5, 0.5, true)
	assert_almost_eq(rocking[BattleMix.ROCK], 1.0, 0.001)
	for layer in [BattleMix.BASE, BattleMix.ALARM, BattleMix.HOPE, BattleMix.DREAD]:
		assert_lt(rocking[layer], 0.25, "layer %d ducks under the riff" % layer)


func test_the_rate_limiter_spaces_one_cue_and_leaves_the_others_alone() -> void:
	var limiter := RateLimiter.new()
	assert_true(limiter.allow(&"sling_volley", 1.0, 0.12))
	assert_false(limiter.allow(&"sling_volley", 1.05, 0.12), "too soon")
	assert_true(limiter.allow(&"bell_ring", 1.05, 1.5), "another cue has its own clock")
	assert_true(limiter.allow(&"sling_volley", 1.13, 0.12))
	var started := 0
	for tick in 600:
		started += int(limiter.allow(&"melee_clash", 2.0 + tick / 60.0, 0.09))
	assert_between(started, 100, 112, "ten seconds of clashes every frame: about eleven a second")


func test_a_full_pool_drops_the_small_sound_and_makes_room_for_the_big_one() -> void:
	var bank := AudioBank.new()
	bank.load_all()
	var pool := SfxPool.new()
	add_child_autofree(pool)
	var long := bank.stream("sfx/bell")
	for index in SfxPool.VOICES:
		assert_not_null(pool.play(&"bell_ring", long, {"rank": 1, "now": float(index)}))
	assert_null(pool.play(&"sling_volley", bank.stream("sfx/sling_1"), {"rank": 0, "now": 99.0}))
	var cheer := pool.play(&"victory", bank.stream("sfx/cheer"), {"rank": 3, "now": 100.0})
	assert_not_null(cheer, "the ending always sounds")
	assert_eq(pool.sounding(&"victory"), 1)
	assert_eq(pool.sounding(&"bell_ring"), SfxPool.VOICES - 1, "the oldest bell gave way")


func test_settings_survive_a_restart_and_clamp() -> void:
	SaveStore.clear()
	var fresh := AudioSettings.load_saved()
	assert_false(fresh.muted)
	assert_between(fresh.music, 0.1, 1.0)
	fresh.music = 0.35
	fresh.sfx = 7.0
	fresh.muted = true
	assert_true(fresh.save())
	var again := AudioSettings.load_saved()
	assert_almost_eq(again.music, 0.35, 0.001)
	assert_almost_eq(again.sfx, 1.0, 0.001, "a volume over 1 is clamped")
	assert_true(again.muted)
	SaveStore.write_json(AudioSettings.FILE, {"music": "loud", "muted": 3})
	assert_almost_eq(AudioSettings.load_saved().music, AudioSettings.DEFAULT_MUSIC, 0.001)


func test_the_buses_exist_once_and_carry_the_settings() -> void:
	AudioBuses.ensure()
	AudioBuses.ensure()
	var music := AudioServer.get_bus_index(AudioBuses.MUSIC)
	var sfx := AudioServer.get_bus_index(AudioBuses.SFX)
	assert_gt(music, 0)
	assert_gt(sfx, 0)
	assert_eq(AudioServer.bus_count, 3, "Master, Music, Sfx: asking twice adds nothing")
	var settings := AudioSettings.new()
	settings.music = 0.5
	AudioBuses.apply(settings, false)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
	assert_false(AudioServer.is_bus_mute(music))
	settings.muted = true
	AudioBuses.apply(settings, false)
	assert_true(AudioServer.is_bus_mute(music))
	assert_true(AudioServer.is_bus_mute(sfx))
	settings.muted = false
	AudioBuses.apply(settings, true)
	assert_true(AudioServer.is_bus_mute(sfx), "a silent run mutes whatever the player saved")


func test_a_director_without_files_or_a_main_scene_stays_quiet_and_whole() -> void:
	var lone := AudioDirector.new()
	lone.bank.root = "res://assets/no_such_folder/"
	add_child_autofree(lone)
	assert_eq(AudioDirector.live(), lone)
	assert_gt(lone.bank.missing.size(), 40)
	lone.ui(&"ui_buy")
	lone.music.show_hub()
	lone.music.show_battle()
	lone.music.ending(true)
	var shot := SiegeSnapshot.new()
	shot.events = [{"kind": SiegeEvent.BELL_RING, "pos": Vector2.ZERO}, {"kind": &"new_kind"}]
	AudioDirector.on_snapshot(shot, Rect2(0, 0, 600, 400))
	assert_eq(lone.pool.plays.size(), 0, "nothing to play, nothing breaks")
	assert_false(lone.music.hub.playing)


func test_on_snapshot_without_a_director_is_a_no_op() -> void:
	assert_null(AudioDirector.live())
	AudioDirector.on_snapshot(SiegeSnapshot.new(), Rect2())
	pass_test("no director, no error")
