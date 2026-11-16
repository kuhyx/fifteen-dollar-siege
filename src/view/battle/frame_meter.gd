class_name FrameMeter
extends RefCounted
## How long the battle screen's OWN work takes per frame (its _process and
## its _draw calls, not the sim, not the GPU): the number the frame gate
## judges, because it is the part this code controls on any machine.
## With `cpu_clock` on (the bots, on Linux) each stretch is also timed on the
## thread's CPU clock, and a frame counts as the SMALLER of the two: a stall
## the machine causes (another process on the core) stretches the wall time
## but not the CPU time, so a busy machine cannot fail the gate, and a hitch
## of the game's own making still does (lesson L12).

## The kernel's per-thread run time, in nanoseconds (first field).
const CPU_CLOCK := "/proc/thread-self/schedstat"

## Also time on the thread's CPU clock (costs two file reads per stretch).
var cpu_clock := false
## Wall milliseconds of this screen's work in the frame that just ended.
var last_ms := 0.0
## The slowest frame since `reset`, as judged (see above).
var worst_ms := 0.0
## The slowest frame since `reset` by the wall clock alone.
var worst_wall_ms := 0.0
var total_ms := 0.0
var total_cpu_ms := 0.0
var frames := 0

var _open := 0.0
var _open_cpu := 0.0
var _started := 0
var _cpu_started := 0.0
var _running := false


## Milliseconds this thread has run so far (-1 where the clock is missing:
## not Linux).
static func cpu_ms() -> float:
	var file := FileAccess.open(CPU_CLOCK, FileAccess.READ)
	if file == null:
		return -1.0
	return float(file.get_line().get_slice(" ", 0)) / 1000000.0


## Starts a stretch of the screen's work (several per frame are added up).
func begin() -> void:
	if cpu_clock:
		_cpu_started = cpu_ms()
	_started = Time.get_ticks_usec()
	_running = true


func end() -> void:
	if not _running:
		return
	_open += (Time.get_ticks_usec() - _started) / 1000.0
	if cpu_clock:
		_open_cpu += cpu_ms() - _cpu_started
	_running = false


## Closes the frame: call once per frame, before the first `begin`.
func next_frame() -> void:
	var judged := minf(_open, _open_cpu) if cpu_clock else _open
	last_ms = _open
	frames += 1
	total_ms += _open
	total_cpu_ms += _open_cpu
	worst_ms = maxf(worst_ms, judged)
	worst_wall_ms = maxf(worst_wall_ms, _open)
	_open = 0.0
	_open_cpu = 0.0


## Forgets what was measured (the gate calls it once the screen is loaded).
func reset() -> void:
	worst_ms = 0.0
	worst_wall_ms = 0.0
	total_ms = 0.0
	total_cpu_ms = 0.0
	frames = 0
	_open = 0.0
	_open_cpu = 0.0


## The mean frame: by the CPU clock when it is on (exact over many frames,
## whatever else the machine does), else by the wall clock.
func mean_ms() -> float:
	return (total_cpu_ms if cpu_clock else total_ms) / maxi(frames, 1)
