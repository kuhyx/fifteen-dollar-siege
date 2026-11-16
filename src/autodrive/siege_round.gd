class_name SiegeRound
extends RefCounted
## The autodrive bot's beats on the battle screen (autodrive.gd calls them):
## the staged beats before the first tick (seen, then skipped), the HUD, the
## orders of Command mode, the pause, the frame gate, the payoff frame taken
## BEFORE the result opens (lesson L13) and the result's own controls.

const DECIDE_LIMIT_FRAMES := 6000
## Frames of a siege the frame gate judges (BattleChecks.smooth).
const SMOOTH_FRAMES := 40
## Frames a staged beat plays before the bot takes its frame.
const BEAT_LOOK_FRAMES := 20
## Where the burst rallies: the point tools/sim/bot_orders.gd pins the fixtures
## with (shipped code never preloads tools/sim, so the number is repeated).
const BURST_RALLY_AT := Vector2(200.0, 90.0)
## Frames the camera takes to turn to what an order changed.
const CAMERA_SETTLE_FRAMES := 30


## One siege of this mode to its result screen. `bot.hashes` gets the state hash.
static func play(bot: Autodrive, wins: bool, mode: StringName) -> bool:
	var tag := "win" if wins else "lose"
	if not await bot.on_screen(&"battle"):
		return false
	var battle := bot.main.screen as BattleScreen
	var men := 0
	for i in battle.shot.entity_count():
		if battle.shot.ent_team[i] == SiegeSnapshot.Team.ARMY:
			men += battle.shot.ent_count[i]
	var ok := await staged_beats(bot, battle, tag)
	var commander := BotCommander.new() if wins and mode == &"command" else null
	await bot.frames(20)
	ok = (
		ok
		and bot.check(men == SiegeSim.army_size(bot.main.loadout), "the army has %d men" % men)
		and await bot.shot("battle_" + tag)
		and BattleChecks.hud_ok(bot, battle)
		and (mode != &"command" or await give_orders(bot, battle, commander))
		and (not wins or await pause_freezes(bot, battle))
		and await _smooth(bot, battle)
	)
	return ok and await to_result(bot, battle, wins, commander)


## The frame gate at the bot's speed; the worst frame goes on the RESULT line.
static func _smooth(bot: BotBase, battle: BattleScreen) -> bool:
	var worst := await BattleChecks.smooth(bot, battle, SMOOTH_FRAMES)
	bot.numbers.append("work_worst_ms_x%d=%.2f" % [int(battle.speed), worst])
	return worst >= 0.0


## The beats before the first tick: each is on stage while the clock stands
## still, shown in a frame, then cut short by the skip key.
static func staged_beats(bot: BotBase, battle: BattleScreen, tag: String) -> bool:
	while battle.beats.staging():
		var playing := func() -> bool: return not battle.beats.current.is_empty()
		if not await bot.wait_for(playing, 300, "a staged beat to start"):
			return false
		var kind: StringName = battle.beats.current["kind"]
		await bot.frames(BEAT_LOOK_FRAMES)
		var ok := (
			bot.check(is_zero_approx(battle.sim.clock_s()), "the clock stands still in a beat")
			and bot.check(battle.beats.current.get("kind") == kind, "the beat plays %s" % kind)
			and await bot.shot("beat_%s_%s" % [kind, tag])
		)
		if not ok:
			return false
		InputSynth.key_tap(KEY_SPACE)
		await bot.frames(3)
	return true


## Waits for the decision (giving the commander's orders as they fall due),
## takes the payoff frame BEFORE any result UI opens (lesson L13), then plays
## the result screen's own payoff and controls.
static func to_result(
	bot: Autodrive, battle: BattleScreen, wins: bool, commander: BotCommander
) -> bool:
	var tag := "win" if wins else "lose"
	var want := SiegeSim.Outcome.WIN if wins else SiegeSim.Outcome.LOSE
	for frame in DECIDE_LIMIT_FRAMES:
		if battle.sim.outcome() != SiegeSim.Outcome.RUNNING:
			break
		if commander != null and not await _advise(bot, battle, commander):
			return false
		await bot.frames(1)
	if not bot.check(battle.sim.outcome() != SiegeSim.Outcome.RUNNING, "the siege was decided"):
		return false
	bot.hashes.append(str(battle.sim.state_hash()))
	var showing: bool = await BattleChecks.payoff_seen(bot, battle)
	var ok := (
		bot.check(battle.sim.outcome() == want, "the siege ends in %s" % tag)
		and bot.check(showing, "the payoff shows before the result")
		and bot.check(_delights_fired(battle, wins), "the fun pass's delights fired in a %s" % tag)
		and await bot.shot("payoff_" + tag)
		and await bot.on_screen(&"result")
	)
	return ok and await MenuBeats.result(bot, wins, want, bot.main.loadout.ids)


