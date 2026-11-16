class_name FigureBand
extends RefCounted
## The rock band: a generic four-piece (singer, guitar, bass, drums), nobody
## in particular. Black shirts, long hair, the army's colour on the drum.

const PLAYERS := 4
const GAP := 3.4


## One player (0 singer, 1 guitar, 2 bass, 3 drums).
static func build(player: int, detail: bool) -> FigureBuilder:
	var b := FigureBuilder.make(detail)
	_player(b, player)
	return b


## All four side by side: for a band that is ONE entity with one head.
static func whole(detail: bool) -> FigureBuilder:
	var b := FigureBuilder.make(detail)
	for player in PLAYERS:
		b.offset = Vector2((player - 1.5) * GAP, 0.0)
		_player(b, player)
	b.offset = Vector2.ZERO
	return b


static func _player(b: FigureBuilder, player: int) -> void:
	if player == 3:
		_drummer(b)
		return
	FigureParts.back_arm(b, WorldPalette.SOOT.lightened(0.12))
	FigureParts.legs(b, WorldPalette.ARMY_DARK)
	FigureParts.block(b, WorldPalette.SOOT.lightened(0.08))
	FigureParts.head(b)
	FigureParts.hair(b, WorldPalette.HAIR, true)
	b.swing = 1.0
	b.gear = 1.0
	match player:
		0:
			b.swing = 0.0
			b.bar(Vector2(1.2, 0.0), Vector2(1.2, -2.5), 0.1, WorldPalette.STEEL_DARK)
			b.disc(Vector2(1.14, -2.62), Vector2.ONE * 0.2, WorldPalette.STEEL)
			b.swing = 1.0
			FigureParts.arm(b, WorldPalette.SKIN, Vector2(0.95, -3.4))
		1:
			_guitar(b, WorldPalette.GUITAR, 1.7)
		2:
			_guitar(b, WorldPalette.WHITE, 2.1)
	b.swing = 0.0
	b.gear = 0.0


static func _guitar(b: FigureBuilder, tint: Color, reach: float) -> void:
	b.swing = 0.0
	b.bar(Vector2(0.4, -1.5), Vector2(reach, -1.5 - reach * 0.42), 0.16, WorldPalette.WOOD)
	b.disc(Vector2(0.3, -1.42), Vector2(0.6, 0.44), tint, -0.4)
	if b.detail:
		b.disc(Vector2(0.3, -1.42), Vector2(0.16, 0.14), WorldPalette.SOOT)
		b.box(reach - 0.1, -1.7 - reach * 0.42, 0.3, 0.3, WorldPalette.SOOT)
	b.swing = 1.0
	FigureParts.arm(b, WorldPalette.SKIN, Vector2(0.62, -1.3))


## Sits behind a bass drum with the army's ring, a cymbal and two sticks.
static func _drummer(b: FigureBuilder) -> void:
	b.box(-0.5, -0.9, 1.0, 0.24, WorldPalette.WOOD_DARK)
	b.box(-0.1, -0.7, 0.2, 0.7, WorldPalette.STEEL_DARK)
	b.shape([-0.7, -2.2, 0.7, -2.2, 0.55, -0.9, -0.55, -0.9], WorldPalette.SOOT.lightened(0.08))
	b.disc(Vector2(0.0, -2.78), Vector2.ONE * 0.6, WorldPalette.SKIN)
	b.slice(Vector2(0.0, -2.78), Vector2.ONE * 0.64, PI * 0.8, PI * 1.82, WorldPalette.HAIR)
	b.shape([-0.66, -2.9, -0.2, -2.9, -0.5, -1.7, -0.95, -1.75], WorldPalette.HAIR)
	b.gear = 1.0
	b.disc(Vector2(1.1, -0.8), Vector2.ONE * 0.8, WorldPalette.WHITE)
	b.disc(Vector2(1.1, -0.8), Vector2.ONE * 0.56, WorldPalette.ARMY)
	b.disc(Vector2(1.1, -0.8), Vector2.ONE * 0.3, WorldPalette.WHITE)
	b.bar(Vector2(2.0, 0.0), Vector2(2.0, -2.3), 0.08, WorldPalette.STEEL_DARK)
	b.disc(Vector2(2.0, -2.34), Vector2(0.7, 0.1), WorldPalette.BRASS, -0.15)
	if b.detail:
		b.disc(Vector2(0.3, -2.82), Vector2(0.09, 0.12), WorldPalette.SOOT)
		b.box(0.2, -1.75, 0.8, 0.3, WorldPalette.STEEL)
	b.swing = 1.0
	b.bar(Vector2(0.5, -1.92), Vector2(1.0, -1.9), 0.3, WorldPalette.SKIN)
	b.bar(Vector2(0.95, -1.92), Vector2(1.7, -2.6), 0.08, WorldPalette.WOOD)
	b.swing = 0.0
	b.gear = 0.0
