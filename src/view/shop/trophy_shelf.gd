class_name TrophyShelf
extends Control
## The hub's progress you can see: 25 slots on two boards, one per buff. A
## buff that has been part of a won siege stands there in colour; the others
## are dark outlines waiting. A buff won with for the first time gets a spark.

const SLOT := 120.0
const GAP := 16.0
const PER_ROW := 13
const BOARD_H := 12.0
const ROW_PITCH := 170.0
const WAITING := Palette.WAITING
## A wave of light crosses the shelf every PERIOD_S real seconds and takes
## SWEEP_S to cross; the slots it passes brighten and the won ones hop.
const PERIOD_S := 4.5
const SWEEP_S := 1.8
const WAVE_PX := 170.0
const HOP_PX := 16.0

## Buffs won with (filled slots).
var won: Array[StringName] = []:
	set(value):
		won = value
		queue_redraw()
## Buffs that are new on the shelf: drawn with a spark.
var fresh: Array[StringName] = []:
	set(value):
		fresh = value
		queue_redraw()

var _age := 0.0


static func wide() -> float:
	return PER_ROW * (SLOT + GAP) - GAP


static func high() -> float:
	return ROW_PITCH + SLOT + BOARD_H + 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## How much of the passing wave slot `index` carries at `age` (0..1).
static func glow(index: int, age: float) -> float:
	var front := fmod(age, PERIOD_S) / SWEEP_S * (wide() + 2.0 * WAVE_PX) - WAVE_PX
	var centre := (index % PER_ROW) * (SLOT + GAP) + SLOT / 2.0
	return exp(-pow((centre - front) / (WAVE_PX * 0.5), 2.0))


## The slot of buff number `index` (catalogue order), in this control's space.
func slot(index: int) -> Rect2:
	var corner := Vector2((index % PER_ROW) * (SLOT + GAP), (index / PER_ROW) * ROW_PITCH)
	return Rect2(corner, Vector2.ONE * SLOT)


func _draw() -> void:
	var defs := BuffCatalog.all()
	var board := PictoInk.WOOD.darkened(0.45)
	for row in 2:
		var count := mini(defs.size() - row * PER_ROW, PER_ROW)
		var plank := Rect2(
			-12.0, row * ROW_PITCH + SLOT + 4.0, count * (SLOT + GAP) - GAP + 24.0, BOARD_H
		)
		draw_rect(plank, board)
	for i in defs.size():
		var id := defs[i].id
		var lit := glow(i, _age)
		var box := slot(i).grow(-8.0)
		var picture := BuffPictograms.of(id)
		if won.has(id):
			picture.draw(self, Rect2(box.position - Vector2(0.0, HOP_PX * lit), box.size))
		else:
			picture.draw_flat(self, box, WAITING.lerp(Palette.INK, 0.6 * lit))
		if fresh.has(id):
			UiPictograms.of(&"spark").draw(
				self, Rect2(box.position - Vector2(6, 6), Vector2(40, 40))
			)
