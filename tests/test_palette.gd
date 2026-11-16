extends GutTest
## One palette from the design system's tokens: every colour of `Palette` is a
## token or a recorded mix of two, rebuilt here from the token values. A
## drifted value or a colour with no recipe fails. (No literal outside the
## palette file: scripts/check_palette.sh.)

const NOT_COLOURS: Array[String] = ["NO_TINT", "CLEAR", "MIXES"]
const TOLERANCE := 0.002


func _consts() -> Dictionary:
	return (Palette as GDScript).get_script_constant_map()


func test_every_colour_is_a_token_or_a_mix_of_two() -> void:
	var consts := _consts()
	for name: String in Palette.MIXES:
		var recipe: Array = Palette.MIXES[name]
		var first: Color = consts["T_" + recipe[0]]
		var second: Color = consts["T_" + recipe[1]]
		var expected := first.lerp(second, float(recipe[2]))
		var have: Color = consts[name]
		assert_almost_eq(have.r, expected.r, TOLERANCE, "%s red" % name)
		assert_almost_eq(have.g, expected.g, TOLERANCE, "%s green" % name)
		assert_almost_eq(have.b, expected.b, TOLERANCE, "%s blue" % name)
		var alpha := float(recipe[3]) if recipe.size() > 3 else 1.0
		assert_almost_eq(have.a, alpha, TOLERANCE, "%s alpha" % name)


func test_no_colour_is_missing_its_recipe() -> void:
	var consts := _consts()
	for name: String in consts:
		if name.begins_with("T_") or NOT_COLOURS.has(name):
			continue
		assert_true(Palette.MIXES.has(name), "%s has no recipe" % name)


func test_the_tokens_are_the_design_system_s() -> void:
	var consts := _consts()
	assert_eq((consts["T_INK"] as Color).to_html(false).to_upper(), "211D1B")
	assert_eq((consts["T_ACCENT"] as Color).to_html(false).to_upper(), "B8862E")
	assert_eq((consts["T_DANGER"] as Color).to_html(false).to_upper(), "E2585F")
	assert_eq((consts["T_CAT_2"] as Color).to_html(false).to_upper(), "398FC0")


func test_the_other_palette_names_are_aliases_of_it() -> void:
	assert_eq(WorldPalette.ARMY, Palette.ARMY)
	assert_eq(WorldPalette.WHITE, Palette.INK)
	assert_eq(PictoInk.VIOLET, Palette.VIOLET)
	assert_eq(PictoInk.WOOD, Palette.PICTO_WOOD)
