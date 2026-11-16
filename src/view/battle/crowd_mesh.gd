class_name CrowdMesh
extends RefCounted
## The RenderingServer calls behind a squad: one MultiMesh of 2D instances
## with a colour and a custom value each, and the canvas item that draws it
## with the crowd shader.

## Floats per instance: 2D transform (8), colour (4), custom (4).
const FLOATS := 16


## The instance data of one variant: every `variants`-th individual from
## `variant` on, each at the origin (the shader places it), a shade of its
## own, and its home and phase as the custom value.
static func buffer(
	homes: PackedVector2Array, phases: PackedFloat32Array, variant: int, variants: int
) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	for individual in range(variant, homes.size(), variants):
		var shade := 0.86 + 0.14 * phases[individual]
		var home := homes[individual]
		data.append_array([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, shade, shade, shade, 1.0])
		data.append_array([home.x, home.y, phases[individual], 0.0])
	return data


## A MultiMesh of `shape`, one instance per FLOATS of `data`.
static func multimesh(shape: Mesh, data: PackedFloat32Array) -> RID:
	var rid := RenderingServer.multimesh_create()
	var count := data.size() / FLOATS
	RenderingServer.multimesh_allocate_data(
		rid, count, RenderingServer.MULTIMESH_TRANSFORM_2D, true, true
	)
	RenderingServer.multimesh_set_mesh(rid, shape.get_rid())
	if count > 0:
		RenderingServer.multimesh_set_buffer(rid, data)
	return rid


## A canvas item under `parent` that draws `mesh` with `look`. The shader
## moves the figures, so the item is never culled by where the mesh "is":
## `rect` (the whole map) says where it may draw.
static func item(parent: RID, mesh: RID, look: ShaderMaterial, rect: Rect2) -> RID:
	var rid := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, parent)
	RenderingServer.canvas_item_add_multimesh(rid, mesh)
	RenderingServer.canvas_item_set_material(rid, look.get_rid())
	RenderingServer.canvas_item_set_custom_rect(rid, true, rect)
	return rid
