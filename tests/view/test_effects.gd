extends GutTest
## Every event the sim can emit has an effect the player can see: this test
## fails the moment a name in SiegeEvent.ALL has no handler.

var effects: BattleEffects
var shot: SiegeSnapshot


func before_each() -> void:
	var map := SiegeMap.new()
	effects = BattleEffects.new()
	add_child_autofree(effects)
	effects.setup(MapPlan.of(map), null, FrameMeter.new())
	shot = SiegeSnapshot.new()
	_add(Vector2(100, 200), SiegeSnapshot.Team.ARMY)
	_add(Vector2(140, 200), SiegeSnapshot.Team.VILLAGE)
	_add(Vector2(400, 200), SiegeSnapshot.Team.VILLAGE)
	effects.shot = shot


func _add(at: Vector2, team: int) -> void:
	shot.ent_pos.append(at)
	shot.ent_team.append(team)
	shot.ent_kind.append(SiegeSnapshot.Kind.MEN)
	shot.ent_count.append(10)
	shot.ent_state.append(SiegeSnapshot.State.IDLE)
	shot.ent_facing.append(0.0)


func _event(kind: StringName) -> Dictionary:
	var event := {"kind": kind, "pos": Vector2(100, 200), "team": SiegeSnapshot.Team.ARMY}
	event["command"] = SiegeSim.Command.RALLY
	event["from"] = Vector2(60, 180)
	event["progress"] = 0.5
	return event


func test_every_event_name_has_a_visible_effect() -> void:
	assert_eq(SiegeEvent.ALL.size(), 25, "a new event name needs a handler and a showcase beat")
	for kind in SiegeEvent.ALL:
		assert_true(BattleEffects.handles(kind), "%s has no handler" % kind)
		effects.clear()
		effects.spawn(_event(kind))
		assert_gt(effects.live.size(), 0, "%s puts nothing on the battlefield" % kind)
		assert_eq(effects.live[0].kind, kind)
		assert_true(effects.live[0].painter.is_valid(), "%s has no painter" % kind)
		assert_gt(effects.live[0].life, 0.2, "%s is too short to see" % kind)


func test_every_effect_draws_through_its_whole_life_without_an_error() -> void:
	for kind in SiegeEvent.ALL:
		effects.spawn(_event(kind))
	for step in 230:
		effects.advance(0.016)
		effects.queue_redraw()
		await get_tree().process_frame
	assert_eq(effects.live.size(), 0, "every effect ends")
	assert_gt(effects.draws, 0, "and was drawn on the way")


func test_a_star_too_small_to_triangulate_is_not_drawn() -> void:
	# A wasp sting once shrank to a star the engine rejected ("Invalid polygon
	# data"): anywhere on the map, every star that IS drawn must triangulate.
	var rejected := 0
	for spot in 400:
		var at := Vector2(100.0 + spot * 1.37, 160.0 + spot * 0.61)
		for size: float in [BattleFx.MIN_STAR_M, 0.5, 1.6, 9.0]:
			var outline := BattleFx.star_outline(at, size, size * 0.4, 5)
			assert_eq(outline.size(), 10)
			if Geometry2D.triangulate_polygon(outline).is_empty():
				rejected += 1
	assert_eq(rejected, 0, "a drawn star the engine cannot fill")
	assert_true(BattleFx.star_outline(Vector2(100, 160), 0.06, 0.02, 5).is_empty(), "too small")
	assert_true(BattleFx.star_outline(Vector2.ZERO, 0.0, 0.0, 5).is_empty())


func test_an_unknown_event_is_ignored() -> void:
	effects.spawn({"kind": &"not_an_event", "pos": Vector2.ZERO})
	effects.spawn({"pos": Vector2.ZERO})
	assert_eq(effects.live.size(), 0)
	assert_false(BattleEffects.handles(&"not_an_event"))


func test_a_volley_flies_at_the_nearest_enemy() -> void:
	effects.spawn(_event(SiegeEvent.SLING_VOLLEY))
	assert_eq(effects.live[0].to, Vector2(140, 200), "the army shoots at the villagers in reach")
	var back := _event(SiegeEvent.ARROW_VOLLEY)
	back["team"] = SiegeSnapshot.Team.VILLAGE
	back["pos"] = Vector2(140, 200)
	effects.spawn(back)
	assert_eq(effects.live[1].to, Vector2(100, 200), "the village shoots back at the army")
	assert_eq(effects.live[1].tint(), Palette.VILLAGE)


func test_a_pumpkin_flies_from_its_catapult_to_the_splat() -> void:
	effects.spawn(_event(SiegeEvent.PUMPKIN_SPLAT))
	assert_eq(effects.live[0].to, Vector2(60, 180), "it comes from `from`")
	assert_eq(effects.live[0].pos, Vector2(100, 200), "and lands on `pos`")


func test_orders_plant_and_pull_the_rally_flag() -> void:
	assert_false(effects.has_rally())
	effects.spawn(_event(SiegeEvent.COMMAND))
	assert_true(effects.has_rally())
	assert_eq(effects.rally, Vector2(100, 200))
	var charge := _event(SiegeEvent.COMMAND)
	charge["command"] = SiegeSim.Command.CHARGE
	effects.spawn(charge)
	assert_false(effects.has_rally(), "a charge pulls the flag")
	effects.plant(Vector2(50, 60))
	assert_eq(
		effects.rally, Vector2(50, 60), "the screen plants it at once, before the sim answers"
	)


func test_the_sim_s_progress_and_endings_leave_marks() -> void:
	effects.spawn(_event(SiegeEvent.CENTRE_HELD))
	assert_eq(effects.centre_progress, 0.0, "the ring is the snapshot's, not the event's")
	assert_false(effects.flag_up)
	effects.spawn(_event(SiegeEvent.VICTORY))
	assert_true(effects.flag_up, "the flag goes up on the church")
	effects.spawn(_event(SiegeEvent.ALARM))
	assert_true(effects.alarmed)


func test_live_effects_are_capped() -> void:
	for i in BattleEffects.MAX_LIVE + 40:
		effects.spawn(_event(SiegeEvent.MELEE_CLASH))
	assert_eq(effects.live.size(), BattleEffects.MAX_LIVE, "a storm of events cannot eat the frame")


func test_reactions_reach_the_crowd() -> void:
	var crowd := CrowdLayer.new()
	add_child_autofree(crowd)
	crowd.setup(Rect2(0, 0, 600, 400), FigureLook.new())
	var tween := SnapshotTween.new()
	tween.push(shot, 0.0)
	crowd.sync(shot)
	crowd.draw_frame(tween, shot, 0.0, 10.0, 3.0)
	effects.crowd = crowd
	var calm := crowd.squads[0].spread_goal()
	effects.spawn(_event(SiegeEvent.SQUAD_ROUT))
	assert_gt(crowd.squads[0].spread_goal(), calm, "a rout scatters the squad")
	effects.spawn(_event(SiegeEvent.COMBUST))
	assert_true(crowd.squads[0].burning, "combust sets the army on fire")
	assert_false(crowd.squads[1].burning)
