extends GutTest
## The buffs gate's table (BuffSigns) is complete: every buff is either given
## signs or named stat-only (its chip is all there is), and every effect and
## cue it counts on exists.

const STAT_ONLY: Array[StringName] = [
	&"deaf_villagers", &"prep_hour", &"prep_ten_minutes", &"sleepless_village", &"stew"
]


func test_every_buff_has_signs_or_is_stat_only() -> void:
	for def in BuffCatalog.all():
		assert_eq(BuffSigns.is_stat_only(def.id), def.id in STAT_ONLY, def.id)
	for id: StringName in BuffSigns.SIGNS:
		assert_not_null(BuffCatalog.by_id(id), "%s is a buff" % id)


func test_no_buff_is_chip_only_any_more() -> void:
	for id in STAT_ONLY:
		assert_true(BuffSigns.MOMENTS.has(id), "%s needs a moment of its own on the field" % id)
	for id: StringName in BuffSigns.MOMENTS:
		assert_not_null(BuffCatalog.by_id(id), "%s is a buff" % id)


func test_every_event_a_sign_names_has_an_effect_and_a_cue() -> void:
	for id: StringName in BuffSigns.SIGNS:
		for event: StringName in BuffSigns.SIGNS[id][1]:
			assert_true(BattleEffects.handles(event), "%s of %s has an effect" % [event, id])
			assert_ne(AudioCues.for_event({"kind": event}), &"", "%s of %s has a cue" % [event, id])


func test_the_kinds_a_sign_names_exist_in_the_contract() -> void:
	for id: StringName in BuffSigns.SIGNS:
		var kind: int = BuffSigns.SIGNS[id][0]
		assert_true(kind == BuffSigns.NONE or kind in SiegeSnapshot.Kind.values(), id)


func test_an_effect_is_counted_and_a_cue_is_heard() -> void:
	var battle := BattleScreen.new()
	battle.loadout = Loadout.of([&"shotgun"])
	battle.setup(SiegeSim.create(battle.loadout, 1), &"watch", 1.0)
	add_child_autofree(battle)
	var event := {"kind": SiegeEvent.SHOTGUN_BLAST, "pos": Vector2(200.0, 200.0)}
	battle.effects.spawn(event)
	assert_eq(battle.effects.seen[SiegeEvent.SHOTGUN_BLAST], 1)
	assert_eq(BuffSigns.missing(battle, &"stew"), "no chip", "a buff not bought has no chip")
