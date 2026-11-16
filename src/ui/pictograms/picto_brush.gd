class_name PictoBrush
extends RefCounted
## Draws shapes onto a Pictogram in its 128-unit square. `ink` picks a colour
## (a new layer in front of the others), then shapes are added; `cut` punches a
## shape out of the current layer only. Angles are degrees, 0 = right, 90 =
## down. Curves get just enough segments for their size.

var picture := Pictogram.new()

var _glyph: VectorGlyph


func ink(tint: Color) -> void:
	_glyph = picture.layer(tint)


## A polygon from a flat list: [x0, y0, x1, y1, ...].
func poly(flat: Array, cut := false) -> void:
	var points := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		points.append(Vector2(flat[i], flat[i + 1]))
	_glyph.polygon(points, cut)


func disc(x: float, y: float, r: float, cut := false) -> void:
	oval(x, y, r, r, 0.0, cut)


## An ellipse with radii rx, ry, turned by `turn` degrees.
func oval(x: float, y: float, rx: float, ry: float, turn := 0.0, cut := false) -> void:
	var count := _segments(maxf(rx, ry))
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count
		var spoke := Vector2(cos(angle) * rx, sin(angle) * ry).rotated(deg_to_rad(turn))
		points.append(Vector2(x, y) + spoke)
	_glyph.polygon(points, cut)


## A band `width` thick along the circle of radius r, from angle `from` to `to`.
func arc(x: float, y: float, r: float, from: float, to: float, width: float, cut := false) -> void:
	var span := deg_to_rad(to - from)
	var count := maxi(3, ceili(_segments(r) * absf(span) / TAU))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in count + 1:
		var spoke := Vector2.from_angle(deg_to_rad(from) + span * i / count)
		outer.append(Vector2(x, y) + spoke * (r + width / 2.0))
		inner.append(Vector2(x, y) + spoke * (r - width / 2.0))
	inner.reverse()
	outer.append_array(inner)
	_glyph.polygon(outer, cut)


## A whole ring, `width` thick (two half arcs: no polygon has a hole).
func ring(x: float, y: float, r: float, width: float, cut := false) -> void:
	arc(x, y, r, 0.0, 180.0, width, cut)
	arc(x, y, r, 180.0, 360.0, width, cut)


## A line with round ends.
func bar(x1: float, y1: float, x2: float, y2: float, width: float, cut := false) -> void:
	var a := Vector2(x1, y1)
	var b := Vector2(x2, y2)
	var r := width / 2.0
	var along := (b - a).angle()
	var count := maxi(3, _segments(r) / 2)
	var points := PackedVector2Array()
	for i in count + 1:
		points.append(b + Vector2.from_angle(along - PI / 2.0 + PI * i / count) * r)
	for i in count + 1:
		points.append(a + Vector2.from_angle(along + PI / 2.0 + PI * i / count) * r)
	_glyph.polygon(points, cut)


## A rectangle, with rounded corners when `radius` is given.
func box(x: float, y: float, w: float, h: float, radius := 0.0, cut := false) -> void:
	if radius <= 0.0:
		_glyph.rect(x, y, w, h, cut)
		return
	var r := minf(radius, minf(w, h) / 2.0)
	var count := maxi(2, _segments(r) / 4)
	var centres: Array[Vector2] = [
		Vector2(x + w - r, y + r),
		Vector2(x + w - r, y + h - r),
		Vector2(x + r, y + h - r),
		Vector2(x + r, y + r)
	]
	var points := PackedVector2Array()
	for corner in 4:
		for i in count + 1:
			var angle := PI / 2.0 * (corner - 1) + PI / 2.0 * i / count
			points.append(centres[corner] + Vector2.from_angle(angle) * r)
	_glyph.polygon(points, cut)


## Round-ended lines through the points of a flat list [x0, y0, x1, y1, ...].
func path(flat: Array, width: float, cut := false) -> void:
	for i in range(0, flat.size() - 3, 2):
		bar(flat[i], flat[i + 1], flat[i + 2], flat[i + 3], width, cut)


## A star of `tips` points; `turn` -90 puts one tip straight up.
func star(x: float, y: float, r: float, inner: float, tips: int, turn := -90.0) -> void:
	var points := PackedVector2Array()
	for i in tips * 2:
		var reach := r if i % 2 == 0 else inner
		var angle := deg_to_rad(turn) + PI * i / tips
		points.append(Vector2(x, y) + Vector2.from_angle(angle) * reach)
	_glyph.polygon(points)


## A little person: a head over a rounded body. (x, y) is the chest; the
## figure is about 34 wide and 86 tall at scale 1. `grow` fattens it (cut a
## grown one first to keep a gap around a figure in front of others).
func man(x: float, y: float, s: float, grow := 0.0, cut := false) -> void:
	disc(x, y - 30.0 * s, 13.0 * s + grow, cut)
	var corner := Vector2(x - 17.0 * s - grow, y - 14.0 * s - grow)
	var size := Vector2(34.0 * s + 2.0 * grow, 56.0 * s + 2.0 * grow)
	box(corner.x, corner.y, size.x, size.y, 15.0 * s + grow, cut)


func _segments(r: float) -> int:
	return clampi(ceili(r * 1.1) + 10, 12, 56)
