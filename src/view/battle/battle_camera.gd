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
const PAD_M := 24.0
const MIN_SPAN_M := Vector2(150.0, 84.0)
## Villagers this close to the army are part of the action.
const ENGAGE_M := 70.0
## Metres of the way ahead of the army that stay in the frame.
const LEAD_M := 60.0

var bounds := Rect2(0.0, 0.0, 600.0, 400.0)
## The canvas rectangle the map is shown in.
var view := Rect2(0.0, 0.0, 1920.0, 1080.0)
var center := Vector2.ZERO
var zoom := 1.0
var auto := true

var _goal_center := Vector2.ZERO
var _goal_zoom := 1.0


func setup(p_bounds: Rect2, p_view: Rect2) -> void:
	bounds = p_bounds
	view = p_view
	frame(bounds)
	snap()


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
	_goal_center = box.get_center().clamp(bounds.position, bounds.end)
	var wanted := minf(view.size.x / maxf(box.size.x, 1.0), view.size.y / maxf(box.size.y, 1.0))
	_goal_zoom = clampf(wanted, fit_zoom() * MIN_FIT, MAX_ZOOM)


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
	center += held - to_map(canvas_point)
	center = center.clamp(bounds.position, bounds.end)


## Moves the map with the pointer by `canvas_delta` pixels.
func pan(canvas_delta: Vector2) -> void:
	auto = false
	center = (center - canvas_delta / zoom).clamp(bounds.position, bounds.end)


func resume_auto() -> void:
	auto = true


## What the auto camera should show: the army, the stretch ahead of it and
## every villager it has reached. The whole map when there is no army.
static func action_box(shot: SiegeSnapshot, map: SiegeMap) -> Rect2:
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
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.VILLAGE and _reached(shot, i, army):
			box = box.expand(shot.ent_pos[i])
	return _fitted(box.grow(PAD_M), map.bounds)


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
