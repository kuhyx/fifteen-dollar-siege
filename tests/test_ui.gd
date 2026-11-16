extends GutTest
## The small shared pieces: pictograms, seven-segment numbers, the command
## line, the bot's refusals and the blank-frame check.

const GLYPH_IDS: Array[StringName] = [
	&"watch",
	&"command",
	&"rally",
	&"win",
	&"lab",
	&"play",
	&"resume",
	&"back",
	&"home",
	&"quit",
	&"menu",
	&"coin",
	&"combust",
	&"charge",
	&"retreat",
	&"morale",
	&"alarm",
	&"men",
	&"clock",
	&"buff",
	&"check"
]


func test_every_pictogram_draws_something_inside_its_square() -> void:
	for id in GLYPH_IDS:
		var glyph := Glyphs.texture(id).glyph
		assert_gt(glyph.pieces.size(), 0, String(id))
		assert_between(glyph.area(), 200.0, VectorGlyph.UNITS * VectorGlyph.UNITS, String(id))
		for piece in glyph.pieces:
			for point in piece:
				assert_true(Rect2(0, 0, 128, 128).grow(0.5).has_point(point), "%s %s" % [id, point])


func test_an_unknown_pictogram_is_an_error_not_a_blank() -> void:
	Glyphs.texture(&"no_such_glyph")
	assert_push_error("unknown glyph")


func test_a_glyph_button_has_an_icon_a_spoken_label_and_no_words() -> void:
	var button := GlyphButton.make(&"play", "Start the siege", 100.0)
	autofree(button)
	assert_not_null(button.icon)
	assert_eq(button.text, "")
	assert_eq(button.accessibility_name, "Start the siege")
	assert_eq(button.custom_minimum_size, Vector2(100, 100))


func test_seven_segment_widths_grow_with_the_digits() -> void:
	assert_almost_eq(SevenSegment.width(7, 100.0), 56.0, 0.01)
	assert_almost_eq(SevenSegment.width(42, 100.0), 132.0, 0.01)
	assert_almost_eq(SevenSegment.width(300, 100.0), 208.0, 0.01)
	assert_eq(SevenSegment.width(-42, 100.0), SevenSegment.width(42, 100.0))
	assert_eq(SevenSegment.DIGITS.size(), 10)
	assert_eq(SevenSegment.DIGITS[8], 0b1111111, "eight lights every segment")
	assert_eq(SevenSegment.DIGITS[1], 0b0000110, "one lights the two right ones")


func test_launch_options_read_the_game_arguments() -> void:
	var options := (
		LaunchOptions
		. parse(
			[
				"--dev",
				"--mode=command",
				"--loadout=double_men,stew",
				"--seed=7",
				"--speed=16",
				"--lab-runs=30",
				"--save-dir=/x/save",
				"--result-file=/x/result",
				"--screenshot-dir=/x/shots",
				"--expect-window=1920x1080",
				"--session-id=abc",
			]
		)
	)
	assert_eq(options.problem, "")
	assert_true(options.dev)
	assert_eq(options.mode, &"command")
	assert_eq(options.loadout.ids, [&"double_men", &"stew"] as Array[StringName])
	assert_eq(options.sim_seed, 7)
	assert_eq(options.speed, 16.0)
	assert_eq(options.lab_runs, 30)
	assert_eq(options.save_dir, "/x/save")
	assert_eq(options.result_file, "/x/result")
	assert_eq(options.screenshot_dir, "/x/shots")
	assert_eq(options.expect_window, "1920x1080")
	assert_true(options.unknown.is_empty(), "--session-id belongs to the dev tools")


func test_launch_options_defaults_and_problems() -> void:
	var plain := LaunchOptions.parse([])
	assert_false(plain.dev)
	assert_eq(plain.mode, &"")
	assert_eq(plain.sim_seed, -1, "a random seed per siege")
	assert_eq(plain.speed, 1.0)
	assert_eq(plain.lab_runs, LaunchOptions.DEFAULT_LAB_RUNS)
	assert_eq(LaunchOptions.parse(["--autodrive=lab"]).autodrive, &"lab")
	assert_string_contains(LaunchOptions.parse(["--mode=party"]).problem, "unknown mode")
	assert_string_contains(LaunchOptions.parse(["--speed=fast"]).problem, "--speed=fast")
	assert_string_contains(LaunchOptions.parse(["--speed=9000"]).problem, "--speed=9000")
	assert_string_contains(LaunchOptions.parse(["--seed=1.5"]).problem, "whole number")
	var rich := LaunchOptions.parse(["--loadout=double_men,knight_armor,wasps,medics"])
	assert_string_contains(rich.problem, "not a legal loadout")
	assert_eq(LaunchOptions.parse(["--frobnicate"]).unknown, ["--frobnicate"] as Array[String])
	assert_eq(LaunchOptions.value_of(["--a=1", "--b=2"], "--b="), "2")
	assert_eq(LaunchOptions.value_of(["--a=1"], "--b="), "")


func test_a_bot_refuses_the_real_save_and_a_missing_save_dir() -> void:
	assert_string_contains(BotReport.save_dir_problem(""), "pass --save-dir")
	assert_string_contains(BotReport.save_dir_problem("relative/dir"), "absolute")
	assert_string_contains(BotReport.save_dir_problem("res://save"), "absolute")
	assert_string_contains(BotReport.save_dir_problem("user://save"), "real save")
	assert_string_contains(BotReport.save_dir_problem("user://"), "real save")
	assert_eq(BotReport.save_dir_problem("/tmp/some/throwaway"), "")
	assert_eq(BotReport.save_dir_problem("user://bot_save"), "")


func test_a_bot_checks_the_window_it_was_promised() -> void:
	assert_eq(BotReport.window_problem("", Vector2i(5, 5)), "", "nothing asked")
	assert_eq(BotReport.window_problem("1920x1080", Vector2i(1920, 1080)), "")
	assert_string_contains(BotReport.window_problem("1920x1080", Vector2i(1280, 720)), "window is")
	assert_string_contains(BotReport.window_problem("big", Vector2i(1, 1)), "cannot read")


func test_the_verdict_file_is_written_whole() -> void:
	var dir: String = preload("res://tests/run_tmp.gd").path("verdict")
	var path := dir.path_join("deep/result")
	assert_true(BotReport.write_verdict(path, "PASS first"))
	assert_true(BotReport.write_verdict(path, "FAIL second"), "overwrites")
	assert_eq(FileAccess.get_file_as_string(path), "FAIL second\n")
	assert_false(FileAccess.file_exists(path + ".tmp"))
	assert_true(BotReport.write_verdict("", "PASS"), "no path: nothing to do")


func test_a_flat_frame_is_blank_and_a_drawn_one_is_not() -> void:
	var flat := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	flat.fill(Color(0.2, 0.2, 0.2))
	assert_true(FrameStats.is_blank(flat))
	assert_true(FrameStats.is_blank(null))
	var drawn := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	drawn.fill(Color.BLACK)
	drawn.fill_rect(Rect2i(0, 0, 32, 64), Color.WHITE)
	assert_false(FrameStats.is_blank(drawn))
	assert_eq(FrameStats.luminance(Image.new())["mean"], 0.0)
