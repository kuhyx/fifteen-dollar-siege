extends GutTest
## Delights of the menus: the shop's dice roll a random legal loadout with
## the coins flying, a win earns stars that pop in, and the result offers a
## random new fifteen dollars. Fails when any stops working, or when a new
## control has no key picture, no spoken label or no place on screen.


func _shop() -> LoadoutScreen:
	var shop := LoadoutScreen.new()
	add_child_autofree(shop)
	return shop


func test_a_roll_is_always_a_legal_loadout_that_spends_nearly_everything() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var seen := {}
	for i in 60:
		var ids := LoadoutDice.roll(rng)
		var loadout := Loadout.of(ids)
		assert_true(loadout.is_legal(), "roll %d" % i)
		assert_gte(loadout.cost(), 12, "a roll spends nearly all of the 15 dollars")
		seen[ids.hash()] = true
	assert_gt(seen.size(), 40, "and the rolls differ")
	var avoid := LoadoutDice.roll(rng)
	for i in 30:
		assert_ne(Array(LoadoutDice.roll(rng, avoid)), avoid, "never the loadout it avoids")


func test_the_shop_dice_sell_back_and_buy_a_random_loadout_card_by_card() -> void:
	var shop := _shop()
	shop.toggle(&"stew")
	var bought: Array = []
	shop.changed.connect(func(id: StringName, now: bool, _c: int) -> void: bought.append([id, now]))
	shop.dice.roll()
	assert_true(shop.dice.rolling, "the dice rattle while it rolls")
	await wait_until(func() -> bool: return not shop.dice.rolling, 6.0)
	assert_true(shop.loadout.is_legal())
	assert_gte(shop.loadout.cost(), 12)
	assert_eq(bought[0], [&"stew", false], "the first thing that happens is the sell-back")
	assert_eq(bought.size(), 1 + shop.loadout.ids.size(), "the sell-back, then a buy for each card")
	await wait_until(func() -> bool: return shop.flight.in_air() == 0, 5.0)
	assert_eq(shop.tray.coins, shop.loadout.remaining(), "every coin landed")
	assert_eq(shop.dice.rolls, 1)
	assert_eq(shop.dice.button.rotation, 0.0, "the dice stand still again")


func test_the_dice_button_is_a_labelled_keyed_control_inside_the_screen() -> void:
	var shop := _shop()
	var button := shop.dice.button
	assert_ne(button.accessibility_name, "", "a spoken label")
	assert_eq(button.text, "", "no words")
	var hint := button.get_node("KeyHint") as KeyHint
	assert_false(hint.unknown(), "its key has a picture")
	var box := Rect2(button.position, button.size)
	assert_true(Rect2(Vector2.ZERO, ScreenFrame.SIZE).encloses(box), "inside the 1920x1080 frame")
	assert_false(shop.go_button.get_rect().intersects(box), "and clear of the go button")


func test_stars_follow_the_dollars_of_a_win() -> void:
	var win := SiegeSim.Outcome.WIN
	assert_eq(StarRating.of(SiegeSim.Outcome.LOSE, Loadout.of([&"stew"])), 0)
	assert_eq(StarRating.of(win, Loadout.of([&"golf_carts", &"moose", &"emperor"])), 1)
	assert_eq(StarRating.of(win, Loadout.of([&"golf_carts", &"moose"])), 2)
	assert_eq(StarRating.of(win, Loadout.of([&"stew", &"prep_ten_minutes"])), 3)


func test_the_star_thresholds_sit_on_their_dollar() -> void:
	var win := SiegeSim.Outcome.WIN
	var by_cost := {
		2: 3,
		StarRating.THREE_AT: 3,
		StarRating.THREE_AT + 1: 2,
		StarRating.TWO_AT: 2,
		StarRating.TWO_AT + 1: 1,
		Loadout.BUDGET: 1,
	}
	for dollars: int in by_cost:
		var ids: Array[StringName] = []
		var rest := dollars
		for def in BuffCatalog.all():
			if def.price <= rest:
				ids.append(def.id)
				rest -= def.price
		var loadout := Loadout.of(ids)
		assert_eq(loadout.cost(), dollars, "built a %d-dollar loadout" % dollars)
		assert_eq(StarRating.of(win, loadout), by_cost[dollars], "%d dollars" % dollars)


func test_a_win_pops_its_stars_in_one_after_another() -> void:
	var result := ResultScreen.new()
	result.setup(SiegeSim.Outcome.WIN, Loadout.of([&"stew", &"prep_ten_minutes"]))
	add_child_autofree(result)
	assert_true(result.stars.visible)
	assert_eq(result.stars.earned, 3)
	assert_eq(result.stars.shown, 0)
	result.stars._process(ResultStars.FIRST_S + 0.01)
	assert_eq(result.stars.shown, 1, "the first star")
	result.stars._process(ResultStars.STEP_S)
	assert_eq(result.stars.shown, 2, "the second, a beat later")
	result.stars._process(ResultStars.STEP_S)
	assert_eq(result.stars.shown, 3)
	var lost := ResultScreen.new()
	lost.setup(SiegeSim.Outcome.LOSE, Loadout.of([&"stew"]))
	add_child_autofree(lost)
	assert_false(lost.stars.visible, "a loss earns none")


func test_the_result_offers_the_dice_in_view_with_a_key() -> void:
	var result := ResultScreen.new()
	result.setup(SiegeSim.Outcome.LOSE, Loadout.of([&"stew"]))
	add_child_autofree(result)
	var dice := result.controls.dice
	assert_not_null(dice)
	assert_eq(result.controls.buttons().size(), 4)
	assert_ne(dice.accessibility_name, "")
	assert_false((dice.get_node("KeyHint") as KeyHint).unknown())
	var frame := Rect2(Vector2.ZERO, ScreenFrame.SIZE)
	for name: String in result.controls.buttons():
		var button := result.controls.buttons()[name] as Control
		var box := Rect2(result.controls.position + button.position, button.size)
		assert_true(frame.encloses(box), "%s on screen" % name)
	var edit_box := Rect2(result.controls.edit.position, result.controls.edit.size)
	assert_false(edit_box.intersects(Rect2(dice.position, dice.size)), "buttons do not overlap")


func test_the_result_dice_start_a_siege_with_a_new_random_loadout() -> void:
	SaveStore.clear()
	var main: Main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	main.options.speed = 400.0
	main.options.sim_seed = SiegeFixtures.WIN_SEED
	main.mode = &"watch"
	main.start_siege(Loadout.of([&"stew"]))
	main.open_result(SiegeSim.Outcome.LOSE)
	assert_eq(main.screen_name, &"result")
	(main.screen as ResultScreen).controls.dice.pressed.emit()
	assert_eq(main.screen_name, &"battle")
	assert_true(main.loadout.is_legal())
	assert_gte(main.loadout.cost(), 12)
	assert_ne(main.loadout.ids, [&"stew"] as Array[StringName], "a new fifteen dollars")


func test_the_dice_breathe_after_a_moment() -> void:
	var result := ResultScreen.new()
	result.setup(SiegeSim.Outcome.LOSE, Loadout.of([&"stew"]))
	add_child_autofree(result)
	assert_eq(result.controls.dice.scale, Vector2.ONE, "still at first")
	var sizes := {}
	for step in 60:
		result._process(0.05)
		sizes[snappedf(result.controls.dice.scale.x, 0.01)] = true
	assert_gt(sizes.size(), 5, "then they swell and shrink")
