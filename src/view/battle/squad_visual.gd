class_name SquadVisual
extends RefCounted
## One sim entity on screen: `capacity` individuals in one MultiMesh per
## figure variant, drawn through the RenderingServer with the crowd shader.
## The shader moves the living with the anchor; an individual that falls is
## pinned to the spot in its instance transform and stays there.

const FLOATS := CrowdMesh.FLOATS
## Seconds the last man of a moving squad trails behind [design guess].
const LAG_S := 0.3
## Seconds for spread, fade and flames to settle [design guess].
const SETTLE_S := 0.35
## Draw-order steps per metre of depth, and how far under a fallen squad goes.
const DEPTH_PER_M := 2.0
const UNDER := 100000

var index := 0
var kind := -1
var team := 0
var spec: FigureSpec
var capacity := 0
var alive := 0
var state := 0
var anchor := Vector2.ZERO
var spread := 0.0
var fade := 1.0
var burning := false
var material := ShaderMaterial.new()
## Times the spread is stretched (wasps grow with the far-zoom boost).
var grow := 1.0
## Footprints nobody stands on (MapPlan.blocks).
var blocks := PackedVector4Array()
## Extra spread from a rout (`kick`), decaying.
var scatter := 0.0

var _homes := PackedVector2Array()
var _phases := PackedFloat32Array()
var _order := PackedInt32Array()
var _down := PackedByteArray()
var _spots := PackedVector2Array()
var _buffers: Array[PackedFloat32Array] = []
var _meshes: Array[RID] = []
var _items: Array[RID] = []
var _flame_material: ShaderMaterial
var _flame_size := 0.0
var _lag := Vector2.ZERO
var _trail := Vector2.ZERO
var _flip := 1.0
var _posed := false
var _settled := false
var _depth := 0
var _parent: RID
var _rect := Rect2()


func build(parent: RID, shader: Shader, heads: int, far: bool, rect: Rect2) -> void:
	_parent = parent
	_rect = rect
	capacity = heads
	alive = heads
	_homes = CrowdScatter.homes(index, capacity)
	_phases = CrowdScatter.phases(index, capacity)
	_order = CrowdScatter.fall_order(index, capacity)
	_down.resize(capacity)
	_spots.resize(capacity)
	spread = spread_goal()
	material.shader = shader
	spec.apply(material)
	var shapes := spec.meshes(far, heads)
	for variant in shapes.size():
		_buffers.append(CrowdMesh.buffer(_homes, _phases, variant, shapes.size()))
		_meshes.append(CrowdMesh.multimesh(shapes[variant], _buffers[variant]))
		_items.append(CrowdMesh.item(_parent, _meshes[variant], material, _rect))


## Heads alive now: the missing ones fall where they stand, in a fixed order;
## when the count grows again the last to fall stand up first.
func set_heads(heads: int) -> void:
	var target := clampi(heads, 0, capacity)
	_settled = _settled and target == alive
	while alive > target:
		alive -= 1
		_pin(_order[capacity - alive - 1], true)
	while alive < target:
		_pin(_order[capacity - alive - 1], false)
		alive += 1


func set_grow(factor: float) -> void:
	if is_equal_approx(grow, factor):
		return
	grow = factor
	material.set_shader_parameter("grow", factor)


func set_far(far: bool) -> void:
	var shapes := spec.meshes(far, capacity)
	for variant in mini(shapes.size(), _meshes.size()):
		RenderingServer.multimesh_set_mesh(_meshes[variant], shapes[variant].get_rid())


## This frame's pose: where the anchor is, how fast it moves, what it does.
## A squad that stands still and has settled costs nothing here.
func pose(at: Vector2, velocity: Vector2, p_state: int, facing: float, delta: float) -> void:
	if p_state != state or not _posed:
		state = p_state
		_settled = false
		if not _posed:  # born in this state: no glide from a default
			spread = spread_goal()
			fade = fade_goal()
		_posed = true
		var unseen := state == SiegeSnapshot.State.HIDDEN and team == SiegeSnapshot.Team.ARMY
		material.set_shader_parameter("pose", float(state))
		material.set_shader_parameter("shimmer", 1.0 if unseen else 0.0)
	if at != anchor:
		anchor = at
		_both("anchor", anchor)
	_layer()
	var side := signf(cos(facing))
	if side != _flip and absf(cos(facing)) > 0.2:
		_flip = side
		material.set_shader_parameter("flip", side)
	var trail := velocity * LAG_S
	if _settled and trail.is_equal_approx(_trail):
		return
	_trail = trail
	_settle(delta)


