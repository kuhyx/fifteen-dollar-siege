class_name FxHiding
extends RefCounted
## Where the villagers went. A squad of villagers in hiding is not drawn in
## the open (it is indoors), so the house nearest to it shows eyes in a window
## on its roof, one pair per PER_PAIR people up to MAX_PAIRS: the player sees
## where the 1,500 went and how many. The eyes glance about and blink.

## Hidden people one pair of eyes stands for, and pairs a house can show.
const PER_PAIR := 12
const MAX_PAIRS := 4
## An eye is never narrower than this on screen (canvas px) [design guess].
const EYE_PX := 7.0
const WINDOW_M := Vector2(2.6, 1.7)
const ROOF_SHARE := 0.8


## Metres one eye measures at `view_zoom` (canvas pixels per metre).
static func eye_m(view_zoom: float) -> float:
	return maxf(0.6, EYE_PX / maxf(view_zoom, 0.001))


## Pairs of eyes a house with `hidden` people shows.
static func pairs_for(hidden: int) -> int:
	return clampi(ceili(float(hidden) / PER_PAIR), 1, MAX_PAIRS)


## True while any villager squad is in hiding.
static func any(crowd: CrowdLayer) -> bool:
	for squad in crowd.squads:
		if _hiding(squad):
			return true
	return false


## House index -> hidden villagers whose squad stands nearest to it.
static func tally(crowd: CrowdLayer, plan: MapPlan) -> Dictionary:
	var out := {}
	for squad in crowd.squads:
		if not _hiding(squad) or plan.houses.is_empty():
			continue
		var best := 0
		for i in plan.houses.size():
			var near := plan.houses[i].get_center().distance_to(squad.anchor)
			if near < plan.houses[best].get_center().distance_to(squad.anchor):
				best = i
		out[best] = out.get(best, 0) + squad.alive
	return out


## One window per pair of eyes, at design size, along each house's long side.
static func windows(crowd: CrowdLayer, plan: MapPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := tally(crowd, plan)
	for index: int in seen:
		var house := plan.houses[index]
		var pairs := pairs_for(seen[index])
		for k in pairs:
			var along := (k + 0.5) / pairs
			var long_side := house.size.x >= house.size.y
			var centre := (
				house.position
				+ Vector2(
					house.size.x * (along if long_side else 0.5),
					house.size.y * (0.5 if long_side else along)
				)
			)
			var size := WINDOW_M.min(
				(
					house.size
					* ROOF_SHARE
					/ Vector2(pairs if long_side else 1, 1 if long_side else pairs)
				)
			)
			out.append({"rect": Rect2(centre - size / 2.0, size), "house": index, "pair": k})
	return out


## Draws the windows and the eyes in them.
static func paint(
	canvas: CanvasItem, crowd: CrowdLayer, plan: MapPlan, clock: float, zoom: float
) -> void:
	var eye := eye_m(zoom)
	for window in windows(crowd, plan):
		var rect: Rect2 = window["rect"]
		var size := Vector2(maxf(rect.size.x, eye * 4.2), maxf(rect.size.y, eye * 2.6))
		var frame := Rect2(rect.get_center() - size / 2.0, size)
		canvas.draw_rect(frame.grow(eye * 0.25), Palette.WOOD_DARK)
		canvas.draw_rect(frame, Palette.SOOT)
		var phase: float = clock * 0.8 + float(window["house"]) * 1.7 + float(window["pair"]) * 0.9
		var open := 0.15 if sin(phase * 2.1) > 0.93 else 1.0
		var look := sin(phase) * eye * 0.18
		for side: float in [-1.0, 1.0]:
			var at := frame.get_center() + Vector2(side * eye * 1.1, 0.0)
			var white := Vector2(eye * 0.62, eye * 0.62 * open)
			canvas.draw_set_transform(at, 0.0, white / eye)
			canvas.draw_circle(Vector2.ZERO, eye, Palette.INK)
			canvas.draw_circle(Vector2(look / white.x * eye, 0.0), eye * 0.42, Palette.SOOT)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _hiding(squad: SquadVisual) -> bool:
	if squad == null or squad.alive <= 0:
		return false
	return squad.team == SiegeSnapshot.Team.VILLAGE and squad.state == SiegeSnapshot.State.HIDDEN
