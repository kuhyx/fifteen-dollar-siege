class_name MenuBeats
extends RefCounted
## The autodrive bot's beats on the menu-side screens (autodrive.gd calls
## them): the shop tour (hover a card for its vignette, buy, a refused buy,
## sell, touch), the result's payoff and its three controls, the Lab's batch,
## ranking and controls. Every beat asserts what it claims and takes a shot.
## The tour picks its own buffs: it does not depend on the loadouts the bot
## fights with.

const TOUR_BUFF := &"wasps"
const TOUCH_BUFF := &"moose"
## With TOUR_BUFF these spend all 15 dollars; ONE_MORE is then refused.
const FILLERS: Array[StringName] = [&"double_men", &"knight_armor"]
const ONE_MORE := &"stew"
const WAIT_FRAMES := 6000
## Frames from the decision to the same loadout fighting again.
const RETRY_FRAMES := 60
## Frames a win's result waits for its stars to pop in (about 2.4 s).
const STARS_FRAMES := 150


## The empty shop, a hovered card's vignette, a buy caught with its coins in
## the air, a buy over the budget (refused), the sells, and a buy by touch
## (tap looks, the second tap buys). Leaves the shop empty again.
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
	if not await _refusal(bot, shop):
		return false
	for id: StringName in [TOUR_BUFF] + FILLERS:
		await bot.click(shop.cards[id])
	var back := await settled(bot, shop) and shop.tray.coins == Loadout.BUDGET
	if not bot.check(back and shop.loadout.ids.is_empty(), "a second click sells a card back"):
		return false
	return await _dice(bot, shop) and await _touch(bot, shop)


## The dice: one press buys a random legal loadout card by card (a frame
## while the coins fly), and it sells back like any other buy. Leaves the
## shop empty again.
static func _dice(bot: BotBase, shop: LoadoutScreen) -> bool:
	await bot.click(shop.dice.button)
	# The first card lands within a few frames; a roll of three cards is over in
	# 20 (the dice are random), so the frame is taken the moment it buys.
	var buying := func() -> bool: return shop.dice.rolling and not shop.loadout.ids.is_empty()
	if not await bot.wait_for(buying, 20, "the dice to roll and buy a card"):
		return false
	if not await bot.shot("shop_dice"):
		return false
	var stopped := func() -> bool: return not shop.dice.rolling
	if not await bot.wait_for(stopped, 600, "the dice to stop") or not await settled(bot, shop):
		return false
	var full := shop.loadout.is_legal() and shop.loadout.cost() >= 12
	if not bot.check(full, "a roll is a legal, nearly full loadout"):
		return false
	for id: StringName in shop.loadout.ids.duplicate():
		await bot.click(shop.cards[id])
	var emptied := await settled(bot, shop) and shop.loadout.ids.is_empty()
	return bot.check(emptied and shop.tray.coins == Loadout.BUDGET, "a roll sells back")


## Waits until every coin has landed and the tray stands still.
static func settled(bot: BotBase, shop: LoadoutScreen) -> bool:
	var still := func() -> bool: return shop.flight.in_air() == 0 and not shop.tray.is_shaking()
	return await bot.wait_for(still, 300, "the coins to land")


## The result: its controls are up at once (the battle's payoff was the beat).
## A win goes on with
## "change the loadout" (the shop opens with it); a loss with "again" (the
## same loadout fights once more), then home.
static func result(bot: BotBase, wins: bool, want: int, ids: Array[StringName]) -> bool:
	var tag := "win" if wins else "lose"
	var screen := bot.main.screen as ResultScreen
	await bot.frames(3 if not wins else STARS_FRAMES)
	var up := screen.outcome == want and screen.controls_shown
	var ok := (
		bot.check(up, "the %s result has its controls up at once, no second payoff" % tag)
		and bot.all_inside(screen.controls.buttons(), "result control")
		and bot.check(screen.controls.dice != null, "the result offers the dice")
		and bot.check(screen.stars.shown == StarRating.of(want, bot.main.loadout), "stars popped")
		and await bot.shot("result_" + tag)
	)
	if not ok:
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
	return await impatient_retry(bot, ids) and await _leave_by_pause(bot)


## An impatient player: one press after the first look skips the payoff, the
## result is up with its controls, and the same loadout fights again, all
## inside RETRY_FRAMES frames (a second at the bot's fixed 60 fps) of the
## siege being decided.
static func impatient_retry(bot: BotBase, ids: Array[StringName]) -> bool:
	var battle := bot.main.screen as BattleScreen
	var decided := func() -> bool: return battle.sim.outcome() != SiegeSim.Outcome.RUNNING
	if not await bot.wait_for(decided, WAIT_FRAMES, "the retried siege to be decided"):
		return false
	var started := Engine.get_process_frames()
	await bot.frames(ceili(BattleBeats.SKIP_AFTER_S * 60.0) + 2)
	InputSynth.key_tap(KEY_ENTER)
	var over := func() -> bool: return bot.main.screen_name == &"result"
	if not await bot.wait_for(over, 30, "the result after one press"):
		return false
	var screen := bot.main.screen as ResultScreen
	await bot.frames(2)
	if not bot.check(screen.controls_shown, "one press and the controls are up"):
		return false
	await bot.click(screen.retry_button)
	var used := Engine.get_process_frames() - started
	bot.numbers.append("retry_frames=%d" % used)
	return (
		bot.check(used < RETRY_FRAMES, "retry took %d frames after the outcome" % used)
		and await bot.on_screen(&"battle")
		and bot.check(bot.main.loadout.ids == ids, "the same loadout again")
	)


## Esc, then the pause menu's hub button.
static func _leave_by_pause(bot: BotBase) -> bool:
	await bot.press_escape()
	if not bot.check(bot.main.pause_menu.is_open(), "Esc opens the pause menu"):
		return false
	await bot.click(bot.main.pause_menu.buttons["hub"])
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


## Spends the last dollar, then tries one buy more: the tray shakes, its rim
## turns red and nothing is bought.
static func _refusal(bot: BotBase, shop: LoadoutScreen) -> bool:
	for id in FILLERS:
		await bot.click(shop.cards[id])
	if not await settled(bot, shop) or not bot.check(shop.tray.coins == 0, "the tray is empty"):
		return false
	await bot.click(shop.cards[ONE_MORE])
	var refused := shop.tray.is_shaking() and not shop.loadout.has(ONE_MORE)
	var kept := shop.loadout.cost() == Loadout.BUDGET
	return (
		bot.check(refused and kept, "a buy over the budget shakes the tray and buys nothing")
		and await bot.shot("shop_refusal")
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
