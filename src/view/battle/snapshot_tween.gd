class_name SnapshotTween
extends RefCounted
## Smooth motion between sim snapshots. The sim moves in whole ticks; the
## screen draws every frame. This keeps the last two different snapshots and
## shows the world one tick behind the true sim time, on the straight line
## between them: a figure glides at any frame rate and any speed setting.

## A jump longer than this is a teleport, not a walk: no glide.
const TELEPORT_M := 40.0

var _from := PackedVector2Array()
var _to := PackedVector2Array()
var _from_clock := 0.0
var _to_clock := 0.0
## Sim seconds handed to SiegeSim.step so far (ahead of the snapshot clock by
## the part of a tick the sim has not run yet).
var _time := 0.0
var _started := false


## Takes this frame's snapshot; `dt_sim` is what the sim was stepped by.
func push(shot: SiegeSnapshot, dt_sim: float) -> void:
	_time = maxf(_time + dt_sim, shot.clock_s)
	if _started and shot.clock_s <= _to_clock and shot.ent_pos.size() == _to.size():
		return
	var shown := PackedVector2Array()
	for i in shot.ent_pos.size():
		var next := shot.ent_pos[i]
		var last := _to[i] if i < _to.size() else next
		shown.append(next if last.distance_to(next) > TELEPORT_M else last)
	_from = shown
	_to = shot.ent_pos.duplicate()
	_from_clock = _to_clock
	_to_clock = shot.clock_s
	_started = true


## 0 = the older snapshot, 1 = the newer one.
func alpha() -> float:
	var span := _to_clock - _from_clock
	if span <= 0.0:
		return 1.0
	return clampf((_time - SiegeSim.STEP_S - _from_clock) / span, 0.0, 1.0)


## Where entity `index` is drawn now, in map metres.
func position(index: int) -> Vector2:
	if index < 0 or index >= _to.size():
		return Vector2.ZERO
	return _from[index].lerp(_to[index], alpha())


## Its speed in metres per sim second.
func velocity(index: int) -> Vector2:
	var span := _to_clock - _from_clock
	if index < 0 or index >= _to.size() or span <= 0.0:
		return Vector2.ZERO
	return (_to[index] - _from[index]) / span


func size() -> int:
	return _to.size()
