extends GutTest
## The buff pictograms: one per buff id, vector, inside the 128-unit square,
## and no two alike (a coarse colour raster of each is compared with every
## other). A buff without a pictogram fails here before it reaches the shop.

const GRID := 12
## Share of the grid cells two pictograms must differ in.
const MIN_DIFFERENT := 0.18


## One colour per grid cell (the front-most layer covering its centre).
func _raster(picture: Pictogram) -> Array[Color]:
	var cells: Array[Color] = []
	var step := Pictogram.UNITS / GRID
	for row in GRID:
		for column in GRID:
			var point := Vector2((column + 0.5) * step, (row + 0.5) * step)
			cells.append(picture.color_at(point))
	return cells


func _difference(a: Array[Color], b: Array[Color]) -> float:
	var different := 0
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			different += 1
	return float(different) / a.size()


func test_every_buff_has_a_pictogram_inside_the_square() -> void:
	assert_eq(BuffCatalog.all().size(), 25)
	for def in BuffCatalog.all():
		assert_true(BuffPictograms.has(def.id), "%s has a pictogram" % def.id)
		var picture := BuffPictograms.of(def.id)
		assert_gt(picture.layers.size(), 1, "%s uses more than one colour" % def.id)
		assert_gt(picture.area(), 900.0, "%s fills enough of the card" % def.id)
		var box := picture.bounds()
		assert_true(Rect2(0, 0, 128, 128).grow(0.5).encloses(box), "%s %s" % [def.id, box])
		assert_gt(minf(box.size.x, box.size.y), 70.0, "%s is not a sliver" % def.id)


func test_no_two_buff_pictograms_look_alike() -> void:
	var rasters: Dictionary = {}
	for def in BuffCatalog.all():
		rasters[def.id] = _raster(BuffPictograms.of(def.id))
	var ids := rasters.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var apart := _difference(rasters[ids[i]], rasters[ids[j]])
			assert_gt(apart, MIN_DIFFERENT, "%s and %s look alike" % [ids[i], ids[j]])


func test_an_unknown_buff_has_no_pictogram() -> void:
	assert_false(BuffPictograms.has(&"no_such_buff"))
	assert_true(BuffPictograms.of(&"no_such_buff").is_empty())
	assert_push_error("no pictogram")


func test_the_pictogram_colours_come_from_one_palette() -> void:
	var allowed := PictoInk.all()
	for def in BuffCatalog.all():
		for tint in BuffPictograms.of(def.id).tints:
			assert_true(allowed.has(tint), "%s uses %s" % [def.id, tint])


func test_a_pictogram_builds_a_feathered_mesh_per_size() -> void:
	var brush := PictoBrush.new()
	brush.ink(PictoInk.LIGHT)
	brush.box(20, 20, 80, 60)
	brush.ink(PictoInk.GOLD)
	brush.disc(64, 64, 20)
	var picture := brush.picture
	assert_eq(picture.layers.size(), 2)
	assert_eq(picture.color_at(Vector2(64, 64)), PictoInk.GOLD, "the front layer wins")
	assert_eq(picture.color_at(Vector2(24, 24)), PictoInk.LIGHT)
	assert_eq(picture.color_at(Vector2(2, 2)), Color.TRANSPARENT)
	var small := picture.mesh_for(0.5)
	var large := picture.mesh_for(4.0)
	assert_gt(small["points"].size(), 8, "fill and feather vertices")
	assert_eq(small["points"].size(), small["colors"].size())
	assert_eq(small["indices"].size() % 3, 0)
	assert_ne(small["points"], large["points"], "the feather follows the size on screen")
	assert_same(picture.mesh_for(4.0), large, "built once per size step")
