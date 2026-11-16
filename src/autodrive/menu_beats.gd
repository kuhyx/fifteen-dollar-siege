class_name MenuBeats
extends RefCounted
## The autodrive bot's beats on the menu-side screens (autodrive.gd calls
## them): the shop tour (hover a card for its vignette, buy, sell, touch), the
## refused buy, the result's payoff and its three controls, the Lab's batch,
## ranking and controls. Every beat asserts what it claims and takes a shot.

const TOUR_BUFF := &"wasps"
const TOUCH_BUFF := &"moose"
const WAIT_FRAMES := 6000


## The empty shop, a hovered card's vignette, a buy caught with its coins in
## the air, the sell, and the same by touch (tap looks, the second tap buys).
static func shop_tour(bot: BotBase, shop: LoadoutScreen) -> bool:
	var card := shop.cards[TOUR_BUFF] as BuffCard
	var empty := shop.loadout.ids.is_empty() and shop.tray.coins == Loadout.BUDGET
	if not await settled(bot, shop) or not bot.check(empty, "the shop opens with 15 coins"):
		return false
	if not await bot.shot("shop_empty"):
		return false
	InputSynth.canvas_motion(Vector2(4, 4), card.get_global_rect().get_center())
	await bot.frames(45)
	var stage := shop.preview.stage
	var playing := shop.focused_id == TOUR_BUFF and stage.buff == TOUR_BUFF and stage.time > 0.3
	if (
		not bot.check(playing, "a hovered card plays its vignette")
		or not await bot.shot("shop_vignette")
	):
		return false
	await bot.click(card)
	await bot.frames(4)
	var flying := shop.loadout.has(TOUR_BUFF) and shop.flight.in_air() > 0
	if not bot.check(flying, "a buy sends coins flying") or not await bot.shot("shop_midbuy"):
		return false
	var paid := await settled(bot, shop) and card.coins_in == card.def.price
	if not bot.check(paid and shop.tray.coins == 10, "the coins land in the card"):
		return false
	await bot.click(card)
	var back := await settled(bot, shop) and shop.tray.coins == Loadout.BUDGET
	if not bot.check(back and not shop.loadout.has(TOUR_BUFF), "a second click sells it back"):
		return false
	return await _touch(bot, shop)


## The over-budget click just made: the tray shakes, nothing was bought.
static func refusal(bot: BotBase, shop: LoadoutScreen, id: StringName) -> bool:
	var refused := shop.tray.is_shaking() and not shop.loadout.has(id)
	return (
		bot.check(refused, "a buy over the budget shakes the tray")
		and await bot.shot("shop_refusal")
	)


## Waits until every coin has landed and the tray stands still.
static func settled(bot: BotBase, shop: LoadoutScreen) -> bool:
	var still := func() -> bool: return shop.flight.in_air() == 0 and not shop.tray.is_shaking()
	return await bot.wait_for(still, 300, "the coins to land")


## The result: the payoff alone first, then the controls. A win goes on with
## "change the loadout" (the shop opens with it); a loss with "again" (the
## same loadout fights once more), then home.
static func result(bot: BotBase, wins: bool, want: int, ids: Array[StringName]) -> bool:
	var tag := "win" if wins else "lose"
	var screen := bot.main.screen as ResultScreen
	var alone := screen.outcome == want and not screen.controls_shown
	if not bot.check(alone, "the %s payoff plays before any control" % tag):
		return false
	await bot.frames(40)
	if not await bot.shot("result_" + tag) or not await _controls_up(bot, screen, tag):
		return false
	if wins:
		await bot.click(screen.edit_button)
		var shop_open := await bot.on_screen(&"loadout")
		var kept := shop_open and (bot.main.screen as LoadoutScreen).loadout.ids == ids
		return bot.check(kept, "edit opens the shop with the same loadout")
	await bot.click(screen.retry_button)
	var again := await bot.on_screen(&"battle") and bot.main.loadout.ids == ids
	if (
		not bot.check(again, "retry fights again with the same loadout")
		or not await bot.shot("retry")
	):
		return false
	var over := func() -> bool: return bot.main.screen_name == &"result"
	if not await bot.wait_for(over, WAIT_FRAMES, "the retried siege to end"):
		return false
	screen = bot.main.screen as ResultScreen
	var up := func() -> bool: return screen.controls_shown
	if not await bot.wait_for(up, 300, "the controls after the retry"):
		return false
	await bot.click(screen.home_button)
	return await bot.on_screen(&"hub")


