class_name SquadVisual
extends RefCounted
## One sim entity on screen: `capacity` individuals in one MultiMesh per
## figure variant, drawn through the RenderingServer with the crowd shader.
## The shader moves the living with the anchor; an individual that falls is
## pinned to the spot in its instance transform and stays there.

## Floats per instance: 2D transform (8), colour (4), custom (4).
const FLOATS := 16
## Seconds the last man of a moving squad trails behind [design guess].
const LAG_S := 0.3
## Seconds for spread, fade and flames to settle [design guess].
const SETTLE_S := 0.35
const FLEE_SPREAD := 1.6
const FIGHT_SPREAD := 0.9
const MOVE_SPREAD := 1.1

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
## Extra spread from a rout, decaying.
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
var _sent: Dictionary = {}
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
	material.set_shader_parameter("motion", spec.motion)
	material.set_shader_parameter("pivot", spec.pivot)
	material.set_shader_parameter("buzz", spec.buzz)
	material.set_shader_parameter("hover", spec.hover)
	material.set_shader_parameter("down_turn", spec.down_turn)
	var shapes := spec.meshes(far, heads)
	for variant in shapes.size():
		_buffers.append(_buffer(variant, shapes.size()))
		_meshes.append(_multimesh(shapes[variant], _buffers[variant]))
		_items.append(_item(_meshes[variant], material))


## Heads alive now: the missing ones fall where they stand, in a fixed order;
## when the count grows again the last to fall stand up first.
func set_heads(heads: int) -> void:
	var target := clampi(heads, 0, capacity)
	while alive > target:
		alive -= 1
		_pin(_order[capacity - alive - 1], true)
	while alive < target:
		_pin(_order[capacity - alive - 1], false)
		alive += 1


func set_far(far: bool) -> void:
	var shapes := spec.meshes(far, capacity)
	for variant in mini(shapes.size(), _meshes.size()):
		RenderingServer.multimesh_set_mesh(_meshes[variant], shapes[variant].get_rid())


## This frame's pose: where the anchor is, how fast it moves, what it does.
func pose(at: Vector2, velocity: Vector2, p_state: int, facing: float, delta: float) -> void:
	var blend := 1.0 - exp(-delta / SETTLE_S)
	state = p_state
	anchor = at
	spread = lerpf(spread, spread_goal(), blend)
	fade = lerpf(fade, fade_goal(), blend)
	scatter = lerpf(scatter, 0.0, blend * 0.5)
	_lag = _lag.lerp(velocity * LAG_S, blend)
	_send("anchor", anchor)
	_send("spread", spread)
	_send("lag", _lag)
	_send("fade", fade)
	_send("pose", float(state))
	var hidden := state == SiegeSnapshot.State.HIDDEN and team == SiegeSnapshot.Team.ARMY
	_send("shimmer", 1.0 if hidden else 0.0)
	if absf(cos(facing)) > 0.2:
		_send("flip", signf(cos(facing)))
	if burning:
		_flame_size = lerpf(_flame_size, 1.0, blend * 0.4)
		_send("burn", _flame_size)
		for uniform: String in ["anchor", "spread", "lag"]:
			_flame_material.set_shader_parameter(uniform, _sent[uniform])
		_flame_material.set_shader_parameter("flame", maxf(_flame_size, 0.05))


## Sets a shader value only when it changed (most squads stand still).
func _send(uniform: String, value: Variant) -> void:
	if _sent.get(uniform) != value:
		_sent[uniform] = value
		material.set_shader_parameter(uniform, value)


func set_clock(clock: float) -> void:
	material.set_shader_parameter("clock", clock)
	if burning:
		_flame_material.set_shader_parameter("clock", clock)


## The disc the squad wants to fill for its heads and its state.
func spread_goal() -> float:
	var wide := 1.0 + scatter
	match state:
		SiegeSnapshot.State.FLEE:
			wide *= FLEE_SPREAD
		SiegeSnapshot.State.FIGHT:
			wide *= FIGHT_SPREAD
		SiegeSnapshot.State.MOVE:
			wide *= MOVE_SPREAD
	return CrowdScatter.radius(spec.spacing, maxi(alive, 1) if capacity > 1 else 0) * wide


## 0 hides the squad: villagers in hiding are indoors.
func fade_goal() -> float:
	var indoors := state == SiegeSnapshot.State.HIDDEN and team == SiegeSnapshot.Team.VILLAGE
	return 0.0 if indoors else 1.0


func fallen() -> int:
	return capacity - alive


func is_down(individual: int) -> bool:
	return _down[individual] == 1


## Where an individual is drawn, in map metres.
func place(individual: int) -> Vector2:
	if _down[individual] == 1:
		return _spots[individual]
	return anchor + _homes[individual] * spread - _lag * _phases[individual]


## Sets every figure of the squad on fire (flames grow in `pose`).
func ignite(flame: FigureSpec) -> void:
	if burning:
		return
	burning = true
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = material.shader
	for variant in _buffers.size():
		var fire := _multimesh(flame.near[0], _buffers[variant])
		_meshes.append(fire)
		_items.append(_item(fire, _flame_material))


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


func _buffer(variant: int, variants: int) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	for individual in range(variant, capacity, variants):
		var shade := 0.86 + 0.14 * _phases[individual]
		var home := _homes[individual]
		data.append_array([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, shade, shade, shade, 1.0])
		data.append_array([home.x, home.y, _phases[individual], 0.0])
	return data


func _multimesh(shape: Mesh, data: PackedFloat32Array) -> RID:
	var rid := RenderingServer.multimesh_create()
	var count := data.size() / FLOATS
	RenderingServer.multimesh_allocate_data(
		rid, count, RenderingServer.MULTIMESH_TRANSFORM_2D, true, true
	)
	RenderingServer.multimesh_set_mesh(rid, shape.get_rid())
	if count > 0:
		RenderingServer.multimesh_set_buffer(rid, data)
	return rid


func _item(mesh: RID, look: ShaderMaterial) -> RID:
	var item := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(item, _parent)
	RenderingServer.canvas_item_add_multimesh(item, mesh)
	RenderingServer.canvas_item_set_material(item, look.get_rid())
	RenderingServer.canvas_item_set_custom_rect(item, true, _rect)
	return item
