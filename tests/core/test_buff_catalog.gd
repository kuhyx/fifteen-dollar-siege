extends GutTest
## The catalog is the source meme's 25 buffs: prices, order, verbatim words.

const TIER_SIZES := {5: 7, 4: 5, 3: 5, 2: 4, 1: 4}
## Real names and brands stay in source_text; an id never carries one.
const BANNED_IN_IDS: Array[String] = ["chuck", "norris", "napol", "acdc", "ac_dc", "frank", "ufo"]


func test_there_are_25_buffs_in_price_tiers() -> void:
	var all := BuffCatalog.all()
	assert_eq(all.size(), 25)
	var counts := {}
	for def in all:
		counts[def.price] = counts.get(def.price, 0) + 1
	assert_eq(counts, TIER_SIZES)


func test_the_order_is_the_source_order_dearest_first() -> void:
	var last := 5
	for def in BuffCatalog.all():
		assert_true(def.price <= last, "%s is out of order" % def.id)
		last = def.price


func test_ids_are_unique_neutral_snake_case() -> void:
	var seen := {}
	var snake := RegEx.create_from_string("^[a-z]+(_[a-z]+)*$")
	for def in BuffCatalog.all():
		var id := String(def.id)
		assert_false(seen.has(id), "duplicate id %s" % id)
		seen[id] = true
		assert_not_null(snake.search(id), "%s is not snake_case" % id)
		for word in BANNED_IN_IDS:
			assert_false(id.contains(word), "%s names %s" % [id, word])


func test_by_id_finds_each_buff_and_null_for_an_unknown_one() -> void:
	for def in BuffCatalog.all():
		assert_same(BuffCatalog.by_id(def.id), def)
	assert_null(BuffCatalog.by_id(&"death_ray"))


func test_all_returns_the_same_list_every_time() -> void:
	assert_same(BuffCatalog.all()[0], BuffCatalog.all()[0])
	assert_eq(BuffCatalog.all().size(), 25, "a second call adds nothing")


func test_source_text_is_verbatim_typos_included() -> void:
	assert_eq(BuffCatalog.by_id(&"emperor").source_text, "Napolean leads your men into battle")
	assert_eq(
		BuffCatalog.by_id(&"rock_band").source_text,
		(
			'AC/DC sets up and plays a live performance of "Thunderstruck"'
			+ " are your men march into battle"
		)
	)
	assert_eq(BuffCatalog.by_id(&"prep_hour").source_text, "+1 hour prep time")
	assert_eq(BuffCatalog.by_id(&"fifty_men").source_text, "+50 men join your army")
	assert_eq(
		BuffCatalog.by_id(&"pep_talk").source_text,
		"Chuck Norris gives your men a pep talk before the invasion"
	)
	for def in BuffCatalog.all():
		assert_ne(def.source_text.strip_edges(), "", String(def.id))


func test_prices_of_the_rule_buffs() -> void:
	assert_eq(BuffCatalog.by_id(&"double_men").price, 5)
	assert_eq(BuffCatalog.by_id(&"fifty_men").price, 4)
	assert_eq(BuffCatalog.by_id(&"prep_ten_minutes").price, 1)
