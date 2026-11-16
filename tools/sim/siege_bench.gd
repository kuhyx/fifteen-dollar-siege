extends SceneTree
## The speed budget: wall time of whole headless sieges over the fixed random
## loadout sample (tools/sim/loadout_space.gd), one seed each.
##   godot --headless -s tools/sim/siege_bench.gd -- [--sieges=60] [--max-ms=400]
## Prints one RESULT line (median, p90 and max in ms, mean sim seconds) and
## exits 1 when the median is over --max-ms.

const Args = preload("res://tools/sim/sim_args.gd")
const Space = preload("res://tools/sim/loadout_space.gd")


func _init() -> void:
	var args := Args.parse()
	var sieges := int(args.get("sieges", "60"))
	var max_ms := float(args.get("max-ms", "400"))
	var walls: Array[float] = []
	var sim_s := 0.0
	for i in sieges:
		var loadout: Loadout = Space.sample(i)
		var started := Time.get_ticks_usec()
		var sim := SiegeSim.create(loadout, 500 + i)
		sim.run_to_end()
		walls.append((Time.get_ticks_usec() - started) / 1000.0)
		sim_s += sim.clock_s()
	walls.sort()
	var median := walls[walls.size() >> 1]
	var p90 := walls[mini(int(walls.size() * 0.9), walls.size() - 1)]
	var verdict := "ok" if median <= max_ms else "OVER the %d ms budget" % int(max_ms)
	print(
		(
			"RESULT bench sieges=%d median_ms=%.1f p90_ms=%.1f max_ms=%.1f mean_sim_s=%.1f %s"
			% [sieges, median, p90, walls[-1], sim_s / maxi(sieges, 1), verdict]
		)
	)
	quit(0 if median <= max_ms else 1)
