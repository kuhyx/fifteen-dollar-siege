extends GutTest
## The Command-mode bot's orders (BotCommander) against the same seeds with no
## orders, on the real sim: they change every siege, win more of them and keep
## men alive. All three orders get given, each at a moment a player could tell.

const RALLY := SiegeSim.Command.RALLY
const CHARGE := SiegeSim.Command.CHARGE
const RETREAT := SiegeSim.Command.RETREAT
const SEEDS := 12
const FIRST_SEED := 1000
const WITH_GUN: Array[StringName] = [&"fifty_men", &"shotgun"]
const PLAIN: Array[StringName] = [&"fifty_men"]


## One siege to its decision, with the bot's orders or without any. Returns
## {won, hash, given (the orders, in order), alive (army heads left)}.
func _play(ids: Array, sim_seed: int, commanded: bool) -> Dictionary:
	var sim := SiegeSim.create(Loadout.of(ids), sim_seed)
	var commander := BotCommander.new()
	var given: Array[int] = []
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		if commanded:
			var order := commander.advise(sim.snapshot(), sim.map())
			if not order.is_empty():
				sim.command(order["kind"], order["pos"])
				given.append(order["kind"])
		sim.step(SiegeSim.STEP_S * 5)
	return {
		"won": sim.outcome() == SiegeSim.Outcome.WIN,
		"hash": sim.state_hash(),
		"given": given,
		"alive": _army_heads(sim.snapshot()),
	}


func _army_heads(shot: SiegeSnapshot) -> int:
	var heads := 0
	for i in shot.entity_count():
		if (
			shot.ent_team[i] == SiegeSnapshot.Team.ARMY
			and shot.ent_kind[i] == SiegeSnapshot.Kind.MEN
		):
			heads += shot.ent_count[i]
	return heads


func test_the_orders_win_sieges_and_keep_men_alive() -> void:
	var wins := [0, 0]
	var alive := [0, 0]
	var changed := 0
	for k in SEEDS:
		var watched := _play(WITH_GUN, FIRST_SEED + k, false)
		var played := _play(WITH_GUN, FIRST_SEED + k, true)
		for arm in 2:
			var one: Dictionary = [watched, played][arm]
			wins[arm] += int(one["won"])
			alive[arm] += one["alive"]
		changed += int(watched["hash"] != played["hash"])
		assert_eq(played["given"][0], RALLY, "the first order is the rally")
	gut.p(
		(
			"ORDERS won %d -> %d of %d, men left %d -> %d"
			% [wins[0], wins[1], SEEDS, alive[0], alive[1]]
		)
	)
	assert_eq(changed, SEEDS, "every siege goes another way once orders are given")
	assert_gte(wins[1], wins[0] + 4, "the orders win sieges")
	assert_gt(alive[1], alive[0] + SEEDS * 10, "and keep men alive")


func test_all_three_orders_are_given_when_the_siege_calls_for_them() -> void:
	var seen := {}
	for k in SEEDS:
		for kind: int in _play(PLAIN, FIRST_SEED + k, true)["given"]:
			seen[kind] = int(seen.get(kind, 0)) + 1
	gut.p("ORDERS given %s" % [seen])
	assert_gt(seen.get(RALLY, 0), SEEDS - 1, "a rally in every siege")
	assert_gt(seen.get(CHARGE, 0), SEEDS / 2, "a charge in most")
	assert_gt(seen.get(RETREAT, 0), 0, "and a retreat when the men are worn down")


func test_a_retreat_changes_the_siege() -> void:
	for k in SEEDS:
		var played := _play(PLAIN, FIRST_SEED + k, true)
		if RETREAT in played["given"]:
			var plan := BotCommander.new()
			plan.never_retreats = true
			var without := _play_with(plan, PLAIN, FIRST_SEED + k)
			assert_ne(without["hash"], played["hash"], "the retreat made another siege")
			return
	fail_test("no siege called for a retreat")


func _play_with(commander: BotCommander, ids: Array, sim_seed: int) -> Dictionary:
	var sim := SiegeSim.create(Loadout.of(ids), sim_seed)
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		var order := commander.advise(sim.snapshot(), sim.map())
		if not order.is_empty():
			sim.command(order["kind"], order["pos"])
		sim.step(SiegeSim.STEP_S * 5)
	return {"hash": sim.state_hash()}
