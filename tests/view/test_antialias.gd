extends GutTest
## Antialiasing on the Compatibility renderer. MSAA 2D does nothing there (the
## Godot docs list it for Forward+ and Mobile only, and a frame with it on is
## pixel-identical to one without), so the edges are feathered by hand: every
## figure shape carries a one-pixel fringe the crowd shader pushes outward.

const FEATHER := Color(1, 1, 1, 0)


func _square() -> FigureBuilder:
	var b := FigureBuilder.make(true)
	b.box(0.0, -2.0, 1.0, 2.0, Color.RED)
	return b


func _arrays(b: FigureBuilder) -> Array:
	return b.mesh().surface_get_arrays(0)


func test_a_shape_gets_a_fringe_vertex_for_each_corner() -> void:
	var arrays := _arrays(_square())
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(colors.size(), 8, "four corners, four fringe corners")
	var clear := 0
	for tint in colors:
		if is_zero_approx(tint.a):
			clear += 1
	assert_eq(clear, 4, "the fringe fades out")


func test_the_fringe_points_outward_in_the_uv() -> void:
	var arrays := _arrays(_square())
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var verts: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
	var centre := Vector2(0.5, -1.0)
	for i in range(4, 8):
		assert_gt(uvs[i].y, 0.5, "marked as fringe")
		var out := Vector2.from_angle(uvs[i].y - FigureBuilder.FRINGE_FLAG)
		var corner := verts[i]
		assert_gt(out.dot(corner - centre), 0.0, "away from the middle")
	for i in 4:
		assert_lt(uvs[i].y, 0.5, "the body is not fringe")


func test_the_fringe_does_not_change_the_figure_s_own_geometry() -> void:
	var b := _square()
	assert_eq(b.triangles(), 2)
	assert_eq(b.bounds(), Rect2(0.0, -2.0, 1.0, 2.0))
	assert_eq(b.body_tint(), Color.RED)


func test_every_figure_of_the_game_is_feathered() -> void:
	for kind: int in SiegeSnapshot.Kind.values():
		var spec := FigureLibrary.spec(kind, FigureLook.new())
		for mesh: ArrayMesh in spec.near + spec.far:
			var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			var clear := 0
			for tint in colors:
				clear += 1 if is_zero_approx(tint.a) else 0
			assert_gt(clear, 0, "kind %d has no fringe" % kind)


func test_the_shader_knows_how_big_a_pixel_is() -> void:
	assert_almost_eq(CrowdLayer.pixel_m_for(4.0), 0.25, 0.0001)
	assert_gt(CrowdLayer.pixel_m_for(1.0), CrowdLayer.pixel_m_for(10.0))
