extends GutTest
## What the army bought is on the battle screen as pictograms: a chip per buff
## (so the buffs that only change numbers are seen too), large above the army
## for a moment, then small under the meters; small while a beat is staged.

const BOUGHT: Array[StringName] = [&"stew", &"sleepless_village", &"deaf_villagers"]


func _chips() -> BuffChips:
	var chips := BuffChips.new()
	chips.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chips.size = Vector2(1920.0, 1080.0)
	chips.setup(Loadout.of(BOUGHT))
	add_child_autofree(chips)
	return chips


func test_a_chip_for_every_buff_bought() -> void:
	var chips := _chips()
	assert_eq(chips.ids, BOUGHT)
	for id in BuffCatalog.all():
		assert_true(BuffPictograms.has(id.id), "%s has a pictogram to show" % id.id)


func test_the_row_stands_large_then_settles_under_the_strip() -> void:
	var chips := _chips()
	var big := chips.chip_box(0)
	assert_eq(big.size.x, BuffChips.BIG_CHIP)
	assert_lt(big.get_center().y, 1080.0 * 0.5, "above the army, not on it")
	chips.advance(BuffChips.SHOW_S + BuffChips.SETTLE_S + 0.1, false)
	var small := chips.chip_box(0)
	assert_eq(small.size.x, BuffChips.CHIP)
	assert_gte(small.position.y, HudMeters.TOP + HudMeters.TALL, "under the meters strip")
	assert_almost_eq(
		chips.chip_box(1).get_center().x - small.get_center().x,
		BuffChips.CHIP + BuffChips.GAP,
		0.01
	)


func test_a_staged_beat_keeps_the_row_small_and_out_of_the_way() -> void:
	var chips := _chips()
	chips.advance(0.1, true)
	assert_eq(chips.chip_box(0).size.x, BuffChips.CHIP)
	chips.advance(0.1, false)
	assert_eq(chips.chip_box(0).size.x, BuffChips.BIG_CHIP, "large once the beat is over")


func test_the_battle_screen_shows_the_loadout() -> void:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of(BOUGHT)
	battle.setup(SiegeSim.create(battle.loadout, 1), &"watch", 1.0)
	add_child_autofree(battle)
	assert_eq(battle.hud.chips.ids, BOUGHT)
	battle.dress(Loadout.of([&"booze"]))
	assert_eq(battle.hud.chips.ids, [&"booze"] as Array[StringName], "dressing changes the row")
