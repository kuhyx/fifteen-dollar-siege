class_name LaunchOptions
extends RefCounted
## The game's own command line (everything after `--`), parsed once:
##   --dev                    dev feedback mode (run.sh passes it)
##   --mode=watch|command|lab open straight into that mode's siege
##   --loadout=id,id          the loadout for --mode (default: nothing bought)
##   --screen=shop|result     with --mode: open that mode's shop, or the result
##                            of the siege --loadout and --seed play, not a siege
##   --check-state=PATH       a hand-off check: write the screen's state to PATH
##                            (and PATH.png) after a moment, then quit 0
##   --seed=N                 every siege uses this seed (default: random)
##   --speed=N                sim seconds per real second (default 2)
##   --lab-runs=N             sieges per Lab batch (default 200)
##   --save-dir=DIR           save root (bots and tests never use the real one)
##   --autodrive=MODE         the bot plays MODE (or `showcase`) and exits 0 / 1
##   --result-file=PATH --screenshot-dir=DIR --expect-window=WxH   bot outputs
##   --every=S (reel bot) --shard=I/N (buffs bot)
##   --feedback-dir=DIR --session-id=ID --dev-shot=PNG --dev-tag=T dev tools
## Unknown arguments are kept in `unknown` (the bot fails on them).

const MODES: Array[StringName] = [&"watch", &"command", &"lab"]
## What --autodrive= takes: every mode, the battle screen's showcase and the
## touch-only pass (R17).
const BOT_MODES: Array[StringName] = [
	&"watch", &"command", &"lab", &"showcase", &"touch", &"reel", &"buffs", &"fun"
]
## The screens --screen= opens straight on.
const SCREENS: Array[StringName] = [&"shop", &"result"]
const DEFAULT_LAB_RUNS := 200
## A siege lasts about 100 sim seconds and the first 30 are a march: x2 is
## about a minute of watching [design guess]. x1 to x8 are on the HUD.
const DEFAULT_SPEED := 2.0
const MAX_SPEED := 64.0
const VALUES: Array[String] = [
	"--mode=",
	"--loadout=",
	"--screen=",
	"--check-state=",
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
	"--every=",
	"--shard=",
]

var dev := false
var mode: StringName = &""
var loadout := Loadout.new()
## The screen to open on instead of a siege ("" = the siege or the hub).
var screen: StringName = &""
var check_state := ""
## -1 = a fresh random seed per siege.
var sim_seed := -1
var speed := DEFAULT_SPEED
var lab_runs := DEFAULT_LAB_RUNS
var save_dir := ""
var autodrive: StringName = &""
var result_file := ""
var screenshot_dir := ""
var expect_window := ""
## Reel bot: sim seconds between two frames. Buffs bot: "I/N", the I-th of N shards.
var every_s := 0.0
var shard := ""
var unknown: Array[String] = []
## What is wrong with the arguments, "" when nothing.
var problem := ""


static func parse(args: Array = OS.get_cmdline_user_args()) -> LaunchOptions:
	var out := LaunchOptions.new()
	for arg: Variant in args:
		out._take(str(arg))
	if out.screen != &"" and out.mode == &"" and out.problem == "":
		out.problem = "--screen=%s needs --mode" % out.screen
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
		"--screen=":
			_screen(value)
		"--check-state=":
			check_state = value
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
		"--every=":
			every_s = _float(prefix, value, 0.1, 600.0)
		"--shard=":
			shard = value


func _mode(value: String, known: Array[StringName] = MODES) -> StringName:
	if not known.has(StringName(value)):
		problem = "unknown mode '%s' (watch, command or lab)" % value
		return &""
	return StringName(value)


func _screen(value: String) -> void:
	if not SCREENS.has(StringName(value)):
		problem = "unknown screen '%s' (shop or result)" % value
		return
	screen = StringName(value)


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
