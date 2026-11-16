class_name LabScreen
extends Control
## Lab mode: one loadout, many headless sieges. The sieges run a slice per
## frame inside a time budget (LabRunner), so the screen never freezes and
## there is no loading cover. While they run a ring fills with the win rate,
## the rate stands inside it as a number, every siege drops a tick (tall
## green = won, short red = lost) and a thin outer ring shows how far the
## batch is. Beside it: every loadout tried so far, ranked. The batch is
## saved to the Lab book when it ends. No words.
## Kept for the bot, the tests and the dev tools: `result`, `done`,
## `finished`, `home_button`, `home_pressed` and `pick_at`.

signal finished(result: Dictionary)
signal home_pressed
signal again_pressed
signal edit_pressed

## Main-thread milliseconds a frame may spend running sieges.
const FRAME_BUDGET_MS := 6
## The ticks and the ring catch up with the sieges at least this slowly, so a
## batch that is done in a blink can still be watched arriving. [design guess]
const REVEAL_S := 0.9
const RING_AT := Vector2(520, 420)
const RING_R := 200.0
const RATE_H := 120.0

var loadout := Loadout.new()
var total_runs := 0
var base_seed := 0
## {wins, runs, mean_seconds} so far; the same shape as Lab.run_batch.
var result := {"wins": 0, "runs": 0, "mean_seconds": 0.0}
var done := false
var home_button: PictoButton
var controls: EndControls
var ticks := TickStrip.new()
var ranking := LabRanking.new()
var runner: LabRunner
## Sieges whose tick is on show (it trails `result["runs"]` by a moment).
var shown_runs := 0

var _frame: ScreenFrame
var _shown := 0.0
var _shown_wins := 0


func setup(p_loadout: Loadout, p_runs: int, p_base_seed: int) -> void:
	loadout = p_loadout.duplicate()
	total_runs = p_runs
	base_seed = p_base_seed
	runner = LabRunner.new(loadout, total_runs, base_seed)
	result = runner.result
	_frame = ScreenFrame.into(self)
	ticks.total = total_runs
	ticks.outcomes = runner.outcomes
	_frame.place(ticks, Rect2(100, 700, 840, 150))
	_frame.place(ranking, Rect2(1040, 140, 840, 780))
	controls = EndControls.new()
	var corner := Vector2(RING_AT.x - EndControls.wide() / 2.0, 936)
	_frame.place(controls, Rect2(corner, Vector2(EndControls.wide(), EndControls.BUTTON.y)))
	controls.again_pressed.connect(func() -> void: again_pressed.emit())
	controls.edit_pressed.connect(func() -> void: edit_pressed.emit())
	controls.hub_pressed.connect(func() -> void: home_pressed.emit())
	home_button = controls.hub
	_frame.draw.connect(_draw_bench)


func _ready() -> void:
	ranking.show_lines(LabBook.ranked(), LabBook.key_of(loadout))
	controls.again.grab_focus()


func win_rate() -> float:
	return float(result["wins"]) / float(result["runs"]) if result["runs"] > 0 else 0.0


## The win rate of the sieges whose ticks are on show.
func shown_rate() -> float:
	return float(_shown_wins) / shown_runs if shown_runs > 0 else 0.0


func _process(delta: float) -> void:
	if runner == null:
		return
	if not runner.is_done():
		runner.work(FRAME_BUDGET_MS)
	_reveal(delta)
	if runner.is_done() and not done:
		done = true
		LabBook.record(loadout, result["wins"], result["runs"])
		ranking.show_lines(LabBook.ranked(), LabBook.key_of(loadout))
		finished.emit(result)


## What is under a canvas point (dev feedback's select tool).
func pick_at(_point: Vector2) -> Dictionary:
	return {
		"kind": "lab_result",
		"id": "win_rate",
		"state": "done" if done else "running",
		"wins": result["wins"],
		"runs": result["runs"],
	}


## Lets the ticks on show catch up with the sieges run.
func _reveal(delta: float) -> void:
	var runs: int = result["runs"]
	if shown_runs >= runs:
		return
	_shown = minf(_shown + maxf(total_runs / REVEAL_S, 30.0) * delta, runs)
	var next := mini(maxi(int(_shown), shown_runs + 1), runs)
	for i in range(shown_runs, next):
		_shown_wins += runner.outcomes[i]
	shown_runs = next
	ticks.outcomes = runner.outcomes
	ticks.shown = shown_runs
	ticks.queue_redraw()
	_frame.queue_redraw()


## The bench: the loadout, the rings, the rate, the counts (drawn on the frame).
func _draw_bench() -> void:
	LoadoutStrip.draw(_frame, loadout.ids, Vector2(160, 40), 72.0)
	var share := float(shown_runs) / maxi(total_runs, 1)
	_frame.draw_arc(RING_AT, RING_R + 44.0, 0.0, TAU, 96, Palette.PANEL, 8.0, true)
	if share > 0.0:
		var top := -PI / 2.0
		_frame.draw_arc(RING_AT, RING_R + 44.0, top, top + TAU * share, 96, Palette.ARMY, 8.0, true)
	RateRing.draw(_frame, RING_AT, RING_R, 44.0, shown_rate() if shown_runs > 0 else 0.0)
	var rate := shown_rate()
	var wide := RateRing.percent_width(rate, RATE_H)
	var at := RING_AT - Vector2(wide / 2.0, RATE_H / 2.0)
	RateRing.percent(_frame, at, RATE_H, rate, Palette.INK if shown_runs > 0 else Palette.DIM)
	var line := Vector2(100, 866)
	SevenSegment.draw_number(_frame, shown_runs, line, 36.0, Palette.INK)
	var total_w := SevenSegment.width(total_runs, 36.0)
	SevenSegment.draw_number(
		_frame, total_runs, line + Vector2(840.0 - total_w, 0), 36.0, Palette.DIM
	)
	UiPictograms.of(&"clock").draw(_frame, Rect2(line + Vector2(360, -4), Vector2(44, 44)))
	var mean := int(result["mean_seconds"])
	SevenSegment.draw_number(_frame, mean, line + Vector2(418, 0), 36.0, Palette.INK)
