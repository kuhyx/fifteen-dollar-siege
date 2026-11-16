class_name Autodrive
extends BotBase
## The --autodrive=<watch|command|lab> bot: plays one mode through the real
## main scene with synthesized clicks and keys, and exits 0 only when every
## assert held. One run: hub (buttons on screen, Esc opens the pause menu),
## the shop tour (vignette, buy, sell, touch, a refused buy), a siege bought
## to WIN, a siege bought to LOSE (each to its result screen, the payoff
## frame taken BEFORE the result opens, then the result's own controls: edit
## after the win, retry after the loss), then Esc -> hub button. The beats on
## the menu-side screens live in menu_beats.gd.
## Lives outside src/dev so an exported build can run it too.
## scripts/lib/bot.sh `bot_frames` holds the number of beats per mode.

## The pinned sieges of the real sim (src/core/siege_fixtures.gd): a loadout
## and seed that win, a loadout and seed that lose.
const WIN_IDS := SiegeFixtures.WIN_IDS
const LOSE_IDS := SiegeFixtures.LOSE_IDS
## One buy too many for WIN_IDS (16 dollars): must be refused.
const ONE_TOO_MANY := &"stew"
## The bots with a script of their own.
const OTHER_BOTS: Array[StringName] = [&"showcase", &"touch", &"reel", &"buffs", &"fun"]
const DECIDE_LIMIT_FRAMES := 6000

## State hashes of the sieges played (the RESULT line).
var hashes: PackedStringArray = []

var _mode: StringName


func _ready() -> void:
	main = get_parent() as Main
	_mode = main.options.autodrive
	if _mode in OTHER_BOTS:  # the battle's tour, a finger's loop, a reel, the buffs
		var other: BotBase = _other_bot()
		other.main = main
		add_child(other)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _other_bot() -> BotBase:
	match _mode:
		&"showcase":
			return ShowcaseBot.new()
		&"touch":
			return TouchBot.new()
		&"reel":
			return ReelBot.new()
		&"fun":
			return FunBot.new()
	return BuffsBot.new()


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	await frames(3)
	if _may_run():
		await _play()
	finish(
		"mode=%s frames=%d hashes=%s %s" % [_mode, shots.count, ",".join(hashes), " ".join(numbers)]
	)


func _may_run() -> bool:
	var options := main.options
	var window := BotReport.window_problem(options.expect_window, DisplayServer.window_get_size())
	return (
		check(BotReport.save_dir_problem(options.save_dir) == "", "no throwaway --save-dir")
		and check(options.unknown.is_empty(), "unknown arguments: %s" % [options.unknown])
		and check(window == "", window)
	)


func _play() -> void:
	if not await _hub_beat():
		return
	for wins: bool in [true, false]:
		var ids := WIN_IDS if wins else LOSE_IDS
		main.options.sim_seed = SiegeFixtures.WIN_SEED if wins else SiegeFixtures.LOSE_SEED
		if not await _buy(ids, "win" if wins else "lose"):
			return
		var played: bool
		if _mode == &"lab":
			played = await _lab_round(wins)
		else:
			played = await SiegeRound.play(self, wins, _mode)
		if not played:
			return
	await _pause_to_hub()


## The hub: three mode buttons on screen, Esc opens and closes the pause menu.
func _hub_beat() -> bool:
	if not await on_screen(&"hub"):
		return false
	var hub := main.screen as HubScreen
	var ok := (
		check(hub != null and hub.buttons.size() == 3, "the hub has three mode buttons")
		and all_inside(hub.buttons, "hub button")
		and inside(main.menu_button, "the menu button")
	)
	if not ok or not await shot("hub"):
		return false
	await press_escape()
	ok = (
		check(main.pause_menu.is_open() and get_tree().paused, "Esc opens the pause menu")
		and all_inside(main.pause_menu.buttons, "pause button")
		and await VolumeBeat.run(self)
	)
	if not ok or not await shot("pause"):
		return false
	await press_escape()
	return check(not main.pause_menu.is_open() and not get_tree().paused, "Esc closes the menu")


## Hub (or the result's edit control) -> this mode's loadout screen -> buys
## exactly `ids` through the cards.
func _buy(ids: Array[StringName], tag: String) -> bool:
	if main.screen_name == &"hub":
		await click((main.screen as HubScreen).buttons[_mode])
	if not await on_screen(&"loadout"):
		return false
	var shop := main.screen as LoadoutScreen
	var ok := (
		check(shop.cards.size() == 25, "25 buff cards, saw %d" % shop.cards.size())
		and all_inside(shop.cards, "card")
	)
	if not ok:
		return false
	for id: StringName in shop.loadout.ids.duplicate():  # last time's picks
		await click(shop.cards[id])
	if tag == "win" and not await MenuBeats.shop_tour(self, shop):
		return false
	for id in ids:
		await click(shop.cards[id])
	if shop.loadout.remaining() == 0:
		await click(shop.cards[ONE_TOO_MANY])
	var want := Loadout.of(ids)
	ok = (
		check(shop.loadout.ids == want.ids, "the cards bought %s" % [shop.loadout.ids])
		and check(shop.loadout.is_legal(), "a buy over the budget is refused")
		and await MenuBeats.settled(self, shop)
	)
	if not ok or not await shot("loadout_" + tag):
		return false
	await click(shop.go_button)
	return true


## Lab: the batch arrives tick by tick, finishes, sides with the pinned
## fixture, the loadout is ranked, and the Lab's own controls lead on.
func _lab_round(wins: bool) -> bool:
	if not await on_screen(&"lab"):
		return false
	var lab := main.screen as LabScreen
	if not await MenuBeats.lab_running(self, lab, "win" if wins else "lose"):
		return false
	var done := func() -> bool: return lab.done
	if not await wait_for(done, DECIDE_LIMIT_FRAMES, "the lab batch"):
		return false
	var runs: int = lab.result["runs"]
	var mostly_won: bool = lab.result["wins"] * 2 > runs
	var seconds: float = lab.result["mean_seconds"]
	hashes.append("%d/%d" % [lab.result["wins"], runs])
	await frames(3)
	var ok := (
		check(runs == main.options.lab_runs, "the lab ran %d sieges" % runs)
		and check(mostly_won == wins, "the lab sides with the fixture: %s" % hashes[-1])
		and check(seconds > 30.0 and seconds < 300.0, "mean seconds of a siege: %s" % seconds)
		and await MenuBeats.lab_ranked(self, lab, wins)
		and await shot("lab_win" if wins else "lab_lose")
	)
	return ok and await MenuBeats.lab_leave(self, lab, wins)


## The pause menu's way back: start a siege, Esc, the hub button.
func _pause_to_hub() -> bool:
	await click((main.screen as HubScreen).buttons[_mode])
	if not await on_screen(&"loadout"):
		return false
	await click((main.screen as LoadoutScreen).go_button)
	if not await on_screen(&"lab" if _mode == &"lab" else &"battle"):
		return false
	await press_escape()
	if not check(main.pause_menu.is_open(), "Esc opens the menu during a siege"):
		return false
	await click(main.pause_menu.buttons["hub"])
	return (
		await on_screen(&"hub")
		and check(not get_tree().paused, "the hub is not paused")
		and await shot("hub_again")
	)
