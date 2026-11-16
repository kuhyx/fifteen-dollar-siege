class_name SiegeFixtures
extends RefCounted
## Two pinned sieges for the bot and the tests: a loadout and seed that WIN and
## a loadout and seed that LOSE under the real sim, in Watch mode, under the
## bot's Command-mode orders, and (by a clear margin) as a Lab batch starting
## at that seed. tests/core/test_siege_fixtures.gd holds them to it.
## After any tuning change find new seeds with tools/sim/find_fixtures.gd.
## The winning loadout adds no heads to the army (the bot counts the men).

const WIN_IDS: Array[StringName] = [&"double_men", &"golf_carts", &"knight_armor", &"pep_talk"]
const WIN_SEED := 22
const LOSE_IDS: Array[StringName] = [&"pep_talk", &"stew"]
const LOSE_SEED := 1
