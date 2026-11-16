class_name TouchBot
extends BotBase
## The --autodrive=touch bot (R17): a phone player's whole loop with ONLY
## touch events. Hub -> shop (a first tap looks, a second buys) -> go ->
## Command battle (plant a rally flag, change the speed, pause, resume, the
## menu button and resume) -> the payoff skipped by a tap -> result -> the
## same loadout again. It counts every key, pad and real-mouse event that
## reaches the game and fails when there is even one: the taps are the
## engine's own touch events (InputSynth.touch_tap), the mouse clicks the
## engine makes from them are emulated and allowed.

const BUYS: Array[StringName] = [&"double_men", &"fifty_men", &"knight_armor", &"pep_talk"]
const WAIT_FRAMES := 6000
const SPEED_TAKEN := 4.0

## Events that were not a touch (or the mouse the engine makes from one).
var foreign := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	var real_mouse := mouse != null and mouse.device != InputEvent.DEVICE_ID_EMULATION
	if event is InputEventKey or event is InputEventJoypadButton or real_mouse:
		foreign += 1


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	await frames(3)
	var options := main.options
	var window := BotReport.window_problem(options.expect_window, DisplayServer.window_get_size())
	var may_run := (
		check(BotReport.save_dir_problem(options.save_dir) == "", "no throwaway --save-dir")
		and check(options.unknown.is_empty(), "unknown arguments: %s" % [options.unknown])
		and check(window == "", window)
	)
	if may_run:
		await _play()
	check(foreign == 0, "%d events that were not touch reached the game" % foreign)
	finish("mode=touch frames=%d foreign=%d" % [shots.count, foreign])


func _play() -> void:
	var ok := (
		await on_screen(&"hub")
		and await _tap_control(
			(main.screen as HubScreen).buttons[&"command"], &"loadout", "the command button"
		)
		and await _buy()
		and await _fight()
		and await _again()
	)
	if ok:
		await _home()


## A finger on the middle of `control`.
func tap(control: Control) -> void:
	InputSynth.touch_tap(control.get_global_rect().get_center())
	await frames(3)


func tap_at(canvas_point: Vector2) -> void:
	InputSynth.touch_tap(canvas_point)
	await frames(3)


func _tap_control(control: Control, goes_to: StringName, what: String) -> bool:
	await tap(control)
	return check(await on_screen(goes_to), "a tap on %s opens %s" % [what, goes_to])


func _buy() -> bool:
	var shop := main.screen as LoadoutScreen
	for id in BUYS:
		await tap(shop.cards[id])
		var looked := shop.focused_id == id and not shop.loadout.has(id)
		if not check(looked, "a first tap on %s only shows it" % id):
			return false
		await tap(shop.cards[id])
		if not check(shop.loadout.has(id), "a second tap buys %s" % id):
			return false
	await MenuBeats.settled(self, shop)
	if not (check(shop.loadout.is_legal(), "within the budget") and await shot("touch_shop")):
		return false
	return await _tap_control(shop.go_button, &"battle", "go")


## Plant a rally flag, speed up, pause, resume, the menu button and back.
func _fight() -> bool:
	var battle := main.screen as BattleScreen
	await frames(20)
	return await _rally(battle) and await _pause_resume(battle) and await _menu(battle)


func _rally(battle: BattleScreen) -> bool:
	await tap_at(battle.camera.view.get_center() + Vector2(0.0, -120.0))
	return (
		check(battle.commands_sent == 1, "a tap on the map plants the rally flag")
		and check(battle.effects.has_rally(), "and the flag stands")
		and await shot("touch_rally")
	)


func _pause_resume(battle: BattleScreen) -> bool:
	await tap(battle.hud.speed_buttons[2])
	var started := battle.sim.clock_s()
	var picked := is_equal_approx(battle.speed, SPEED_TAKEN)
	await tap(battle.hud.pause_button)
	var frozen := battle.sim.clock_s()
	await frames(10)
	var paused := battle.held and is_equal_approx(frozen, battle.sim.clock_s())
	await tap(battle.hud.pause_button)
	await frames(10)
	var runs := not battle.held and battle.sim.clock_s() > frozen
	return (
		check(picked, "a tap picks the speed")
		and check(paused, "a tap pauses")
		and check(runs and frozen >= started, "a second tap resumes")
		and check(not battle.hud.pause_button.has_badge(), "a touch screen shows no key badge")
	)


func _menu(battle: BattleScreen) -> bool:
	await tap(main.menu_button)
	var opened := main.pause_menu.is_open() and await shot("touch_menu")
	if not check(opened, "the menu button opens the pause menu"):
		return false
	await tap(main.pause_menu.buttons["resume"])
	return check(not main.pause_menu.is_open() and not battle.held, "a tap on resume closes it")


## The siege ends; a tap after the first look skips the payoff; the result's
## "again" fights the same loadout.
func _again() -> bool:
	var battle := main.screen as BattleScreen
	await tap(battle.hud.speed_buttons[3])
	var decided := func() -> bool: return battle.sim.outcome() != SiegeSim.Outcome.RUNNING
	if not await wait_for(decided, WAIT_FRAMES, "the siege to be decided"):
		return false
	await frames(ceili(BattleBeats.SKIP_AFTER_S * 60.0) + 2)
	await tap_at(Vector2(960.0, 540.0))
	if not (await on_screen(&"result") and await shot("touch_result")):
		return false
	var result := main.screen as ResultScreen
	if not check(result.controls_shown, "the controls are up for a finger"):
		return false
	await tap(result.retry_button)
	var again := await on_screen(&"battle") and main.loadout.ids == Loadout.of(BUYS).ids
	return check(again, "a tap on again fights the same loadout")


func _home() -> void:
	await tap(main.menu_button)
	await tap(main.pause_menu.buttons["hub"])
	check(await on_screen(&"hub"), "a tap on the hub button goes home")
