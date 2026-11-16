class_name Glyphs
extends RefCounted
## The scaffold's pictograms as VectorGlyphs (128-unit square, sharp at any
## size, white: tint on draw). Placeholder art: the art agent replaces the
## shapes, the ids stay. Unknown ids are an error, never a silent blank.

static var _textures: Dictionary = {}


static func texture(id: StringName) -> GlyphTexture:
	if not _textures.has(id):
		_textures[id] = GlyphTexture.of(_build(id))
	return _textures[id]


static func has(id: StringName) -> bool:
	return not _build(id).pieces.is_empty()


static func _build(id: StringName) -> VectorGlyph:
	var g := VectorGlyph.new()
	match id:
		&"watch":  # an eye
			g.polygon(_points([[8, 64], [40, 30], [88, 30], [120, 64], [88, 98], [40, 98]]))
			g.ring(Vector2(64, 64), 24, 0.0, true)
			g.ring(Vector2(64, 64), 13)
		&"command", &"rally", &"win":  # a flag on a pole
			g.rect(28, 12, 10, 108)
			g.polygon(_points([[38, 16], [108, 38], [38, 62]]))
		&"lab":  # a bar chart
			g.rect(16, 76, 22, 36)
			g.rect(52, 44, 22, 68)
			g.rect(88, 18, 22, 94)
			g.rect(10, 112, 108, 6)
		&"play", &"resume":
			g.polygon(_points([[36, 20], [106, 64], [36, 108]]))
		&"back":
			g.polygon(_points([[14, 64], [58, 24], [58, 104]]))
			g.rect(56, 52, 56, 24)
		&"home":
			g.polygon(_points([[64, 12], [118, 62], [10, 62]]))
			g.rect(26, 62, 76, 52)
			g.rect(54, 80, 20, 34, true)
		&"quit":  # a power mark
			g.ring(Vector2(64, 68), 46, 34)
			g.rect(50, 8, 28, 52, true)
			g.rect(58, 10, 12, 52)
		&"menu":
			g.rect(20, 28, 88, 14)
			g.rect(20, 57, 88, 14)
			g.rect(20, 86, 88, 14)
		&"coin":
			g.ring(Vector2(64, 64), 52)
			g.ring(Vector2(64, 64), 38, 30, true)
		&"combust":  # a flame
			g.polygon(_points([[64, 6], [98, 62], [90, 98], [64, 120], [38, 98], [30, 62]]))
			g.polygon(_points([[64, 62], [80, 92], [64, 110], [48, 92]]), true)
		&"charge":  # a double arrow forward
			g.polygon(_points([[14, 24], [60, 64], [14, 104]]))
			g.polygon(_points([[62, 24], [112, 64], [62, 104]]))
		&"retreat":  # a turn-back arrow
			g.polygon(_points([[10, 44], [46, 12], [46, 76]]))
			g.rect(44, 34, 50, 20)
			g.rect(88, 34, 20, 72)
			g.rect(30, 86, 78, 20)
		&"morale":  # a heart
			g.ring(Vector2(42, 46), 28)
			g.ring(Vector2(86, 46), 28)
			g.polygon(_points([[16, 58], [112, 58], [64, 116]]))
		&"alarm":  # a bell
			g.polygon(_points([[64, 10], [96, 40], [102, 92], [26, 92], [32, 40]]))
			g.rect(14, 92, 100, 12)
			g.ring(Vector2(64, 112), 10)
		&"men":  # a head and shoulders
			g.ring(Vector2(64, 36), 24)
			g.polygon(_points([[22, 118], [34, 70], [94, 70], [106, 118]]))
		&"clock":
			g.ring(Vector2(64, 64), 52, 40)
			g.rect(59, 30, 10, 38)
			g.rect(59, 59, 34, 10)
		&"buff":  # a placeholder card mark: a four-point star
			g.polygon(
				_points(
					[[64, 8], [78, 50], [120, 64], [78, 78], [64, 120], [50, 78], [8, 64], [50, 50]]
				)
			)
		&"check":
			g.line(Vector2(22, 66), Vector2(52, 96), 16)
			g.line(Vector2(52, 96), Vector2(106, 30), 16)
		_:
			push_error("unknown glyph %s" % id)
	return g


static func _points(pairs: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pair: Array in pairs:
		out.append(Vector2(pair[0], pair[1]))
	return out
