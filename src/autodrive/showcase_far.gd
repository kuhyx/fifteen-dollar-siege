class_name ShowcaseFar
extends RefCounted
## The showcase's whole-map checks: what the player sees of an order or a
## swarm when the camera is far, measured on pixels (BattleChecks).


## Wasps on the whole-map view: a cloud, not dots (the haze is measured).
static func swarm(bot: ShowcaseBot) -> bool:
	var battle: BattleScreen = await bot.open(&"swarm")
	await bot.watch(battle, 40)
	var anchor := battle.crowd.squads[0].anchor
	var cloud := Rect2(battle.map_to_canvas(anchor) - Vector2(110, 110), Vector2(220, 220))
	return (
		bot.check(battle.crowd.has_swarm(), "the wasps are in the air")
		and await BattleChecks.reads_at_a_glance(
			bot, battle.effects, cloud, "wasp cloud", BattleChecks.CLOUD_FLOOR
		)
		and await bot.shot("wasps_far")
	)


## Command mode at whole-map zoom: a click plants the flag, the buttons
## charge and retreat; each order must change enough pixels to be seen.
static func orders(bot: ShowcaseBot) -> bool:
	var battle: BattleScreen = await bot.open(&"orders", &"command")
	var flag := Vector2(250, 110)
	await bot.click_at(battle.map_to_canvas(flag))
	await bot.watch(battle, 14)
	var planted := battle.commands_sent == 1 and battle.effects.has_rally()
	var near := battle.map_to_canvas(flag)
	var spot := Rect2(near + Vector2(-90, -170), Vector2(240, 210))
	if not (
		bot.check(planted, "a click plants the rally flag")
		and await BattleChecks.reads_at_a_glance(
			bot, battle.effects, spot, "rally flag", BattleChecks.FLAG_FLOOR
		)
		and await bot.shot("orders_rally")
	):
		return false
	await bot.click(battle.charge_button)
	await bot.watch(battle, 20)
	var way := Rect2(battle.map_to_canvas(Vector2(300, 150)), Vector2(200, 160))
	if not (
		bot.check(not battle.effects.has_rally(), "a charge pulls the flag")
		and await BattleChecks.reads_at_a_glance(
			bot, battle.effects, way, "charge chevrons", BattleChecks.CHEVRON_FLOOR
		)
		and await bot.shot("orders_charge")
	):
		return false
	await bot.click(battle.retreat_button)
	await bot.watch(battle, 8)
	var back := Rect2(battle.map_to_canvas(Vector2(80, 150)), Vector2(380, 160))
	return (
		bot.check((battle.sim as ShowcaseSim).show_orders == 3, "three orders reached the sim")
		and await BattleChecks.reads_at_a_glance(
			bot, battle.effects, back, "retreat chevrons", BattleChecks.CHEVRON_FLOOR
		)
	)
