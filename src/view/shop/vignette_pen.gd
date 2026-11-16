class_name VignettePen
extends RefCounted
## Draws a vignette's shapes, given in stage units (192 x 128, y down, the
## ground at y = 104), onto a canvas item at any size: points are mapped to the
## item's own space and every edge is antialiased there, so a vignette is as
## sharp at 3840x2160 as at 1280x800. With no canvas it only counts, measures
## and hashes what would be drawn (tests/test_vignettes.gd).

const STAGE := Vector2(192, 128)
## The part of the stage a viewer sees: the actors fill the frame, and a walk
## on or off happens outside it.
const VIEW := Rect2(16, 21, 160, 107)

var canvas: CanvasItem
## Stage units -> the canvas item's own space.
var xform := Transform2D.IDENTITY
## Shapes drawn so far.
var count := 0
## Polygons that could not be filled (crossing or empty outlines): always 0.
var broken := 0
## A hash of everything drawn: two moments that differ give two digests.
var digest := 0
## The box around everything drawn, in stage units.
var reach := Rect2()


## A pen that fits the view into `box` of `p_canvas` (centred, on its floor).
static func fitted(p_canvas: CanvasItem, box: Rect2) -> VignettePen:
	var pen := VignettePen.new()
	pen.canvas = p_canvas
	var zoom := minf(box.size.x / VIEW.size.x, box.size.y / VIEW.size.y)
	var corner := box.position + Vector2((box.size.x - VIEW.size.x * zoom) / 2.0, 0.0)
	corner.y += box.size.y - VIEW.size.y * zoom
	pen.xform = Transform2D(Vector2(zoom, 0), Vector2(0, zoom), corner - VIEW.position * zoom)
	return pen


func disc(at: Vector2, r: float, tint: Color) -> void:
	_note(0, [at.x, at.y, r], Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0), tint)
	if canvas != null:
		canvas.draw_circle(xform * at, r * _zoom(), tint, true, -1.0, true)


## A line with round ends.
func line(a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	_note(1, [a.x, a.y, b.x, b.y, width], Rect2(a, Vector2.ZERO).expand(b).grow(width / 2.0), tint)
	if canvas == null:
		return
	var wide := width * _zoom()
	canvas.draw_line(xform * a, xform * b, tint, wide, true)
	canvas.draw_circle(xform * a, wide / 2.0, tint, true, -1.0, true)
	canvas.draw_circle(xform * b, wide / 2.0, tint, true, -1.0, true)


## A filled polygon from a flat list [x0, y0, x1, y1, ...], moved by `at`.
func poly(flat: Array, tint: Color, at := Vector2.ZERO) -> void:
	var points := PackedVector2Array()
	var box := Rect2(Vector2(flat[0], flat[1]) + at, Vector2.ZERO)
	for i in range(0, flat.size() - 1, 2):
		var point := Vector2(flat[i], flat[i + 1]) + at
		box = box.expand(point)
		points.append(xform * point)
	_note(2, flat + [at.x, at.y], box, tint)
	if Geometry2D.triangulate_polygon(points).is_empty():
		broken += 1
		return
	if canvas == null:
		return
	canvas.draw_colored_polygon(points, tint)
	if tint.a >= 1.0:
		points.append(points[0])
		canvas.draw_polyline(points, tint, 1.0, true)


func rect(box: Rect2, tint: Color) -> void:
	_note(3, [box.position.x, box.position.y, box.size.x, box.size.y], box, tint)
	if canvas != null:
		canvas.draw_rect(Rect2(xform * box.position, box.size * _zoom()), tint)


## An ellipse with radii rx, ry.
func oval(at: Vector2, rx: float, ry: float, tint: Color) -> void:
	var flat := []
	for i in 28:
		flat.append_array([cos(TAU * i / 28.0) * rx, sin(TAU * i / 28.0) * ry])
	poly(flat, tint, at)


## Part of a circle's outline, `width` thick, from angle `from` to `to` (degrees).
func arc(at: Vector2, r: float, from: float, to: float, width: float, tint: Color) -> void:
	var box := Rect2(at + Vector2.from_angle(deg_to_rad(from)) * r, Vector2.ZERO)
	for share: float in [0.25, 0.5, 0.75, 1.0]:
		box = box.expand(at + Vector2.from_angle(deg_to_rad(lerpf(from, to, share))) * r)
	_note(4, [at.x, at.y, r, from, to, width], box.grow(width / 2.0), tint)
	if canvas == null:
		return
	var wide := width * _zoom()
	canvas.draw_arc(xform * at, r * _zoom(), deg_to_rad(from), deg_to_rad(to), 24, tint, wide, true)


## A pictogram `size` stage units tall, centred on `at`, turned by `turn` radians.
func picture(picto: Pictogram, at: Vector2, size: float, turn := 0.0, fade := 0.0) -> void:
	var box := Rect2(at - Vector2.ONE * size / 2.0, Vector2.ONE * size)
	_note(5, [at.x, at.y, size, turn, fade, picto.area()], box, Color.WHITE)
	if canvas == null:
		return
	var shrink := size / Pictogram.UNITS
	var local := Transform2D(turn, Vector2.ONE * shrink, 0.0, at)
	local = local.translated_local(-Vector2.ONE * Pictogram.UNITS / 2.0)
	picto.draw_xform(canvas, xform * local, fade, Palette.PANEL)


func _zoom() -> float:
	return xform.get_scale().x


func _note(kind: int, numbers: Array, box: Rect2, tint: Color) -> void:
	reach = box if count == 0 else reach.merge(box)
	count += 1
	var rounded := [digest, kind, tint.to_rgba32()]
	for number: float in numbers:
		rounded.append(roundi(number * 8.0))
	digest = hash(rounded)
