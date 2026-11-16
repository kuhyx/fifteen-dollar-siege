# Sources: the base model

One row per tuning constant of `src/core/siege_tuning.gd` (build-game R6).
`[design guess]` marks a value the research could not source; the words after it
say why it is what it is. Buff constants: `DOCS-design-buff-sources.md`. The
model: `DOCS-design-sim.md`. `tests/core/test_sources.gd` fails when a constant
has no row here or its value differs.

## Source keys

| key | source |
|---|---|
| premise | the meme, verbatim in `DOCS-design.md` section 1; buff texts in `BuffCatalog.ROWS` |
| kuhy | a rule kuhy set (`DOCS-design.md` section 3) |
| acoup | <https://acoup.blog/2022/07/01/collections-total-generalship-commanding-pre-modern-armies-part-iiic-morale-and-cohesion/> |
| dupuy-break | <https://dupuyinstitute.org/2018/04/18/breakpoints-in-u-s-army-doctrine/> |
| dupuy-rtd | <https://dupuyinstitute.org/2023/03/13/returns-to-duty-rtds/> |
| demography | <https://en.wikipedia.org/wiki/Demography_of_England>, <https://blogs.valpo.edu/ellenfoster/?p=750> |
| hue-and-cry | <https://en.wikipedia.org/wiki/Hue_and_cry> |
| assize | <https://en.wikipedia.org/wiki/Assize_of_Arms_of_1181> |
| fyrd | <https://en.wikipedia.org/wiki/Fyrd> |
| bell | <https://www.cambridge.org/core/product/4A645176EDB95A0A8B22416A4E79677F/core-reader> |
| slingshot | <https://crateclub.com/blogs/loadout/how-far-can-a-slingshot-shoot> (a retailer; secondary) |
| mail | <https://en.wikipedia.org/wiki/Mail_(armour)> |
| armour-energy | Askew, Formenti, Minetti 2012, <https://www.ndcn.ox.ac.uk/team/federico-formenti/publication_modal/374524> |
| helmet | <https://en.wikipedia.org/wiki/Football_helmet> |
| paper-armour | <https://www.astm.org/news/paper-armor-indeed-ja11> |
| sleep | <https://pmc.ncbi.nlm.nih.gov/articles/PMC3250358> |
| alcohol | <https://spac.umd.edu/news/story/how-alcohol-dilutes-anxiety>, <https://nhtsa.gov/node/35951>, <https://public.websites.umich.edu/~bbushman/bc90.pdf> |
| meal | <https://thespotter.substack.com/p/fueling-your-workouts-what-to-eat> (secondary) |
| buckshot | <https://athlonoutdoors.com/article/00-buckshot-ammo-test/>, <https://www.shootingillustrated.com/content/buckshot-basics/> |
| gun-noise | <https://prep.asha.org/siteassets/ais/ais-recreational-firearm-noise-exposure.pdf> |
| wasp | <https://en.wikipedia.org/wiki/Schmidt_sting_pain_index>, <https://ask.ifas.ufl.edu/publication/IN1112> |
| moose | <https://en.wikipedia.org/wiki/Moose>, <https://www.adfg.alaska.gov/index.cfm?adfg=viewing.landmammals&species=moose> |
| golf-cart | <https://en.wikipedia.org/wiki/Golf_cart> |
| chunkin | <https://en.wikipedia.org/wiki/Punkin_Chunkin> |
| deafness | <https://www.who.int/news-room/fact-sheets/detail/deafness-and-hearing-loss> |
| synchrony | Wiltermuth and Heath 2009, <https://www.sciencedaily.com/releases/2009/01/090128160930.htm> |

## Per-kind tables (`src/core/siege_kinds.gd`)

| table | source |
|---|---|
| `SiegeKinds.MELEE` | club 1 (premise); farm tools 1.3, retinue spear and training 1.8 ([design guess] from assize); bat 3 for the ten strongest; monster 14, moose 6 [design guess] |
| `SiegeKinds.TOUGH` | mail against clubs 1 / 0.75 (mail, [design guess]); bat men 1.5, monster 10, moose 6 [design guess] |
| `SiegeKinds.SPEED` | jog 3.4, crowd 2.2, mailed 2.9 [design guess]; moose 8.3 = 30 km/h (moose: 24-32 km/h in practice); cart speed is CART_SPEED |

## Constants

