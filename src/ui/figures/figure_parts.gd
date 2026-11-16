class_name FigureParts
extends RefCounted
## The pieces every human figure is put together from: legs, one of two body
## shapes, head, arms. The army wears a BLOCK (shoulders widest, round head);
## the village a TUNIC (hem widest, pointed hood): the teams differ in outline,
## not only in colour. Metres; feet at the origin; the figure faces +x.

const HEAD := Vector2(0.0, -2.74)
const HEAD_R := 0.62
const SHOULDER_Y := -2.14
const HIP_Y := -0.74
const HEM_Y := -0.36
## The shoulder of the weapon arm: what a swing turns about.
const PIVOT := Vector2(0.5, -1.92)
const HAND := Vector2(1.02, -1.42)


static func legs(b: FigureBuilder, tint: Color, shoes := WorldPalette.SOOT) -> void:
	if not b.detail:
		b.box(-0.46, -0.8, 0.92, 0.8, tint)
		return
	b.box(-0.5, -0.8, 0.4, 0.8, tint)
	b.box(0.1, -0.8, 0.4, 0.8, tint)
	b.box(-0.5, -0.17, 0.54, 0.17, shoes)
	b.box(0.1, -0.17, 0.54, 0.17, shoes)


## The army's body: a block, widest at the shoulders.
static func block(b: FigureBuilder, tint: Color) -> void:
	b.shape([-0.84, SHOULDER_Y, 0.84, SHOULDER_Y, 0.64, HIP_Y, -0.64, HIP_Y], tint)


## The village's body: a tunic, widest at the hem.
static func tunic(b: FigureBuilder, tint: Color) -> void:
	b.shape([-0.48, SHOULDER_Y, 0.48, SHOULDER_Y, 1.0, HEM_Y, -1.0, HEM_Y], tint)
	if b.detail:
		b.box(-0.62, -1.42, 1.24, 0.14, WorldPalette.WOOD_DARK)


static func head(b: FigureBuilder, skin := WorldPalette.SKIN) -> void:
	b.disc(HEAD, Vector2.ONE * HEAD_R, skin)
	if b.detail:
		b.disc(HEAD + Vector2(0.3, -0.04), Vector2(0.09, 0.12), WorldPalette.SOOT)


## Hair over the top and the back of the head (the back is -x).
static func hair(b: FigureBuilder, tint := WorldPalette.HAIR, long := false) -> void:
	b.slice(HEAD, Vector2.ONE * HEAD_R * 1.06, PI * 0.8, PI * 1.82, tint)
	if long:
		b.shape([-0.66, -2.9, -0.2, -2.9, -0.5, -1.7, -0.95, -1.75], tint)


## The village's pointed hood: drawn before the head, its tip stands above it.
static func hood(b: FigureBuilder, tint: Color) -> void:
	b.shape([-0.8, -2.3, -0.62, -3.1, 0.08, -3.92, 0.7, -3.1, 0.6, -2.5], tint)


## The weapon arm, from the shoulder to `hand` (tag it with swing first).
static func arm(b: FigureBuilder, sleeve: Color, hand := HAND) -> void:
	b.bar(PIVOT, hand, 0.32, sleeve)
	if b.detail:
		b.disc(hand, Vector2.ONE * 0.19, WorldPalette.SKIN)


## The other arm, hanging at the back.
static func back_arm(b: FigureBuilder, sleeve: Color) -> void:
	if b.detail:
		b.bar(Vector2(-0.62, -1.98), Vector2(-0.88, -1.22), 0.3, sleeve)


## A plain army man without his weapon: legs, block, back arm, head, hair.
static func man(b: FigureBuilder, shirt: Color, trousers: Color) -> void:
	back_arm(b, shirt.darkened(0.18))
	legs(b, trousers)
	block(b, shirt)
	head(b)
	hair(b)


## A plain villager without tools: feet, tunic, hood, face.
static func villager(b: FigureBuilder, cloth: Color, hood_tint: Color) -> void:
	back_arm(b, cloth.darkened(0.18))
	legs(b, WorldPalette.WOOD_DARK)
	tunic(b, cloth)
	hood(b, hood_tint)
	head(b)
