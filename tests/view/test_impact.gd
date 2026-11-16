extends GutTest
## Delight: heavy blows shake the camera and stop the world for a heartbeat.
## Fails when a heavy event stops kicking, a light one starts, or the shake
## leaks into the map-to-canvas mapping the bot and the player click through.


class OneShotSim:
	extends SiegeSim
	var inner: SiegeSim
	var opening: Array[Dictionary] = []

	func map() -> SiegeMap:
		return inner.map()

	func step(dt: float) -> void:
		inner.step(dt)

	func command(kind: int, pos: Vector2) -> void:
		inner.command(kind, pos)

	func snapshot() -> SiegeSnapshot:
		var shot := inner.snapshot()
		shot.events.append_array(opening)
		opening = []
		return shot

	func outcome() -> int:
		return inner.outcome()

	func clock_s() -> float:
		return inner.clock_s()

	func state_hash() -> int:
		return inner.state_hash()


func _blow(kind: StringName) -> Dictionary:
	return {"kind": kind, "pos": Vector2(300, 300), "team": SiegeSnapshot.Team.ARMY}


func test_heavy_events_kick_and_light_ones_do_not() -> void:
	for kind: StringName in BattleImpact.HEAVY:
		var impact := BattleImpact.new()
		impact.on_event(_blow(kind))
		assert_gt(impact.trauma, 0.0, "%s must shake the camera" % kind)
	for kind: StringName in [SiegeEvent.MELEE_CLASH, SiegeEvent.SLING_VOLLEY, SiegeEvent.BELL_RING]:
		var impact := BattleImpact.new()
		impact.on_event(_blow(kind))
		assert_eq(impact.trauma, 0.0, "%s is too common to shake" % kind)


func test_the_shake_moves_the_view_then_settles_and_hold_ends() -> void:
	var impact := BattleImpact.new()
	impact.on_event(_blow(SiegeEvent.MONSTER_SMASH))
	assert_true(impact.frozen(), "a heavy blow holds the world for a moment")
	var moved := 0.0
	for step in 12:
		moved = maxf(moved, impact.offset(step * 0.013).length())
	assert_gt(moved, 3.0, "the view visibly moves")
	assert_lt(moved, BattleImpact.MAX_PX + 0.01, "and never past the cap")
	for step in 200:
		impact.update(0.016)
	assert_false(impact.frozen(), "the hold is a heartbeat, not a pause")
	assert_eq(impact.offset(1.0), Vector2.ZERO, "it settles")


func test_blows_pile_up_but_stay_under_the_cap() -> void:
	var impact := BattleImpact.new()
	for i in 40:
		impact.on_event(_blow(SiegeEvent.CART_CRASH))
	assert_lte(impact.trauma, 1.0)
	assert_lte(impact.hold, BattleImpact.MAX_HOLD_S)


func test_the_screen_shakes_on_a_smash_and_the_mapping_follows() -> void:
	var sim := OneShotSim.new()
	sim.inner = SiegeSim.create(Loadout.new(), 5)
	sim.opening.append(_blow(SiegeEvent.MONSTER_SMASH))
	var battle := BattleScreen.new()
	battle.setup(sim, &"watch", 1.0)
	add_child_autofree(battle)
	battle.set_process(false)  # the test owns the clock: no real-time frames on top
	assert_gt(battle.flair.impact.trauma, 0.0, "the smash reached the impact")
	battle._process(0.016)
	var offset := battle.flair.impact.offset(battle._clock)
	var plain := battle.camera.to_canvas(Vector2(200, 200))
	assert_eq(battle.map_to_canvas(Vector2(200, 200)), plain + offset)
	assert_eq(battle.canvas_to_map(plain + offset).snappedf(0.01), Vector2(200, 200))


func test_every_fun_cue_is_on_the_sheet_and_plays_through_funcue() -> void:
	for cue: StringName in AudioCues.FUN:
		assert_true(AudioCues.CUES.has(cue), "%s needs a cue row" % cue)
	FunCue.play(&"fun_toll")
	assert_true(true, "no director: a quiet no-op")


func test_a_melee_full_of_smashes_does_not_strangle_the_sim() -> void:
	# A monster smashes on almost every sim step. The world may be held for a
	# heartbeat at a blow, never most of the time, and the camera must calm
	# between blows: x16 may not play like x3.
	var impact := BattleImpact.new()
	var running := 0
	var calm := 0
	for frame in 300:
		impact.on_event(_blow(SiegeEvent.MONSTER_SMASH))
		if not impact.frozen():
			running += 1
		if impact.trauma < 0.3:
			calm += 1
		impact.update(1.0 / 60.0)
	assert_gte(running, 255, "the sim steps on at least 85 % of the frames")
	assert_gt(calm, 60, "and the camera settles between blows")
