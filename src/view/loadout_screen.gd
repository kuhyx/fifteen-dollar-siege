class_name LoadoutScreen
extends Control
## Buy buffs with the 15 dollars: 25 cards in price rows (5 down to 1), the
## budget as 15 coins (gold = still unspent), the army size as a number, a go
## button. A buy over the budget is refused: the card shakes red and nothing
## changes. SCAFFOLD view: the view agent replaces it and keeps the signals,
## `loadout`, `cards`, `toggle` and `pick_at`.

signal start_pressed(loadout: Loadout)
signal back_pressed
signal changed(id: StringName, bought: bool, cost: int)
signal refused(id: StringName)

const BAR_H := 150.0
const SIDE_PX := 150.0
const COIN_PX := 44.0
const MEN_H := 64.0

var loadout := Loadout.new()
## Buff id -> BuffCard.
var cards: Dictionary = {}
var go_button: GlyphButton
var back_button: GlyphButton


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The top bar leaves the corners free: the menu button (left) and the dev
	# camera glyph (right) live there.
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = SIDE_PX
	bar.offset_right = -SIDE_PX
	bar.offset_top = 20.0
	bar.offset_bottom = 130.0
	add_child(bar)
	back_button = GlyphButton.make(&"back", "Back to the hub", 110.0)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	bar.add_child(back_button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	go_button = GlyphButton.make(&"play", "Start the siege", 110.0)
	go_button.pressed.connect(func() -> void: start_pressed.emit(loadout.duplicate()))
	bar.add_child(go_button)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.offset_top = BAR_H
	add_child(rows)
	var row: HBoxContainer = null
	var price := -1
	var index := 0
	for def in BuffCatalog.all():
		if def.price != price:
			price = def.price
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			rows.add_child(row)
		var card := BuffCard.make(def, index)
		card.pressed.connect(toggle.bind(def.id))
		row.add_child(card)
		cards[def.id] = card
		index += 1


func _ready() -> void:
	_refresh()
	go_button.grab_focus()


## Starts from `p_loadout` (a copy; illegal ones start empty).
func preset(p_loadout: Loadout) -> void:
	loadout = p_loadout.duplicate() if p_loadout.is_legal() else Loadout.new()
	_refresh()


## Buys or sells one buff; false when the buy was refused (over the budget).
func toggle(id: StringName) -> bool:
	if not loadout.toggle(id):
		if cards.has(id):
			(cards[id] as BuffCard).shake()
		refused.emit(id)
		return false
	_refresh()
	changed.emit(id, loadout.has(id), loadout.cost())
	return true


## What is under a canvas point (dev feedback's select tool), {} for nothing.
func pick_at(point: Vector2) -> Dictionary:
	for id: StringName in cards:
		var card := cards[id] as BuffCard
		if card.get_global_rect().has_point(point):
			var state := "bought" if card.bought else "for sale"
			return {"kind": "buff_card", "id": String(id), "state": state, "price": card.def.price}
	return {}


func _refresh() -> void:
	for id: StringName in cards:
		var card := cards[id] as BuffCard
		card.bought = loadout.has(id)
		card.out_of_reach = not card.bought and card.def.price > loadout.remaining()
	queue_redraw()


func _draw() -> void:
	var total := Loadout.BUDGET * (COIN_PX + 8.0) - 8.0
	var x := size.x / 2.0 - total / 2.0
	for i in Loadout.BUDGET:
		var coin := Rect2(Vector2(x + i * (COIN_PX + 8.0), 24.0), Vector2.ONE * COIN_PX)
		var unspent := i < loadout.remaining()
		var tint := Palette.COIN if unspent else Palette.COIN_SPENT
		draw_texture_rect(Glyphs.texture(&"coin"), coin, false, tint)
	var men := SiegeSim.army_size(loadout)
	var men_w := SevenSegment.width(men, MEN_H)
	var left := size.x / 2.0 - (men_w + MEN_H + 16.0) / 2.0
	var icon := Rect2(Vector2(left, 80.0), Vector2.ONE * MEN_H)
	draw_texture_rect(Glyphs.texture(&"men"), icon, false, Palette.ARMY)
	SevenSegment.draw_number(self, men, Vector2(left + MEN_H + 16.0, 80.0), MEN_H, Palette.INK)
