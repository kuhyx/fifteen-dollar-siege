class_name CoinFlight
extends Control
## The coins in the air between the tray and a card: each one leaves a moment
## after the one before, flies an arc and lands. The shop counts what is still
## heading for a target, so a coin is always in exactly one place: the tray,
## the air or a card.

signal landed(target: StringName)

## Seconds one coin flies. [design guess]: quick enough to buy in a row.
const FLY_S := 0.26
## Seconds between two coins of one buy leaving.
const STAGGER_S := 0.045
## How high the arc rises above the straight line, in canvas units.
const ARC := 70.0
const COIN_PX := 44.0

## Each coin: {from, to, target, wait, age}.
var _coins: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Sends one coin between two canvas points; `order` staggers a group.
func send(from: Vector2, to: Vector2, target: StringName, order: int) -> void:
	_coins.append({"from": from, "to": to, "target": target, "wait": order * STAGGER_S, "age": 0.0})
	set_process(true)


## Coins still on their way to `target`.
func heading_to(target: StringName) -> int:
	var count := 0
	for coin in _coins:
		if coin["target"] == target:
			count += 1
	return count


func in_air() -> int:
	return _coins.size()


## Takes the coins heading to `target` out of the air (their owner changed its mind).
func cancel(target: StringName) -> void:
	_coins = _coins.filter(func(coin: Dictionary) -> bool: return coin["target"] != target)
	queue_redraw()


func _process(delta: float) -> void:
	var down: Array[StringName] = []
	for coin in _coins:
		if coin["wait"] > 0.0:
			coin["wait"] -= delta
		else:
			coin["age"] += delta
		if coin["age"] >= FLY_S:
			down.append(coin["target"])
	_coins = _coins.filter(func(coin: Dictionary) -> bool: return coin["age"] < FLY_S)
	if _coins.is_empty():
		set_process(false)
	queue_redraw()
	for target in down:
		landed.emit(target)


func _draw() -> void:
	var to_local := get_global_transform().affine_inverse()
	var picture := UiPictograms.of(&"coin")
	for coin in _coins:
		if coin["wait"] > 0.0:
			continue
		var along := smoothstep(0.0, 1.0, coin["age"] / FLY_S)
		var from: Vector2 = coin["from"]
		var at := from.lerp(coin["to"], along) + Vector2(0, -sin(along * PI) * ARC)
		var box := Rect2(to_local * at - Vector2.ONE * COIN_PX / 2.0, Vector2.ONE * COIN_PX)
		picture.draw(self, box)
