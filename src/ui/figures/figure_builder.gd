class_name FigureBuilder
extends RefCounted
## Vector shapes, one colour each, recorded in metres (feet at the origin, up
## is -y, the figure faces +x) and turned into one ArrayMesh: a figure is as
## sharp at 3840x2160 as at 1280x800. `swing` = 1 tags the shapes that follow
## as the weapon arm (UV.x): the crowd shader swings them about a pivot.
## `detail` false is the far level: fewer segments, and the callers skip the
## small parts.

const NEAR_SEGMENTS := 14
const FAR_SEGMENTS := 6
## Added to a fringe vertex's outward angle in the mesh's UV.y, so the crowd
## shader can tell it from a body vertex (whose UV.y is 0). Angles run -PI..PI.
const FRINGE_FLAG := 4.0

var detail := true
var swing := 0.0
## 1 tags the shapes that follow as gear (UV.y): held or worn, not the body.
var gear := 0.0
## Applied to every shape that follows (a boy is a small man; a band is four
## players side by side).
var scale := 1.0
var offset := Vector2.ZERO
var points := PackedVector2Array()
var colors := PackedColorArray()
var tags := PackedVector2Array()
var indices := PackedInt32Array()
## The one-pixel feather around every shape (antialiasing by hand: MSAA 2D
## does nothing on the Compatibility renderer). Fringe vertices sit on the
## outline; the shader pushes them out. Kept apart from the body so the
## figure's own measures (bounds, triangles, spans) ignore them.
var fringe_points := PackedVector2Array()
var fringe_colors := PackedColorArray()
var fringe_angles := PackedFloat32Array()
var fringe_tags := PackedFloat32Array()
## Triangle corners: 0 or more = a body vertex, -1 - k = fringe vertex k.
var fringe_indices := PackedInt32Array()


static func make(p_detail: bool, p_scale := 1.0) -> FigureBuilder:
	var builder := FigureBuilder.new()
	builder.detail = p_detail
	builder.scale = p_scale
	return builder


## A filled outline (any simple polygon).
func poly(outline: PackedVector2Array, tint: Color) -> void:
	var order := Geometry2D.triangulate_polygon(outline)
	var base := points.size()
	for point in outline:
		points.append(point * scale + offset)
		colors.append(tint)
		tags.append(Vector2(swing, gear))
	for index in order:
		indices.append(base + index)
	_feather(outline, base, tint)


## A fringe around the outline whose vertices are `base`... in `points`.
func _feather(outline: PackedVector2Array, base: int, tint: Color) -> void:
	var count := outline.size()
	var area := 0.0
	for i in count:
		area += outline[i].cross(outline[(i + 1) % count])
	var first := fringe_points.size()
	for i in count:
		var before := (outline[i] - outline[(i + count - 1) % count]).normalized()
		var after := (outline[(i + 1) % count] - outline[i]).normalized()
		var normal := Vector2(before.y + after.y, -before.x - after.x)
		if normal.is_zero_approx():
			normal = Vector2(before.y, -before.x)
		normal = normal.normalized() * signf(area)
		fringe_points.append(outline[i] * scale + offset)
		fringe_colors.append(Color(tint, 0.0))
		fringe_angles.append(normal.angle() + FRINGE_FLAG)
		fringe_tags.append(swing)
	for i in count:
		var next := (i + 1) % count
		fringe_indices.append_array([base + i, base + next, -1 - (first + next)])
		fringe_indices.append_array([base + i, -1 - (first + next), -1 - (first + i)])


## The same from flat numbers: [x0, y0, x1, y1, ...].
func shape(flat: Array, tint: Color) -> void:
	var outline := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		outline.append(Vector2(flat[i], flat[i + 1]))
	poly(outline, tint)


## A rectangle from its top-left corner (y grows downward).
func box(x: float, y: float, w: float, h: float, tint: Color) -> void:
	shape([x, y, x + w, y, x + w, y + h, x, y + h], tint)


