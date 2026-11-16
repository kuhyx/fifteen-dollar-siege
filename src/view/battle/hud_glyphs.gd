class_name HudGlyphs
extends RefCounted
## The battle HUD's own pictograms, as VectorGlyphs (128-unit square, sharp
## at any size, white: tinted on draw). Pictograms shared with other screens
## (flag, charge, retreat, heart, bell, clock) come from `Glyphs`.

const PAUSE := &"pause"
const PLAY := &"play"
const AUTO := &"auto"
const SKIP := &"skip"
const ARMY := &"bust_army"
const VILLAGE := &"bust_village"
const SPEEDS: Array[StringName] = [&"speed_1", &"speed_2", &"speed_3", &"speed_4"]

static var _textures: Dictionary = {}


static func texture(id: StringName) -> GlyphTexture:
	if not _textures.has(id):
		_textures[id] = GlyphTexture.of(_build(id))
	return _textures[id]


static func _build(id: StringName) -> VectorGlyph:
	var g := VectorGlyph.new()
	match id:
		PAUSE:
			g.rect(30, 22, 24, 84)
			g.rect(74, 22, 24, 84)
		PLAY:
			_arrows(g, 1, 56.0)
		AUTO:  # a view finder: four corners around the action
			for corner: Vector2 in [
				Vector2(12, 12), Vector2(84, 12), Vector2(12, 84), Vector2(84, 84)
			]:
				g.rect(corner.x, corner.y + (0.0 if corner.y < 64.0 else 20.0), 32, 12)
				g.rect(corner.x + (0.0 if corner.x < 64.0 else 20.0), corner.y, 12, 32)
			g.ring(Vector2(64, 64), 16)
		SKIP:  # two arrows running into a bar
			_arrows(g, 2, 40.0)
			g.rect(100, 26, 14, 76)
		ARMY:  # a round head on square shoulders
			g.ring(Vector2(64, 40), 26)
			g.polygon(_points([14, 74, 114, 74, 104, 120, 24, 120]))
		VILLAGE:  # a pointed hood over a wide tunic
			g.polygon(_points([64, 4, 96, 58, 32, 58]))
			g.ring(Vector2(64, 50), 20)
			g.polygon(_points([44, 74, 84, 74, 116, 120, 12, 120]))
		_:
			_arrows(g, SPEEDS.find(id) + 1, 0.0)
	return g


## `count` arrows pointing right, side by side: the speeds x1, x2, x4, x8.
static func _arrows(g: VectorGlyph, count: int, wide: float) -> void:
	var step := 104.0 / maxi(count, 1)
	var width := wide if wide > 0.0 else minf(step * 1.15, 56.0)
	var left := 64.0 - (step * (count - 1) + width) / 2.0
	for i in count:
		var x := left + i * step
		g.polygon(_points([x, 24, x + width, 64, x, 104]))


static func _points(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out
