class_name FigureSpec
extends RefCounted
## One kind's figure, ready to draw: its meshes in two levels of detail (one
## per variant: the band has four players), how far apart a squad of it
## stands, and how it moves (the crowd shader's amplitudes).

const SHOULDER_PROBE := -2.0
const HEM_PROBE := -0.5

var kind := 0
## Meshes seen up close, one per variant; figure i of a squad wears variant
## i % size.
var near: Array[ArrayMesh] = []
## The same variants, simplified for a zoomed-out view.
var far: Array[ArrayMesh] = []
## All variants in one mesh (null when there is one variant): for an entity
## that is a whole band with a single head.
var whole_near: ArrayMesh
var whole_far: ArrayMesh
## Metres from the feet to the top.
var height := 0.0
## Metres between two figures of a squad.
var spacing := 1.45
## Amplitudes of bob (walk), shake (fight), lean (flee), swing (weapon arm).
var motion := Vector4.ZERO
## Metres of constant jitter (wasps) and of slow hovering (the UFO).
var buzz := 0.0
var hover := 0.0
## Radians a fallen figure is turned (a man lies flat, a catapult tips).
var down_turn := 1.5
## What the swing arm turns about, in figure metres.
var pivot := Vector2.ZERO
var near_triangles := 0
var far_triangles := 0
var signature := 0
var far_signature := 0
## Body width high and low (far level): the team's outline.
var shoulder_span := 0.0
var hem_span := 0.0
var body_tint := Color.TRANSPARENT
var swings := false


static func from(
	p_kind: int, nears: Array[FigureBuilder], fars: Array[FigureBuilder]
) -> FigureSpec:
	var spec := FigureSpec.new()
	spec.kind = p_kind
	var near_marks: Array[int] = []
	var far_marks: Array[int] = []
	for i in nears.size():
		spec.near.append(nears[i].mesh())
		spec.far.append(fars[i].mesh())
		spec.near_triangles += nears[i].triangles()
		spec.far_triangles += fars[i].triangles()
		spec.height = maxf(spec.height, nears[i].height())
		spec.swings = spec.swings or nears[i].swings()
		near_marks.append(nears[i].signature())
		far_marks.append(fars[i].signature())
	spec.signature = near_marks.hash()
	spec.far_signature = far_marks.hash()
	var size := fars[0].scale
	spec.shoulder_span = fars[0].span_at(SHOULDER_PROBE * size)
	spec.hem_span = fars[0].span_at(HEM_PROBE * size)
	spec.body_tint = nears[0].body_tint()
	return spec


## Hands the crowd shader this figure's amplitudes.
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("motion", motion)
	material.set_shader_parameter("pivot", pivot)
	material.set_shader_parameter("buzz", buzz)
	material.set_shader_parameter("hover", hover)
	material.set_shader_parameter("down_turn", down_turn)


## The meshes a squad of `heads` draws with, at one level of detail.
func meshes(is_far: bool, heads: int) -> Array[ArrayMesh]:
	var whole := whole_far if is_far else whole_near
	if whole != null and heads < near.size():
		return [whole]
	return far if is_far else near