## An ellipse; `turns` rotates it (radians).
func disc(center: Vector2, radius: Vector2, tint: Color, turns := 0.0) -> void:
	var count := NEAR_SEGMENTS if detail else FAR_SEGMENTS
	var outline := PackedVector2Array()
	for i in count:
		var rim := Vector2.from_angle(TAU * i / count) * radius
		outline.append(center + rim.rotated(turns))
	poly(outline, tint)


## Part of a disc between two angles (0 = +x, clockwise on screen), with its
## middle: a cap, a dome, a half moon.
func slice(center: Vector2, radius: Vector2, from: float, to: float, tint: Color) -> void:
	var count := (NEAR_SEGMENTS if detail else FAR_SEGMENTS) / 2 + 1
	var outline := PackedVector2Array()
	for i in count + 1:
		outline.append(center + Vector2.from_angle(lerpf(from, to, float(i) / count)) * radius)
	poly(outline, tint)


## A thick straight line with flat ends.
func bar(a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	var side := (b - a).normalized().orthogonal() * width / 2.0
	poly(PackedVector2Array([a + side, b + side, b - side, a - side]), tint)


## A thick line through several points.
func strip(path: Array[Vector2], width: float, tint: Color) -> void:
	for i in path.size() - 1:
		bar(path[i], path[i + 1], width, tint)


func triangles() -> int:
	return indices.size() / 3


func bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var box_out := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box_out = box_out.expand(point)
	return box_out


## How tall the figure stands above its feet.
func height() -> float:
	return -bounds().position.y


## Width of the body (no swing arm, no gear) at height `y`: the gap between
## the leftmost and the rightmost crossing of a horizontal line.
func span_at(y: float) -> float:
	var low := INF
	var high := -INF
	for i in range(0, indices.size(), 3):
		if tags[indices[i]].x > 0.5 or tags[indices[i]].y > 0.5:
			continue
		for edge in 3:
			var a := points[indices[i + edge]]
			var b := points[indices[i + (edge + 1) % 3]]
			if (a.y - y) * (b.y - y) > 0.0 or is_equal_approx(a.y, b.y):
				continue
			var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
			low = minf(low, x)
			high = maxf(high, x)
	return maxf(high - low, 0.0)


## True when some shape is tagged for the swing.
func swings() -> bool:
	for tag in tags:
		if tag.x > 0.5:
			return true
	return false


## The colour that covers most of the body (no swing arm, no gear).
func body_tint() -> Color:
	var areas := {}
	for i in range(0, indices.size(), 3):
		var tag := tags[indices[i]]
		if tag.x > 0.5 or tag.y > 0.5:
			continue
		var a := points[indices[i]]
		var cross := (points[indices[i + 1]] - a).cross(points[indices[i + 2]] - a)
		var tint := colors[indices[i]]
		areas[tint] = areas.get(tint, 0.0) + absf(cross)
	var best := Palette.CLEAR
	for tint: Color in areas:
		if areas[tint] > areas.get(best, 0.0):
			best = tint
	return best


## One number for the whole drawing: two figures that differ get two numbers.
func signature() -> int:
	return [points, colors, tags, indices].hash()


func mesh() -> ArrayMesh:
	var all_points := points.duplicate()
	var all_colors := colors.duplicate()
	var all_tags := PackedVector2Array()
	for tag in tags:
		all_tags.append(Vector2(tag.x, 0.0))
	for i in fringe_points.size():
		all_points.append(fringe_points[i])
		all_colors.append(fringe_colors[i])
		all_tags.append(Vector2(fringe_tags[i], fringe_angles[i]))
	var all_indices := indices.duplicate()
	for corner in fringe_indices:
		all_indices.append(corner if corner >= 0 else points.size() - 1 - corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_points
	arrays[Mesh.ARRAY_COLOR] = all_colors
	arrays[Mesh.ARRAY_TEX_UV] = all_tags
	arrays[Mesh.ARRAY_INDEX] = all_indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
