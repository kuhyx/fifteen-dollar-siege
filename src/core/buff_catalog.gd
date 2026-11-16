class_name BuffCatalog
extends RefCounted
## The 25 buffs of the source meme (todo task df2a2bf2), in its order: price
## tier 5 down to 1. Ids are neutral (no real name or brand reaches the screen);
## the third column is the source text VERBATIM, typos included. Never "fix" it.

const ROWS: Array[Array] = [
	[&"invisibility_potions", 5, "Your army gets 50 potions of invisibility"],
	[&"knight_armor", 5, "Every man in your army gets a full set of knight armor"],
	[&"double_men", 5, "Double the amount of men in your army"],
	[&"abduction", 5, "A UFO abducts 100 random villagers the night before your army invades"],
	[&"stitched_monster", 5, "Frankenstein's monster joins your army"],
	[&"wasps", 5, "300 paper wasps join your army"],
	[&"medics", 5, "20 doctors join your army as medics with medkits"],
	[&"deaf_villagers", 4, "20% of the population of the village you are invading becomes deaf"],
	[&"shotgun", 4, "One man in your army gets a sawed off shotgun with 50 shells"],
	[&"emperor", 4, "Napolean leads your men into battle"],
	[&"fifty_men", 4, "+50 men join your army"],
	[&"golf_carts", 4, "Your army gains 30 golf carts with full tanks of gas"],
	[&"prep_hour", 3, "+1 hour prep time"],
	[&"pumpkin_catapults", 3, "Your army gains portable catapults that launch pumpkins"],
	[
		&"rock_band",
		3,
		(
			'AC/DC sets up and plays a live performance of "Thunderstruck"'
			+ " are your men march into battle"
		)
	],
	[
		&"football_helmets",
		3,
		"Every man in your army wears a football helmet for protection in battle"
	],
	[&"moose", 3, "3 adult moose join your army"],
	[&"metal_bats", 2, "The 10 strongest men in your army get metal baseball bats"],
	[
		&"sleepless_village",
		2,
		"Everybody in the village you are attacking had 4 hours of sleep the night before"
	],
	[&"trumpet_boy", 2, "A boy with a trumpet leads your men into battle, boosting morale"],
	[&"booze", 2, "Each man in your army gets a canteen of booze"],
	[&"pep_talk", 1, "Chuck Norris gives your men a pep talk before the invasion"],
	[&"cardboard_armor", 1, "Your men get a full set of cardboard armor each"],
	[&"stew", 1, "Your men are fed well with vegetable stew before battle"],
	[&"prep_ten_minutes", 1, "You get +10 minutes of prep time"],
]

static var _all: Array[BuffDef] = []
static var _by_id: Dictionary = {}


## Every buff, in the source's order. The same instances on every call.
static func all() -> Array[BuffDef]:
	if _all.is_empty():
		for row: Array in ROWS:
			var def := BuffDef.new(row[0], row[1], row[2])
			_all.append(def)
			_by_id[def.id] = def
	return _all


## The buff with this id, or null for an unknown one.
static func by_id(id: StringName) -> BuffDef:
	all()
	return _by_id.get(id)
