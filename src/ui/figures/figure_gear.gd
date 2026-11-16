class_name FigureGear
extends RefCounted
## What a figure holds or wears: clubs, farm tools, bows, the buff weapons, and
## the three armours the army can buy. Weapons are drawn while the builder's
## `swing` is 1 (the callers set it), so a fight swings them.


static func club(b: FigureBuilder) -> void:
	b.shape([0.9, -1.22, 1.1, -1.16, 1.78, -2.92, 1.3, -3.08], WorldPalette.WOOD)


## The metal bat of the ten strongest: longer than a club, and it shines.
static func bat(b: FigureBuilder) -> void:
	b.shape([0.9, -1.2, 1.1, -1.14, 1.98, -3.5, 1.5, -3.66], WorldPalette.STEEL)
	if b.detail:
		b.shape([0.9, -1.2, 1.1, -1.14, 1.3, -1.68, 1.08, -1.76], WorldPalette.SOOT)
		b.bar(Vector2(1.52, -2.6), Vector2(1.72, -3.3), 0.1, WorldPalette.WHITE)


static func pitchfork(b: FigureBuilder) -> void:
	b.bar(Vector2(0.86, -0.3), Vector2(1.24, -3.2), 0.15, WorldPalette.WOOD)
	b.bar(Vector2(0.86, -3.12), Vector2(1.62, -3.26), 0.14, WorldPalette.STEEL_DARK)
	for x: float in [0.9, 1.26, 1.6]:
		b.bar(Vector2(x, -3.18), Vector2(x + 0.1, -4.0), 0.12, WorldPalette.STEEL_DARK)


static func spear(b: FigureBuilder) -> void:
	b.bar(Vector2(0.92, -0.1), Vector2(1.22, -3.9), 0.14, WorldPalette.WOOD)
	b.shape([1.04, -3.85, 1.42, -3.9, 1.3, -4.6], WorldPalette.STEEL)


## The retinue's kite shield, in the village colour with a pale band.
static func shield(b: FigureBuilder) -> void:
	b.shape([0.42, -2.06, 1.3, -2.06, 1.3, -1.3, 0.86, -0.56, 0.42, -1.3], WorldPalette.VILLAGE)
	if b.detail:
		b.box(0.78, -2.06, 0.16, 1.4, WorldPalette.CLOTH)
		b.box(0.42, -1.72, 0.88, 0.16, WorldPalette.CLOTH)


static func bow(b: FigureBuilder) -> void:
	var curve: Array[Vector2] = [
		Vector2(1.0, -2.75), Vector2(1.42, -2.3), Vector2(1.56, -1.7), Vector2(1.42, -1.1)
	]
	curve.append(Vector2(1.0, -0.65))
	b.strip(curve, 0.14, WorldPalette.WOOD)
	if b.detail:
		b.bar(Vector2(1.0, -2.75), Vector2(1.0, -0.65), 0.05, WorldPalette.CLOTH)
		b.bar(Vector2(0.7, -1.7), Vector2(1.95, -1.7), 0.07, WorldPalette.WOOD_DARK)
		b.shape([1.9, -1.84, 2.2, -1.7, 1.9, -1.56], WorldPalette.STEEL)


static func shotgun(b: FigureBuilder) -> void:
	b.bar(Vector2(0.4, -1.3), Vector2(0.95, -1.5), 0.3, WorldPalette.WOOD)
	b.bar(Vector2(0.9, -1.52), Vector2(2.0, -1.62), 0.2, WorldPalette.SOOT)
	if b.detail:
		b.bar(Vector2(0.9, -1.36), Vector2(1.95, -1.46), 0.14, WorldPalette.STEEL_DARK)


static func trumpet(b: FigureBuilder) -> void:
	b.bar(Vector2(0.5, -2.6), Vector2(1.36, -2.76), 0.16, WorldPalette.BRASS)
	b.shape([1.3, -2.96, 1.86, -3.12, 1.8, -2.44, 1.3, -2.56], WorldPalette.BRASS)


