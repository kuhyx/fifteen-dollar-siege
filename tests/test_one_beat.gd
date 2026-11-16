extends GutTest
## The payoff and the result are ONE beat: the battle plays the flag or the
## flames once, any press after a short look skips ahead, and the result
## screen opens with its controls already up on the end state of the same
## scene (nothing is played twice). An impatient player can fight the same
## loadout again in under a second after the siege is decided.

const IMPATIENT_S := 1.0

var main: Main


func before_each() -> void:
	SaveStore.clear()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.options.speed = 32.0
	main.options.sim_seed = 5
	main.mode = &"watch"
	main.start_siege(Loadout.of([&"double_men", &"fifty_men"]))


func after_each() -> void:
	get_tree().paused = false


func _press(code: Key) -> void:
	InputSynth.key_tap(code)
	await wait_frames(2)


func test_a_press_during_the_look_does_nothing_yet() -> void:
	var battle := main.screen as BattleScreen
	await wait_until(func() -> bool: return battle.payoff_active, 20.0)
	await _press(KEY_ENTER)
	assert_true(battle.payoff_active, "the first moments are for looking")
	assert_eq(main.screen_name, &"battle")


func test_any_press_after_the_look_skips_to_the_result() -> void:
	var battle := main.screen as BattleScreen
	await wait_until(func() -> bool: return battle.payoff_active, 20.0)
	await wait_seconds(BattleBeats.SKIP_AFTER_S + 0.1)
	assert_eq(main.screen_name, &"battle", "the payoff is still playing")
	await _press(KEY_ENTER)
	assert_eq(main.screen_name, &"result", "one press and the result is up")


func test_the_result_has_its_controls_at_once_on_the_end_state() -> void:
	main.open_result(SiegeSim.Outcome.WIN)
	var screen := main.screen as ResultScreen
	await wait_frames(2)
	assert_true(screen.controls_shown, "no second payoff before the controls")
	assert_gte(screen.scene_age(), ResultScene.SETTLED_S, "the flag is already up")
	main.open_result(SiegeSim.Outcome.LOSE)
	await wait_frames(2)
	assert_gte((main.screen as ResultScreen).scene_age(), ResultScene.SETTLED_S)


func test_the_same_loadout_again_is_one_press_away() -> void:
	var battle := main.screen as BattleScreen
	await wait_until(func() -> bool: return battle.payoff_active, 20.0)
	var started := Time.get_ticks_msec()
	await wait_seconds(BattleBeats.SKIP_AFTER_S + 0.05)
	await _press(KEY_ENTER)
	var screen := main.screen as ResultScreen
	assert_not_null(screen)
	screen.retry_button.pressed.emit()
	await wait_frames(2)
	assert_eq(main.screen_name, &"battle", "and the siege starts again")
	assert_eq(main.loadout.ids, Loadout.of([&"double_men", &"fifty_men"]).ids)
	assert_lt((Time.get_ticks_msec() - started) / 1000.0, IMPATIENT_S, "under a second")


func test_the_press_that_skips_does_not_click_a_result_button() -> void:
	var battle := main.screen as BattleScreen
	await wait_until(func() -> bool: return battle.payoff_active, 20.0)
	await wait_seconds(BattleBeats.SKIP_AFTER_S + 0.1)
	var spot := Vector2(960.0, 940.0)  # where the result's controls will be
	InputSynth.canvas_tap(MOUSE_BUTTON_LEFT, spot)
	await wait_frames(3)
	assert_eq(main.screen_name, &"result", "the click skipped the payoff and nothing more")
