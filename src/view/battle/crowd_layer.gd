class_name CrowdLayer
extends Node2D
## Every individual of the siege, drawn. One SquadVisual per sim entity (its
## heads scattered around the anchor), all through RenderingServer MultiMeshes
## and one shader: about 2,400 figures cost a few uniform updates per frame,
## not a draw each. Two levels of detail follow the zoom. Lives inside the
## world node, so its coordinates are map metres.

const SHADER: Shader = preload("res://src/view/battle/crowd.gdshader")
## The animation clock of every figure: ONE global shader value a frame
## (project.godot, [shader_globals]), not one per squad.
const CLOCK := &"siege_clock"
## A man drawn shorter than this many screen pixels uses the simple figure.
const FAR_BELOW_PX := 26.0
## The level switches back only past this factor: no flicker at the edge.
const LOD_SLACK := 1.15
## A man's height, the yardstick of the level of detail.
const MAN_M := 3.4
## A man drawn shorter than this many real pixels is blown up to it (up to
## MAX_BOOST times life size), so the whole-map view still shows men and not
## specks. The shader scales every figure about its feet.
const MIN_MAN_PX := 18.0
const MAX_BOOST := 4.0
## The shader's global for it, set once a frame beside the clock.
const BOOST := &"figure_boost"
## A rout within this many metres throws a squad apart.
const SCATTER_M := 30.0
const SCATTER_KICK := 1.2
## Metres of jump the pep talk's cheer loses per second.
const CHEER_FADE := 0.5

var look := FigureLook.new()
var squads: Array[SquadVisual] = []
## True while the simple figures are drawn.
var far := false
## MultiMeshes made so far: the frame gate fails if this grows mid-siege.
var allocations := 0

var _rect := Rect2()
var _cheer := 0.0


func setup(map_bounds: Rect2, p_look: FigureLook) -> void:
	_rect = map_bounds.grow(60.0)
	look = p_look
	FigureLibrary.warm(look)


## Makes the squads match the snapshot's entities (new, changed kind, more
## heads than it was built for) and lets the missing heads fall.
func sync(shot: SiegeSnapshot) -> void:
	for i in shot.entity_count():
		var heads := shot.ent_count[i]
		if i >= squads.size():
			squads.append(null)
		var squad := squads[i]
		if squad == null or squad.kind != shot.ent_kind[i] or heads > squad.capacity:
			if squad != null:
				squad.free_rids()
			squad = _make(i, shot.ent_kind[i], shot.ent_team[i], heads)
			squads[i] = squad
		squad.set_heads(heads)


## This frame: every squad at its glided position, in its pose.
func draw_frame(
	tween: SnapshotTween, shot: SiegeSnapshot, clock: float, delta: float, zoom_px: float
) -> void:
	_pick_level(zoom_px)
	RenderingServer.global_shader_parameter_set(CLOCK, clock)
	var boost := boost_for(zoom_px)
	RenderingServer.global_shader_parameter_set(BOOST, boost)
	var cheering := _cheer > 0.0
	_cheer = maxf(_cheer - delta * CHEER_FADE, 0.0)
	for i in mini(squads.size(), shot.entity_count()):
		var squad := squads[i]
		var at := tween.position(i)
		squad.pose(at, tween.velocity(i), shot.ent_state[i], shot.ent_facing[i], delta)
		if squad.kind == SiegeSnapshot.Kind.WASPS:
			squad.set_grow(boost)
		if cheering and squad.team == SiegeSnapshot.Team.ARMY:
			squad.material.set_shader_parameter("cheer", _cheer)


## How many times life size a figure is drawn at `zoom_px` (real pixels per
## metre): 1 once a man is tall enough, more as the camera goes out.
static func boost_for(zoom_px: float) -> float:
	return clampf(MIN_MAN_PX / maxf(zoom_px * MAN_M, 0.001), 1.0, MAX_BOOST)


## True while any swarm of wasps is in the air.
func has_swarm() -> bool:
	for squad in squads:
		if FxSwarm.is_flying(squad):
			return true
	return false


## Individuals drawn, standing or fallen.
func figures() -> int:
	var total := 0
	for squad in squads:
		total += squad.capacity
	return total


## Dresses the army anew (the look follows the loadout).
func dress(p_look: FigureLook) -> void:
	look = p_look
	FigureLibrary.warm(look)
	for squad in squads:
		if FigurePeople.DRESSED.has(squad.kind):
			squad.kind = -1


## Every figure of `team` bursts into flames.
func ignite(team: int) -> void:
	for squad in squads:
		if squad.team == team and not squad.burning:
			squad.ignite(FigureLibrary.flame())
			allocations += 1


## A rout at `pos`: the nearest squad of `team` is thrown apart.
func scatter(pos: Vector2, team: int) -> void:
	var nearest := nearest_squad(pos, team)
	if nearest != null and nearest.anchor.distance_to(pos) < SCATTER_M:
		nearest.kick(SCATTER_KICK)


## The army jumps for joy for a moment (the pep talk).
func cheer(metres: float) -> void:
	_cheer = metres


func nearest_squad(pos: Vector2, team: int) -> SquadVisual:
	var best: SquadVisual = null
	for squad in squads:
		if squad.team != team or squad.alive == 0:
			continue
		if best == null or squad.anchor.distance_to(pos) < best.anchor.distance_to(pos):
			best = squad
	return best


func _make(index: int, kind: int, team: int, heads: int) -> SquadVisual:
	var squad := SquadVisual.new()
	squad.index = index
	squad.kind = kind
	squad.team = team
	squad.spec = FigureLibrary.spec(kind, look)
	squad.build(get_canvas_item(), SHADER, heads, far, _rect)
	var sways := look.wobble() if FigurePeople.DRESSED.has(kind) else 0.0
	squad.material.set_shader_parameter("wobble", sways)
	allocations += 1
	return squad


func _pick_level(zoom_px: float) -> void:
	var man_px := zoom_px * MAN_M
	var wanted := far
	if far and man_px > FAR_BELOW_PX * LOD_SLACK:
		wanted = false
	elif not far and man_px < FAR_BELOW_PX / LOD_SLACK:
		wanted = true
	if wanted == far:
		return
	far = wanted
	for squad in squads:
		squad.set_far(far)


func _exit_tree() -> void:
	for squad in squads:
		squad.free_rids()
	squads.clear()