## A white box with a green cross (the game's heal colour) and a handle.
static func medkit(b: FigureBuilder) -> void:
	b.box(0.72, -1.36, 0.86, 0.66, WorldPalette.WHITE)
	b.box(1.06, -1.28, 0.18, 0.5, Palette.GOOD)
	b.box(0.9, -1.12, 0.5, 0.18, Palette.GOOD)
	if b.detail:
		b.box(1.0, -1.5, 0.3, 0.14, WorldPalette.STEEL_DARK)


## Booze: a canteen on the hip (the sway is the crowd shader's work).
static func canteen(b: FigureBuilder) -> void:
	if b.detail:
		b.disc(Vector2(-0.5, -0.9), Vector2(0.24, 0.3), WorldPalette.STEEL_DARK)
		b.box(-0.58, -1.3, 0.16, 0.16, WorldPalette.WOOD_DARK)


## Cardboard armour: a box over the chest, taped, with the army's stripe.
static func cardboard(b: FigureBuilder) -> void:
	b.box(-0.96, -2.3, 1.92, 1.6, WorldPalette.CARDBOARD)
	b.box(-0.18, -2.3, 0.36, 1.6, WorldPalette.ARMY)
	if b.detail:
		b.box(-0.96, -1.62, 1.92, 0.13, WorldPalette.TAPE)
		b.shape([0.42, -1.9, 0.62, -2.16, 0.82, -1.9], WorldPalette.TAPE)


## Knight armour for the body: plate, a tabard in the army's colour, pauldrons.
static func plate(b: FigureBuilder) -> void:
	FigureParts.block(b, WorldPalette.STEEL)
	b.box(-0.26, FigureParts.SHOULDER_Y, 0.52, 1.4, WorldPalette.ARMY)
	if b.detail:
		b.disc(Vector2(-0.8, -2.08), Vector2(0.3, 0.26), WorldPalette.STEEL_DARK)
		b.disc(Vector2(0.8, -2.08), Vector2(0.3, 0.26), WorldPalette.STEEL_DARK)


## A closed helm with a visor slit and a plume in the army's colour.
static func knight_helm(b: FigureBuilder) -> void:
	b.shape([-0.2, -3.28, -0.82, -3.86, -1.0, -3.1, -0.52, -2.96], WorldPalette.ARMY)
	b.disc(FigureParts.HEAD, Vector2.ONE * 0.68, WorldPalette.STEEL)
	b.box(0.02, -2.86, 0.64, 0.14, WorldPalette.SOOT)
	if b.detail:
		b.box(0.26, -2.6, 0.08, 0.34, WorldPalette.STEEL_DARK)
		b.box(0.46, -2.6, 0.08, 0.3, WorldPalette.STEEL_DARK)


## A football helmet: a white shell, the army's stripe, a face cage.
static func football_helmet(b: FigureBuilder) -> void:
	var middle := FigureParts.HEAD + Vector2(-0.06, -0.08)
	b.disc(middle, Vector2.ONE * 0.76, WorldPalette.WHITE)
	b.shape([-0.2, -3.56, 0.14, -3.58, 0.2, -2.9, -0.2, -2.9], WorldPalette.ARMY)
	b.disc(FigureParts.HEAD + Vector2(0.3, 0.1), Vector2(0.34, 0.36), WorldPalette.SKIN)
	if b.detail:
		b.bar(Vector2(0.24, -2.42), Vector2(0.84, -2.5), 0.08, WorldPalette.STEEL_DARK)
		b.bar(Vector2(0.3, -2.72), Vector2(0.86, -2.76), 0.08, WorldPalette.STEEL_DARK)
		b.bar(Vector2(0.84, -2.8), Vector2(0.84, -2.44), 0.08, WorldPalette.STEEL_DARK)


## The retinue's conical helm with a nose guard: pointed, like every village top.
static func nasal_helm(b: FigureBuilder) -> void:
	b.shape([-0.7, -2.86, -0.5, -3.3, 0.06, -3.96, 0.62, -3.3, 0.72, -2.86], WorldPalette.STEEL)
	if b.detail:
		b.box(0.34, -2.9, 0.12, 0.5, WorldPalette.STEEL_DARK)
		b.box(-0.72, -2.94, 1.46, 0.12, WorldPalette.STEEL_DARK)
