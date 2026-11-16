class_name HudMeters
extends Control
## The strip at the top of the battle: the army's morale (left, with the
## army's round-headed bust), the hold-the-centre ring, the village's morale
## (right, mirrored, with the hooded bust), the alarm (a bell and a bar) and
## the clock. Levels and shapes only: no word, and numbers as seven segments.

const WIDE := 1440.0
const TALL := 96.0
const TOP := 14.0
const BAR := Vector2(300.0, 26.0)
const LOW_MORALE := 0.25
const RING_R := 32.0

var army := 1.0
var village := 1.0
var alarm := 0.0
## 0..1 of the 30 seconds the army must hold the centre.
var centre := 0.0
var seconds := 0
## Real seconds the bell keeps swinging after a ring.
var ringing := 0.0

var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## This frame's levels. Redraws only when something the eye can see changed.
func show_levels(shot: SiegeSnapshot, held: float, delta: float) -> void:
	_clock += delta
	ringing = maxf(ringing - delta, 0.0)
	var moving := ringing > 0.0 or minf(shot.army_morale, shot.village_morale) < LOW_MORALE
	var same := (
		is_equal_approx(army, shot.army_morale)
		and is_equal_approx(village, shot.village_morale)
		and is_equal_approx(alarm, shot.alarm)
		and is_equal_approx(centre, held)
		and seconds == int(shot.clock_s)
	)
	army = shot.army_morale
	village = shot.village_morale
	alarm = shot.alarm
	centre = held
	seconds = int(shot.clock_s)
	if moving or not same:
		queue_redraw()


func _draw() -> void:
	var left := (size.x - WIDE) / 2.0
	var strip := Rect2(left, TOP, WIDE, TALL)
	draw_style_box(GlyphButton.box(Color(Palette.PANEL, 0.86)), strip)
	var mid := strip.get_center().y
	var x := left + 20.0
	_side(x, mid, HudGlyphs.ARMY, Palette.ARMY, army, false)
	x += 416.0 + 24.0
	_ring(Vector2(x + 38.0, mid))
	x += 76.0 + 24.0
	_side(x, mid, HudGlyphs.VILLAGE, Palette.VILLAGE, village, true)
	x += 416.0 + 36.0
	_alarm(x, mid)
	x += 192.0 + 36.0
	_time(x, mid)


## A bust, a heart and a bar. `mirrored` puts the bust on the right and
## fills the bar from the right: the two sides face each other.
func _side(
	x: float, mid: float, bust: StringName, tint: Color, level: float, mirrored: bool
) -> void:
	var low := level < LOW_MORALE
	var shake := sin(_clock * 30.0) * 3.0 if low else 0.0
	var bust_x := x + 346.0 if mirrored else x
	var heart_x := x + 308.0 if mirrored else x + 78.0
	var bar := Rect2(Vector2(x if mirrored else x + 116.0, mid - BAR.y / 2.0), BAR)
	draw_texture_rect(HudGlyphs.texture(bust), Rect2(bust_x, mid - 35.0, 70.0, 70.0), false, tint)
	var heart := Rect2(heart_x + shake, mid - 15.0, 30.0, 30.0)
	draw_texture_rect(Glyphs.texture(&"morale"), heart, false, Palette.BAD if low else Palette.INK)
	draw_rect(bar, Palette.PANEL.darkened(0.3))
	var fill := bar.size.x * clampf(level, 0.0, 1.0)
	var from := bar.end.x - fill if mirrored else bar.position.x
	var pulse := 0.6 + 0.4 * absf(sin(_clock * 8.0)) if low else 1.0
	draw_rect(Rect2(from, bar.position.y, fill, bar.size.y), Color(tint, pulse))
	draw_rect(bar, Palette.DIM, false, 2.0)


## The hold on the centre: a ring that closes, with a flag inside.
func _ring(at: Vector2) -> void:
	draw_arc(at, RING_R, 0.0, TAU, 48, Palette.PANEL.darkened(0.3), 9.0)
	draw_arc(at, RING_R, 0.0, TAU, 48, Palette.DIM, 2.0)
	if centre > 0.0:
		var end := -PI / 2.0 + TAU * clampf(centre, 0.0, 1.0)
		draw_arc(at, RING_R, -PI / 2.0, end, 48, Palette.GOOD, 9.0)
	var flag := Rect2(at - Vector2.ONE * 19.0 + Vector2(3.0, 0.0), Vector2.ONE * 38.0)
	var tint := Palette.GOOD if centre > 0.0 else Palette.DIM
	draw_texture_rect(Glyphs.texture(&"rally"), flag, false, tint)


## A bell that swings while it rings, and how far the alarm has spread.
func _alarm(x: float, mid: float) -> void:
	var loud := alarm >= 1.0
	var tint := Palette.BAD if loud else Palette.COIN
	var swing := sin(_clock * 16.0) * 5.0 * minf(ringing, 1.0)
	var bell := Rect2(x + swing, mid - 22.0, 44.0, 44.0)
	draw_texture_rect(Glyphs.texture(&"alarm"), bell, false, tint if alarm > 0.0 else Palette.DIM)
	var bar := Rect2(x + 52.0, mid - 9.0, 140.0, 18.0)
	draw_rect(bar, Palette.PANEL.darkened(0.3))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(alarm, 0.0, 1.0), bar.size.y)), tint)
	draw_rect(bar, Palette.DIM, false, 2.0)


## Minutes, two dots, seconds.
func _time(x: float, mid: float) -> void:
	draw_texture_rect(
		Glyphs.texture(&"clock"), Rect2(x, mid - 20.0, 40.0, 40.0), false, Palette.DIM
	)
	var tall := 36.0
	var at := Vector2(x + 50.0, mid - tall / 2.0)
	var minutes := seconds / 60
	SevenSegment.draw_number(self, minutes, at, tall, Palette.INK)
	at.x += SevenSegment.width(minutes, tall) + 8.0
	draw_rect(Rect2(at.x, mid - 9.0, 5.0, 5.0), Palette.INK)
	draw_rect(Rect2(at.x, mid + 4.0, 5.0, 5.0), Palette.INK)
	at.x += 13.0
	SevenSegment.draw_number(self, (seconds % 60) / 10, at, tall, Palette.INK)
	at.x += SevenSegment.width(0, tall) + SevenSegment.GAP * tall
	SevenSegment.draw_number(self, seconds % 10, at, tall, Palette.INK)
