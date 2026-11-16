class_name FxMarks
extends RefCounted
## Marks that stay on the battlefield until the siege changes them: the rally
## flag the player planted, the ring that fills while the army holds the
## centre, and the flag that goes up on the church at a win.

const RALLY_POLE_M := 10.0
## The rally flag's pole is never shorter than this on screen (canvas px).
const RALLY_POLE_PX := 120.0
## Stroke width of the flag's pole and rings on screen, and its dark halo.
const RALLY_LINE_PX := 4.0
const HALO_PX := 3.0
const WIN_POLE_M := 22.0
const CENTRE_RING_M := 18.0


## How many times the flag's design size it is drawn at `view_zoom`
## (canvas pixels per metre): up, when the camera is far, so it never
## shrinks to a speck.
static func scale_for(view_zoom: float) -> float:
	return maxf(1.0, RALLY_POLE_PX / RALLY_POLE_M / view_zoom)


## The player's rally flag: it drops in with a bounce, then waves. A dark
## halo under every stroke keeps it readable on grass, yard and crowd alike.
static func rally_flag(canvas: CanvasItem, at: Vector2, age: float, view_zoom := 6.0) -> void:
	var size := scale_for(view_zoom)
	var px := 1.0 / view_zoom
	var drop := minf(age * 5.0, 1.0)
	var bounce := 1.0 + 0.25 * sin(minf(age * 5.0, 2.0) * PI) * exp(-age * 4.0)
	var top := at + Vector2(0, -RALLY_POLE_M * size * drop * bounce)
	var pulse := 1.0 + 0.12 * sin(age * 4.0)
	var ring := 2.4 * size * pulse
	var line := RALLY_LINE_PX * px
	var halo := (RALLY_LINE_PX + 2.0 * HALO_PX) * px
	canvas.draw_arc(at, ring, 0.0, TAU, 32, WorldPalette.SOOT, halo, true)
	canvas.draw_arc(at, ring, 0.0, TAU, 32, Palette.ARMY, line, true)
	canvas.draw_line(at, top, WorldPalette.SOOT, halo)
	canvas.draw_line(at, top, WorldPalette.WHITE, line)
	var cloth := Vector2(7.0, 4.4) * size
	var rim := HALO_PX * px
	banner(
		canvas, top + Vector2(-rim, -rim), cloth + Vector2(rim, rim) * 2.0, age, WorldPalette.SOOT
	)
	banner(canvas, top, cloth, age, Palette.ARMY)
	canvas.draw_circle(top, 0.9 * size + rim, WorldPalette.SOOT)
	canvas.draw_circle(top, 0.9 * size, Palette.COIN)


## The hold on the centre: a faint full ring and a bright arc for the part
## of the 30 seconds that is done.
static func centre_ring(canvas: CanvasItem, at: Vector2, held: float, radius: float) -> void:
	if held <= 0.0:
		return
	var reach := radius if radius > 0.0 else CENTRE_RING_M
	canvas.draw_arc(at, reach, 0.0, TAU, 64, Color(WorldPalette.WHITE, 0.22), 1.0)
	var end := -PI / 2.0 + TAU * clampf(held, 0.0, 1.0)
	canvas.draw_arc(at, reach, -PI / 2.0, end, 64, Palette.GOOD, 1.6)


## The army's flag on the church tower, `raised` 0..1 of the way up the pole.
static func win_flag(canvas: CanvasItem, tower: Vector2, raised: float, clock: float) -> void:
	var top := tower + Vector2(0, -WIN_POLE_M)
	canvas.draw_line(tower, top, WorldPalette.SOOT, 1.1)
	canvas.draw_line(tower, top, WorldPalette.WHITE, 0.6)
	canvas.draw_circle(top, 1.1, Palette.COIN)
	var size := Vector2(15.0, 9.0)
	var hoist := tower.lerp(top, 0.15 + 0.85 * clampf(raised, 0.0, 1.0)) + Vector2(0, 0.6)
	banner(canvas, hoist, size, clock, Palette.ARMY)
	var star_at := hoist + Vector2(size.x * 0.4, size.y * 0.5 + sin(clock * 5.0 + 1.2) * 0.5)
	BattleFx.star(canvas, star_at, 2.6, 1.1, 5, Palette.COIN)


## A flag flying to the right of `hoist`, waving in strips.
static func banner(
	canvas: CanvasItem, hoist: Vector2, size: Vector2, clock: float, tint: Color
) -> void:
	var strips := 5
	for i in strips:
		var left := float(i) / strips
		var right := float(i + 1) / strips
		var wave_left := sin(clock * 5.0 + left * 4.0) * size.y * 0.12 * left
		var wave_right := sin(clock * 5.0 + right * 4.0) * size.y * 0.12 * right
		var strip := PackedVector2Array([hoist + Vector2(size.x * left, wave_left)])
		strip.append(hoist + Vector2(size.x * right, wave_right))
		strip.append(hoist + Vector2(size.x * right, size.y + wave_right))
		strip.append(hoist + Vector2(size.x * left, size.y + wave_left))
		canvas.draw_colored_polygon(strip, tint.darkened(0.1 * (i % 2)))
