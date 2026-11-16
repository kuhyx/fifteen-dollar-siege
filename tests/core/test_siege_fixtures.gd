extends GutTest
## SiegeFixtures: the pinned sieges the bot plays. Each must end as it says in
## Watch mode, under the bot's Command-mode orders (rally, retreat, charge) at
## every timing in tools/sim/bot_orders.gd, and with the right events.
## Red after a tuning change: find new seeds with tools/sim/find_fixtures.gd.

const BotOrders = preload("res://tools/sim/bot_orders.gd")
const WIN := SiegeSim.Outcome.WIN
const LOSE := SiegeSim.Outcome.LOSE


func _kinds(shot: SiegeSnapshot) -> Array[StringName]:
	var out: Array[StringName] = []
	for event in shot.events:
		out.append(event["kind"])
	return out


## Plays the siege to its decision; returns every event kind it raised.
func _play_out(sim: SiegeSim) -> Array[StringName]:
	var out: Array[StringName] = []
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		sim.step(1.0)
		out.append_array(_kinds(sim.snapshot()))
	return out


func test_the_fixtures_are_legal_loadouts() -> void:
	assert_true(Loadout.of(SiegeFixtures.WIN_IDS).is_legal())
	assert_true(Loadout.of(SiegeFixtures.LOSE_IDS).is_legal())
	assert_false(SiegeFixtures.WIN_IDS.has(&"stew"), "the bot's one buy too many is the stew")


func test_the_winning_fixture_adds_no_heads_to_the_army() -> void:
	var loadout := Loadout.of(SiegeFixtures.WIN_IDS)
	var shot := SiegeSim.create(loadout, SiegeFixtures.WIN_SEED).snapshot()
	var heads := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY:
			heads += shot.ent_count[i]
	assert_eq(heads, SiegeSim.army_size(loadout), "the bot counts the men on the field")


func test_the_winning_fixture_wins_and_shows_it() -> void:
	var sim := SiegeSim.create(Loadout.of(SiegeFixtures.WIN_IDS), SiegeFixtures.WIN_SEED)
	var kinds := _play_out(sim)
	var shot := sim.snapshot()
	assert_eq(sim.outcome(), WIN)
	assert_between(sim.clock_s(), 30.0, SiegeTuning.TIME_CAP_S - 1.0, "won, not timed out")
	assert_has(kinds, SiegeEvent.ALARM)
	assert_has(kinds, SiegeEvent.VICTORY)
	assert_does_not_have(kinds, SiegeEvent.COMBUST)
	assert_eq(shot.village_morale, 0.0, "a beaten village has no morale left")
	assert_eq(sim.village_low(), 0.0)
	assert_gt(shot.army_morale, 0.0)


func test_the_losing_fixture_combusts_and_shows_it() -> void:
	var sim := SiegeSim.create(Loadout.of(SiegeFixtures.LOSE_IDS), SiegeFixtures.LOSE_SEED)
	var kinds := _play_out(sim)
	var shot := sim.snapshot()
	assert_eq(sim.outcome(), LOSE)
	assert_between(sim.clock_s(), 30.0, SiegeTuning.TIME_CAP_S - 1.0, "routed, not timed out")
	assert_has(kinds, SiegeEvent.COMBUST)
	assert_does_not_have(kinds, SiegeEvent.VICTORY)
	assert_eq(shot.army_morale, 0.0)
	assert_gt(sim.village_low(), 0.0, "the village never broke")
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY:
			assert_eq(shot.ent_state[i], SiegeSnapshot.State.DOWN, "the whole army combusts")


func test_the_fixtures_hold_under_the_bots_orders() -> void:
	var win := Loadout.of(SiegeFixtures.WIN_IDS)
	var lose := Loadout.of(SiegeFixtures.LOSE_IDS)
	for timing: Vector3i in BotOrders.TIMINGS:
		assert_eq(BotOrders.play(win, SiegeFixtures.WIN_SEED, timing), WIN, "orders at %s" % timing)
		assert_eq(BotOrders.play(lose, SiegeFixtures.LOSE_SEED, timing), LOSE, "at %s" % timing)
