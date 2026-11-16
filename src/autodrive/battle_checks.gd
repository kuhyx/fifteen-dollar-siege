class_name BattleChecks
extends RefCounted
## Asserts on the battle screen that every bot shares: the payoff is on
## screen before the result, the HUD is whole, and the frame gate.

## Part of the payoff that must have played before its frame is taken
## (lesson L13): the camera has turned and the flag is up, or the flames are.
const PAYOFF_SEEN := 0.6
## The frame gate: up to TRIES windows; a window passes when no frame's own
## work went over FrameStats.WORK_BUDGET_MS. A stall the machine causes
## (another process on the core) does not come back in the next window; a
## cost of the game's own does.
const TRIES := 3
## Entering the screen may take this long, whole [lesson L9: under 1 s].
const ENTER_BUDGET_MS := 1000.0


## Waits until the payoff has played PAYOFF_SEEN of its time. True when the
## battle screen is still up then: the frame taken next shows the payoff.
static func payoff_seen(bot: BotBase, battle: BattleScreen) -> bool:
	var played := func() -> bool:
		return battle.payoff_progress() >= PAYOFF_SEEN or bot.main.screen != battle
	await bot.wait_for(played, 900, "the payoff to play")
	return bot.main.screen == battle and battle.payoff_active


## Every HUD control lies inside the viewport, shows a pictogram, speaks a
## label and (lesson L6) never shows the placeholder key.
static func hud_ok(bot: BotBase, battle: BattleScreen) -> bool:
	var buttons := battle.hud.buttons()
	for action: StringName in buttons:
		var button := buttons[action] as HudButton
		if not button.is_visible_in_tree():
			continue
		var whole := bot.inside(button, "the %s button" % action)
		var plain := button.text == "" and button.accessibility_name != "" and button.icon != null
		if not (whole and bot.check(plain, "%s must be a labelled pictogram" % action)):
			return false
		if not bot.check(not button.badge_unknown, "%s shows the placeholder key" % action):
			return false
	return bot.check(battle.setup_ms < ENTER_BUDGET_MS, "entering took %.0f ms" % battle.setup_ms)


## The frame gate (lessons L7, L12): over `frames` frames after the screen
## is up, no frame's own work is over budget, no figure is built and no
## MultiMesh is allocated. Returns the worst frame in ms (-1 on failure).
static func smooth(bot: BotBase, battle: BattleScreen, frames: int) -> float:
	var built := FigureLibrary.builds
	var made := battle.crowd.allocations
	var problem := ""
	for attempt in TRIES:
		battle.meter.reset()
		await bot.frames(frames)
		problem = FrameStats.budget_problem(battle.meter.worst_ms, battle.meter.frames)
		if problem == "":
			break
	var lazy := FigureLibrary.builds - built + battle.crowd.allocations - made
	var steady := bot.check(
		lazy == 0 or battle.payoff_active, "%d things made on first sight" % lazy
	)
	return battle.meter.worst_ms if bot.check(problem == "", problem) and steady else -1.0
