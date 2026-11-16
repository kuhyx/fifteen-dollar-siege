class_name BuffsBot
extends BotBase
## The --autodrive=buffs bot: for each of the 25 buffs (this shard's share,
## --shard=I/N) one siege of that buff alone, watched until every sign of it
## (BuffSigns: chip, figure, look, effect, men, audio cue) is on the battle
## screen; then ONE frame is saved, named after the buff. Fails when a buff's
## signs never all show before the siege ends.

const SEED := 1000
const SPEED := 16.0
const LIMIT_FRAMES := 6000
## Frames a staged beat plays before the bot looks at it.
const BEAT_LOOK_FRAMES := 20


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	await frames(3)
	var options := main.options
	var window := BotReport.window_problem(options.expect_window, DisplayServer.window_get_size())
	var part := _shard(options.shard)
	var ok := (
		check(BotReport.save_dir_problem(options.save_dir) == "", "no throwaway --save-dir")
		and check(options.unknown.is_empty(), "unknown arguments: %s" % [options.unknown])
		and check(window == "", window)
		and check(part.size() == 2, "--shard=I/N needs a shard like 0/3")
	)
	var seen := 0
	if ok:
		var all := BuffCatalog.all()
		for index in all.size():
			if index % part[1] != part[0]:
				continue
			if not await _one(all[index].id):
				break
			seen += 1
	check(not ok or seen > 0, "no buff was played")
	finish("mode=buffs frames=%d buffs=%d" % [shots.count, seen])


## [I, N] of "I/N" ([] when it is none).
func _shard(text: String) -> Array[int]:
	var parts := text.split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return []
	var out: Array[int] = [int(parts[0]), int(parts[1])]
	return out if out[1] > 0 and out[0] >= 0 and out[0] < out[1] else []


## One siege of `id` alone to the moment all its signs show; one frame.
func _one(id: StringName) -> bool:
	AudioDirector.live().heard.clear()
	main.options.sim_seed = SEED
	main.options.speed = SPEED
	main.mode = &"watch"
	main.start_siege(Loadout.of([id]))
	if not await on_screen(&"battle"):
		return false
	var battle := main.screen as BattleScreen
	var why := "the siege ended first"
	for frame in LIMIT_FRAMES:
		if battle.beats.staging() and battle.beats.current.has("kind"):
			await frames(BEAT_LOOK_FRAMES)
		why = BuffSigns.missing(battle, id)
		if why == "":
			print("BUFF %s at %.1f s" % [id, battle.shot.clock_s])
			return await shot("buff_%s" % id)
		if battle.beats.staging():
			battle.beats.skip_all()
		elif battle.sim.outcome() != SiegeSim.Outcome.RUNNING:
			break
		await frames(1)
	return check(false, "%s: %s" % [id, why])
