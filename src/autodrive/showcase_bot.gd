class_name ShowcaseBot
extends BotBase
## The --autodrive=showcase bot: what the stub sim cannot show yet, shown.
## It opens the REAL battle screen through Main with a scripted ShowcaseSim
## and takes one frame per group: every Kind in every State, each look of
## the army, every event's effect, both staged beats, both payoffs, and the
## 2,400-figure crowd the frame gate is measured on. Exit 0 only when every
## assert held. scripts/lib/bot.sh `bot_frames` holds its number of beats.

const GRIDS: Array[StringName] = [
	&"kinds_army", &"kinds_leaders", &"kinds_village", &"specials_a", &"specials_b"
]
const EVENT_SCENES: Array[StringName] = [&"events_ranged", &"events_melee", &"events_calls"]
## Name -> the buffs whose look it shows.
const LOOKS := {
	"plain": [],
	"knight": [&"knight_armor"],
	"football": [&"football_helmets"],
	"cardboard": [&"cardboard_armor"],
	"booze": [&"booze"],
	"bats": [&"metal_bats", &"knight_armor", &"football_helmets", &"cardboard_armor"],
}
const POSE_FRAMES := 40
## Frames of the 2,400-figure window the frame gate judges (2.5 s).
const CROWD_FRAMES := 150
const DRAWN_FRAMES := 12

## "kind:state" pairs and event names that were on screen.
var _pairs: Dictionary = {}
var _events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	shots = BotShots.new(main.options.screenshot_dir)
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
	main.options.speed = 1.0
	await frames(3)
	var options := main.options
	var window := BotReport.window_problem(options.expect_window, DisplayServer.window_get_size())
	var may_run := (
		check(BotReport.save_dir_problem(options.save_dir) == "", "no throwaway --save-dir")
		and check(options.unknown.is_empty(), "unknown arguments: %s" % [options.unknown])
		and check(window == "", window)
	)
	if may_run and await _play():
		_covered()
	finish("mode=showcase frames=%d %s" % [shots.count, " ".join(numbers)])


func _play() -> bool:
	for scene in GRIDS:
		var grid: BattleScreen = await open(scene)
		await watch(grid, POSE_FRAMES)
		if not (
			check(not grid.crowd.far, "%s: full figures up close" % scene) and await shot(scene)
		):
			return false
	if not await _looks():
		return false
	for scene in EVENT_SCENES:
		var battle: BattleScreen = await open(scene)
		var due := func() -> bool:
			return _saw(battle) and battle.sim.clock_s() >= ShowcaseScript.SHOT_S
		if not (await wait_for(due, 300, "the effects of %s" % scene) and await shot(scene)):
			return false
	return (
		await ShowcaseFar.swarm(self)
		and await ShowcaseFar.hiding(self)
		and await ShowcaseFar.orders(self)
		and await _beats()
		and await _ending(true)
		and await _ending(false)
		and await _crowd()
	)


## Opens the battle screen on a showcase scene, the way a siege opens it.
func open(scene: StringName, mode: StringName = &"watch") -> BattleScreen:
	var sim := ShowcaseSim.make(scene)
	main.mode = mode
	main.open_battle(sim)
	var battle := main.screen as BattleScreen
	if ShowcaseScript.GRIDS.has(scene) or ShowcaseScript.BOXES.has(scene):
		battle.camera.hold(ShowcaseScript.box(scene))
	await frames(3)
	check(battle.crowd.figures() == sim.heads(), "%s: a figure per head" % scene)
	BattleChecks.hud_ok(self, battle)
	return battle


## Notes what is on screen: each entity's kind and state, each live effect.
func _saw(battle: BattleScreen) -> bool:
	for i in battle.shot.entity_count():
		_pairs["%d:%d" % [battle.shot.ent_kind[i], battle.shot.ent_state[i]]] = true
	for fx in battle.effects.live:
		_events[fx.kind] = true
	return true


func watch(battle: BattleScreen, count: int) -> void:
	for i in count:
		_saw(battle)
		await get_tree().process_frame


