class_name FunBot
extends BotBase
## The --autodrive=fun bot: one real siege per delight of the fun pass
## (DOCS-design-fun.md), watched until the delight is ON SCREEN, then one
## frame named after it. Fails when a delight never shows before its siege
## ends, so a delight that stops firing turns the gate red.

const SEED := 1000
const SPEED := 16.0
const LIMIT_FRAMES := 9000
## Frames a delight plays before its frame is taken (it has grown by then).
const LOOK_FRAMES := 12
const SCENES := [
	[&"shake_monster", [&"stitched_monster"], 1000],
	[&"reveal", [&"invisibility_potions"], 1000],
	[&"tally", SiegeFixtures.WIN_IDS, SiegeFixtures.WIN_SEED],
	[&"finale", SiegeFixtures.WIN_IDS, SiegeFixtures.WIN_SEED],
	[&"last_stand", SiegeFixtures.LOSE_IDS, SiegeFixtures.LOSE_SEED],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	await frames(3)
	var ok := (
		check(BotReport.save_dir_problem(main.options.save_dir) == "", "no throwaway --save-dir")
		and check(main.options.unknown.is_empty(), "unknown arguments: %s" % [main.options.unknown])
	)
	for scene: Array in SCENES:
		if not ok:
			break
		ok = await _scene(scene[0], Loadout.of(scene[1]), scene[2])
	finish("mode=fun frames=%d" % shots.count)


## The condition under which a delight is on screen, read from the battle.
static func showing(battle: BattleScreen, tag: StringName) -> bool:
	match tag:
		&"shake_monster":
			return (
				battle.flair.impact.trauma > 0.4 and _kind_live(battle, SiegeSnapshot.Kind.MONSTER)
			)
		&"reveal":
			return _live(battle, &"reveal") > 0
		&"tally":
			return _live(battle, &"toll") > 0 and _live(battle, &"pop") > 1
		&"finale":
			return battle.payoff_active and _live(battle, &"firework") >= 3
		&"last_stand":
			return battle.hud.edge.intensity() > 0.7 and battle.hud.edge.beats > 0
	return false


static func _live(battle: BattleScreen, kind: StringName) -> int:
	var count := 0
	for fx in battle.effects.live:
		if fx.kind == kind:
			count += 1
	return count


static func _kind_live(battle: BattleScreen, kind: int) -> bool:
	for squad in battle.crowd.squads:
		if squad.kind == kind and squad.alive > 0:
			return true
	return false


func _scene(tag: StringName, loadout: Loadout, seed_value: int) -> bool:
	main.options.sim_seed = seed_value
	main.options.speed = SPEED
	main.mode = &"watch"
	main.start_siege(loadout)
	if not await on_screen(&"battle"):
		return false
	var battle := main.screen as BattleScreen
	for frame in LIMIT_FRAMES:
		if main.screen != battle:
			break
		if battle.beats.staging():
			battle.beats.skip_all()
		if showing(battle, tag):
			print("FUN %s at %.1f s" % [tag, battle.shot.clock_s])
			await frames(LOOK_FRAMES)
			return await shot("fun_%s" % tag)
		await frames(1)
	return check(false, "%s never showed on screen" % tag)
