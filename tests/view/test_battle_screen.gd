extends GutTest
## The battle screen as the player meets it: instant entry, staged beats that
## hold the clock and can be skipped, keys and buttons for every control, a
## click that plants the flag while a drag only pans, and a payoff that is on
## screen before the result opens.


## A real sim whose first snapshot also carries the pre-battle events.
class BeatSim:
	extends SiegeSim
	var inner: SiegeSim
	var opening: Array[Dictionary] = []

	func map() -> SiegeMap:
		return inner.map()

	func step(dt: float) -> void:
		inner.step(dt)

	func command(kind: int, pos: Vector2) -> void:
		inner.command(kind, pos)

	func snapshot() -> SiegeSnapshot:
		var shot := inner.snapshot()
		shot.events.append_array(opening)
		opening = []
		return shot

	func outcome() -> int:
		return inner.outcome()

	func clock_s() -> float:
		return inner.clock_s()

	func state_hash() -> int:
		return inner.state_hash()


func before_each() -> void:
	InputDevice.device = InputDevice.Device.KEYS


func _battle(mode: StringName, ids: Array, sim: SiegeSim = null) -> BattleScreen:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of(ids)
	battle.setup(sim if sim != null else SiegeSim.create(battle.loadout, 5), mode, 1.0)
	add_child_autofree(battle)
	return battle


func _staged() -> BattleScreen:
	var sim := BeatSim.new()
	sim.inner = SiegeSim.create(Loadout.new(), 5)
	sim.opening.append({"kind": SiegeEvent.UFO_ABDUCT, "pos": sim.map().village_center})
	sim.opening.append({"kind": SiegeEvent.PEP_TALK, "pos": sim.map().army_spawn})
	return _battle(&"watch", [], sim)


func _mouse(button: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	return event


func _click(battle: BattleScreen, at: Vector2) -> void:
	battle._gui_input(_mouse(MOUSE_BUTTON_LEFT, true, at))
	battle._gui_input(_mouse(MOUSE_BUTTON_LEFT, false, at))


func test_entering_the_screen_is_instant_and_draws_every_head() -> void:
	var battle := _battle(&"watch", [&"double_men", &"fifty_men"])
	assert_lt(battle.setup_ms, 1000.0, "the transition is under a second (%s ms)" % battle.setup_ms)
	assert_eq(battle.crowd.figures(), 2300)
	assert_eq(battle.shot.entity_count(), battle.crowd.squads.size())
	var built := FigureLibrary.builds
	var made := battle.crowd.allocations
	await wait_frames(20)
	assert_eq(FigureLibrary.builds, built, "no figure is built after the screen is up")
	assert_eq(battle.crowd.allocations, made)
	assert_gt(battle.meter.frames, 10, "the screen measures its own work every frame")
	assert_gt(battle.shot.clock_s, 0.0, "and the siege runs")
	var point := Vector2(200, 150)
	assert_almost_eq(battle.canvas_to_map(battle.map_to_canvas(point)), point, Vector2(0.01, 0.01))
	assert_eq(battle.pick_at(battle.map_to_canvas(battle.shot.ent_pos[0]))["kind"], "entity")


func test_the_army_wears_what_the_loadout_bought() -> void:
	var battle := _battle(&"watch", [&"knight_armor", &"booze"])
	assert_true(battle.crowd.look.knight)
	assert_true(battle.crowd.look.booze)
	battle.dress(Loadout.of([&"cardboard_armor"]))
	assert_true(battle.crowd.look.cardboard)
	assert_false(battle.crowd.look.knight)


func test_staged_beats_hold_the_clock_and_can_be_skipped() -> void:
	var battle := _staged()
	await wait_frames(4)
	assert_eq(battle.beats.current["kind"], SiegeEvent.UFO_ABDUCT, "the night before comes first")
	assert_eq(battle.sim.clock_s(), 0.0, "the siege has not begun")
	assert_true(battle.hud.skip_button.is_visible_in_tree(), "the way to skip is on screen")
	assert_false(battle.hud.pause_button.is_visible_in_tree())
	assert_eq(battle.effects.live[0].kind, SiegeEvent.UFO_ABDUCT)
	assert_false(battle.camera.auto and battle.camera.zoom < 3.0, "the camera goes to the beat")
	InputSynth.key_tap(KEY_SPACE)
	await wait_frames(3)
	assert_eq(battle.beats.current["kind"], SiegeEvent.PEP_TALK, "skipped to the next beat")
	assert_eq(battle.effects.live.size(), 1, "the skipped beat left the stage")
	assert_eq(battle.sim.clock_s(), 0.0)
	_click(battle, Vector2(900, 500))
	await wait_frames(3)
	assert_false(battle.beats.staging(), "a tap skips too")
	await wait_until(func() -> bool: return battle.sim.clock_s() > 0.0, 2.0)
	assert_gt(battle.sim.clock_s(), 0.0, "now the siege runs")
	assert_false(battle.hud.skip_button.is_visible_in_tree())
	assert_false(battle.held, "the skip key did not also pause")


func test_a_beat_ends_by_itself() -> void:
	var battle := _staged()
	await wait_frames(2)
	battle.beats.update(BattleEffects.life_of(SiegeEvent.UFO_ABDUCT) + 0.1)
	await wait_frames(2)
	assert_eq(battle.beats.current["kind"], SiegeEvent.PEP_TALK)
	battle.hud.skip_button.pressed.emit()
	assert_false(battle.beats.staging(), "the skip button works as well")


func test_space_holds_the_siege_and_number_keys_pick_the_speed() -> void:
	var battle := _battle(&"watch", [])
	await wait_frames(3)
	InputSynth.key_tap(KEY_SPACE)
	var frozen := battle.sim.clock_s()
	assert_true(battle.held)
	await wait_frames(5)
	assert_eq(battle.sim.clock_s(), frozen, "held: the clock stands still")
	battle.hud.pause_button.pressed.emit()
	assert_false(battle.held, "the button releases it")
	for i in 4:
		InputSynth.key_tap([KEY_1, KEY_2, KEY_3, KEY_4][i])
		assert_eq(battle.speed, [1.0, 2.0, 4.0, 8.0][i])
	battle.hud.speed_buttons[1].pressed.emit()
	assert_eq(battle.speed, 2.0)
	battle._gui_input(_mouse(MOUSE_BUTTON_WHEEL_UP, true, Vector2(900, 500)))
	assert_false(battle.camera.auto, "the wheel takes the camera")
	InputSynth.key_tap(KEY_0)
	assert_true(battle.camera.auto, "0 gives it back")
	battle._gui_input(_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2(900, 500)))
	battle.hud.auto_button.pressed.emit()
	assert_true(battle.camera.auto, "so does the button")


