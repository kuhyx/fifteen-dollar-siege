extends GutTest
## The code-drawn figures: one per Kind in two levels of detail, the two teams
## told apart by shape as well as by colour, and the army's look following the
## loadout.

const ARMY_HUMANS: Array[int] = [
	SiegeSnapshot.Kind.MEN, SiegeSnapshot.Kind.BAT_MEN, SiegeSnapshot.Kind.SHOTGUNNER
]
const VILLAGE_KINDS: Array[int] = [
	SiegeSnapshot.Kind.VILLAGERS,
	SiegeSnapshot.Kind.MILITIA,
	SiegeSnapshot.Kind.RETINUE,
	SiegeSnapshot.Kind.ARCHERS
]


func _plain(kind: int) -> FigureSpec:
	return FigureLibrary.spec(kind, FigureLook.new())


func _dressed(kind: int, ids: Array) -> FigureSpec:
	return FigureLibrary.spec(kind, FigureLook.of(Loadout.of(ids)))


func test_every_kind_has_a_near_and_a_far_figure() -> void:
	for kind_name: String in SiegeSnapshot.Kind.keys():
		var spec := _plain(SiegeSnapshot.Kind[kind_name])
		assert_gt(spec.near.size(), 0, kind_name)
		assert_eq(spec.near.size(), spec.far.size(), "%s: a far mesh per variant" % kind_name)
		assert_gt(spec.far_triangles, 0, kind_name)
		assert_gt(spec.near_triangles, spec.far_triangles, "%s: far is simpler" % kind_name)
		assert_between(spec.height, 0.5, 9.0, kind_name)
		assert_gt(spec.spacing, 0.0, kind_name)
		for mesh in spec.near + spec.far:
			assert_eq(mesh.get_surface_count(), 1, kind_name)


func test_no_two_kinds_share_a_figure() -> void:
	var seen := {}
	for kind_name: String in SiegeSnapshot.Kind.keys():
		var spec := _plain(SiegeSnapshot.Kind[kind_name])
		assert_false(
			seen.has(spec.signature), "%s looks like %s" % [kind_name, seen.get(spec.signature)]
		)
		seen[spec.signature] = kind_name
		assert_false(seen.has(spec.far_signature), "%s far twin" % kind_name)
		seen[spec.far_signature] = kind_name


func test_the_teams_differ_in_shape_not_only_in_colour() -> void:
	for kind in ARMY_HUMANS:
		var spec := _plain(kind)
		assert_gt(spec.shoulder_span, spec.hem_span, "army %d: a block, shoulders widest" % kind)
	for kind in VILLAGE_KINDS:
		var spec := _plain(kind)
		assert_gt(spec.hem_span, spec.shoulder_span * 1.3, "village %d: a tunic, hem widest" % kind)
		assert_gt(spec.height, _plain(SiegeSnapshot.Kind.MEN).height * 0.9, "pointed hood")


func test_the_teams_differ_in_colour() -> void:
	assert_eq(_plain(SiegeSnapshot.Kind.MEN).body_tint, Palette.ARMY)
	assert_eq(_plain(SiegeSnapshot.Kind.MILITIA).body_tint, Palette.VILLAGE)
	assert_ne(_plain(SiegeSnapshot.Kind.VILLAGERS).body_tint, Palette.ARMY)


func test_a_look_reads_the_loadout() -> void:
	var look := FigureLook.of(
		Loadout.of([&"knight_armor", &"football_helmets", &"booze", &"metal_bats"])
	)
	assert_true(look.knight)
	assert_true(look.helmet)
	assert_true(look.booze)
	assert_true(look.bats)
	assert_false(look.cardboard)
	assert_eq(FigureLook.new().key(), FigureLook.of(Loadout.new()).key())
	assert_ne(look.key(), FigureLook.new().key())
	assert_gt(look.wobble(), 0.0, "booze sways")
	assert_eq(FigureLook.new().wobble(), 0.0)


func test_each_look_changes_the_army_figure() -> void:
	var plain := _plain(SiegeSnapshot.Kind.MEN).signature
	var seen := {plain: "plain"}
	for id: StringName in [&"knight_armor", &"football_helmets", &"cardboard_armor"]:
		var spec := _dressed(SiegeSnapshot.Kind.MEN, [id])
		assert_false(seen.has(spec.signature), "%s looks like %s" % [id, seen.get(spec.signature)])
		seen[spec.signature] = id
		assert_ne(_dressed(SiegeSnapshot.Kind.MEN, [id]).far_signature, _plain(0).far_signature)
		assert_gt(spec.shoulder_span, spec.hem_span, "%s keeps the army's block shape" % id)


func test_a_look_leaves_the_village_alone() -> void:
	for kind in VILLAGE_KINDS:
		var dressed := _dressed(kind, [&"knight_armor", &"football_helmets"])
		assert_eq(dressed.signature, _plain(kind).signature)


func test_bat_men_carry_a_longer_club_than_men() -> void:
	assert_gt(_plain(SiegeSnapshot.Kind.BAT_MEN).height, _plain(SiegeSnapshot.Kind.MEN).height)


func test_the_band_is_four_different_players() -> void:
	var band := _plain(SiegeSnapshot.Kind.ROCK_BAND)
	assert_eq(band.near.size(), 4)
	assert_not_null(band.whole_near, "one entity can show the whole band")
	assert_not_null(band.whole_far)


func test_the_library_builds_each_figure_once() -> void:
	FigureLibrary.warm(FigureLook.new())
	var before := FigureLibrary.builds
	for kind: int in SiegeSnapshot.Kind.values():
		assert_same(_plain(kind), _plain(kind))
	assert_eq(FigureLibrary.builds, before, "a second ask builds nothing")
	assert_not_null(FigureLibrary.flame())


func test_the_swing_pivot_and_motion_are_set_for_fighters() -> void:
	var men := _plain(SiegeSnapshot.Kind.MEN)
	assert_gt(men.motion.x, 0.0, "men bob when they walk")
	assert_gt(men.motion.w, 0.0, "men swing a club")
	assert_true(men.swings, "the club is tagged for the swing")
	assert_false(_plain(SiegeSnapshot.Kind.VILLAGERS).swings, "villagers carry nothing")
