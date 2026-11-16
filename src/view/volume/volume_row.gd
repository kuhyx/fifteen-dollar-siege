class_name VolumeRow
extends HBoxContainer
## One channel's volume on the pause menu: its pictogram, a speaker button
## (quieter), the steps, a speaker button (louder). The level lives in the
## AudioDirector (`AudioDirector.live()`), which keeps it in the save and puts
## it on the bus; this row only asks and shows. Each button shows the key that
## does the same (the game's one `KeyHint`). No words; `accessibility_name`
## speaks.

const MUSIC := &"music"
const EFFECTS := &"effects"
const BUTTON_PX := 110.0
const ICON_PX := 96.0
const BADGE_PX := 44.0
const GAP := 24

var channel: StringName = MUSIC
var quieter: GlyphButton
var louder: GlyphButton
var bar := VolumeBar.new()


static func make(p_channel: StringName) -> VolumeRow:
	VolumeKeys.ensure()
	var row := VolumeRow.new()
	var music := p_channel == MUSIC
	row.channel = p_channel
	row.name = "Volume_%s" % p_channel
	row.add_theme_constant_override("separation", GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = VolumeGlyphs.texture(VolumeGlyphs.MUSIC if music else VolumeGlyphs.EFFECTS)
	icon.custom_minimum_size = Vector2.ONE * ICON_PX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Palette.DIM
	icon.accessibility_name = "Music volume" if music else "Effects volume"
	row.add_child(icon)
	row.quieter = _button(
		VolumeGlyphs.QUIETER, "Quieter", VolumeKeys.MUSIC_DOWN if music else VolumeKeys.EFFECTS_DOWN
	)
	row.quieter.pressed.connect(row.step_by.bind(-1))
	row.add_child(row.quieter)
	row.bar.picked.connect(row.set_step)
	row.add_child(row.bar)
	row.louder = _button(
		VolumeGlyphs.LOUDER, "Louder", VolumeKeys.MUSIC_UP if music else VolumeKeys.EFFECTS_UP
	)
	row.louder.pressed.connect(row.step_by.bind(1))
	row.add_child(row.louder)
	return row


static func _button(glyph: StringName, spoken: String, action: StringName) -> GlyphButton:
	var button := GlyphButton.new()
	button.name = "Glyph_%s" % glyph
	button.icon = VolumeGlyphs.texture(glyph)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2.ONE * BUTTON_PX
	button.accessibility_name = spoken
	button.add_theme_color_override("icon_normal_color", Palette.INK)
	button.add_theme_color_override("icon_hover_color", Palette.NO_TINT)
	button.add_theme_color_override("icon_pressed_color", Palette.NO_TINT)
	button.add_theme_color_override("icon_focus_color", Palette.NO_TINT)
	button.add_theme_stylebox_override("normal", GlyphButton.box(Palette.PANEL))
	button.add_theme_stylebox_override("hover", GlyphButton.box(Palette.PANEL_HOVER))
	button.add_theme_stylebox_override("pressed", GlyphButton.box(Palette.PANEL_PRESSED))
	button.add_theme_stylebox_override("focus", GlyphButton.box(Palette.PANEL_HOVER, Palette.INK))
	KeyHint.attach(button, action, BADGE_PX)
	return button


## The step (0..STEPS) now on the channel; 0 when no game audio runs.
func level() -> int:
	var director := AudioDirector.live()
	if director == null:
		return 0
	return AudioSettings.step_of(
		director.settings.music if channel == MUSIC else director.settings.sfx
	)


func step_by(delta: int) -> void:
	set_step(level() + delta)


## Puts the channel on `step`: the director keeps it and sets the bus.
func set_step(step: int) -> void:
	var director := AudioDirector.live()
	if director == null:
		return
	var linear := AudioSettings.linear_of(clampi(step, 0, AudioSettings.STEPS))
	if channel == MUSIC:
		director.set_music_volume(linear)
	else:
		director.set_sfx_volume(linear)
	refresh()


## Shows the channel's current step.
func refresh() -> void:
	bar.level = level()
