extends GutTest
## What the camera frames at the decision, and what it follows before it: the
## last blow is not cut away at a win, and an order's flag is in the picture.

var map: SiegeMap
var plan: MapPlan


func before_each() -> void:
	map = SiegeSim.create(Loadout.new(), 3).map()
	plan = MapPlan.of(map)


func _shot(points: Array) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	for at: Vector2 in points:
		shot.ent_pos.append(at)
		shot.ent_kind.append(SiegeSnapshot.Kind.MEN)
		shot.ent_team.append(SiegeSnapshot.Team.ARMY)
		shot.ent_count.append(10)
		shot.ent_state.append(SiegeSnapshot.State.FIGHT)
		shot.ent_facing.append(0.0)
	return shot


func test_a_win_shows_the_church_and_the_army_that_took_it() -> void:
	var army := Vector2(map.bell.x - 110.0, map.bell.y + 70.0)
	var box := BattleBeats.payoff_box(true, plan, _shot([army, army + Vector2(8, 4)]))
	assert_true(box.has_point(map.bell), "the church is in")
	assert_true(box.has_point(army), "and the army with it")


func test_a_win_far_from_the_church_shows_the_church_alone() -> void:
	var army := Vector2(map.bounds.position.x + 5.0, map.bounds.end.y - 5.0)
	var box := BattleBeats.payoff_box(true, plan, _shot([army]))
	assert_true(box.has_point(map.bell))
	assert_false(box.has_point(army), "too far apart for one picture")


func test_a_loss_shows_the_army() -> void:
	var army := Vector2(220.0, 190.0)
	var box := BattleBeats.payoff_box(false, plan, _shot([army]))
	assert_true(box.has_point(army))
	assert_false(box.has_point(map.bell))


func test_the_followed_picture_takes_in_the_rally_flag() -> void:
	var shot := _shot([Vector2(200.0, 200.0)])
	var flag := Vector2(330.0, 120.0)
	assert_false(BattleCamera.action_box(shot, map).has_point(flag), "out of sight alone")
	assert_true(BattleCamera.action_box(shot, map, flag).has_point(flag), "in sight once planted")