func test_a_click_plants_the_flag_and_a_drag_only_pans() -> void:
	var battle := _battle(&"command", [])
	await wait_frames(2)
	watch_signals(battle)
	var spot := Vector2(900, 500)
	var on_map := battle.canvas_to_map(spot)
	_click(battle, spot)
	assert_eq(battle.commands_sent, 1)
	assert_almost_eq(battle.effects.rally, on_map, Vector2(0.01, 0.01), "the flag is up at once")
	assert_signal_emitted_with_parameters(battle, "command_given", [SiegeSim.Command.RALLY, on_map])
	var before := battle.camera.center
	battle._gui_input(_mouse(MOUSE_BUTTON_LEFT, true, spot))
	var drag := InputEventMouseMotion.new()
	drag.position = spot + Vector2(-80, 0)
	drag.relative = Vector2(-80, 0)
	battle._gui_input(drag)
	battle._gui_input(_mouse(MOUSE_BUTTON_LEFT, false, spot + Vector2(-80, 0)))
	assert_eq(battle.commands_sent, 1, "a drag gives no order")
	assert_gt(battle.camera.center.x, before.x, "it moved the map")
	assert_false(battle.camera.auto)


func test_orders_have_keys_buttons_and_a_pad() -> void:
	var battle := _battle(&"command", [])
	await wait_frames(2)
	InputSynth.key_tap(KEY_ENTER)
	InputSynth.key_tap(KEY_BACKSPACE)
	assert_eq(battle.commands_sent, 2, "Enter charges, Backspace retreats")
	assert_false(battle.effects.has_rally())
	battle.charge_button.pressed.emit()
	battle.retreat_button.pressed.emit()
	assert_eq(battle.commands_sent, 4)
	InputSynth.pad_tap(JOY_BUTTON_A)
	assert_eq(battle.commands_sent, 5, "the pad plants the flag in the middle of the view")
	assert_true(battle.effects.has_rally())
	var seen := battle.effects.live.size()
	battle.hud.rally_button.pressed.emit()
	assert_eq(battle.commands_sent, 5, "the rally button only shows where to click")
	assert_gt(battle.effects.live.size(), seen)
	var watch := _battle(&"watch", [])
	await wait_frames(2)
	InputSynth.key_tap(KEY_ENTER)
	_click(watch, Vector2(900, 500))
	assert_eq(watch.commands_sent, 0, "Watch mode gives no orders")
	assert_null(watch.charge_button)


func test_the_win_payoff_shows_the_flag_before_the_result() -> void:
	var battle := _battle(&"watch", [&"double_men", &"fifty_men"])
	battle.speed = 400.0
	battle.payoff_s = 0.4
	watch_signals(battle)
	await wait_until(func() -> bool: return battle.payoff_active, 10.0)
	assert_signal_emitted(battle, "decided")
	assert_signal_not_emitted(battle, "finished")
	assert_true(battle.effects.flag_up, "the flag goes up on the church")
	assert_true(battle.camera.auto, "the camera is the director's now")
	await wait_frames(3)
	assert_gt(battle.payoff_progress(), 0.0)
	_click(battle, Vector2(900, 500))
	assert_eq(battle.commands_sent, 0, "no orders after the decision")
	await wait_until(func() -> bool: return not battle.payoff_active, 5.0)
	assert_signal_emitted_with_parameters(battle, "finished", [SiegeSim.Outcome.WIN])
	assert_almost_eq(battle.payoff_progress(), 1.0, 0.001)


func test_the_lose_payoff_sets_the_army_on_fire() -> void:
	var battle := _battle(&"watch", [&"stew"])
	battle.speed = 400.0
	watch_signals(battle)
	await wait_until(func() -> bool: return battle.payoff_active, 10.0)
	for squad in battle.crowd.squads:
		assert_eq(squad.burning, squad.team == SiegeSnapshot.Team.ARMY)
	assert_false(battle.effects.flag_up)
	assert_signal_not_emitted(battle, "finished")


func test_a_headless_window_still_draws_full_figures_up_close() -> void:
	var battle := _battle(&"watch", [&"stew"])
	battle.camera.hold(Rect2(0, 0, 40, 25))
	await wait_frames(3)
	assert_eq(DisplayServer.get_name(), "headless", "GUT runs headless")
	assert_eq(battle._pixel_scale(), 1.0, "a 0x0 window has no pixel scale to use")
	assert_false(battle.crowd.far, "a 40 m view of the field shows the full figures")
