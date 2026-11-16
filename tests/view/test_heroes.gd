extends GutTest
## The army's single special figures wear a ring and a pointer: the effects
## layer redraws for them every frame, and only the right kinds wear one.


func _crowd(kinds: Array) -> CrowdLayer:
	var crowd := CrowdLayer.new()
	add_child_autofree(crowd)
	crowd.setup(Rect2(0, 0, 600, 400), FigureLook.new())
	var shot := SiegeSnapshot.new()
	shot.clock_s = SiegeSim.STEP_S
	for i in kinds.size():
		shot.ent_kind.append(kinds[i])
		shot.ent_team.append(SiegeSnapshot.Team.ARMY)
		shot.ent_count.append(1)
		shot.ent_state.append(SiegeSnapshot.State.IDLE)
		shot.ent_pos.append(Vector2(100.0 + 10.0 * i, 100.0))
		shot.ent_facing.append(0.0)
	crowd.sync(shot)
	return crowd


func test_only_the_single_specials_are_heroes() -> void:
	var crowd := _crowd([SiegeSnapshot.Kind.MEN, SiegeSnapshot.Kind.EMPEROR])
	assert_false(FxHeroes.is_hero(crowd.squads[0]))
	assert_true(FxHeroes.is_hero(crowd.squads[1]))
	assert_true(FxHeroes.any(crowd))
	assert_false(FxHeroes.any(_crowd([SiegeSnapshot.Kind.MEN, SiegeSnapshot.Kind.MOOSE])))


func test_every_hero_kind_is_in_the_contract() -> void:
	for kind in FxHeroes.KINDS:
		assert_true(kind in SiegeSnapshot.Kind.values())
