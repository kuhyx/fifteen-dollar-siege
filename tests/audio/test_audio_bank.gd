extends GutTest
## Every sound the game can ask for is a loaded, lossless stream, and Godot
## plays the loops the way the renderer closed them. Checked on the loaded
## resource, never on the .import sidecar (loop mode 1 is "disabled" there).

const RATE := 44100
const SEAM_FRAMES := 2048

var bank: AudioBank


func before_all() -> void:
	bank = AudioBank.new()
	bank.load_all()


func _frames(wav: AudioStreamWAV) -> int:
	return wav.data.size() / (4 if wav.stereo else 2)


func _mixed(wav: AudioStreamWAV, from_frame: int, count: int) -> PackedVector2Array:
	var playback := wav.instantiate_playback()
	# Half a frame in: Godot truncates seconds to a frame, and N / RATE * RATE
	# can land just under N.
	playback.start((from_frame + 0.5) / RATE)
	return playback.mix_audio(1.0, count)


func test_nothing_on_the_cue_sheet_is_missing() -> void:
	assert_eq(Array(bank.missing), [], "run ./install.sh: it renders the audio")
	assert_eq(bank.streams.size(), 57)


func test_every_siege_event_maps_to_loaded_streams() -> void:
	for kind: StringName in SiegeEvent.ALL:
		for command: int in SiegeSim.Command.values():
			var cue := AudioCues.for_event({"kind": kind, "pos": Vector2.ZERO, "command": command})
			assert_true(AudioCues.CUES.has(cue), "%s has a cue" % kind)
			for file: String in AudioCues.CUES.get(cue, {}).get("files", []):
				assert_not_null(bank.stream(file), "%s -> %s is loaded" % [kind, file])


func test_every_menu_cue_maps_to_a_loaded_stream() -> void:
	assert_eq(AudioCues.UI.size(), 10)
	for cue: StringName in AudioCues.UI:
		assert_true(AudioCues.CUES.has(cue), "%s is on the sheet" % cue)
		for file: String in AudioCues.CUES.get(cue, {}).get("files", []):
			assert_not_null(bank.stream(file), "%s -> %s is loaded" % [cue, file])


func test_an_unknown_event_has_no_cue() -> void:
	assert_eq(AudioCues.for_event({"kind": &"not_an_event"}), &"")
	assert_eq(AudioCues.for_event({}), &"")


func test_every_stream_is_16_bit_pcm_at_44100() -> void:
	for file in AudioCues.files():
		var wav := bank.stream(file) as AudioStreamWAV
		if wav == null:
			fail_test("%s is not a WAV stream" % file)
			continue
		assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, "%s is PCM, not a codec" % file)
		assert_eq(wav.mix_rate, RATE, "%s rate" % file)


func test_loops_loop_forward_over_the_whole_file_and_one_shots_do_not() -> void:
	var loops := AudioCues.loops()
	for file in AudioCues.files():
		# A fresh copy straight from the import: the bank sets a loop again in
		# code, which would hide a sidecar that got it wrong.
		var path := AudioCues.ROOT + file + ".wav"
		var wav := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
		if wav == null:
			fail_test("%s did not load" % file)
			continue
		assert_ne(wav, bank.stream(file), "%s: a copy, not the bank's stream" % file)
		if file in loops:
			assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % file)
			assert_eq(wav.loop_begin, 0, "%s loop start" % file)
			assert_eq(wav.loop_end, _frames(wav) - 1, "%s loop end" % file)
			assert_true(wav.stereo, "%s is stereo" % file)
		else:
			assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s plays once" % file)


func test_the_stems_are_one_length_and_the_riff_is_half_of_it() -> void:
	var period := _frames(bank.stream(AudioCues.STEMS[0]) as AudioStreamWAV) - 1
	assert_eq(period, 32 * RATE, "16 bars at 120 = 32 s exactly")
	for index in range(1, 4):
		assert_eq(_frames(bank.stream(AudioCues.STEMS[index]) as AudioStreamWAV) - 1, period)
	assert_eq(_frames(bank.stream(AudioCues.STEMS[4]) as AudioStreamWAV) - 1, period / 2)


## The renderer writes a loop with its first frame again at the end, because
## Godot continues from frame 1 after the last frame. If that ever changes, a
## frame is skipped or doubled at every wrap and this test hears it.
func test_godot_plays_past_the_seam_exactly_as_it_plays_the_start() -> void:
	for file in [AudioCues.HUB, AudioCues.STEMS[4]]:
		var wav := bank.stream(file) as AudioStreamWAV
		var period := _frames(wav) - 1
		var across := _mixed(wav, period - SEAM_FRAMES, SEAM_FRAMES * 2)
		var start := _mixed(wav, 0, SEAM_FRAMES)
		var worst := 0.0
		for index in range(16, SEAM_FRAMES - 16):
			worst = maxf(worst, (across[SEAM_FRAMES + index] - start[index]).length())
		assert_lt(worst, 0.001, "%s: after the wrap comes the start of the file" % file)
		var step := (across[SEAM_FRAMES + 2] - across[SEAM_FRAMES + 1]).length()
		assert_lt(step, 0.05, "%s: no click at the wrap" % file)
