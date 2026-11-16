extends SceneTree
## The quick balance gate (scripts/balance_gate.sh): the pinned checks of
## tools/sim/balance_pins.gd, a few hundred sieges in all.
##   measure  godot --headless -s tools/sim/balance_gate.gd -- --out=DIR
##            [--shard=0] [--shards=1]     runs this shard's arms, writes
##            DIR/shard-K.json ({arm: wins})
##   judge    godot --headless -s tools/sim/balance_gate.gd -- --judge=DIR
##            reads every shard file, prints one line per check and
##            "RESULT balance_gate PASS|FAIL"; exit 1 on FAIL
## An arm is "<loadout key>|<seeds>|<mode>": the wins of that loadout over
## seeds Store.SEED0 .. SEED0+seeds-1, mode w = Watch, c = the scripted
## commander (tools/sim/commander.gd).

const Args = preload("res://tools/sim/sim_args.gd")
const Space = preload("res://tools/sim/loadout_space.gd")
const Store = preload("res://tools/sim/balance_store.gd")
const Pins = preload("res://tools/sim/balance_pins.gd")
const Commander = preload("res://tools/sim/commander.gd")

var _wins := {}
var _failed := 0


func _init() -> void:
	var args := Args.parse()
	if args.has("judge"):
		_judge(args["judge"])
		return
	var shard := int(args.get("shard", "0"))
	var shards := int(args.get("shards", "1"))
	var mine := {}
	var arms := _arms()
	for index in arms.size():
		if index % shards == shard:
			mine[arms[index]] = _measure(arms[index])
	var dir: String = args.get("out", "")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("shard-%d.json" % shard), FileAccess.WRITE)
	file.store_string(JSON.stringify(mine))
	file.close()
	print("RESULT balance_gate measured shard=%d/%d arms=%d" % [shard, shards, mine.size()])
	quit(0)


static func _arm(key: String, seeds: int, mode := "w") -> String:
	return "%s|%d|%s" % [key, seeds, mode]


## Every arm the checks need, each once, in a fixed order.
func _arms() -> Array[String]:
	var seen := {}
	seen[_arm("none", Pins.EMPTY_SEEDS)] = true
	seen[_arm(Pins.BEST, Pins.BEST_SEEDS)] = true
	for index in Pins.SAMPLE:
		seen[_arm(Space.key(Space.sample(Pins.SAMPLE_FROM + index)), 1)] = true
	for buff: String in Pins.CONTEXTS:
		var context: String = Pins.CONTEXTS[buff]
		seen[_arm(context, Pins.SEEDS)] = true
		seen[_arm(_with(context, buff), Pins.SEEDS)] = true
	seen[_arm(Pins.COMMAND, Pins.COMMAND_SEEDS)] = true
	seen[_arm(Pins.COMMAND, Pins.COMMAND_SEEDS, "c")] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	return out


## The key of `context` with `buff` bought on top.
static func _with(context: String, buff: String) -> String:
	var loadout: Loadout = Space.from_key(context)
	loadout.ids.append(StringName(buff))
	return Space.key(loadout)


func _measure(arm: String) -> int:
	var parts := arm.split("|")
	var loadout: Loadout = Space.from_key(parts[0])
	var wins := 0
	for run in int(parts[1]):
		var sim := SiegeSim.create(loadout, Store.SEED0 + run)
		if parts[2] == "c":
			Commander.play(sim)
		else:
			sim.run_to_end()
		wins += int(sim.outcome() == SiegeSim.Outcome.WIN)
	return wins


func _judge(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file)))
		if parsed is Dictionary:
			_wins.merge(parsed)
	var empty := _arm_wins(_arm("none", Pins.EMPTY_SEEDS))
	_check(empty <= Pins.EMPTY_MAX_WINS, "no buffs: %d wins of %d" % [empty, Pins.EMPTY_SEEDS])
	var best := _arm_wins(_arm(Pins.BEST, Pins.BEST_SEEDS))
	_check(best >= Pins.BEST_MIN_WINS, "best loadout: %d wins of %d" % [best, Pins.BEST_SEEDS])
	var sample := 0
	for index in Pins.SAMPLE:
		sample += _arm_wins(_arm(Space.key(Space.sample(Pins.SAMPLE_FROM + index)), 1))
	var in_range := sample >= Pins.SAMPLE_MIN_WINS and sample <= Pins.SAMPLE_MAX_WINS
	_check(in_range, "random sample: %d wins of %d" % [sample, Pins.SAMPLE])
	for buff: String in Pins.CONTEXTS:
		var context: String = Pins.CONTEXTS[buff]
		var without := _arm_wins(_arm(context, Pins.SEEDS))
		var with := _arm_wins(_arm(_with(context, buff), Pins.SEEDS))
		_check(with > without, "%s: %d -> %d wins of %d" % [buff, without, with, Pins.SEEDS])
	_check(Pins.CONTEXTS.size() == BuffCatalog.all().size(), "a pinned context for every buff")
	var watch := _arm_wins(_arm(Pins.COMMAND, Pins.COMMAND_SEEDS))
	var led := _arm_wins(_arm(Pins.COMMAND, Pins.COMMAND_SEEDS, "c"))
	var margin := led - watch >= Pins.COMMAND_MARGIN
	_check(margin, "Command beats Watch: %d -> %d of %d" % [watch, led, Pins.COMMAND_SEEDS])
	var verdict := "PASS" if _failed == 0 else "FAIL (%d checks)" % _failed
	print("RESULT balance_gate %s sim=%s pinned=%s" % [verdict, Store.hash_of_sim(), Pins.SIM_HASH])
	quit(1 if _failed > 0 else 0)


## Wins of an arm; a missing arm fails the gate.
func _arm_wins(arm: String) -> int:
	if not _wins.has(arm):
		_check(false, "arm not measured: %s" % arm)
		return 0
	return int(_wins[arm])


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1
