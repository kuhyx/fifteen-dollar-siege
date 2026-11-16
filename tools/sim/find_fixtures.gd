extends SceneTree
## Finds seeds for SiegeFixtures: a seed where a loadout WINS (or, with
## --lose, LOSES) in Watch mode AND under the bot's Command-mode orders at
## every timing the bot may hit, and where a Lab batch from that seed sides
## the same way by a clear margin (60 % or more wins, or 20 % or fewer).
##   godot --headless -s tools/sim/find_fixtures.gd -- --loadout=a,b,c \
##       [--lose] [--from=1] [--seeds=40] [--lab=30] [--budget-s=45]
## Prints one FIXTURE line per seed that qualifies (seed, sim seconds, lab
## wins); exit 0 when at least one was found.

const Args = preload("res://tools/sim/sim_args.gd")
const BotOrders = preload("res://tools/sim/bot_orders.gd")


func _init() -> void:
	var args := Args.parse()
	var loadout: Loadout = Args.loadout(args.get("loadout", ""))
	var want := SiegeSim.Outcome.LOSE if args.has("lose") else SiegeSim.Outcome.WIN
	var first := int(args.get("from", "1"))
	var seeds := int(args.get("seeds", "40"))
	var lab_runs := int(args.get("lab", "30"))
	var deadline := Time.get_ticks_msec() + int(float(args.get("budget-s", "45")) * 1000.0)
	var found := 0
	for sim_seed in range(first, first + seeds):
		if Time.get_ticks_msec() > deadline:
			break
		var seconds := _plays_out(loadout, sim_seed, want)
		if seconds < 0.0:
			continue
		var lab := Lab.run_batch(loadout, lab_runs, sim_seed)
		var wins: int = lab["wins"]
		var clear := wins * 5 >= lab_runs * 3
		if want == SiegeSim.Outcome.LOSE:
			clear = wins * 5 <= lab_runs
		if clear:
			found += 1
			print("FIXTURE seed=%d seconds=%.1f lab=%d/%d" % [sim_seed, seconds, wins, lab_runs])
	print("find_fixtures: %d seeds qualify for %s" % [found, Args.text(loadout.ids)])
	quit(0 if found > 0 else 1)


## Sim seconds of the Watch siege when every play of `sim_seed` ends in `want`,
## else -1.
func _plays_out(loadout: Loadout, sim_seed: int, want: int) -> float:
	var watch := SiegeSim.create(loadout, sim_seed)
	if watch.run_to_end() != want:
		return -1.0
	for timing in BotOrders.TIMINGS:
		if BotOrders.play(loadout, sim_seed, timing) != want:
			return -1.0
	return watch.clock_s()
