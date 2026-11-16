class_name HudButton
extends GlyphButton
## One HUD control: a pictogram, and in its corner the key or pad button that
## does the same, read from the InputMap for the device in use (no badge on a
## touch screen: the button is the control). `lit` marks the active choice
## with a frame as well as a colour. No words; `accessibility_name` speaks.

const SIZE := 96.0
const BADGE := 40.0

## The InputMap action this button stands for.
var action: StringName = &""
## The active choice (the current speed, a held pause, auto camera).
var lit := false:
	set(value):
		lit = value
		_restyle()
## True when the badge is the UNKNOWN cap: a binding without a picture.
var badge_unknown := false

var _badge: GlyphTexture


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
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("hover", GlyphButton.box(Palette.PANEL_HOVER))
	button.add_theme_stylebox_override("pressed", GlyphButton.box(Palette.PANEL_PRESSED))
	button._restyle()
	button.refresh_badge()
	return button


## Reads the action's binding for the device in use and shows its picture.
func refresh_badge() -> void:
	var event := SiegeActions.event_for(action)
	_badge = KeyGlyphs.texture(event) if event != null else null
	badge_unknown = event != null and not KeyGlyphs.known(event)
	queue_redraw()


func has_badge() -> bool:
	return _badge != null


## The picture in the corner (null on a touch screen).
func badge() -> GlyphTexture:
	return _badge


func _restyle() -> void:
	var frame := Palette.COIN if lit else Color.TRANSPARENT
	add_theme_stylebox_override("normal", GlyphButton.box(Palette.PANEL, frame))
	add_theme_color_override("icon_normal_color", Palette.COIN if lit else Palette.INK)


func _draw() -> void:
	if _badge == null:
		return
	var corner := size - Vector2.ONE * (BADGE - 6.0)
	var chip := Rect2(corner, Vector2.ONE * BADGE)
	draw_style_box(GlyphButton.box(Palette.PANEL.darkened(0.4)), chip)
	draw_texture_rect(_badge, chip.grow(-8.0), false, Palette.INK)
