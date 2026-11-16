class_name VolumeGlyphs
extends RefCounted
## The pause menu's sound pictograms, as VectorGlyphs (128-unit square, sharp
## at any size, white: tinted on draw): a music note and a burst for the two
## channels, and a speaker with one wave (quieter) or three (louder).

const MUSIC := &"volume_music"
const EFFECTS := &"volume_effects"
const QUIETER := &"volume_quieter"
const LOUDER := &"volume_louder"
const IDS: Array[StringName] = [MUSIC, EFFECTS, QUIETER, LOUDER]
## Where the speaker's waves are centred, and the (outer, inner) radius of each.
const WAVE_CENTRE := Vector2(46, 64)
const WAVES := [[28.0, 16.0], [46.0, 34.0], [64.0, 52.0]]
const BURST_POINTS := 16

static var _textures: Dictionary = {}


static func texture(id: StringName) -> GlyphTexture:
	if not _textures.has(id):
		_textures[id] = GlyphTexture.of(_build(id))
	return _textures[id]


static func _build(id: StringName) -> VectorGlyph:
	var g := VectorGlyph.new()
	match id:
		MUSIC:  # a quaver: a head, a stem and a flag
			g.ring(Vector2(38, 98), 20)
			g.rect(48, 18, 12, 80)
			g.polygon(PackedVector2Array([Vector2(60, 18), Vector2(100, 42), Vector2(100, 70)]))
			g.polygon(PackedVector2Array([Vector2(60, 40), Vector2(86, 58), Vector2(60, 52)]), true)
		EFFECTS:  # a burst: a blow landing
			g.polygon(_burst(Vector2(64, 64), 60.0, 28.0))
		QUIETER:
			_speaker(g, 1)
		LOUDER:
			_speaker(g, 3)
		_:
			push_error("unknown volume glyph %s" % id)
	return g


## A speaker with `waves` half-rings in front of it.
static func _speaker(g: VectorGlyph, waves: int) -> void:
	for index in waves:
		var wave: Array = WAVES[index]
		g.ring(WAVE_CENTRE, wave[0], wave[1])
	g.rect(0, 0, WAVE_CENTRE.x, 128, true)  # keep the right half of each ring
	g.rect(4, 46, 20, 36)
	var cone := [Vector2(22, 46), Vector2(50, 22), Vector2(50, 106), Vector2(22, 82)]
	g.polygon(PackedVector2Array(cone))


static func _burst(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for index in BURST_POINTS:
		var radius := outer if index % 2 == 0 else inner
		var angle := TAU * index / BURST_POINTS - PI / 2.0
		out.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return out
