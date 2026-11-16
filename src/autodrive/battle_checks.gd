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
## (FrameMeter also times on the thread's CPU clock for the bots, so a stall
## is not counted in the first place where that clock exists.)
## Canvas-unit squares an order must change on the whole-map view to count as
## seen (FrameDiff): the rally flag, one set of charge or retreat chevrons.
const FLAG_FLOOR := 5000
const CHEVRON_FLOOR := 1500
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
	battle.meter.cpu_clock = FrameMeter.cpu_ms() >= 0.0
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


## Canvas-unit squares of `region` that `layer` adds to the frame: the drawn
## frame minus the frame drawn with the layer hidden. -1 when nothing is
## drawn (headless), which a caller treats as "not measurable".
static func footprint(bot: BotBase, layer: CanvasItem, region: Rect2) -> int:
	var view := bot.get_viewport()
	var with: Image = await bot.shots.grab(view)
	if with == null:
		return -1
	layer.hide()
	var without: Image = await bot.shots.grab(view)
	layer.show()
	var to_window := view.get_final_transform()
	var px := to_window * region
	var count := FrameDiff.changed(with, without, Rect2i(Vector2i(px.position), Vector2i(px.size)))
	return roundi(count / to_window.get_scale().x / to_window.get_scale().y)


## `footprint` against a floor, with the number in the failure.
static func reads_at_a_glance(
	bot: BotBase, layer: CanvasItem, region: Rect2, what: String, floor_px: int
) -> bool:
	var seen := await footprint(bot, layer, region)
	bot.numbers.append("%s=%d" % [what.replace(" ", "_"), seen])
	return bot.check(
		seen < 0 or seen >= floor_px, "%s: %d px of %d changed" % [what, seen, floor_px]
	)
