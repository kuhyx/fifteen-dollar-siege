class_name BestLab
extends Control
## The best the Lab has found so far, on the hub: a small ring, the win rate
## as a number, and the loadout that reached it as pictograms. Before the
## first Lab run it is an empty ring: something to fill.

const RING_R := 30.0
const NUMBER_H := 46.0
const ICON_PX := 52.0

## Best win rate 0..1 (below 0: the Lab has not run yet).
var rate := -1.0
var ids: Array[StringName] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows a LabBook line ({} = none yet).
func show_line(line: Dictionary) -> void:
	rate = line.get("rate", -1.0)
	ids.assign(line.get("ids", []))
	queue_redraw()


func _draw() -> void:
	var known := rate >= 0.0
	var strip := LoadoutStrip.width(ids.size(), ICON_PX) if known else 0.0
	var number := RateRing.percent_width(rate, NUMBER_H) if known else 0.0
	var wide := RING_R * 2.0 + 16.0 + number + (24.0 + strip if known else 0.0)
	var x := (size.x - wide) / 2.0
	var middle := size.y / 2.0
	var centre := Vector2(x + RING_R, middle)
	if not known:
		draw_arc(centre, RING_R, 0.0, TAU, 48, Palette.PANEL_PRESSED, 9.0, true)
		return
	RateRing.draw(self, centre, RING_R, 9.0, rate)
	var at := Vector2(x + RING_R * 2.0 + 16.0, middle - NUMBER_H / 2.0)
	RateRing.percent(self, at, NUMBER_H, rate, Palette.INK)
	LoadoutStrip.draw(self, ids, Vector2(at.x + number + 24.0, middle - ICON_PX / 2.0), ICON_PX)
