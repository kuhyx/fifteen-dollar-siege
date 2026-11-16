class_name GlyphButton
extends Button
## An icon-only button: a pictogram, no words. `spoken` is the accessibility
## label a screen reader says; it is never drawn. Works with mouse, touch
## (emulated mouse) and keyboard / pad focus (ui_accept).

const RADIUS := 18


static func make(glyph: StringName, spoken: String, px := 160.0) -> GlyphButton:
	var button := GlyphButton.new()
	button.name = "Glyph_%s" % glyph
	button.icon = Glyphs.texture(glyph)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2.ONE * px
	button.accessibility_name = spoken
	button.add_theme_color_override("icon_normal_color", Palette.INK)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_focus_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", box(Palette.PANEL))
	button.add_theme_stylebox_override("hover", box(Palette.PANEL_HOVER))
	button.add_theme_stylebox_override("pressed", box(Palette.PANEL_PRESSED))
	button.add_theme_stylebox_override("focus", box(Palette.PANEL_HOVER, Palette.INK))
	return button


## A rounded panel; `border` (when given) draws a 4 px outline.
static func box(fill: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(RADIUS)
	style.set_content_margin_all(18)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(4)
	return style
