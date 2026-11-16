class_name TickStrip
extends Control
## Every siege of a Lab batch as one tick, in the order run: a tall green
## tick is a win, a short red one a loss (colour AND height, so it reads
## without colour too). A batch too big for one tick each shares them out:
## a tick is then green by the share of its sieges that were won.

const MAX_TICKS := 400
const PER_ROW := 50
const TICK_W := 12.0
const GAP := 4.0
const ROW_H := 34.0
const PENDING := Palette.PANEL_PRESSED

## 1 = won, one byte per siege finished (LabRunner.outcomes).
var outcomes := PackedByteArray()
var total := 0
## Sieges revealed so far (the ticks after that are still grey).
var shown := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ticks drawn for a batch of `total` sieges.
func tick_count() -> int:
	return mini(total, MAX_TICKS)


## Share of tick `index`'s revealed sieges that were won (-1: none revealed).
func share_won(index: int) -> float:
	var per_tick := ceili(float(total) / maxi(tick_count(), 1))
	var first := index * per_tick
	var last := mini(mini(first + per_tick, shown), outcomes.size())
	if last <= first:
		return -1.0
	var wins := 0
	for i in range(first, last):
		wins += outcomes[i]
	return float(wins) / (last - first)


func _draw() -> void:
	var ticks := tick_count()
	var columns := mini(ticks, PER_ROW)
	var left := (size.x - (columns * (TICK_W + GAP) - GAP)) / 2.0
	for i in ticks:
		var corner := Vector2(left + (i % PER_ROW) * (TICK_W + GAP), (i / PER_ROW) * (ROW_H + GAP))
		var share := share_won(i)
		if share < 0.0:
			draw_rect(Rect2(corner + Vector2(0, ROW_H - 6.0), Vector2(TICK_W, 6.0)), PENDING)
			continue
		var high := lerpf(ROW_H * 0.35, ROW_H, share)
		var tint := Palette.BAD.lerp(Palette.GOOD, share)
		draw_rect(Rect2(corner + Vector2(0, ROW_H - high), Vector2(TICK_W, high)), tint)
