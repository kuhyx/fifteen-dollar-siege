extends GutTest
## What the hand-off scripts (scripts/handoff/) ask of the game: open straight
## on the shop or the result, and for --check dump the state of the screen on
## show (and a frame) to a file, so a script can prove the state it launched.

var main: Main
var tmp := ""


func before_each() -> void:
	SaveStore.clear()
	tmp = "user://handoff_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(tmp)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)


func after_each() -> void:
	SaveStore.clear(tmp)
	DirAccess.remove_absolute(tmp)


func test_the_screen_and_check_options_parse() -> void:
	var options := LaunchOptions.parse(["--mode=command", "--screen=shop", "--check-state=/x/s"])
	assert_eq(options.problem, "")
	assert_eq(options.screen, &"shop")
	assert_eq(options.check_state, "/x/s")
	assert_eq(LaunchOptions.parse(["--mode=lab", "--screen=result"]).screen, &"result")


func test_a_screen_needs_a_mode_and_must_be_known() -> void:
	assert_string_contains(LaunchOptions.parse(["--screen=shop"]).problem, "--mode")
	assert_string_contains(LaunchOptions.parse(["--mode=watch", "--screen=lobby"]).problem, "lobby")
	assert_eq(LaunchOptions.parse([]).screen, &"")


func test_the_shop_opens_with_the_loadout_bought() -> void:
	main.options = LaunchOptions.parse(["--mode=watch", "--screen=shop", "--loadout=double_men"])
	main.open_first()
	assert_eq(main.screen_name, &"loadout")
	assert_eq(main.mode, &"watch")


func test_the_result_opens_on_the_outcome_of_that_siege() -> void:
	var ids := ",".join(SiegeFixtures.WIN_IDS)
	var args := ["--mode=watch", "--screen=result", "--loadout=" + ids, "--seed=4"]
	main.options = LaunchOptions.parse(args)
	main.open_first()
	assert_eq(main.screen_name, &"result")
	assert_eq((main.screen as ResultScreen).outcome, SiegeSim.Outcome.WIN)
	var lose := ",".join(SiegeFixtures.LOSE_IDS)
	main.options = LaunchOptions.parse(["--mode=watch", "--screen=result", "--loadout=" + lose])
	main.options.sim_seed = SiegeFixtures.LOSE_SEED
	main.open_first()
	assert_eq((main.screen as ResultScreen).outcome, SiegeSim.Outcome.LOSE)


func test_the_state_dump_writes_the_screen_on_show() -> void:
	var path := tmp.path_join("state.json")
	assert_true(StateDump.write(main, path))
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(state is Dictionary)
	assert_eq(state["screen"], "hub")
	assert_false(StateDump.write(main, "/proc/nope/state.json"), "an unwritable path says so")


func _constant(name: String) -> String:
	var text := FileAccess.get_file_as_string("res://scripts/lib/handoff.sh")
	var found := RegEx.create_from_string('(?m)^readonly %s="?([^"\n]*)"?$' % name).search(text)
	return found.get_string(1) if found != null else ""


func test_the_hand_off_loadouts_are_the_pinned_fixtures() -> void:
	assert_eq(_constant("WIN_LOADOUT"), ",".join(SiegeFixtures.WIN_IDS))
	assert_eq(_constant("LOSE_LOADOUT"), ",".join(SiegeFixtures.LOSE_IDS))
	assert_eq(_constant("FIXTURE_SEED"), str(SiegeFixtures.WIN_SEED))
	assert_eq(SiegeFixtures.LOSE_SEED, SiegeFixtures.WIN_SEED, "one seed serves both items")


func test_the_result_item_shows_a_win_with_two_stars() -> void:
	var loadout := Loadout.of(Array(_constant("TWO_STAR_LOADOUT").split(",")))
	assert_true(loadout.is_legal())
	var outcome := SiegeSim.create(loadout, SiegeFixtures.WIN_SEED).run_to_end()
	assert_eq(outcome, SiegeSim.Outcome.WIN)
	assert_eq(StarRating.of(outcome, loadout), 2, "one lit, one lit, one waiting with its coins")