| constant | value | source |
|---|---|---|
| `SiegeTuning.STEP_S` | 0.1 | [design guess] 10 logic ticks per second keep a siege under the speed budget; the view interpolates |
| `SiegeTuning.THINK_TICKS` | 5 | [design guess] decisions twice a second: enough for squads, a fifth of the cost |
| `SiegeTuning.THINK_S` | STEP_S * THINK_TICKS | derived: STEP_S x THINK_TICKS |
| `SiegeTuning.TIME_CAP_S` | 300.0 | [design guess] well past the 60-180 s a siege should take |
| `SiegeTuning.ARMY_SPAWN` | Vector2(190.0, 200.0) | [design guess] 130 m from the houses: about 40 s of approach at a jog |
| `SiegeTuning.CENTRE_R` | 25.0 | [design guess] a village green |
| `SiegeTuning.HOLD_S` | 30.0 | kuhy: hold the centre 30 s |
| `SiegeTuning.HOLD_MIN_HEADS` | 10 | [design guess] one squad |
| `SiegeTuning.HOLD_RATIO` | 3.0 | [design guess] three to one: the plaza is yours, not contested |
| `SiegeTuning.LEASH_M` | 60.0 | [design guess] home defenders do not chase far from their houses |
| `SiegeTuning.CROWDS` | 17 | demography: 2,000 people, about 500 men aged 15-50, 0.6 of them fight: 1,700 do not; 17 groups of 100 |
| `SiegeTuning.CROWD_HEADS` | 100 | [design guess] the grouping |
| `SiegeTuning.MILITIA_SQUADS` | 25 | demography + assize: 300 fighters minus retinue and archers = 250 with farm tools |
| `SiegeTuning.ARCHER_SQUADS` | 3 | [design guess] hunting bows for about a tenth of the 300 fighters |
| `SiegeTuning.RETINUE_SQUADS` | 2 | [design guess] a minor lord's household: 8-20 armed men |
| `SiegeTuning.DETECT_M` | 105.0 | [design guess] a column of strangers is seen across about a field |
| `SiegeTuning.DETECT_PER_S` | 0.2 | [design guess] nobody is posted to look |
| `SiegeTuning.SEE_M` | 35.0 | [design guess] across a street nobody misses it |
| `SiegeTuning.ALARM_SPREAD_S` | 30.0 | [design guess] hue-and-cry: person to person, 5-15 min for a village; shown about 15 times faster |
| `SiegeTuning.BELL_DELAY_S` | 5.0 | [design guess] somebody has to run to the church |
| `SiegeTuning.BELL_PERIOD_S` | 4.0 | [design guess] a tolling bell |
| `SiegeTuning.BELL_BOOST` | 2.0 | bell: the bell is the standard alarm signal; the factor is a [design guess] |
| `SiegeTuning.ARM_MIN_S` | 15.0 | fyrd: a muster is slow; 15-30 min until half are armed, shown about 15 times faster |
| `SiegeTuning.ARM_MAX_S` | 60.0 | fyrd: as ARM_MIN_S |
| `SiegeTuning.RETINUE_ARM_S` | 5.0 | [design guess] household men keep their arms at hand |
| `SiegeTuning.SURPRISE_SHOCK` | 0.15 | [design guess] caught at home, unarmed |
| `SiegeTuning.WALK_SHARE` | 0.4 | [design guess] a walk is about 1.4 m/s against a 3.4 m/s jog |
| `SiegeTuning.SPRINT_SHARE` | 1.6 | [design guess] a short sprint of untrained men, about 5.4 m/s |
| `SiegeTuning.ARRIVE_M` | 2.0 | [design guess] close enough |
| `SiegeTuning.CONTACT_M` | 6.0 | [design guess] two squads of ten, shoulder to shoulder |
| `SiegeTuning.ACQUIRE_M` | 50.0 | [design guess] how far a squad looks for a fight (one grid cell) |
| `SiegeTuning.CHASE_M` | 20.0 | [design guess] a routed squad is run down only when close |
| `SiegeTuning.MELEE_RATE` | 0.014 | [design guess] tuned: a clash of two squads lasts 10-20 s before one breaks |
| `SiegeTuning.FRONTAGE` | 1.5 | [design guess] three men can reach two |
| `SiegeTuning.ROUT_DAMAGE` | 2.5 | acoup: most losses occur after the break; the factor is a [design guess] |
| `SiegeTuning.PARTING_S` | 2.0 | acoup: as ROUT_DAMAGE, the blows a breaking squad takes as it turns |
| `SiegeTuning.LIGHT_WOUND_SHARE` | 0.4 | dupuy-rtd: most battle casualties return to duty; 30-40 % within reach of a medic in the fight |
| `SiegeTuning.SLING_RANGE_M` | 20.0 | slingshot: effective 15-25 m |
| `SiegeTuning.SLING_ACC` | 0.15 | [design guess] slingshot: skill needs practice; 10-25 % hits at 15 m for novices |
| `SiegeTuning.SLING_DOWN` | 0.15 | [design guess] a 10 g stone at 50 m/s is about 12 J: a bruise, rarely more |
| `SiegeTuning.SLING_RELOAD_S` | 2.5 | [design guess] load, draw, aim |
| `SiegeTuning.SLING_AMMO` | 12 | [design guess] a pocketful of small stones |
| `SiegeTuning.SLING_STING` | 0.02 | [design guess] pain and flinching, per hit on a squad of ten |
| `SiegeTuning.SLING_VS_MAIL` | 0.2 | mail: no stop on a mailed man; the factor is a [design guess] |
| `SiegeTuning.FRIENDLY_FIRE` | 0.04 | [design guess] untrained slingers behind their own line |
| `SiegeTuning.BOW_RANGE_M` | 50.0 | [design guess] a hunting bow at a crowd |
| `SiegeTuning.BOW_HOLD_M` | 35.0 | [design guess] archers stand off |
| `SiegeTuning.BOW_ACC` | 0.1 | [design guess] hunters, not soldiers, at a moving squad |
| `SiegeTuning.BOW_DOWN` | 0.4 | [design guess] an arrow in an unarmoured man |
| `SiegeTuning.BOW_RELOAD_S` | 3.0 | [design guess] aimed shots |
| `SiegeTuning.BOW_INTO_MELEE` | 0.5 | [design guess] they will not shoot their neighbours |
| `SiegeTuning.COVER` | 0.7 | [design guess] fences and house corners |
| `SiegeTuning.CHARGE_IMPACT` | 2.0 | [design guess] the shock of a rush, for fresh men |
| `SiegeTuning.CHARGE_SHOCK` | 0.15 | acoup: the onset of an enemy is frightening; the value is a [design guess] |
| `SiegeTuning.ARMY_MORALE` | 0.7 | [design guess] strangers who met an hour ago |
| `SiegeTuning.VILLAGE_MORALE` | 0.9 | [design guess] neighbours defending their homes |
| `SiegeTuning.MORALE_JITTER` | 0.08 | [design guess] squads differ |
| `SiegeTuning.COHESION_STRANGERS` | 0.6 | acoup: men stand for neighbours and kin, strangers do not; 0.6 is a [design guess] |
| `SiegeTuning.COHESION_HOME` | 1.3 | acoup: as above, 1.3 for a community at home is a [design guess] |
| `SiegeTuning.COHESION_AWAY` | 1.0 | [design guess] the same men out in the fields |
| `SiegeTuning.CAS_SHOCK` | 2.4 | acoup: pre-modern units broke at 10 % losses or less; tuned so strangers run after one or two men of ten, neighbours after three or four |
| `SiegeTuning.SHOCK_SPREAD` | 0.5 | [design guess] dupuy-break: no fixed breakpoint exists |
| `SiegeTuning.ROUT_AT` | 0.2 | [design guess] the point where a squad runs |
| `SiegeTuning.RALLY_AT` | 0.45 | [design guess] the point where it can be turned |
| `SiegeTuning.ROUT_CAP_SHARE` | 0.75 | [design guess] a squad that ran once runs sooner |
| `SiegeTuning.CONTAGION_M` | 14.0 | [design guess] the squads next to it |
| `SiegeTuning.CONTAGION` | 0.05 | acoup: a rout spreads; the value is a [design guess] |
| `SiegeTuning.GANG_SHOCK` | 0.03 | acoup: a flank or rear attack is a large morale hit; the value is a [design guess] |
| `SiegeTuning.RECOVER_PER_S` | 0.03 | [design guess] nerve comes back slowly |
| `SiegeTuning.QUIET_S` | 2.0 | [design guess] a breather |
| `SiegeTuning.FLAG_RECOVER` | 3.0 | [design guess] men gathered round a flag steady each other |
| `SiegeTuning.RALLY_CLEAR_M` | 30.0 | [design guess] nobody rallies with the enemy on his heels |
| `SiegeTuning.ROUTED_WEIGHT` | 0.5 | [design guess] a squad that may come back is half a squad |
| `SiegeTuning.ARMY_BREAK` | 0.25 | [design guess] the army is routed when a quarter of its nerve is left |
| `SiegeTuning.VILLAGE_BREAK` | 0.465 | dupuy-break: defenders near 40 % losses break almost surely; tuned between that and the home factor |
| `SiegeTuning.LORD_AURA` | 0.1 | acoup: a visible leader steadies men; the value is a [design guess] |
| `SiegeTuning.LORD_FALL_SHOCK` | 0.15 | acoup: rumour of the leader's fall spreads rout; the value is a [design guess] |
| `SiegeTuning.PANIC_SHOCK` | 0.02 | [design guess] the enemy among the families |
| `SiegeTuning.PANIC_M` | 12.0 | [design guess] within reach |
| `SiegeTuning.TIRE_MARCH` | 0.004 | [design guess] a jog across the fields winds a man a little |
| `SiegeTuning.TIRE_SPRINT` | 0.025 | [design guess] untrained men are spent after 30-40 s of sprinting |
| `SiegeTuning.TIRE_FIGHT` | 0.015 | [design guess] hand-to-hand exhausts in about a minute |
| `SiegeTuning.REST` | 0.02 | [design guess] breath comes back in under a minute |
| `SiegeTuning.FATIGUE_SLOW` | 0.35 | [design guess] |
| `SiegeTuning.FATIGUE_WEAK` | 0.5 | [design guess] |
| `SiegeTuning.FATIGUE_SHOCK` | 0.5 | [design guess] tired men break sooner |
