class_name LabScreen
extends Control
## Lab mode: one loadout, many headless sieges, the win rate as a ring and a
## number (percent), the runs done as a bar and a number, the mean time to the
## decision as seconds. A few sieges run per frame inside a time budget, so the
## screen never hitches and there is no loading cover.
## SCAFFOLD view: the view agent replaces it and keeps `result`, `done`,
## `finished`, `home_button`, `home_pressed` and `pick_at`.

signal finished(result: Dictionary)
signal home_pressed

## Main-thread milliseconds a frame may spend running sieges.
const FRAME_BUDGET_MS := 6
const RING_R := 230.0

var loadout := Loadout.new()
var total_runs := 0
var base_seed := 0
## {wins, runs, mean_seconds} so far; the same shape as Lab.run_batch.
var result := {"wins": 0, "runs": 0, "mean_seconds": 0.0}
var done := false
var home_button: GlyphButton

var _seconds := 0.0


func setup(p_loadout: Loadout, p_runs: int, p_base_seed: int) -> void:
	loadout = p_loadout.duplicate()
	total_runs = p_runs
	base_seed = p_base_seed
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home_button = GlyphButton.make(&"home", "Back to the hub", 140.0)
	home_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	home_button.offset_left = -70.0
	home_button.offset_right = 70.0
	home_button.offset_top = -180.0
	home_button.offset_bottom = -40.0
	home_button.pressed.connect(func() -> void: home_pressed.emit())
	add_child(home_button)


func _ready() -> void:
	home_button.grab_focus()


func win_rate() -> float:
	return float(result["wins"]) / float(result["runs"]) if result["runs"] > 0 else 0.0


func _process(_delta: float) -> void:
	if done:
		return
	var started := Time.get_ticks_msec()
	while result["runs"] < total_runs and Time.get_ticks_msec() - started < FRAME_BUDGET_MS:
		var one := Lab.run_one(loadout, base_seed + int(result["runs"]))
		if one["outcome"] == SiegeSim.Outcome.WIN:
			result["wins"] += 1
		_seconds += one["seconds"]
		result["runs"] += 1
		result["mean_seconds"] = _seconds / result["runs"]
	queue_redraw()
	if result["runs"] >= total_runs:
		done = true
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


func _draw() -> void:
	var centre := Vector2(size.x / 2.0, size.y * 0.4)
	var rate := win_rate()
	draw_arc(centre, RING_R, 0.0, TAU, 96, Palette.BAD.darkened(0.4), 44.0)
	if rate > 0.0:
		draw_arc(centre, RING_R, -PI / 2.0, -PI / 2.0 + TAU * rate, 96, Palette.GOOD, 44.0)
	var percent := roundi(rate * 100.0)
	var height := 130.0
	var wide := SevenSegment.width(percent, height) + height * 0.8
	var left := centre.x - wide / 2.0
	SevenSegment.draw_number(
		self, percent, Vector2(left, centre.y - height / 2.0), height, Palette.INK
	)
	var mark := Vector2(left + wide - height * 0.56, centre.y - height / 2.0)
	SevenSegment.draw_percent(self, mark, height, Palette.INK)
	_draw_progress(Vector2(size.x / 2.0 - 400.0, size.y * 0.4 + RING_R + 70.0))


## Runs done / asked as a bar plus both numbers; mean seconds beside a clock.
func _draw_progress(at: Vector2) -> void:
	var bar := Rect2(at, Vector2(800, 26))
	var share := float(result["runs"]) / float(maxi(total_runs, 1))
	draw_rect(bar, Palette.PANEL)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), Palette.ARMY)
	draw_rect(bar, Palette.DIM, false, 2.0)
	SevenSegment.draw_number(self, int(result["runs"]), at + Vector2(0, 44), 40.0, Palette.INK)
	var total_w := SevenSegment.width(total_runs, 40.0)
	SevenSegment.draw_number(self, total_runs, at + Vector2(800.0 - total_w, 44), 40.0, Palette.DIM)
	var clock := Rect2(at + Vector2(330, 40), Vector2(48, 48))
	draw_texture_rect(Glyphs.texture(&"clock"), clock, false, Palette.DIM)
	var mean := int(result["mean_seconds"])
	SevenSegment.draw_number(self, mean, at + Vector2(392, 44), 40.0, Palette.INK)
