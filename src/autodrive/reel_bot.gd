class_name ReelBot
extends BotBase
## The --autodrive=reel bot: watches ONE siege (--mode, --loadout, --seed,
## --speed) and saves a frame every --every= sim seconds, then the payoff.
## Not a gate: scripts/reel.sh uses it to LOOK at what the sim does on screen.
## Each frame prints a REEL line with the numbers the HUD must agree with.

const DEFAULT_EVERY_S := 5.0
const LIMIT_FRAMES := 9000
## Frames after the payoff's first frame, for the second one (the finale).
const PAYOFF_LATE_FRAMES := 24


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	await frames(3)
	var options := main.options
	var ok := (
		check(BotReport.save_dir_problem(options.save_dir) == "", "no throwaway --save-dir")
		and check(options.unknown.is_empty(), "unknown arguments: %s" % [options.unknown])
		and check(options.mode != &"", "--mode=watch or command is needed")
	)
	if ok:
		await _watch(options.every_s if options.every_s > 0.0 else DEFAULT_EVERY_S)
	finish("mode=reel frames=%d" % shots.count)


func _watch(every_s: float) -> void:
	if not await on_screen(&"battle"):
		return
	var battle := main.screen as BattleScreen
	var next_s := 0.0
	var limit := LIMIT_FRAMES
	while battle.sim.outcome() == SiegeSim.Outcome.RUNNING and limit > 0:
		limit -= 1
		if battle.beats.staging() and battle.beats.current.has("kind"):
			await frames(20)
			await _frame(battle, "beat")
			battle.beats.skip()
		elif battle.sim.clock_s() >= next_s:
			next_s += every_s
			await _frame(battle, "t%03d" % roundi(battle.sim.clock_s()))
		await frames(1)
	if check(limit > 0, "the siege never ended"):
		await BattleChecks.payoff_seen(self, battle)
		await _frame(battle, "payoff")
		await frames(PAYOFF_LATE_FRAMES)
		await _frame(battle, "payoff_late")


func _frame(battle: BattleScreen, label: String) -> void:
	var shot_now := battle.shot
	print(
		(
			"REEL %s t=%.1f alarm=%.2f village=%.2f army=%.2f hold=%.2f entities=%d"
			% [
				label,
				shot_now.clock_s,
				shot_now.alarm,
				shot_now.village_morale,
				shot_now.army_morale,
				shot_now.centre_hold,
				shot_now.entity_count()
			]
		)
	)
	await shot(label)
