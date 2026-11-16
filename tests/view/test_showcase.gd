extends GutTest
## The showcase's scripted sim: its scenes put every Kind in every State and
## every event on the battlefield, and its crowd is the 2,400 figures the
## frame gate is measured on.

const GRIDS: Array[StringName] = [
	&"kinds_army", &"kinds_leaders", &"kinds_village", &"specials_a", &"specials_b"
]
const SCENES: Array[StringName] = [
	&"events_ranged", &"events_melee", &"events_calls", &"orders", &"beats", &"payoff_win"
]


func test_showcase_is_a_bot_mode_and_not_a_game_mode() -> void:
	assert_eq(LaunchOptions.parse(["--autodrive=showcase"]).autodrive, &"showcase")
	assert_eq(LaunchOptions.parse(["--autodrive=showcase"]).problem, "")
	assert_string_contains(LaunchOptions.parse(["--mode=showcase"]).problem, "unknown mode")
	assert_false(LaunchOptions.MODES.has(&"showcase"), "the hub has three modes")


func test_the_grids_show_every_kind_in_every_state() -> void:
	var seen := {}
	for scene in GRIDS:
		var shot := ShowcaseSim.make(scene).snapshot()
		for i in shot.entity_count():
			seen["%d:%d" % [shot.ent_kind[i], shot.ent_state[i]]] = true
			assert_true(
				ShowcaseScript.box(scene).has_point(shot.ent_pos[i]), "%s frames it" % scene
			)
	assert_eq(seen.size(), SiegeSnapshot.Kind.size() * SiegeSnapshot.State.size())


func test_the_scenes_fire_every_event() -> void:
	var fired := {}
	for scene in SCENES + [&"payoff_lose", &"crowd"]:
		var sim := ShowcaseSim.make(scene)
		sim.command(SiegeSim.Command.RALLY, Vector2(10, 10))
		for step in 60:
			sim.step(SiegeSim.STEP_S)
			for event in sim.snapshot().events:
				fired[event["kind"]] = true
				assert_true(event.has("pos"), "%s has a position" % event["kind"])
	for kind in SiegeEvent.ALL:
		assert_true(fired.has(kind), "no scene fires %s" % kind)


func test_the_crowd_is_2400_figures_that_move_and_fall() -> void:
	var sim := ShowcaseSim.make(&"crowd")
	assert_eq(sim.heads(), 2400)
	assert_eq(ShowcaseCrowd.FIGURES, 2400)
	var before := sim.snapshot()
	sim.step(2.0)
	var after := sim.snapshot()
	assert_ne(after.ent_pos, before.ent_pos, "everybody moves")
	assert_ne(after.ent_state, before.ent_state, "states change")
	assert_lt(sim.heads(), 2400, "heads fall")
	assert_gt(after.events.size(), 15, "a storm of events: one every 0.1 s tick")
	assert_almost_eq(after.clock_s, 2.0, SiegeSim.STEP_S + 0.001, "whole ticks only")
	var twin := ShowcaseSim.make(&"crowd")
	twin.step(2.0)
	assert_eq(twin.state_hash(), sim.state_hash(), "the script is deterministic")


func test_the_endings_decide_and_orders_come_back_as_events() -> void:
	var win := ShowcaseSim.make(&"payoff_win")
	assert_eq(win.outcome(), SiegeSim.Outcome.RUNNING)
	win.step(0.5)
	assert_eq(win.outcome(), SiegeSim.Outcome.WIN)
	var lose := ShowcaseSim.make(&"payoff_lose")
	lose.step(0.5)
	assert_eq(lose.outcome(), SiegeSim.Outcome.LOSE)
	lose.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
	assert_eq(lose.show_orders, 0, "no orders after the decision")
	var orders := ShowcaseSim.make(&"orders")
	orders.command(SiegeSim.Command.CHARGE, Vector2.ZERO)
	var echo := orders.snapshot().events.filter(
		func(event: Dictionary) -> bool: return event["kind"] == SiegeEvent.COMMAND
	)
	assert_eq(echo.size(), 1)
	assert_eq(echo[0]["pos"], orders.map().village_center)
	assert_eq(orders.snapshot().events.size(), 0, "events are handed over once")
