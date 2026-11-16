extends GutTest
## Delight: when the army's nerve is nearly gone the screen's edge pulses
## red with a heartbeat, and when it recovers a gold flash relieves it.
## Fails when either stops firing or the edge shows while the army is fine.


func _shot(morale: float) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	shot.army_morale = morale
	return shot


func _edge() -> DangerEdge:
	var edge := DangerEdge.new()
	add_child_autofree(edge)
	return edge


func test_a_healthy_army_has_no_edge() -> void:
	var edge := _edge()
	for step in 60:
		edge.show_state(_shot(0.8), 0.05)
	assert_eq(edge.beats, 0)
	assert_eq(edge.intensity(), 0.0)


func test_a_breaking_army_pulses_and_beats() -> void:
	var edge := _edge()
	var peak := 0.0
	for step in 80:
		edge.show_state(_shot(0.12), 0.05)
		peak = maxf(peak, edge.intensity())
	assert_gt(peak, 0.3, "the edge is visibly red")
	assert_gte(edge.beats, 3, "four seconds of danger: a heartbeat each beat")
	var low := edge.intensity()
	for step in 80:
		edge.show_state(_shot(0.04), 0.05)
	assert_gte(edge.intensity() + peak, low, "deeper danger is not weaker")


func test_recovering_from_danger_flashes_gold_once() -> void:
	var edge := _edge()
	for step in 40:
		edge.show_state(_shot(0.1), 0.05)
	assert_eq(edge.reliefs, 0)
	for step in 20:
		edge.show_state(_shot(0.6), 0.05)
	assert_eq(edge.reliefs, 1)
	for step in 20:
		edge.show_state(_shot(0.7), 0.05)
	assert_eq(edge.reliefs, 1, "once per recovery")


func test_the_battle_hud_carries_the_edge_and_never_blocks_the_mouse() -> void:
	var hud := BattleHud.new()
	add_child_autofree(hud)
	hud.setup(false)
	assert_not_null(hud.edge)
	assert_eq(hud.edge.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	hud.show_state(_shot(0.05), {"speed": 2.0}, 0.1)
	assert_gt(hud.edge.intensity(), 0.0)
