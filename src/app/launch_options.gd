class_name LaunchOptions
extends RefCounted
## The game's own command line (everything after `--`), parsed once:
##   --dev                    dev feedback mode (run.sh passes it)
##   --mode=watch|command|lab open straight into that mode's siege
##   --loadout=id,id          the loadout for --mode (default: nothing bought)
##   --seed=N                 every siege uses this seed (default: random)
##   --speed=N                sim seconds per real second (default 1)
##   --lab-runs=N             sieges per Lab batch (default 200)
##   --save-dir=DIR           save root (bots and tests never use the real one)
##   --autodrive=MODE         the bot plays MODE (or `showcase`) and exits 0 / 1
##   --result-file=PATH --screenshot-dir=DIR --expect-window=WxH   bot outputs
##   --feedback-dir=DIR --session-id=ID --dev-shot=PNG --dev-tag=T dev tools
## Unknown arguments are kept in `unknown` (the bot fails on them).

const MODES: Array[StringName] = [&"watch", &"command", &"lab"]
## What --autodrive= takes: every mode, and the battle screen's showcase.
const BOT_MODES: Array[StringName] = [&"watch", &"command", &"lab", &"showcase"]
const DEFAULT_LAB_RUNS := 200
const MAX_SPEED := 64.0
const VALUES: Array[String] = [
	"--mode=",
	"--loadout=",
	"--seed=",
	"--speed=",
	"--lab-runs=",
	"--save-dir=",
	"--autodrive=",
	"--result-file=",
	"--screenshot-dir=",
	"--expect-window=",
	"--feedback-dir=",
	"--session-id=",
	"--dev-shot=",
	"--dev-tag=",
]

var dev := false
var mode: StringName = &""
var loadout := Loadout.new()
## -1 = a fresh random seed per siege.
var sim_seed := -1
var speed := 1.0
var lab_runs := DEFAULT_LAB_RUNS
var save_dir := ""
var autodrive: StringName = &""
var result_file := ""
var screenshot_dir := ""
var expect_window := ""
var unknown: Array[String] = []
## What is wrong with the arguments, "" when nothing.
var problem := ""


static func parse(args: Array = OS.get_cmdline_user_args()) -> LaunchOptions:
	var out := LaunchOptions.new()
	for arg: Variant in args:
		out._take(str(arg))
	return out


## The value of the first `<prefix>value` argument, "" when absent.
static func value_of(args: Array, prefix: String) -> String:
	for arg: Variant in args:
		if str(arg).begins_with(prefix):
			return str(arg).trim_prefix(prefix)
	return ""


func _take(arg: String) -> void:
	if arg == "--dev":
		dev = true
		return
	for prefix in VALUES:
		if arg.begins_with(prefix):
			_apply(prefix, arg.trim_prefix(prefix))
			return
	unknown.append(arg)


func _apply(prefix: String, value: String) -> void:
	match prefix:
		"--mode=":
			mode = _mode(value)
		"--autodrive=":
			autodrive = _mode(value, BOT_MODES)
		"--loadout=":
			loadout = Loadout.of(Array(value.split(",", false)))
			if not loadout.is_legal():
				problem = "--loadout=%s is not a legal loadout" % value
		"--seed=":
			sim_seed = _number(prefix, value, 0.0, float(1 << 53))
		"--speed=":
			speed = _float(prefix, value, 0.1, MAX_SPEED)
		"--lab-runs=":
			lab_runs = _number(prefix, value, 1.0, 100000.0)
		"--save-dir=":
			save_dir = value
		"--result-file=":
			result_file = value
		"--screenshot-dir=":
			screenshot_dir = value
		"--expect-window=":
			expect_window = value


func _mode(value: String, known: Array[StringName] = MODES) -> StringName:
	if not known.has(StringName(value)):
		problem = "unknown mode '%s' (watch, command or lab)" % value
		return &""
	return StringName(value)


func _float(prefix: String, value: String, low: float, high: float) -> float:
	if not value.is_valid_float() or float(value) < low or float(value) > high:
		problem = "%s%s is not a number in %s..%s" % [prefix, value, low, high]
		return low
	return float(value)


func _number(prefix: String, value: String, low: float, high: float) -> int:
	if not value.is_valid_int():
		problem = "%s%s is not a whole number" % [prefix, value]
		return int(low)
	return int(_float(prefix, value, low, high))
