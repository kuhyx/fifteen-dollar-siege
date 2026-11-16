extends GutTest
## The gold tally never stacks into a smear: at x16 and x64 a whole burst of
## milestones lands in one frame, and the numbers on show must still never
## overlap. The rectangles are the painter's own (FxToll.number_rect).

const SPEEDS: Array[int] = [1, 4, 16, 64]

var battle: BattleScreen


func before_each() -> void:
	battle = BattleScreen.new()
	battle.setup(SiegeSim.create(Loadout.new(), 5), &"watch", 1.0)
	add_child_autofree(battle)
	battle.set_process(false)  # the test owns the clock
	battle.flair = BattleFlair.new()  # no baseline from the real sim's first snapshot


## A snapshot of 40 village squads of 50, `fallen` heads down in all (spread evenly).
func _shot(fallen: int) -> SiegeSnapshot:
	var shot := SiegeSnapshot.new()
	for i in 40:
		shot.ent_pos.append(Vector2(100.0 + (i % 5) * 6.0, 200.0 + (i / 5) * 5.0))
		shot.ent_kind.append(SiegeSnapshot.Kind.VILLAGERS)
		shot.ent_team.append(SiegeSnapshot.Team.VILLAGE)
		shot.ent_count.append(50 - fallen / 40 - (1 if i < fallen % 40 else 0))
		shot.ent_state.append(SiegeSnapshot.State.FIGHT)
		shot.ent_facing.append(0.0)
	return shot


func _live_tolls() -> Array[BattleFx]:
	var out: Array[BattleFx] = []
	for fx in battle.effects.live:
		if fx.kind == &"toll":
			out.append(fx)
	return out


func _rect(fx: BattleFx) -> Rect2:
	return FxToll.number_rect(fx)


func test_tallies_never_overlap_at_any_speed() -> void:
	for speed in SPEEDS:
		battle.effects.clear()
		var fallen := 0
		var now := 0.0
		battle.flair.take(_shot(0), now, battle)
		var frames := 0
		var overlaps := 0
		var ticks := 0.0
		var live_most := 0
		while fallen < 1800 and frames < 400:
			frames += 1
			# The sim ticks every 0.1 s: a frame at xN carries N * 10 / 60 ticks of
			# fighting, 2 heads fall in each (a melee at its worst).
			ticks += speed * 10.0 / 60.0
			while ticks >= 1.0:
				ticks -= 1.0
				fallen += 2
				battle.flair.take(_shot(fallen), now, battle)
			now += 1.0 / 60.0
			battle.effects.advance(1.0 / 60.0)
			var tolls := _live_tolls()
			live_most = maxi(live_most, tolls.size())
			for i in tolls.size():
				for j in range(i + 1, tolls.size()):
					if _rect(tolls[i]).intersects(_rect(tolls[j])):
						overlaps += 1
		assert_eq(
			overlaps, 0, "x%d: tallies on top of each other (up to %d live)" % [speed, live_most]
		)
		assert_gt(int(battle.effects.seen.get(&"toll", 0)), 0, "x%d rang the tally" % speed)


func test_the_number_on_show_is_the_latest_milestone() -> void:
	battle.flair.take(_shot(0), 0.0, battle)
	battle.flair.take(_shot(52), 0.01, battle)
	battle.flair.take(_shot(122), 0.02, battle)
	var tolls := _live_tolls()
	assert_gt(tolls.size(), 0)
	var shown := 0
	for fx in tolls:
		shown = maxi(shown, int(fx.data.get("total", 0)))
	assert_eq(shown, 10 * int(battle.flair.toll.fallen[SiegeSnapshot.Team.VILLAGE] / 10))
