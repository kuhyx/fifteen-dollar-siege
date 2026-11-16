extends GutTest
## Loadout rules: 15 dollars, each buff at most once, unspent dollars lost,
## a buy over the budget refused with nothing changed.


func test_an_empty_loadout_is_legal_and_free() -> void:
	var loadout := Loadout.new()
	assert_eq(loadout.cost(), 0)
	assert_eq(loadout.remaining(), Loadout.BUDGET)
	assert_true(loadout.is_legal())
	assert_eq(Loadout.BUDGET, 15)


func test_toggle_buys_then_sells_back() -> void:
	var loadout := Loadout.new()
	assert_true(loadout.toggle(&"double_men"))
	assert_true(loadout.has(&"double_men"))
	assert_eq(loadout.cost(), 5)
	assert_true(loadout.toggle(&"double_men"), "the second toggle sells it back")
	assert_false(loadout.has(&"double_men"))
	assert_eq(loadout.cost(), 0)


func test_cost_is_the_sum_of_the_prices() -> void:
	var loadout := Loadout.of([&"double_men", &"fifty_men", &"moose", &"booze", &"stew"])
	assert_eq(loadout.cost(), 5 + 4 + 3 + 2 + 1)
	assert_eq(loadout.remaining(), 0)
	assert_true(loadout.is_legal())


func test_a_buy_over_the_budget_is_refused_and_changes_nothing() -> void:
	var loadout := Loadout.of([&"double_men", &"knight_armor", &"wasps"])
	assert_eq(loadout.cost(), 15)
	var before := loadout.ids.duplicate()
	assert_false(loadout.toggle(&"pep_talk"), "16 dollars")
	assert_eq(loadout.ids, before)
	assert_eq(loadout.cost(), 15)


func test_exactly_the_budget_is_allowed() -> void:
	var loadout := Loadout.of([&"double_men", &"knight_armor", &"fifty_men"])
	assert_eq(loadout.cost(), 14)
	assert_true(loadout.toggle(&"pep_talk"), "15 of 15")
	assert_false(loadout.toggle(&"stew"), "16 of 15")
	assert_true(loadout.is_legal())


func test_selling_is_allowed_even_at_the_budget() -> void:
	var loadout := Loadout.of([&"double_men", &"knight_armor", &"wasps"])
	assert_true(loadout.toggle(&"wasps"))
	assert_eq(loadout.cost(), 10)


func test_an_unknown_buff_is_refused() -> void:
	var loadout := Loadout.new()
	assert_false(loadout.toggle(&"death_ray"))
	assert_true(loadout.ids.is_empty())


func test_each_buff_at_most_once() -> void:
	var loadout := Loadout.new()
	loadout.toggle(&"stew")
	loadout.toggle(&"stew")
	loadout.toggle(&"stew")
	assert_eq(loadout.ids.count(&"stew"), 1, "three toggles: bought, sold, bought")
	assert_false(Loadout.of([&"stew", &"stew"]).is_legal(), "a duplicate is illegal")


func test_illegal_loadouts_are_named_illegal() -> void:
	assert_false(Loadout.of([&"death_ray"]).is_legal(), "unknown id")
	var rich := Loadout.of([&"double_men", &"knight_armor", &"wasps", &"medics"])
	assert_eq(rich.cost(), 20)
	assert_false(rich.is_legal(), "over the budget")
	assert_eq(rich.remaining(), -5)


func test_unspent_dollars_buy_nothing() -> void:
	var cheap := Loadout.of([&"stew"])
	assert_eq(cheap.remaining(), 14, "14 dollars are simply lost")
	assert_eq(SiegeSim.army_size(cheap), SiegeSim.army_size(Loadout.new()))


func test_of_takes_strings_and_duplicate_is_a_copy() -> void:
	var loadout := Loadout.of(["stew", "booze"])
	assert_eq(loadout.ids, [&"stew", &"booze"] as Array[StringName])
	var copy := loadout.duplicate()
	copy.toggle(&"stew")
	assert_true(loadout.has(&"stew"), "the copy changed, not the original")


func test_every_legal_single_buy_fits_the_budget() -> void:
	for def in BuffCatalog.all():
		var loadout := Loadout.new()
		assert_true(loadout.toggle(def.id), String(def.id))
		assert_true(loadout.is_legal(), String(def.id))
