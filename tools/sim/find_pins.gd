extends SceneTree
## Picks the pins of the balance gate from what the search measured for the
## current sim, and prints tools/sim/balance_pins.gd (--write saves it):
##   the best loadout found; for every buff the measured context (a loadout
##   without it) where buying it adds the most wins over the first SEEDS
##   seeds; the loadout where the scripted commander beats Watch by the most.
##   godot --headless -s tools/sim/find_pins.gd -- [--write] [--store=DIR]
## Run scripts/balance_search.sh and scripts/balance_lift.sh first: a context
## counts only when both the loadout and the loadout plus the buff have SEEDS
## sieges in the cache. Exit 1 when a buff has no context that helps.

const Args = preload("res://tools/sim/sim_args.gd")
const Space = preload("res://tools/sim/loadout_space.gd")
const Store = preload("res://tools/sim/balance_store.gd")
const Plan = preload("res://tools/sim/balance_plan.gd")
const Commander = preload("res://tools/sim/commander.gd")
const OUT := "res://tools/sim/balance_pins.gd"
const SEEDS := 12
const COMMAND_SEEDS := 16
const SAMPLE := 40
const SOLID := 2
const PREFERRED: Array[String] = ["double_men", "fifty_men", "shotgun+trumpet_boy+wasps"]
const COMMAND_TRIES: Array[String] = [
	"double_men", "double_men+prep_hour", "fifty_men+shotgun", "double_men+football_helmets"
]
const TEMPLATE := """extends RefCounted
## The pinned checks of the quick balance gate (scripts/balance_gate.sh,
## tools/sim/balance_gate.gd). WRITTEN BY tools/sim/find_pins.gd from the
## balance search of sim SIM_HASH: after a tuning change run the search again
## and then find_pins.gd --write. Every check uses seeds 1000, 1001, ...
##   EMPTY     the empty loadout wins at most EMPTY_MAX_WINS of EMPTY_SEEDS (< 5 %%)
##   BEST      the best loadout found wins BEST_MIN_WINS of BEST_SEEDS (85 %%)
##   SAMPLE    SAMPLE loadouts of the random sample from SAMPLE_FROM on, one
##             siege each, win 25-45 %%
##   CONTEXTS  buff -> a loadout without it; buying the buff on top wins more
##             of the first SEEDS sieges
##   COMMAND   the scripted commander wins at least COMMAND_MARGIN more of
##             COMMAND_SEEDS sieges of this loadout than Watch mode does

const SIM_HASH := "%s"
const SEEDS := 12
const EMPTY_SEEDS := 40
const EMPTY_MAX_WINS := 1
const BEST := "%s"
const BEST_SEEDS := 30
const BEST_MIN_WINS := 26
const SAMPLE := 40
const SAMPLE_FROM := %d
const SAMPLE_MIN_WINS := 10
const SAMPLE_MAX_WINS := 18
const CONTEXTS := {
%s
}
const COMMAND := "%s"
const COMMAND_SEEDS := 16
const COMMAND_MARGIN := 2
"""


func _init() -> void:
	var args := Args.parse()
	var store: RefCounted = Store.open(args.get("store", Store.default_root()))
	var ranked: Array[String] = Plan.ranking(store, 96)
	var lines: Array[String] = []
	var missing: Array[String] = []
	for def in BuffCatalog.all():
		var context := _context(store, String(def.id))
		if context == "":
			missing.append(String(def.id))
		else:
			lines.append('\t"%s": "%s",' % [def.id, context])
	var command := _command()
	var best := ranked[0] if not ranked.is_empty() else "none"
	var text := TEMPLATE % [store.sim_hash, best, _sample_from(store), "\n".join(lines), command]
	if args.has("write") and missing.is_empty():
		var file := FileAccess.open(OUT, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	print(text)
	print("RESULT find_pins sim=%s missing=%s" % [store.sim_hash, missing])
	quit(0 if missing.is_empty() else 1)


## The measured loadout without `buff` where adding it wins more of the first
## SEEDS sieges ("" when it helps nowhere): a PREFERRED one when it helps there
## by SOLID wins or more (few distinct contexts keep the gate quick), else the
## one where it helps most.
func _context(store: RefCounted, buff: String) -> String:
	var best := ""
	var best_margin := 0
	for key: String in store.results:
		if key == "none" or not key.split("+").has(buff):
			continue
		var ids := Array(key.split("+"))
		ids.erase(buff)
		var context := "+".join(ids) if not ids.is_empty() else "none"
		var with: int = store.wins_in_first(key, SEEDS)
		var without: int = store.wins_in_first(context, SEEDS)
		if with < 0 or without < 0:
			continue
		var margin := with - without
		if margin >= SOLID and PREFERRED.has(context):
			return context
		if margin > best_margin or (margin == best_margin and margin > 0 and context < best):
			best_margin = margin
			best = context
	return best


## Where the pinned sample starts: the run of SAMPLE consecutive loadouts of
## the random sample whose first sieges win nearest to the whole sample's rate
## (40 single sieges are a coarse ruler; this run is the representative one).
func _sample_from(store: RefCounted) -> int:
	var first: Array[int] = []
	var total := 0.0
	for index in Plan.sample_size:
		var key: String = Space.key(Space.sample(index))
		first.append(maxi(store.wins_in_first(key, 1), 0))
		total += store.rate(key)
	var want := total / Plan.sample_size * SAMPLE
	var best := 0
	var best_gap := INF
	for start in Plan.sample_size - SAMPLE + 1:
		var wins := 0
		for index in range(start, start + SAMPLE):
			wins += first[index]
		if absf(wins - want) < best_gap:
			best_gap = absf(wins - want)
			best = start
	return best


## The loadout of COMMAND_TRIES where the commander adds the most wins.
func _command() -> String:
	var best := COMMAND_TRIES[0]
	var best_margin := -99
	for key in COMMAND_TRIES:
		var loadout: Loadout = Space.from_key(key)
		var margin := 0
		for run in COMMAND_SEEDS:
			var led := SiegeSim.create(loadout, Store.SEED0 + run)
			var watched := SiegeSim.create(loadout, Store.SEED0 + run)
			margin += int(Commander.play(led) == SiegeSim.Outcome.WIN)
			margin -= int(watched.run_to_end() == SiegeSim.Outcome.WIN)
		if margin > best_margin:
			best_margin = margin
			best = key
	return best
