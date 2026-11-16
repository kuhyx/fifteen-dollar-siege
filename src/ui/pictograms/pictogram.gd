class_name Pictogram
extends RefCounted
## A multi-colour vector picture in VectorGlyph's 128-unit square: layers of
## shapes, back to front, one palette colour each. It is drawn as ONE triangle
## array at any size or angle, with a one-pixel feathered edge built for the
## size it has on screen: as sharp at 3840x2160 as at 1280x800, never
## stair-stepped and never a raster.

const UNITS := VectorGlyph.UNITS
## Feather meshes are built per size step: a third of an octave.
const STEPS_PER_OCTAVE := 3.0
## A sharp corner's feather reaches at most this many feather widths.
const MAX_MITER := 2.5

var layers: Array[VectorGlyph] = []
var tints: Array[Color] = []

## Size step -> {points, indices, colors}.
var _meshes: Dictionary = {}


## A one-layer picture of an existing glyph, tinted.
static func of_glyph(glyph: VectorGlyph, tint: Color) -> Pictogram:
	var out := Pictogram.new()
	out.layers.append(glyph)
	out.tints.append(tint)
	return out


## Starts a layer in front of the others; shapes go onto the returned glyph.
func layer(tint: Color) -> VectorGlyph:
	var glyph := VectorGlyph.new()
	layers.append(glyph)
	tints.append(tint)
	_meshes.clear()
	return glyph


func is_empty() -> bool:
	return area() <= 0.0


func area() -> float:
	var total := 0.0
	for glyph in layers:
		total += glyph.area()
	return total


## The box around every shape, in glyph units (empty picture: a zero rect).
func bounds() -> Rect2:
	var box := Rect2()
	var first := true
	for glyph in layers:
		for piece in glyph.pieces:
			for point in piece:
				box = Rect2(point, Vector2.ZERO) if first else box.expand(point)
				first = false
	return box


## The colour seen at a point in glyph units (TRANSPARENT where nothing is).
func color_at(point: Vector2) -> Color:
	for i in range(layers.size() - 1, -1, -1):
		if layers[i].contains(point):
			return tints[i]
	return Palette.CLEAR


## Draws the picture into `box` of `canvas` (call from its _draw). `fade` 0..1
## mixes every colour toward `toward`: a dimmed card stays opaque.
func draw(canvas: CanvasItem, box: Rect2, fade := 0.0, toward := Palette.PANEL) -> void:
	var xform := Transform2D(
		Vector2(box.size.x / UNITS, 0), Vector2(0, box.size.y / UNITS), box.position
	)
	draw_xform(canvas, xform, fade, toward)


## The same with any transform from glyph units to the canvas item's own space.
func draw_xform(
	canvas: CanvasItem, xform: Transform2D, fade := 0.0, toward := Palette.PANEL
) -> void:
	var mesh := mesh_for(xform.get_scale().x * _canvas_px(canvas))
	var colors: PackedColorArray = mesh["colors"]
	if fade > 0.0:
		colors = colors.duplicate()
		for i in colors.size():
			colors[i] = Color(colors[i].lerp(toward, fade), colors[i].a)
	_emit(canvas, xform, mesh, colors)


## Every layer in one colour: a silhouette (an empty shelf slot).
func draw_flat(canvas: CanvasItem, box: Rect2, tint: Color) -> void:
	var xform := Transform2D(
		Vector2(box.size.x / UNITS, 0), Vector2(0, box.size.y / UNITS), box.position
	)
	var mesh := mesh_for(xform.get_scale().x * _canvas_px(canvas))
	var colors: PackedColorArray = mesh["colors"].duplicate()
	for i in colors.size():
		colors[i] = Color(tint, colors[i].a)
	_emit(canvas, xform, mesh, colors)


## The triangles for a picture drawn at `px_per_unit` screen pixels per glyph
## unit: every piece plus a one-pixel rim that fades out.
func mesh_for(px_per_unit: float) -> Dictionary:
	var step := roundi(log(maxf(px_per_unit, 0.01)) / log(2.0) * STEPS_PER_OCTAVE)
	if not _meshes.has(step):
		var feather := 1.0 / pow(2.0, step / STEPS_PER_OCTAVE)
		var mesh := {
			"points": PackedVector2Array(),
			"indices": PackedInt32Array(),
			"colors": PackedColorArray(),
		}
		for i in layers.size():
			for piece in layers[i].pieces:
				_add_piece(mesh, piece, tints[i], feather)
		_meshes[step] = mesh
	return _meshes[step]


func _emit(
	canvas: CanvasItem, xform: Transform2D, mesh: Dictionary, colors: PackedColorArray
) -> void:
	if colors.is_empty():
		return
	var item := canvas.get_canvas_item()
	RenderingServer.canvas_item_add_set_transform(item, xform)
	RenderingServer.canvas_item_add_triangle_array(item, mesh["indices"], mesh["points"], colors)
	RenderingServer.canvas_item_add_set_transform(item, Transform2D.IDENTITY)


## Screen pixels per unit of `canvas`'s own space (1 outside the tree).
func _canvas_px(canvas: CanvasItem) -> float:
	if not canvas.is_inside_tree():
		return 1.0
	var screen := canvas.get_viewport().get_final_transform().get_scale().x
	return screen * canvas.get_global_transform().get_scale().x


func _add_piece(mesh: Dictionary, piece: PackedVector2Array, tint: Color, feather: float) -> void:
	var points: PackedVector2Array = mesh["points"]
	var indices: PackedInt32Array = mesh["indices"]
	var colors: PackedColorArray = mesh["colors"]
	var count := piece.size()
	var base := points.size()
	var side := 1.0 if _signed_area(piece) > 0.0 else -1.0
	points.append_array(piece)
	for k in count:
		colors.append(tint)
	for index in Geometry2D.triangulate_polygon(piece):
		indices.append(base + index)
	for k in count:
		var before := _outward(piece[(k + count - 1) % count], piece[k], side)
		var after := _outward(piece[k], piece[(k + 1) % count], side)
		var miter := (before + after).normalized()
		if miter == Vector2.ZERO:
			miter = after
		var reach := feather / maxf(miter.dot(after), 1.0 / MAX_MITER)
		points.append(piece[k] + miter * reach)
		colors.append(Color(tint, 0.0))
	for k in count:
		var next := (k + 1) % count
		var rim := base + count
		indices.append_array([base + k, base + next, rim + next, base + k, rim + next, rim + k])
	mesh["points"] = points
	mesh["indices"] = indices
	mesh["colors"] = colors


func _signed_area(piece: PackedVector2Array) -> float:
	var sum := 0.0
	for i in piece.size():
		sum += piece[i].cross(piece[(i + 1) % piece.size()])
	return sum


## The unit normal of edge a -> b that points out of the piece.
func _outward(a: Vector2, b: Vector2, side: float) -> Vector2:
	var along := (b - a).normalized()
	return Vector2(along.y, -along.x) * side
