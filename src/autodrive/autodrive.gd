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

## 15 dollars, 300 men: the stub sim wins at 8 dollars or more.
const WIN_IDS: Array[StringName] = [&"double_men", &"fifty_men", &"knight_armor", &"pep_talk"]
## 2 dollars: the stub sim loses.
const LOSE_IDS: Array[StringName] = [&"pep_talk", &"stew"]
## One buy too many for WIN_IDS (16 dollars): must be refused.
const ONE_TOO_MANY := &"stew"
const DECIDE_LIMIT_FRAMES := 6000
## Frames of a siege the frame gate judges (BattleChecks.smooth).
const SMOOTH_FRAMES := 40

var _mode: StringName
var _hashes: PackedStringArray = []


func _ready() -> void:
	main = get_parent() as Main
	_mode = main.options.autodrive
	if _mode == &"showcase":  # the battle screen's own tour: another bot
		var tour := ShowcaseBot.new()
		tour.main = main
		add_child(tour)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	await frames(3)
	if _may_run():
		await _play()
	finish(
		(
			"mode=%s frames=%d hashes=%s %s"
			% [_mode, shots.count, ",".join(_hashes), " ".join(numbers)]
		)
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
		if not await _buy(ids, "win" if wins else "lose"):
			return
		var played: bool
		if _mode == &"lab":
			played = await _lab_round(wins)
		else:
			played = await _siege_round(wins)
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


## Battle to the payoff and the result screen, then home.
func _siege_round(wins: bool) -> bool:
	var tag := "win" if wins else "lose"
	if not await on_screen(&"battle"):
		return false
	var battle := main.screen as BattleScreen
	var men := 0
	for i in battle.shot.entity_count():
		if battle.shot.ent_team[i] == SiegeSnapshot.Team.ARMY:
			men += battle.shot.ent_count[i]
	await frames(20)
	var ok := (
		check(men == SiegeSim.army_size(main.loadout), "the army has %d men" % men)
		and await shot("battle_" + tag)
		and BattleChecks.hud_ok(self, battle)
		and (_mode != &"command" or await _give_orders(battle))
		and (not wins or await _pause_freezes(battle))
		and await BattleChecks.smooth(self, battle, SMOOTH_FRAMES) >= 0.0
	)
	return ok and await _to_result(battle, wins)


## Waits for the decision, takes the payoff frame BEFORE any result UI opens
## (lesson L13), then plays the result screen's own payoff and controls.
func _to_result(battle: BattleScreen, wins: bool) -> bool:
	var tag := "win" if wins else "lose"
	var want := SiegeSim.Outcome.WIN if wins else SiegeSim.Outcome.LOSE
	var decided := func() -> bool: return battle.sim.outcome() != SiegeSim.Outcome.RUNNING
	if not await wait_for(decided, DECIDE_LIMIT_FRAMES, "the siege to be decided"):
		return false
	_hashes.append(str(battle.sim.state_hash()))
	var showing: bool = await BattleChecks.payoff_seen(self, battle)
	var ok := (
		check(battle.sim.outcome() == want, "the siege ends in %s" % tag)
		and check(showing, "the payoff shows before the result")
		and await shot("payoff_" + tag)
		and await on_screen(&"result")
	)
	return ok and await MenuBeats.result(self, wins, want, main.loadout.ids)


## Command mode: a rally click on the map, then retreat and charge buttons.
func _give_orders(battle: BattleScreen) -> bool:
	await click_at(battle.camera.view.get_center() + Vector2(0.0, -120.0))
	if not check(battle.commands_sent == 1, "a map click places the rally flag"):
		return false
	await frames(20)
	if not await shot("rally"):
		return false
	await click(battle.retreat_button)
	await click(battle.charge_button)
	return check(battle.commands_sent == 3, "retreat and charge reach the sim")


## Esc mid-battle: the menu is up and the sim clock stands still.
func _pause_freezes(battle: BattleScreen) -> bool:
	await press_escape()
	var before := battle.sim.clock_s()
	await frames(10)
	var frozen := main.pause_menu.is_open() and is_equal_approx(battle.sim.clock_s(), before)
	if not check(frozen, "the pause menu freezes the siege") or not await shot("pause_battle"):
		return false
	await press_escape()
	await frames(5)
	return check(battle.sim.clock_s() > before, "the siege runs again after the menu closes")


## Lab: the batch arrives tick by tick, finishes, every run agrees with the
## stub rule, the loadout is ranked, and the Lab's own controls lead on.
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
	var expected := runs if wins else 0
	var seconds: float = lab.result["mean_seconds"]
	_hashes.append("%d/%d" % [lab.result["wins"], runs])
	await frames(3)
	var ok := (
		check(runs == main.options.lab_runs, "the lab ran %d sieges" % runs)
		and check(lab.result["wins"] == expected, "the lab counts %d wins" % expected)
		and check(seconds > 15.0 and seconds < 25.0, "mean seconds near 20: %s" % seconds)
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
