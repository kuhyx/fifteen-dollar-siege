class_name GlyphTexture
extends Texture2D
## A VectorGlyph that any Texture2D slot can show (TextureRect, Button.icon,
## draw_texture_rect): it draws the vector shapes at the size asked for, so it
## never blurs when the screen is bigger than the layout. Not for 3D (use
## VectorGlyph.mesh there: a 3D material needs a real texture).

var glyph: VectorGlyph
## Natural size in pixels (what a theme slot like a slider grabber lays out with).
var px: int = int(VectorGlyph.UNITS)
## Colour baked in for slots that cannot tint (a theme icon); white = tint on draw.
var tint: Color = Color.WHITE


static func of(p_glyph: VectorGlyph, p_px := int(VectorGlyph.UNITS)) -> GlyphTexture:
	var tex := GlyphTexture.new()
	tex.glyph = p_glyph
	tex.px = p_px
	return tex


func _get_width() -> int:
	return px


func _get_height() -> int:
	return px


func _has_alpha() -> bool:
	return true


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, _transpose: bool) -> void:
	glyph.draw_rid(to_canvas_item, Rect2(pos, Vector2.ONE * px), modulate * tint)


func _draw_rect(
	to_canvas_item: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool
) -> void:
	glyph.draw_rid(to_canvas_item, rect, modulate * tint)


func _draw_rect_region(
	to_canvas_item: RID, rect: Rect2, _src: Rect2, modulate: Color, _transpose: bool, _clip_uv: bool
) -> void:
	glyph.draw_rid(to_canvas_item, rect, modulate * tint)
