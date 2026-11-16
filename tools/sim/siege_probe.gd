extends SceneTree
## One loadout, a few seeds, what happened: outcome, sim seconds, wall time,
## and with --trace a line every 10 sim seconds of the first siege.
##   godot --headless -s tools/sim/siege_probe.gd -- --loadout=booze,stew \
##       [--seed=1] [--runs=20] [--trace] [--feint] [--order=charge|retreat]
## --order gives that one order at the first tick and lets it stand.
## --feint plays the scripted commander (tools/sim/commander.gd) instead of
## Watch mode. Prints one RESULT line (push = mean of 1 - village_low, in
## percent: how close the army came); exit 0.

const Args = preload("res://tools/sim/sim_args.gd")
const Commander = preload("res://tools/sim/commander.gd")


func _init() -> void:
	var args := Args.parse()
	var loadout: Loadout = Args.loadout(args.get("loadout", ""))
	var first := int(args.get("seed", "1"))
	var runs := int(args.get("runs", "20"))
	var feint := args.has("feint")
	if not loadout.is_legal():
		printerr("siege_probe: not a legal loadout: %s" % [loadout.ids])
		quit(2)
		return
	if args.has("trace"):
		_trace(loadout, first, feint)
	var wins := 0
	var seconds := 0.0
	var push := 0.0
	var started := Time.get_ticks_usec()
	for i in runs:
		var sim := SiegeSim.create(loadout, first + i)
		if args.has("order"):
			var kinds := {"charge": SiegeSim.Command.CHARGE, "retreat": SiegeSim.Command.RETREAT}
			sim.command(kinds.get(args["order"], -1), Vector2.ZERO)
		if feint:
			Commander.play(sim, not args.has("no-charge"))
		else:
			sim.run_to_end()
		wins += int(sim.outcome() == SiegeSim.Outcome.WIN)
		seconds += sim.clock_s()
		push += 1.0 - sim.village_low()
	var wall_ms := (Time.get_ticks_usec() - started) / 1000.0 / maxi(runs, 1)
	print(
		(
			"RESULT loadout=%s wins=%d/%d push=%.0f mean_s=%.1f wall_ms=%.1f"
			% [
				Args.text(loadout.ids),
				wins,
				runs,
				push * 100.0 / maxi(runs, 1),
				seconds / maxi(runs, 1),
				wall_ms
			]
		)
	)
	quit(0)


func _trace(loadout: Loadout, sim_seed: int, feint: bool) -> void:
	var sim := SiegeSim.create(loadout, sim_seed)
	var commander := Commander.new()
	var tally := {}
	while sim.outcome() == SiegeSim.Outcome.RUNNING:
		if feint:
			commander.advise(sim)
		sim.step(SiegeSim.STEP_S * 5)
		var shot := sim.snapshot()
		for event in shot.events:
			tally[event["kind"]] = tally.get(event["kind"], 0) + 1
		if roundi(shot.clock_s * 10.0) % 100 == 0 or shot.outcome != 0:
			print(_line(shot))
	print("events: ", tally)


func _line(shot: SiegeSnapshot) -> String:
	var heads := [0, 0]
	var fleeing := [0, 0]
	for i in shot.entity_count():
		if shot.ent_kind[i] == SiegeSnapshot.Kind.VILLAGERS:
			continue
		var team := shot.ent_team[i]
		if shot.ent_state[i] == SiegeSnapshot.State.FLEE:
			fleeing[team] += shot.ent_count[i]
		else:
			heads[team] += shot.ent_count[i]
	return (
		"t=%5.1f alarm=%.2f army=%.2f (%d up, %d running) village=%.2f (%d up, %d running) hold=%.2f"
		% [
			shot.clock_s,
			shot.alarm,
			shot.army_morale,
			heads[0],
			fleeing[0],
			shot.village_morale,
			heads[1],
			fleeing[1],
			shot.centre_hold
		]
	)
