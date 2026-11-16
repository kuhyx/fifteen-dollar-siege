extends RefCounted
## The four targets of kuhy's balance bar, worked out from a balance store (the
## committed sweep in tools/sim/data/ or a scratch folder): no buffs under 5 %
## wins, a random legal loadout 25-45 %, the best loadout 85 % or more, every
## buff in at least one of the top loadouts. Used by balance_report.gd (which
## prints them) and tests/test_balance_committed.gd (which holds the repo to them).

const Space = preload("res://tools/sim/loadout_space.gd")
const Plan = preload("res://tools/sim/balance_plan.gd")

const EMPTY_MAX := 0.05
const RANDOM_MIN := 25.0
const RANDOM_MAX := 45.0
const BEST_MIN := 0.85
## The empty loadout must have been measured at least this often.
const EMPTY_MIN_RUNS := 100


## {ranked, top, empty, sample, best, missing, measured, ok}: `ranked` and `top`
## are loadout keys (best first), `empty` and `best` win rates 0..1, `sample`
## [mean win rate in percent, loadouts measured, runs each], `missing` the buff
## ids in none of the top `top_n`, `ok` true when every target is met.
static func evaluate(store: RefCounted, top_n := 50, min_runs := 48) -> Dictionary:
	var ranked: Array[String] = Plan.ranking(store, min_runs)
	var top := ranked.slice(0, top_n)
	var empty: float = store.rate("none")
	var best: float = store.rate(top[0]) if not top.is_empty() else 0.0
	var sample := _sample_rate(store)
	var missing := _missing(top)
	var measured: bool = store.runs("none") >= EMPTY_MIN_RUNS
	var ok: bool = (
		measured
		and empty < EMPTY_MAX
		and sample[0] >= RANDOM_MIN
		and sample[0] <= RANDOM_MAX
		and best >= BEST_MIN
		and missing.is_empty()
	)
	return {
		"ranked": ranked,
		"top": top,
		"empty": empty,
		"sample": sample,
		"best": best,
		"missing": missing,
		"measured": measured,
		"ok": ok,
	}


## [mean win rate in percent, loadouts measured, runs each] of the random sample.
static func _sample_rate(store: RefCounted) -> Array:
	var total := 0.0
	var measured := 0
	for index in Plan.sample_size:
		var key: String = Space.key(Space.sample(index))
		if store.runs(key) >= Plan.sample_runs:
			total += store.wins(key) / float(store.runs(key))
			measured += 1
	return [total / maxi(measured, 1) * 100.0, measured, Plan.sample_runs]


## Buff ids in none of the `top` loadouts.
static func _missing(top: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for def in BuffCatalog.all():
		var found := false
		for key in top:
			found = found or key.split("+").has(String(def.id))
		if not found:
			out.append(String(def.id))
	return out
