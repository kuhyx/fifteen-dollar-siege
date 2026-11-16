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
	await bot.frames(20)
	ok = (
		ok
		and bot.check(men == SiegeSim.army_size(bot.main.loadout), "the army has %d men" % men)
		and await bot.shot("battle_" + tag)
		and BattleChecks.hud_ok(bot, battle)
		and (mode != &"command" or await give_orders(bot, battle))
		and (not wins or await pause_freezes(bot, battle))
		and await BattleChecks.smooth(bot, battle, SMOOTH_FRAMES) >= 0.0
	)
	return ok and await to_result(bot, battle, wins)


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


## Waits for the decision, takes the payoff frame BEFORE any result UI opens
## (lesson L13), then plays the result screen's own payoff and controls.
static func to_result(bot: Autodrive, battle: BattleScreen, wins: bool) -> bool:
	var tag := "win" if wins else "lose"
	var want := SiegeSim.Outcome.WIN if wins else SiegeSim.Outcome.LOSE
	var decided := func() -> bool: return battle.sim.outcome() != SiegeSim.Outcome.RUNNING
	if not await bot.wait_for(decided, DECIDE_LIMIT_FRAMES, "the siege to be decided"):
		return false
	bot.hashes.append(str(battle.sim.state_hash()))
	var showing: bool = await BattleChecks.payoff_seen(bot, battle)
	var ok := (
		bot.check(battle.sim.outcome() == want, "the siege ends in %s" % tag)
		and bot.check(showing, "the payoff shows before the result")
		and await bot.shot("payoff_" + tag)
		and await bot.on_screen(&"result")
	)
	return ok and await MenuBeats.result(bot, wins, want, bot.main.loadout.ids)


## Command mode: a rally click on the map, then retreat and charge buttons.
static func give_orders(bot: BotBase, battle: BattleScreen) -> bool:
	await bot.click_at(battle.camera.view.get_center() + Vector2(0.0, -120.0))
	if not bot.check(battle.commands_sent == 1, "a map click places the rally flag"):
		return false
	await bot.frames(20)
	if not await bot.shot("rally"):
		return false
	await bot.click(battle.retreat_button)
	await bot.click(battle.charge_button)
	return bot.check(battle.commands_sent == 3, "retreat and charge reach the sim")


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
