class_name FxSwarm
extends RefCounted
## The wasps' cloud: a warm haze and dark strokes swirling around the swarm,
## drawn on top of the wasps so a swarm reads as a buzzing cloud at any zoom,
## never as a few dots. Its radius has a floor in screen pixels.

## The cloud is never smaller than this on screen (canvas px).
const MIN_CLOUD_PX := 44.0
const STROKES := 6


## Metres the cloud reaches around the anchor at `zoom` (pixels per metre).
static func radius_m(squad: SquadVisual, zoom: float) -> float:
	return maxf(squad.spread * squad.grow + 1.5, MIN_CLOUD_PX / maxf(zoom, 0.001))


## Draws every living swarm of `crowd`.
static func paint(canvas: CanvasItem, crowd: CrowdLayer, clock: float, zoom: float) -> void:
	var px := 1.0 / zoom
	for squad in crowd.squads:
		if not is_flying(squad):
			continue
		var reach := radius_m(squad, zoom)
		canvas.draw_circle(squad.anchor, reach, Color(WorldPalette.BRASS, 0.22))
		canvas.draw_circle(squad.anchor, reach * 0.6, Color(WorldPalette.SOOT, 0.1))
		for i in STROKES:
			var from := clock * (2.4 + 0.45 * i) + i * TAU / STROKES
			var ring := reach * (0.4 + 0.12 * (i % 4))
			var stroke := Color(WorldPalette.SOOT, 0.6)
			canvas.draw_arc(squad.anchor, ring, from, from + 1.2, 10, stroke, 3.0 * px, true)


## A swarm that is still in the air.
static func is_flying(squad: SquadVisual) -> bool:
	if squad == null or squad.kind != SiegeSnapshot.Kind.WASPS:
		return false
	return squad.alive > 0 and squad.state != SiegeSnapshot.State.DOWN


## The night over a loss: a veil on the map and the crowd, and a warm glow
## around every burning squad (above the veil, under the flames).
static func night(canvas: CanvasItem, crowd: CrowdLayer, area: Rect2, veil: float) -> void:
	if veil <= 0.0:
		return
	canvas.draw_rect(area, Color(Palette.NIGHT, Palette.NIGHT.a * veil))
	for squad in crowd.squads:
		if squad != null and squad.burning:
			var reach := squad.spread * squad.grow + 5.0
			canvas.draw_circle(squad.anchor, reach, Color(Palette.FLAME_MID, 0.1 * veil))
			canvas.draw_circle(squad.anchor, reach * 0.6, Color(Palette.FLAME_MID, 0.12 * veil))
