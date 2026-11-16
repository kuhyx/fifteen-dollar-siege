class_name PictoButton
extends Button
## A control that is only a picture: a multi-colour pictogram on a rounded
## panel, no words. `spoken` is what a screen reader says; it is never drawn.
## Mouse, touch (the emulated mouse), keyboard and pad (focus + accept) all
## press it; KeyHint.attach adds a key of its own.

## The picture fills the button's shorter side less this share on each edge.
const PAD := 0.14

var picture: Pictogram
## A disabled button's picture is mixed this far toward its panel.
var faded := 0.6

var _fill := Palette.PANEL


static func make(
	p_picture: Pictogram, spoken: String, p_size: Vector2, fill := Palette.PANEL
) -> PictoButton:
	var button := PictoButton.new()
	button.picture = p_picture
	button._fill = fill
	button.custom_minimum_size = p_size
	button.size = p_size
	button.accessibility_name = spoken
	button.add_theme_stylebox_override("normal", GlyphButton.box(fill))
	button.add_theme_stylebox_override("hover", GlyphButton.box(fill.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", GlyphButton.box(fill.lightened(0.22)))
	button.add_theme_stylebox_override("disabled", GlyphButton.box(fill.darkened(0.2)))
	button.add_theme_stylebox_override("focus", GlyphButton.box(Palette.CLEAR, Palette.INK))
	return button


## The square the picture is drawn into, in the button's own space.
func art_box() -> Rect2:
	var side := minf(size.x, size.y) * (1.0 - 2.0 * PAD)
	return Rect2((size - Vector2.ONE * side) / 2.0, Vector2.ONE * side)


func _draw() -> void:
	if picture != null:
		picture.draw(self, art_box(), faded if disabled else 0.0, _fill)