## The fun pass's delights (DOCS-design-fun.md) that every real siege must
## show: pops where heads fell, the tally bell and the finale at a win, the
## heartbeat edge at a loss.
static func _delights_fired(battle: BattleScreen, wins: bool) -> bool:
	var seen := battle.effects.seen
	if wins:
		return (
			int(seen.get(&"pop", 0)) > 0
			and int(seen.get(&"toll", 0)) > 0
			and int(seen.get(&"firework", 0)) >= 2
		)
	return int(seen.get(&"pop", 0)) > 0 and battle.hud.edge.beats > 0


## Command mode. A won siege is played by the commander (rally, charge, and a
## retreat when the men are worn down), every order through the real controls;
## the first one is given now. A lost one gets the three controls in a burst.
static func give_orders(bot: BotBase, battle: BattleScreen, commander: BotCommander) -> bool:
	if commander != null:
		return await _advise(bot, battle, commander)
	return (
		await _perform(bot, battle, {"kind": SiegeSim.Command.RALLY, "pos": BURST_RALLY_AT})
		and await bot.shot("rally")
		and await _perform(bot, battle, {"kind": SiegeSim.Command.RETREAT, "pos": Vector2.ZERO})
		and await bot.shot("retreat")
		and await _perform(bot, battle, {"kind": SiegeSim.Command.CHARGE, "pos": Vector2.ZERO})
	)


## Asks the commander; gives the order it names through the controls.
static func _advise(bot: BotBase, battle: BattleScreen, commander: BotCommander) -> bool:
	var order := commander.advise(battle.shot, battle.sim.map())
	if order.is_empty():
		return true
	var first := battle.commands_sent == 0
	if not await _perform(bot, battle, order):
		return false
	if not (first or order["kind"] == SiegeSim.Command.CHARGE):
		return true
	await bot.frames(CAMERA_SETTLE_FRAMES)  # the camera turns to what changed
	return await bot.shot("rally" if first else "charge")


## One order by its control: a click on the map for the rally flag, the
## button for charge and retreat. The flag is planted and the order's own
## effect appears on screen.
static func _perform(bot: BotBase, battle: BattleScreen, order: Dictionary) -> bool:
	var sent := battle.commands_sent
	var kind: int = order["kind"]
	if kind == SiegeSim.Command.RALLY:
		var at := battle.map_to_canvas(order["pos"])
		var clear := Rect2(Vector2.ZERO, battle.size).grow(-BattleHud.BOTTOM_CLEAR)
		if clear.has_point(at):
			await bot.click_at(at)
		else:
			battle.order(kind, order["pos"])
	else:
		await bot.click(
			battle.charge_button if kind == SiegeSim.Command.CHARGE else battle.retreat_button
		)
	await bot.frames(6)
	var seen := int(battle.effects.seen.get(SiegeEvent.COMMAND, 0))
	return (
		bot.check(battle.commands_sent == sent + 1, "order %d reaches the sim" % kind)
		and bot.check(seen >= battle.commands_sent, "the order shows as an effect")
		and (
			bot
			. check(
				(
					kind != SiegeSim.Command.RALLY
					or battle.effects.rally.distance_to(order["pos"]) < 1.0
				),
				"the rally flag stands where it was sent",
			)
		)
	)


## Esc mid-battle: the menu is up and the sim clock stands still.
static func pause_freezes(bot: BotBase, battle: BattleScreen) -> bool:
	await bot.press_escape()
	var before := battle.sim.clock_s()
	await bot.frames(10)
	var frozen := bot.main.pause_menu.is_open() and is_equal_approx(battle.sim.clock_s(), before)
	if (
		not bot.check(frozen, "the pause menu freezes the siege")
		or not await bot.shot("pause_battle")
	):
		return false
	await bot.press_escape()
	await bot.frames(5)
	return bot.check(battle.sim.clock_s() > before, "the siege runs again after the menu closes")
