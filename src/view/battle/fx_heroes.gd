class_name FxHeroes
extends RefCounted
## A ring and a pointer on the army's single special figures (the great
## captain, the trumpet boy, the gunman, the monster): one man among hundreds
## is a few pixels at the auto camera's zoom, so each wears a mark that keeps
## its size on screen. The ring breathes, so the eye lands on it.

const KINDS: Array[int] = [
	SiegeSnapshot.Kind.EMPEROR,
	SiegeSnapshot.Kind.TRUMPET_BOY,
	SiegeSnapshot.Kind.SHOTGUNNER,
	SiegeSnapshot.Kind.MONSTER,
]
## Canvas pixels: the ring's radius and line, and the pointer's size.
const RING_PX := 30.0
const LINE_PX := 3.0
const POINTER_PX := 14.0


static func is_hero(squad: SquadVisual) -> bool:
	return squad != null and squad.alive > 0 and squad.kind in KINDS


## True while a hero is alive (the effects layer then redraws every frame).
static func any(crowd: CrowdLayer) -> bool:
	for squad in crowd.squads:
		if is_hero(squad):
			return true
	return false


## Draws the mark of every living hero of `crowd` (`zoom` = pixels per metre).
static func paint(canvas: CanvasItem, crowd: CrowdLayer, clock: float, zoom: float) -> void:
	var px := 1.0 / maxf(zoom, 0.001)
	var breath := 1.0 + 0.12 * sin(clock * 4.0)
	for squad in crowd.squads:
		if not is_hero(squad):
			continue
		var reach := RING_PX * px * breath
		var ring := Palette.COIN
		var edge := Color(WorldPalette.SOOT, 0.8)
		canvas.draw_arc(squad.anchor, reach, 0.0, TAU, 32, edge, (LINE_PX + 3.0) * px, true)
		canvas.draw_arc(squad.anchor, reach, 0.0, TAU, 32, ring, LINE_PX * px, true)
		var tip := squad.anchor + Vector2(0.0, -reach - 2.0 * px)
		var wing := POINTER_PX * px
		var points := PackedVector2Array([tip, tip + Vector2(-wing, -wing * 1.4)])
		points.append(tip + Vector2(wing, -wing * 1.4))
		canvas.draw_colored_polygon(points, ring)
		points.append(points[0])
		canvas.draw_polyline(points, edge, px * 1.5, true)
