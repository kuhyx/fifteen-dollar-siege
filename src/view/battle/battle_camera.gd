class_name BattleCamera
extends RefCounted
## The battle's view of the map: a centre in map metres and a zoom in canvas
## pixels per metre. On AUTO it glides to frame the action (the army and
## whoever it has reached); a wheel, a pinch or a drag takes it over by hand
## until `resume_auto`. Pure arithmetic: the screen applies `transform()`.

## Pixels per metre at the closest zoom [design guess: a man fills ~70 px].
const MAX_ZOOM := 22.0
## The widest view shows a little more than the whole map.
const MIN_FIT := 0.85
## Seconds for the auto camera to cover most of the way [design guess].
const FOLLOW_S := 0.45
const WHEEL_STEP := 1.15
## Auto framing: metres of margin around the action, and its smallest frame.
const PAD_M := 14.0
const MIN_SPAN_M := Vector2(120.0, 68.0)
## Villagers this close to the army are part of the action.
const ENGAGE_M := 45.0
## Metres of the way ahead of the army that stay in the frame.
const LEAD_M := 40.0
## The auto camera never zooms out past this many canvas pixels per metre
## (a man about 20 px tall): a wide fight shows its army, not the whole map.
const AUTO_MIN_ZOOM := 6.0
## How far the army may stand from the middle of an over-wide frame, as a
## share of the half view.
const ANCHOR_SLACK := 0.4

var bounds := Rect2(0.0, 0.0, 600.0, 400.0)
## The canvas rectangle the action is framed in (the screen without the
## HUD's strips), and the whole screen: the map is drawn on all of it.
var view := Rect2(0.0, 0.0, 1920.0, 1080.0)
var screen := Rect2(0.0, 0.0, 1920.0, 1080.0)
var center := Vector2.ZERO
var zoom := 1.0
var auto := true

var _goal_center := Vector2.ZERO
var _goal_zoom := 1.0


func setup(p_bounds: Rect2, p_view: Rect2) -> void:
	bounds = p_bounds
	view = p_view
	screen = p_view
	frame(bounds)
	snap()


## A screen of `area` canvas pixels whose top and bottom strips belong to
## the HUD: the action is framed between them.
func fit_screen(area: Vector2, top: float, bottom: float) -> void:
	screen = Rect2(Vector2.ZERO, area if area.x > 1.0 else Vector2(1920.0, 1080.0))
	view = Rect2(0.0, top, screen.size.x, screen.size.y - top - bottom)


## Pixels per metre that show the whole map.
func fit_zoom() -> float:
	return minf(view.size.x / bounds.size.x, view.size.y / bounds.size.y)


func to_canvas(point: Vector2) -> Vector2:
	return view.get_center() + (point - center) * zoom


func to_map(point: Vector2) -> Vector2:
	return center + (point - view.get_center()) / zoom


## Map metres -> canvas pixels, for the node that holds the world.
func transform() -> Transform2D:
	return Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom), view.get_center() - center * zoom)


## Aims the auto camera at `box` (map metres). It glides there in `update`.
func frame(box: Rect2) -> void:
	var wanted := minf(view.size.x / maxf(box.size.x, 1.0), view.size.y / maxf(box.size.y, 1.0))
	_goal_zoom = clampf(wanted, fit_zoom() * MIN_FIT, MAX_ZOOM)
	_goal_center = on_map(box.get_center(), _goal_zoom)


## The auto camera's `frame`: the same, but never out past AUTO_MIN_ZOOM.
## When the action is wider than that view allows, the camera stays near
## `anchor` (the army) instead of showing everything small.
func follow(box: Rect2, anchor: Vector2) -> void:
	frame(box)
	if _goal_zoom >= AUTO_MIN_ZOOM:
		return
	_goal_zoom = AUTO_MIN_ZOOM
	var half := view.size / AUTO_MIN_ZOOM / 2.0 * ANCHOR_SLACK
	var aside := (box.get_center() - anchor).clamp(-half, half)
	_goal_center = on_map(anchor + aside, _goal_zoom)