func _looks() -> bool:
	var battle: BattleScreen = await open(&"looks")
	for look: String in LOOKS:
		var wanted := FigureLook.of(Loadout.of(LOOKS[look]))
		battle.dress(Loadout.of(LOOKS[look]))
		await frames(12)
		var men := battle.crowd.squads[0]
		var ok := (
			check(battle.crowd.look.key() == wanted.key(), "the men wear %s" % look)
			and check(men.spec == FigureLibrary.spec(0, wanted), "%s is on the squad" % look)
			and await shot("look_" + look)
		)
		if not ok:
			return false
	return true


## The staged beats: the clock stands still, Space skips, then the siege runs.
func _beats() -> bool:
	var battle: BattleScreen = await open(&"beats")
	await watch(battle, 80)
	var ufo: bool = battle.beats.current.get("kind") == SiegeEvent.UFO_ABDUCT
	var held := battle.sim.clock_s() == 0.0 and battle.hud.skip_button.is_visible_in_tree()
	if not (check(ufo and held, "the UFO beat holds the clock") and await shot("beat_ufo")):
		return false
	InputSynth.key_tap(KEY_SPACE)
	await watch(battle, 60)
	var pep: bool = battle.beats.current.get("kind") == SiegeEvent.PEP_TALK
	if not (check(pep, "Space skips to the pep talk") and await shot("beat_pep")):
		return false
	var over := func() -> bool: return not battle.beats.staging() and battle.sim.clock_s() > 0.0
	return await wait_for(over, 400, "the beats to end and the siege to start")


## A decided siege: the payoff frame is taken BEFORE the result opens.
func _ending(won: bool) -> bool:
	var tag := "payoff_win" if won else "payoff_lose"
	var battle: BattleScreen = await open(tag)
	var seen: bool = await BattleChecks.payoff_seen(self, battle)
	_saw(battle)
	var show := battle.effects.flag_raised() >= 0.99 if won else battle.crowd.squads[0].burning
	var subject := Rect2()
	for squad in battle.crowd.squads:
		if squad.team == SiegeSnapshot.Team.ARMY:
			var at := battle.map_to_canvas(squad.anchor)
			subject = Rect2(at, Vector2.ZERO) if subject == Rect2() else subject.expand(at)
	var ok := (
		check(seen, "%s shows before the result" % tag)
		and await BattleChecks.subject_stands_out(
			self,
			subject.grow(60.0),
			tag,
			BattleChecks.SUBJECT_WIN if won else BattleChecks.SUBJECT_LOSS
		)
		and check(show, "%s: the flag is up / the army burns" % tag)
		and await shot(tag)
		and await on_screen(&"result")
	)
	return ok and check((main.screen as ResultScreen).won() == won, "the result agrees")


## The frame gate on 2,400 figures, then a close look at a fight.
func _crowd() -> bool:
	var battle: BattleScreen = await open(&"crowd")
	await frames(20)
	var worst: float = await BattleChecks.smooth(self, battle, CROWD_FRAMES)
	var whole := battle.crowd.figures() == ShowcaseCrowd.FIGURES
	numbers.append("figures=%d enter_ms=%.1f" % [battle.crowd.figures(), battle.setup_ms])
	var meter := battle.meter
	numbers.append("work_worst_ms=%.2f work_mean_ms=%.2f" % [worst, meter.mean_ms()])
	numbers.append("wall_worst_ms=%.2f" % meter.worst_wall_ms)
	numbers.append("live_effects=%d drawn_ms=%.1f" % [battle.effects.live.size(), await _drawn()])
	if not (
		check(worst >= 0.0 and whole, "2,400 figures inside the frame budget")
		and await shot("crowd_2400")
	):
		return false
	battle = await open(&"fight")
	await watch(battle, 70)
	return (
		check(battle.crowd.squads[0].fallen() == 3, "the fallen lie in the fight")
		and await BattleChecks.edges_soft(self)
		and await shot("fight_close")
	)


## Mean wall milliseconds of a really drawn frame (0 headless): on Xvfb this
## is the software rasteriser's time, a number for the report, not a gate.
func _drawn() -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec()
	for i in DRAWN_FRAMES:
		await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	return (Time.get_ticks_usec() - started) / 1000.0 / DRAWN_FRAMES


func _covered() -> void:
	var kinds := SiegeSnapshot.Kind.size() * SiegeSnapshot.State.size()
	check(_pairs.size() == kinds, "showed %d of %d kind and state pairs" % [_pairs.size(), kinds])
	for kind in SiegeEvent.ALL:
		check(_events.has(kind), "the effect of %s was never on screen" % kind)