## Draw order among the squads: further up the map first, a squad that is
## down under everyone; a burning squad goes on top of the whole crowd.
func _layer() -> void:
	var depth := int(anchor.y * DEPTH_PER_M)
	if state == SiegeSnapshot.State.DOWN:
		depth -= UNDER
	if depth == _depth:
		return
	_depth = depth
	for item in _items:
		RenderingServer.canvas_item_set_draw_index(item, depth)


## A rout throws the squad apart; it closes up again by itself.
func kick(wider: float) -> void:
	scatter = wider
	_settled = false


## Glides spread, fade, lag, scatter and flames toward their goals, and
## stops (until something changes) once they are there.
func _settle(delta: float) -> void:
	var blend := 1.0 - exp(-delta / SETTLE_S)
	var growing := burning and _flame_size < 0.995
	scatter = lerpf(scatter, 0.0, blend * 0.5)
	spread = lerpf(spread, spread_goal(), blend)
	fade = lerpf(fade, fade_goal(), blend)
	_lag = _lag.lerp(_trail, blend)
	_both("spread", spread)
	_both("lag", _lag)
	material.set_shader_parameter("fade", fade)
	if burning:
		_flame_size = lerpf(_flame_size, 1.0, blend * 0.4)
		material.set_shader_parameter("burn", _flame_size)
		_flame_material.set_shader_parameter("flame", maxf(_flame_size, 0.05))
	var there := absf(spread - spread_goal()) < 0.02 and absf(fade - fade_goal()) < 0.01
	_settled = there and not growing and scatter < 0.01 and _lag.distance_to(_trail) < 0.02


## Sets a value on the figures and, when they burn, on their flames.
func _both(uniform: String, value: Variant) -> void:
	material.set_shader_parameter(uniform, value)
	if burning:
		_flame_material.set_shader_parameter(uniform, value)


## The disc the squad wants to fill for its heads and its state.
func spread_goal() -> float:
	var heads := maxi(alive, 1) if capacity > 1 else 0
	return (
		CrowdScatter.radius(spec.spacing, heads)
		* (1.0 + scatter)
		* CrowdScatter.state_spread(state)
	)


## 0 hides the squad: villagers in hiding are indoors.
func fade_goal() -> float:
	var indoors := state == SiegeSnapshot.State.HIDDEN and team == SiegeSnapshot.Team.VILLAGE
	return 0.0 if indoors else 1.0


func fallen() -> int:
	return capacity - alive


## The squad's place in the draw order (higher is drawn later, on top).
func depth() -> int:
	return _depth


func is_down(individual: int) -> bool:
	return _down[individual] == 1


## Where an individual is drawn, in map metres.
func place(individual: int) -> Vector2:
	if _down[individual] == 1:
		return _spots[individual]
	var spot := anchor + _homes[individual] * spread * grow - _lag * _phases[individual]
	return CrowdScatter.clear_of(spot, blocks)


## Sets every figure of the squad on fire (flames grow in `pose`).
func ignite(flame: FigureSpec) -> void:
	if burning:
		return
	burning = true
	_settled = false
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = material.shader
	for variant in _buffers.size():
		var fire := CrowdMesh.multimesh(flame.near[0], _buffers[variant])
		_meshes.append(fire)
		_items.append(CrowdMesh.item(_parent, fire, _flame_material, _rect))
	_both("anchor", anchor)
	_both("spread", spread)
	_both("lag", _lag)
	for item in _items:
		RenderingServer.canvas_item_set_z_index(item, 1)


func free_rids() -> void:
	for rid in _items + _meshes:
		RenderingServer.free_rid(rid)
	_items.clear()
	_meshes.clear()


func _pin(individual: int, down: bool) -> void:
	var variants := _buffers.size()
	var slot := individual / variants
	var at := place(individual) if down else Vector2.ZERO
	_down[individual] = 1 if down else 0
	_spots[individual] = at
	var data := _buffers[individual % variants]
	data[slot * FLOATS + 3] = at.x
	data[slot * FLOATS + 7] = at.y
	data[slot * FLOATS + 15] = 1.0 if down else 0.0
	for mesh in range(individual % variants, _meshes.size(), variants):
		RenderingServer.multimesh_set_buffer(_meshes[mesh], data)