## The Lab mid-batch: some ticks are on show, not all, and nothing froze.
static func lab_running(bot: BotBase, lab: LabScreen, tag: String) -> bool:
	var started := func() -> bool: return lab.shown_runs > 0
	if not await bot.wait_for(started, 300, "the first lab tick"):
		return false
	var partly := lab.shown_runs < lab.total_runs and lab.ticks.shown == lab.shown_runs
	return (
		bot.check(partly, "the lab shows its batch arriving")
		and await bot.shot("lab_running_" + tag)
	)


## The finished Lab: every tick on show and the loadout in the ranking.
static func lab_ranked(bot: BotBase, lab: LabScreen, wins: bool) -> bool:
	var all := func() -> bool: return lab.shown_runs == lab.total_runs
	if not await bot.wait_for(all, 600, "every lab tick"):
		return false
	var lines := lab.ranking.lines
	var listed := lines.size() == (1 if wins else 2) and lab.ranking.places().size() == lines.size()
	var first: bool = not lines.is_empty() and lines[0]["rate"] >= lines[-1]["rate"]
	return (
		bot.check(listed and first, "the lab ranks the loadouts tried: %s" % [lines])
		and bot.all_inside(lab.controls.buttons(), "lab control")
	)


## Leaves the Lab: a win by "change the loadout", a loss by "again" (a second
## batch of the same loadout), then home.
static func lab_leave(bot: BotBase, lab: LabScreen, wins: bool) -> bool:
	if wins:
		await bot.click(lab.controls.edit)
		return await bot.on_screen(&"loadout")
	await bot.click(lab.controls.again)
	if not await bot.on_screen(&"lab"):
		return false
	var second := bot.main.screen as LabScreen
	var done := func() -> bool: return second.done
	var ran := second != lab and await bot.wait_for(done, WAIT_FRAMES, "the second lab batch")
	if not bot.check(ran, "again runs a new batch of the same loadout"):
		return false
	await bot.click(second.home_button)
	return await bot.on_screen(&"hub")


static func _controls_up(bot: BotBase, screen: ResultScreen, tag: String) -> bool:
	var up := func() -> bool: return screen.controls_shown
	return (
		await bot.wait_for(up, 300, "the result controls")
		and bot.all_inside(screen.controls.buttons(), "result control")
		and await bot.shot("result_%s_controls" % tag)
	)


## A finger: the first tap only shows the card, the second buys, a third sells.
static func _touch(bot: BotBase, shop: LoadoutScreen) -> bool:
	var at := (shop.cards[TOUCH_BUFF] as Control).get_global_rect().get_center()
	InputSynth.touch_tap(at)
	await bot.frames(3)
	var looked := shop.focused_id == TOUCH_BUFF and not shop.loadout.has(TOUCH_BUFF)
	if not bot.check(looked, "a first tap only shows the card"):
		return false
	InputSynth.touch_tap(at)
	await bot.frames(3)
	if not bot.check(shop.loadout.has(TOUCH_BUFF), "a second tap buys"):
		return false
	InputSynth.touch_tap(at)
	await bot.frames(3)
	InputSynth.canvas_motion(Vector2(4, 4), at)
	var sold := await settled(bot, shop) and shop.loadout.ids.is_empty()
	return bot.check(sold, "a tap on a bought card on show sells it")
