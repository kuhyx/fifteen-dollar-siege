class_name ShopPreview
extends Control
## The card on show, large: its vignette loops on the stage, and under it its
## pictogram stands beside its price in coins (gold when bought, with the
## check). With no card on show the stage is the army itself on the march.
## Everything here is also on the card: nothing is hover-only.

const STRIP_H := 110.0
const GAP := 14.0
const COIN_PX := 44.0

## The buff on show ("" = none: the army marches).
var buff: StringName = &"":
	set(value):
		buff = value
		stage.buff = value
		queue_redraw()
var bought := false:
	set(value):
		bought = value
		queue_redraw()
var stage := VignetteStage.new()
## Width at the strip's right end left free (the go button stands there).
var keep_free := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)


func _ready() -> void:
	_lay_out()
	resized.connect(_lay_out)


func _lay_out() -> void:
	stage.position = Vector2.ZERO
	stage.size = Vector2(size.x, size.y - STRIP_H - GAP)
	queue_redraw()


func _draw() -> void:
	var frame := GlyphButton.box(Palette.CLEAR, Palette.PANEL_PRESSED)
	frame.set_corner_radius_all(0)
	draw_style_box(frame, Rect2(stage.position, stage.size).grow(4.0))
	var def := BuffCatalog.by_id(buff)
	if def == null:
		return
	var strip := Rect2(0, size.y - STRIP_H, size.x - keep_free, STRIP_H)
	var panel := GlyphButton.box(Palette.PANEL)
	draw_style_box(panel, strip)
	var art := Rect2(strip.position + Vector2(18, 7), Vector2.ONE * (STRIP_H - 14.0))
	BuffPictograms.of(buff).draw(self, art)
	var coin := UiPictograms.of(&"coin")
	for i in def.price:
		var corner := Vector2(art.end.x + 28.0 + i * (COIN_PX + 8.0), strip.get_center().y - 22.0)
		coin.draw(
			self, Rect2(corner, Vector2.ONE * COIN_PX), 0.0 if bought else 0.55, Palette.PANEL
		)
	if bought:
		var mark := Rect2(strip.end - Vector2(STRIP_H - 14.0, STRIP_H - 22.0), Vector2.ONE * 66.0)
		UiPictograms.of(&"check").draw(self, mark)
