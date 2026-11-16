extends SceneTree
## Reads what the balance search measured for the current sim and prints the
## four numbers kuhy's bar is about, the top loadouts and each buff's best rank.
##   godot --headless -s tools/sim/balance_report.gd -- [--top=50] [--rows=10]
##       [--min-runs=48] [--strict] [--store=DIR]
## Targets: no buffs under 5 %, a random loadout 25-45 %, the best 85 % or
## more, every buff in at least one of the top 50. --strict exits 1 when one
## is missed (or not measured yet). The output is Markdown: the table in
## DOCS-design-sim.md is this tool's output.

const Args = preload("res://tools/sim/sim_args.gd")
const Space = preload("res://tools/sim/loadout_space.gd")
const Store = preload("res://tools/sim/balance_store.gd")
const Plan = preload("res://tools/sim/balance_plan.gd")

var _store: RefCounted


func _init() -> void:
	var args := Args.parse()
	Plan.configure(args)
	_store = Store.open(args.get("store", Store.default_root()))
	var top_n := int(args.get("top", "50"))
	var ranked: Array[String] = Plan.ranking(_store, int(args.get("min-runs", "48")))
	var top := ranked.slice(0, top_n)
	var sieges := 0
	for key: String in _store.results:
		sieges += _store.runs(key)
	var sample := _sample_rate()
	var empty: float = _store.rate("none")
	var best: float = _store.rate(top[0]) if not top.is_empty() else 0.0
	var missing := _missing(top)
	var stamp := Time.get_date_string_from_system()
	var counts := [_store.results.size(), sieges, ranked.size()]
	var head := "sim hash `%s`, %s: " % [_store.sim_hash, stamp]
	print(head + "%d loadouts, %d sieges, %d ranked" % counts)
	print("")
	print("| target | measured | from |")
	print("|---|---|---|")
	print("| no buffs < 5 %% | %.1f %% | %d sieges |" % [empty * 100.0, _store.runs("none")])
	print("| random 25-45 %% | %.1f %% | %d loadouts x %d |" % sample)
	print("| best >= 85 %% | %.1f %% | %d sieges |" % [best * 100.0, _runs_of(top)])
	print("| 25 buffs in the top %d | %d | missing: %s |" % [top_n, 25 - missing.size(), missing])
	print("")
	_print_top(top.slice(0, int(args.get("rows", "10"))))
	_print_buffs(ranked, top_n)
	var random_rate: float = sample[0]
	var measured: bool = _store.runs("none") >= 100
	var ok := (
		measured
		and empty < 0.05
		and random_rate >= 25.0
		and random_rate <= 45.0
		and best >= 0.85
		and missing.is_empty()
	)
	print("RESULT report sim=%s targets=%s" % [_store.sim_hash, "met" if ok else "MISSED"])
	quit(1 if args.has("strict") and not ok else 0)


## [mean win rate in percent, loadouts measured, runs each] of the random sample.
func _sample_rate() -> Array:
	var total := 0.0
	var measured := 0
	for index in Plan.sample_size:
		var key: String = Space.key(Space.sample(index))
		if _store.runs(key) >= Plan.sample_runs:
			total += _store.wins(key) / float(_store.runs(key))
			measured += 1
	return [total / maxi(measured, 1) * 100.0, measured, Plan.sample_runs]


func _runs_of(top: Array[String]) -> int:
	return _store.runs(top[0]) if not top.is_empty() else 0


## Buff ids in none of the `top` loadouts.
func _missing(top: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for def in BuffCatalog.all():
		var found := false
		for key in top:
			found = found or key.split("+").has(String(def.id))
		if not found:
			out.append(String(def.id))
	return out


func _print_top(rows: Array[String]) -> void:
	print("| rank | loadout | wins | sieges | sim s |")
	print("|---|---|---|---|---|")
	for rank in rows.size():
		var key := rows[rank]
		var rate: float = _store.rate(key) * 100.0
		var cells := [rank + 1, key.replace("+", " "), rate, _store.runs(key)]
		print("| %d | %s | %.0f %% | %d | %.0f |" % (cells + [_store.mean_seconds(key)]))
	print("")


## Each buff: its best rank, that loadout's rate, and what it is worth in the
## random sample (_worth).
func _print_buffs(ranked: Array[String], top_n: int) -> void:
	var worth := _worth()
	print("| buff | $ | best rank | rate there | worth in the random sample |")
	print("|---|---|---|---|---|")
	var all := BuffCatalog.all()
	for column in all.size():
		var def := all[column]
		var id := String(def.id)
		var rank := -1
		for index in ranked.size():
			if ranked[index].split("+").has(id):
				rank = index
				break
		var where := "-"
		var rate := 0.0
		if rank >= 0:
			where = "%d%s" % [rank + 1, "" if rank < top_n else " (out)"]
			rate = _store.rate(ranked[rank]) * 100.0
		var cells := [id, def.price, where, rate, worth[column] * 100.0]
		print("| %s | %d | %s | %.0f %% | %+.0f pp |" % cells)
	print("")


## Percentage points of win rate each buff adds, fitted over the random sample:
## the least-squares answer to "rate of a loadout = sum of its buffs' worth"
## (no constant: nothing bought is worth nothing). Solved by Gauss-Jordan on
## the normal equations, with a small ridge so a rare buff cannot blow up.
func _worth() -> Array[float]:
	var all := BuffCatalog.all()
	var n := all.size()
	var matrix: Array[Array] = []
	for row in n:
		var line: Array[float] = []
		line.resize(n + 1)
		line.fill(0.0)
		line[row] = 0.5
		matrix.append(line)
	for index in Plan.sample_size:
		var key: String = Space.key(Space.sample(index))
		if _store.runs(key) < Plan.sample_runs:
			continue
		var has: Array[int] = []
		var ids := key.split("+")
		for column in n:
			if ids.has(String(all[column].id)):
				has.append(column)
		var rate: float = _store.rate(key)
		for a in has:
			matrix[a][n] += rate
			for b in has:
				matrix[a][b] += 1.0
	for pivot in n:
		var scale: float = matrix[pivot][pivot]
		for column in n + 1:
			matrix[pivot][column] /= scale
		for row in n:
			if row == pivot:
				continue
			var factor: float = matrix[row][pivot]
			for column in n + 1:
				matrix[row][column] -= factor * matrix[pivot][column]
	var out: Array[float] = []
	for row in n:
		out.append(matrix[row][n])
	return out
