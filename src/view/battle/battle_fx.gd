class_name BattleFx
extends RefCounted
## One live effect on the battlefield: what draws it, where, toward what and
## how old it is. The drawing itself is a static function of an Fx* file; this
## also holds the few shapes they all share. Everything is in map metres.

## A star smaller than this is not drawn: nobody could see it, and the
## engine cannot triangulate a polygon that small.
const MIN_STAR_M := 0.3

var kind: StringName = &""
## The function that draws it: func(canvas: CanvasItem, fx: BattleFx).
var painter: Callable
var pos := Vector2.ZERO
## Where it aims or flies (the nearest enemy, a launch point, the camp).
var to := Vector2.ZERO
var team := 0
var age := 0.0
var life := 1.0
var seed_value := 0
## Event data the painter may need (`command`, `progress`).
var data: Dictionary = {}
## The camera's pixels per metre when it was last drawn: painters keep their
## marks a legible size on screen with it.
var zoom := 6.0


## 0 at birth, 1 at the end.
func progress() -> float:
	return clampf(age / life, 0.0, 1.0)


## 1 for most of the life, then down to 0 over the last `tail` of it.
func fading(tail := 0.35) -> float:
	return clampf((1.0 - progress()) / tail, 0.0, 1.0)


## A fixed number in 0..1 for this effect and `salt`.
func chance(salt: int) -> float:
	return float(hash([seed_value, salt]) & 0xFFFF) / 65535.0


## A fixed offset inside a disc of `reach` metres.
func jitter(salt: int, reach: float) -> Vector2:
	return Vector2.from_angle(chance(salt) * TAU) * reach * sqrt(chance(salt + 977))


## The direction it aims in (right when it aims at itself).
func heading() -> Vector2:
	return (to - pos).normalized() if to.distance_to(pos) > 0.01 else Vector2.RIGHT


func tint() -> Color:
	return Palette.ARMY if team == SiegeSnapshot.Team.ARMY else Palette.VILLAGE


## A point `part` (0..1) of the way from a to b on a thrown arc `lift` high.
static func lob(a: Vector2, b: Vector2, part: float, lift: float) -> Vector2:
	return a.lerp(b, part) + Vector2(0.0, -lift * 4.0 * part * (1.0 - part))


## A spiky star: `spikes` points between the radii `outer` and `inner`.
static func star(
	canvas: CanvasItem, at: Vector2, outer: float, inner: float, spikes: int, tint_in: Color
) -> void:
	var outline := star_outline(at, outer, inner, spikes)
	if not outline.is_empty():
		canvas.draw_colored_polygon(outline, tint_in)


## The star's outline; empty when it is too small to draw.
static func star_outline(
	at: Vector2, outer: float, inner: float, spikes: int
) -> PackedVector2Array:
	var outline := PackedVector2Array()
	if outer < MIN_STAR_M:
		return outline
	var waist := minf(inner, outer * 0.6)
	for i in spikes * 2:
		var reach := outer if i % 2 == 0 else waist
		outline.append(at + Vector2.from_angle(TAU * i / (spikes * 2.0) - PI / 2.0) * reach)
	return outline


## An arrow head pointing along `along`.
static func chevron(
	canvas: CanvasItem, at: Vector2, along: Vector2, size: float, tint_in: Color
) -> void:
	var side := along.orthogonal() * size * 0.7
	var outline := PackedVector2Array([at + along * size, at - along * size * 0.4 + side])
	outline.append_array([at, at - along * size * 0.4 - side])
	canvas.draw_colored_polygon(outline, tint_in)


## A bold arrow head: a V of two strokes `size` metres long pointing along
## `along`, `px` metres per screen pixel. A halo, a rim and the fill, so it
## reads on grass and on the crowd alike.
static func vee(
	canvas: CanvasItem, at: Vector2, along: Vector2, size: float, px: float, fill: Color
) -> void:
	var side := along.orthogonal() * size * 0.9
	var path := PackedVector2Array([at - along * size * 0.5 + side, at + along * size * 0.5])
	path.append(at - along * size * 0.5 - side)
	var width := size * 0.32
	canvas.draw_polyline(path, Color(WorldPalette.SOOT, fill.a), width + 8.0 * px, true)
	canvas.draw_polyline(path, Color(WorldPalette.WHITE, fill.a), width + 3.0 * px, true)
	canvas.draw_polyline(path, fill, width, true)


## A plus sign `size` wide.
static func plus(canvas: CanvasItem, at: Vector2, size: float, tint_in: Color) -> void:
	var thick := size * 0.34
	canvas.draw_rect(Rect2(at - Vector2(thick, size) / 2.0, Vector2(thick, size)), tint_in)
	canvas.draw_rect(Rect2(at - Vector2(size, thick) / 2.0, Vector2(size, thick)), tint_in)


## A music note: a head and a stem.
static func note(canvas: CanvasItem, at: Vector2, size: float, tint_in: Color) -> void:
	canvas.draw_circle(at, size * 0.36, tint_in)
	canvas.draw_rect(
		Rect2(at + Vector2(size * 0.22, -size * 1.2), Vector2(size * 0.16, size * 1.2)), tint_in
	)
	canvas.draw_rect(
		Rect2(at + Vector2(size * 0.22, -size * 1.2), Vector2(size * 0.6, size * 0.22)), tint_in
	)


## A jagged line from a to b (a lightning bolt, a crack).
static func bolt(
	canvas: CanvasItem, a: Vector2, b: Vector2, kinks: int, width: float, tint_in: Color
) -> void:
	var path := PackedVector2Array([a])
	var side := (b - a).orthogonal() * 0.22
	for i in range(1, kinks):
		path.append(a.lerp(b, float(i) / kinks) + side * (1.0 if i % 2 == 0 else -1.0))
	path.append(b)
	canvas.draw_polyline(path, tint_in, width)
