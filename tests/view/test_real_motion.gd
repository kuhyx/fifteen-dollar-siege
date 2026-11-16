extends GutTest
## The real sim moves in 0.1 s ticks; the screen draws 60 frames a second at
## x1 to x8. Every frame's drawn place of every squad must lie on the straight
## line between the two ticks around "now minus one tick" (SnapshotTween):
## no stutter (a squad standing still between ticks) and no teleport.

const FRAME_S := 1.0 / 60.0
const SECONDS := 24.0


func _truth(seed_value: int) -> Array[PackedVector2Array]:
	var sim := SiegeSim.create(Loadout.of(SiegeFixtures.WIN_IDS), seed_value)
	var ticks: Array[PackedVector2Array] = [sim.snapshot().ent_pos]
	for tick in int(SECONDS / SiegeSim.STEP_S) + 2:
		sim.step(SiegeSim.STEP_S)
		ticks.append(sim.snapshot().ent_pos)
	return ticks


## Where the tween shows the world at `time` seconds handed to the sim.
func _worst_error_at(speed: float) -> float:
	var seed_value := SiegeFixtures.WIN_SEED
	var ticks := _truth(seed_value)
	var sim := SiegeSim.create(Loadout.of(SiegeFixtures.WIN_IDS), seed_value)
	var tween := SnapshotTween.new()
	tween.push(sim.snapshot(), 0.0)
	var time := 0.0
	var worst := 0.0
	var moved := 0
	var before := PackedVector2Array()
	while time < SECONDS:
		var dt := FRAME_S * speed
		sim.step(dt)
		time += dt
		tween.push(sim.snapshot(), dt)
		var shown := time - SiegeSim.STEP_S
		if shown < SiegeSim.STEP_S:
			continue
		var tick := floori(shown / SiegeSim.STEP_S + 1e-6)
		var fraction := clampf(shown / SiegeSim.STEP_S - tick, 0.0, 1.0)
		for i in tween.size():
			var want := ticks[tick][i].lerp(ticks[tick + 1][i], fraction)
			if ticks[tick][i].distance_to(ticks[tick + 1][i]) > SnapshotTween.TELEPORT_M:
				continue
			worst = maxf(worst, tween.position(i).distance_to(want))
			if before.size() == tween.size() and tween.position(i) != before[i]:
				moved += 1
		before = PackedVector2Array()
		for i in tween.size():
			before.append(tween.position(i))
	assert_gt(moved, 1000, "squads moved on the frames of this run")
	return worst


func test_x1_glides_on_the_line_between_ticks() -> void:
	assert_lt(_worst_error_at(1.0), 0.02)


func test_x8_glides_between_the_snapshots_it_gets() -> void:
	# One snapshot per frame spans one or two ticks: a squad that turns inside
	# them is cut by at most a third of a metre.
	assert_lt(_worst_error_at(8.0), 0.3)


func test_x1_squads_move_on_nearly_every_frame() -> void:
	var sim := SiegeSim.create(Loadout.of(SiegeFixtures.WIN_IDS), SiegeFixtures.WIN_SEED)
	var tween := SnapshotTween.new()
	tween.push(sim.snapshot(), 0.0)
	var frozen := 0
	var frames := 0
	var before := PackedVector2Array()
	var speed_before := PackedFloat32Array()
	for frame in 600:
		sim.step(FRAME_S)
		tween.push(sim.snapshot(), FRAME_S)
		if frame > 12 and before.size() == tween.size():
			for i in tween.size():
				# On the move over two ticks in a row (a squad that sets off on
				# the tick that just came was standing a moment ago).
				if tween.velocity(i).length() > 1.0 and speed_before[i] > 1.0:
					frames += 1
					frozen += 1 if tween.position(i) == before[i] else 0
		before = PackedVector2Array()
		speed_before = PackedFloat32Array()
		for i in tween.size():
			before.append(tween.position(i))
			speed_before.append(tween.velocity(i).length())
	assert_gt(frames, 1000)
	assert_eq(frozen, 0, "a squad on the move never stands still for a frame")