## `point` moved so that, at `at_zoom`, the screen shows no more of the
## nothing beyond the map than it must (a map narrower than the screen sits
## in the middle).
func on_map(point: Vector2, at_zoom: float) -> Vector2:
	var low := bounds.position + (view.get_center() - screen.position) / at_zoom
	var high := bounds.end - (screen.end - view.get_center()) / at_zoom
	var out := point
	for axis in 2:
		if low[axis] <= high[axis]:
			out[axis] = clampf(point[axis], low[axis], high[axis])
		else:
			out[axis] = (low[axis] + high[axis]) / 2.0
	return out


## Jumps to where `frame` aimed.
func snap() -> void:
	center = _goal_center
	zoom = _goal_zoom


## Shows `box` at once and holds it (the showcase and the staged beats).
func hold(box: Rect2) -> void:
	frame(box)
	snap()
	auto = false


func update(delta: float) -> void:
	if not auto:
		return
	var blend := 1.0 - exp(-delta / FOLLOW_S)
	center = center.lerp(_goal_center, blend)
	zoom = exp(lerpf(log(zoom), log(_goal_zoom), blend))


## Zooms by `factor`, keeping the map point under `canvas_point` in place.
func zoom_at(canvas_point: Vector2, factor: float) -> void:
	auto = false
	var held := to_map(canvas_point)
	zoom = clampf(zoom * factor, fit_zoom() * MIN_FIT, MAX_ZOOM)
	center = on_map(center + held - to_map(canvas_point), zoom)


## Moves the map with the pointer by `canvas_delta` pixels.
func pan(canvas_delta: Vector2) -> void:
	auto = false
	center = on_map(center - canvas_delta / zoom, zoom)


func resume_auto() -> void:
	auto = true


## What the auto camera should show: the army, the stretch ahead of it and
## every villager it has reached, and the rally flag when one stands. The
## whole map when there is no army.
static func action_box(shot: SiegeSnapshot, map: SiegeMap, rally := Vector2.INF) -> Rect2:
	var army := PackedVector2Array()
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY and shot.ent_count[i] > 0:
			army.append(shot.ent_pos[i])
	if army.is_empty():
		return map.bounds
	var box := Rect2(army[0], Vector2.ZERO)
	var middle := Vector2.ZERO
	var inside := false
	for point in army:
		box = box.expand(point)
		middle += point / army.size()
		inside = inside or point.distance_to(map.village_center) < map.village_radius * 1.2
	box = box.expand(middle + (map.village_center - middle).limit_length(LEAD_M))
	if inside:
		box = box.expand(map.village_center)
	if rally != Vector2.INF:
		box = box.expand(rally)
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.VILLAGE and _reached(shot, i, army):
			box = box.expand(shot.ent_pos[i])
	return _fitted(box.grow(PAD_M), map.bounds)


## The middle of the army (the map's middle when there is none).
static func action_anchor(shot: SiegeSnapshot, map: SiegeMap) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY and shot.ent_count[i] > 0:
			sum += shot.ent_pos[i]
			count += 1
	return sum / count if count > 0 else map.bounds.get_center()


static func _reached(shot: SiegeSnapshot, index: int, army: PackedVector2Array) -> bool:
	if shot.ent_count[index] <= 0:
		return false
	if shot.ent_state[index] == SiegeSnapshot.State.FIGHT:
		return true
	for point in army:
		if point.distance_to(shot.ent_pos[index]) < ENGAGE_M:
			return true
	return false


## `box` grown to the smallest frame and moved back onto the map.
static func _fitted(box: Rect2, limit: Rect2) -> Rect2:
	var size := box.size.max(MIN_SPAN_M).min(limit.size)
	var corner := box.get_center() - size / 2.0
	corner = corner.clamp(limit.position, limit.end - size)
	return Rect2(corner, size)
