extends GutTest
## The battle screen on the REAL sim, frame by frame at x48: the HUD shows what
## the snapshot says, nobody is drawn off the map, and the camera keeps the
## army in view.

const LOADOUTS := {
	"win": SiegeFixtures.WIN_IDS,
	"top1": [&"double_men", &"invisibility_potions", &"stitched_monster"],
}


func _battle(ids: Array, seed_value: int) -> BattleScreen:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of(ids)
	battle.size = Vector2(1920.0, 1080.0)
	battle.setup(SiegeSim.create(battle.loadout, seed_value), &"watch", 48.0)
	add_child_autofree(battle)
	battle.beats.skip_all()
	return battle


## Fraction of the living army heads whose squad is inside the screen.
func _in_view(battle: BattleScreen) -> float:
	var all := 0
	var seen := 0
	var window := Rect2(Vector2.ZERO, battle.size)
	for i in battle.shot.entity_count():
		if battle.shot.ent_team[i] != SiegeSnapshot.Team.ARMY or battle.shot.ent_count[i] <= 0:
			continue
		all += battle.shot.ent_count[i]
		if window.has_point(battle.map_to_canvas(battle.shot.ent_pos[i])):
			seen += battle.shot.ent_count[i]
	return seen / float(maxi(all, 1))


func test_every_loadout_keeps_hud_map_and_camera_honest() -> void:
	for name: String in LOADOUTS:
		var battle := _battle(LOADOUTS[name], 1000)
		var worst_view := 1.0
		var frames := 0
		while not battle.payoff_active and frames < 1500:
			await wait_process_frames(1)
			frames += 1
			var shot := battle.shot
			var meters := battle.hud.meters
			assert_almost_eq(meters.village, shot.village_morale, 0.0001, "%s village" % name)
			assert_almost_eq(meters.army, shot.army_morale, 0.0001, "%s army" % name)
			assert_almost_eq(meters.alarm, shot.alarm, 0.0001, "%s alarm" % name)
			assert_almost_eq(meters.centre, shot.centre_hold, 0.0001, "%s centre" % name)
			if frames % 5 == 0 and shot.clock_s > 6.0:
				worst_view = minf(worst_view, _in_view(battle))
		gut.p("REAL %s: %d frames, army in view at worst %.2f" % [name, frames, worst_view])
		assert_gt(frames, 40, "%s plays on screen" % name)
		assert_gt(worst_view, 0.5, "%s: the camera keeps most of the army in view" % name)
