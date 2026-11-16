class_name BuffDef
extends RefCounted
## One buff the player can buy before the siege: a neutral id, its price in
## dollars and the source's own words (typos kept). The words are repo data
## and the accessibility label of the card; they are never drawn on screen.

var id: StringName
var price: int
var source_text: String


func _init(p_id: StringName = &"", p_price: int = 0, p_source_text: String = "") -> void:
	id = p_id
	price = p_price
	source_text = p_source_text
