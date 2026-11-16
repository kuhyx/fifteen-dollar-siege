class_name LoadoutScreen
extends Control
## The buff shop. 25 cards stand on five price shelves (5 dollars down to 1);
## the 15 dollars are coins in a tray that fly into a card when it is bought
## and back when it is sold. A card the dollars left do not reach is dimmed,
## and trying it shakes the tray: nothing is ever written. The card on show
## (hovered, focused, or tapped once) plays its vignette in the preview; a
## click buys, on touch the second tap does. The go button starts the siege.
## Kept for the bot, the tests and the dev tools: the signals, `loadout`,
## `cards`, `go_button`, `back_button`, `toggle` and `pick_at`.

signal start_pressed(loadout: Loadout)
signal back_pressed
signal changed(id: StringName, bought: bool, cost: int)
signal refused(id: StringName)

## The flight target that means "back into the tray".
const TRAY := &"tray"
const GO_FILL := Color(0.24, 0.5, 0.28)

var loadout := Loadout.new()
## Buff id -> BuffCard.
var cards: Dictionary = {}
var go_button: PictoButton
var back_button: PictoButton
var tray := CoinTray.new()
var flight := CoinFlight.new()
var preview := ShopPreview.new()
var army := ArmyMeter.new()
## The card on show in the preview ("" = none yet).
var focused_id: StringName = &""


func _init() -> void:
	var frame := ScreenFrame.into(self)
	back_button = PictoButton.make(UiPictograms.of(&"back"), "Back to the hub", Vector2(100, 100))
	frame.place(back_button, Rect2(144, 22, 100, 100))
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	KeyHint.attach(back_button, MenuKeys.BACK)
	frame.place(tray, Rect2(290, 24, CoinTray.wide(), CoinTray.HIGH))
	var rows := PriceRows.new()
	frame.place(rows, Rect2(40, 142, 1290, 920))
	for def in BuffCatalog.all():
		var card := BuffCard.make(def)
		frame.place(card, Rect2(rows.position + rows.next_spot(def.price), BuffCard.SIZE))
		card.pressed.connect(_on_card_pressed.bind(card))
		card.mouse_entered.connect(_on_card_hovered.bind(def.id))
		card.focus_entered.connect(_on_card_focused.bind(def.id))
		cards[def.id] = card
	frame.place(army, Rect2(1352, 150, 528, 170))
	preview.keep_free = 300.0
	frame.place(preview, Rect2(1010, 331, 870, 704))
	var go := UiPictograms.of(&"go")
	go_button = PictoButton.make(go, "Start the siege", Vector2(280, 110), GO_FILL)
	frame.place(go_button, Rect2(1600, 925, 280, 110))
	go_button.pressed.connect(func() -> void: start_pressed.emit(loadout.duplicate()))
	KeyHint.attach(go_button, MenuKeys.PICKS[0])
	add_child(flight)
	flight.landed.connect(func(_target: StringName) -> void: _settle())


func _ready() -> void:
	_refresh()
	go_button.grab_focus()


## Starts from `p_loadout` (a copy; illegal ones start empty).
func preset(p_loadout: Loadout) -> void:
	loadout = p_loadout.duplicate() if p_loadout.is_legal() else Loadout.new()
	_refresh()


## Buys or sells one buff; false when the buy was refused (over the budget).
func toggle(id: StringName) -> bool:
	var card := cards.get(id) as BuffCard
	if not loadout.toggle(id):
		tray.shake()
		if card != null:
			card.shake()
		refused.emit(id)
		return false
	var bought := loadout.has(id)
	if card != null and is_inside_tree():
		_fly(card, bought)
		card.pop(bought)
	_refresh()
	changed.emit(id, bought, loadout.cost())
	return true


## Puts a card on show: its frame lights and the preview plays its vignette.
func focus_card(id: StringName) -> void:
	if not cards.has(id) or id == focused_id:
		return
	if cards.has(focused_id):
		(cards[focused_id] as BuffCard).shown = false
	focused_id = id
	(cards[id] as BuffCard).shown = true
	preview.buff = id
	preview.bought = loadout.has(id)


## A press on a card. A finger looks first (tap to show, tap again to buy);
## a mouse or a key already shows the card it points at, so it buys at once.
func press(id: StringName, from_touch: bool) -> void:
	if from_touch and focused_id != id:
		focus_card(id)
		return
	focus_card(id)
	toggle(id)


## What is under a canvas point (dev feedback's select tool), {} for nothing.
func pick_at(point: Vector2) -> Dictionary:
	for id: StringName in cards:
		var card := cards[id] as BuffCard
		if card.get_global_rect().has_point(point):
			var state := "bought" if card.bought else "for sale"
			return {"kind": "buff_card", "id": String(id), "state": state, "price": card.def.price}
	if tray.get_global_rect().has_point(point):
		return {"kind": "coin_tray", "id": "budget", "state": "%d left" % loadout.remaining()}
	return {}


func _input(event: InputEvent) -> void:
	MenuKeys.note(event)


func _on_card_pressed(card: BuffCard) -> void:
	press(card.def.id, card.take_touch())


## A real mouse over a card shows it; a finger has no hover (it taps to look).
## The engine reports "entered" before anyone has seen the event that caused
## it, so the device is only known a moment later: decide then.
func _on_card_hovered(id: StringName) -> void:
	_show_if_mouse.call_deferred(id)


func _show_if_mouse(id: StringName) -> void:
	if MenuKeys.device != MenuKeys.Device.TOUCH:
		focus_card(id)


## Keyboard or pad focus shows the card; the focus a click gives does not
## count, or a finger's first tap would already be its second.
func _on_card_focused(id: StringName) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		focus_card(id)


## Sends a card's coins through the air: from the tray's right end for a buy,
## back into the first empty slots for a sell.
func _fly(card: BuffCard, bought: bool) -> void:
	var id := card.def.id
	var price := card.def.price
	flight.cancel(id)
	for i in price:
		if bought:
			var from := tray.slot_center(loadout.remaining() + price - 1 - i)
			flight.send(from, card.slot_center(i), id, i)
		else:
			var to := tray.slot_center(loadout.remaining() - price + i)
			flight.send(card.slot_center(i), to, TRAY, i)


## Every coin is in one place: what is in the air is not yet where it lands.
func _settle() -> void:
	tray.coins = loadout.remaining() - flight.heading_to(TRAY)
	for id: StringName in cards:
		var card := cards[id] as BuffCard
		var paid := card.def.price if loadout.has(id) else 0
		card.coins_in = maxi(paid - flight.heading_to(id), 0)


func _refresh() -> void:
	for id: StringName in cards:
		var card := cards[id] as BuffCard
		card.bought = loadout.has(id)
		card.out_of_reach = not card.bought and card.def.price > loadout.remaining()
	army.men = SiegeSim.army_size(loadout)
	preview.stage.men = army.men
	preview.bought = loadout.has(focused_id)
	_settle()
