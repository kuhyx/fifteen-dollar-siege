class_name FrameMeter
extends RefCounted
## How long the battle screen's OWN work takes per frame (its _process and
## its _draw calls, not the sim, not the GPU): the number the frame gate
## judges, because it is the part this code controls on any machine.

## Milliseconds of this screen's work in the frame that just ended.
var last_ms := 0.0
## The slowest frame since `reset`.
var worst_ms := 0.0
var total_ms := 0.0
var frames := 0

var _open := 0.0
var _started := 0
var _running := false


## Starts a stretch of the screen's work (several per frame are added up).
func begin() -> void:
	_started = Time.get_ticks_usec()
	_running = true


func end() -> void:
	if _running:
		_open += (Time.get_ticks_usec() - _started) / 1000.0
		_running = false


## Closes the frame: call once per frame, before the first `begin`.
func next_frame() -> void:
	last_ms = _open
	_open = 0.0
	frames += 1
	total_ms += last_ms
	worst_ms = maxf(worst_ms, last_ms)


## Forgets what was measured (the gate calls it once the screen is loaded).
func reset() -> void:
	worst_ms = 0.0
	total_ms = 0.0
	frames = 0


func mean_ms() -> float:
	return total_ms / maxi(frames, 1)
