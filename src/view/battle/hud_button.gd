class_name HudButton
extends GlyphButton
## One HUD control: a pictogram, and in its corner the key or pad button that
## does the same: the game's one `KeyHint`, read from the InputMap for the
## device in use (nothing on a touch screen: the button is the control).
## `lit` marks the active choice with a frame as well as a colour. No words;
## `accessibility_name` speaks.

const SIZE := 96.0
const BADGE := 40.0

## The InputMap action this button stands for.
var action: StringName = &""
## The active choice (the current speed, a held pause, auto camera).
var lit := false:
	set(value):
		lit = value
		_restyle()
## The key picture in the corner.
var hint: KeyHint


static func create(
	picture: Texture2D, spoken: String, p_action: StringName, px := SIZE
) -> HudButton:
	var button := HudButton.new()
	button.name = "Hud_%s" % p_action
	button.action = p_action
	button.icon = picture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2.ONE * px
	button.accessibility_name = spoken
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("icon_hover_color", Palette.NO_TINT)
	button.add_theme_color_override("icon_pressed_color", Palette.NO_TINT)
	button.add_theme_stylebox_override("hover", GlyphButton.box(Palette.PANEL_HOVER))
	button.add_theme_stylebox_override("pressed", GlyphButton.box(Palette.PANEL_PRESSED))
	button._restyle()
	button.hint = KeyHint.attach(button, p_action, BADGE, false)
	return button


## True while the control shows a key or pad button.
func has_badge() -> bool:
	return hint.glyph_event() != null


## True when its binding has no picture (a placeholder: tests fail on it).
func badge_unknown() -> bool:
	return hint.unknown()


## The event whose picture is in the corner (null on a touch screen).
func badge_event() -> InputEvent:
	return hint.glyph_event()


func _restyle() -> void:
	var frame := Palette.COIN if lit else Palette.CLEAR
	add_theme_stylebox_override("normal", GlyphButton.box(Palette.PANEL, frame))
	add_theme_color_override("icon_normal_color", Palette.COIN if lit else Palette.INK)
