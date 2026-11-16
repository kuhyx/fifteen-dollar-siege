# Sources: the 25 buffs

One row per constant of `src/core/buff_tuning.gd` (build-game R6). Keys and
the `[design guess]` convention: `DOCS-design-sources.md`. What each buff does:
`DOCS-design-sim.md`.

| constant | value | source |
|---|---|---|
| `BuffTuning.FIFTY_COHESION` | 0.99 | [design guess] a few more strangers |
| `BuffTuning.FIFTY_NOISE` | 1.07 | [design guess] a bigger column is noticed from further |
| `BuffTuning.DOUBLE_COHESION` | 0.9 | [design guess] twice the strangers, lower average cohesion |
| `BuffTuning.DOUBLE_NOISE` | 1.15 | [design guess] a bigger, louder column |
| `BuffTuning.PREP_HOUR_COHESION` | 1.15 | [design guess] synchrony: drill raises cooperation; +15 % for an hour |
| `BuffTuning.PREP_HOUR_SHOCK` | 0.95 | [design guess] rout threshold +5 % |
| `BuffTuning.PREP_HOUR_ACC` | 1.1 | [design guess] an hour with the slingshot |
| `BuffTuning.PREP_TEN_COHESION` | 1.03 | [design guess] one formation or one signal: +2-3 % |
| `BuffTuning.PREP_TEN_ACC` | 1.03 | [design guess] as PREP_TEN_COHESION |
| `BuffTuning.PEP_MORALE` | 0.1 | [design guess] a one-off 10-20 % lift |
| `BuffTuning.PEP_FADE_S` | 120.0 | [design guess] it wears off: nothing real behind it |
| `BuffTuning.BOOZE_SHOCK` | 0.77 | alcohol: a 0.4 g/kg dose damps the fear response; rout threshold +30 % |
| `BuffTuning.BOOZE_ACC` | 0.85 | alcohol: coordination and tracking are worse at 0.05 BAC |
| `BuffTuning.BOOZE_MELEE` | 0.95 | alcohol: as BOOZE_ACC, less for gross movement |
| `BuffTuning.BOOZE_FRIENDLY_FIRE` | 2.0 | alcohol: more aggression when provoked; the factor is a [design guess] |
| `BuffTuning.BOOZE_MORALE` | 0.05 | alcohol: liquid courage; the value is a [design guess] |
| `BuffTuning.BOOZE_IGNORE` | 0.25 | [design guess] drunk squads do not listen |
| `BuffTuning.STEW_TIRE` | 0.95 | meal: a pre-effort meal barely matters under an hour: +5 % stamina |
| `BuffTuning.STEW_MORALE` | 0.02 | [design guess] fed men grumble less |
| `BuffTuning.KNIGHT_SPEED` | 0.85 | armour-energy: armour slows; 0.8 for untrained men, softened in tuning |
| `BuffTuning.KNIGHT_TIRE` | 1.3 | armour-energy: 30-50 kg of plate costs 2.1-2.3 times the energy; mail-weight interpolation 1.3-1.5 |
| `BuffTuning.KNIGHT_MELEE_HURT` | 0.3 | mail: stops cuts and most thrusts of farm tools; the factor is a [design guess] |
| `BuffTuning.KNIGHT_RANGED_HURT` | 0.4 | mail: only strong bows pierce; 0.6 softened in tuning |
| `BuffTuning.KNIGHT_ACC` | 0.9 | [design guess] a stranger in a harness that does not fit |
| `BuffTuning.KNIGHT_SHOCK` | 0.85 | [design guess] a man in full harness feels safe |
| `BuffTuning.HELMET_MELEE_HURT` | 0.8 | helmet: stops skull fractures, not concussion; the head is a fifth of the hits |
| `BuffTuning.HELMET_RANGED_HURT` | 0.7 | helmet: as HELMET_MELEE_HURT, arrows come from above |
| `BuffTuning.HELMET_FRIENDLY_HURT` | 0.3 | helmet: a sling stone to the helmet is nothing |
| `BuffTuning.HELMET_SHOCK` | 0.92 | helmet: risk compensation, men get bolder |
| `BuffTuning.HELMET_SLING_RANGE` | 0.7 | helmet: risk compensation, they close in instead of slinging |
| `BuffTuning.CARDBOARD_HURT` | 0.93 | paper-armour: no test shows protection; 0-5 % at best |
| `BuffTuning.CARDBOARD_S` | 20.0 | [design guess] it tears and soaks |
| `BuffTuning.CARDBOARD_MORALE` | 0.05 | [design guess] it feels like armour |
| `BuffTuning.ABDUCTED` | 100 | premise: 100 random villagers |
| `BuffTuning.ABDUCT_BEAM` | 20 | [design guess] five beams of twenty |
| `BuffTuning.ABDUCT_MORALE` | -0.22 | [design guess] a village that watched it is shaken |
| `BuffTuning.ABDUCT_DETECT` | 1.3 | [design guess] a spooked village keeps watch |
| `BuffTuning.DEAF_SHARE` | 0.2 | premise: 20 % of the population |
| `BuffTuning.DEAF_SPREAD` | 1.3 | [design guess] deafness: no data on alarms; a shout chain with deaf links is slower |
| `BuffTuning.DEAF_COHESION` | 1.0 | [design guess] a squad that cannot hear its neighbours |
| `BuffTuning.SLEEPLESS_DETECT` | 1.25 | sleep: lapses of attention rise with lost sleep; scaled to one short night |
| `BuffTuning.SLEEPLESS_REACTION` | 1.1 | sleep: reaction +10-15 % |
| `BuffTuning.SLEEPLESS_ACC` | 0.9 | sleep: accuracy -10 % |
| `BuffTuning.SLEEPLESS_FATIGUE` | 0.1 | [design guess] they start tired |
| `BuffTuning.AURA_NEEDS` | 0.25 | [design guess] acoup: a leader steadies men; he cannot hold men whose nerve is gone |
| `BuffTuning.EMPEROR_AURA` | 0.06 | [design guess] a great captain: 15-25 % of the morale ceiling, less through an interpreter |
| `BuffTuning.EMPEROR_COHESION` | 1.1 | [design guess] +10 % cohesion |
| `BuffTuning.EMPEROR_DRILL_S` | 4.0 | [design guess] he lines them up first |
| `BuffTuning.EMPEROR_FALL_SHOCK` | 0.25 | acoup: rumour of the leader's fall spreads rout |
| `BuffTuning.TRUMPET_AURA` | 0.04 | [design guess] synchrony: music helps men move as one; 10-15 % at most |
| `BuffTuning.TRUMPET_PERIOD_S` | 8.0 | [design guess] a call now and then |
| `BuffTuning.TRUMPET_CALL` | 0.015 | [design guess] a small lift per call |
| `BuffTuning.TRUMPET_RALLY` | 0.05 | [design guess] a call turns running men |
| `BuffTuning.TRUMPET_M` | 80.0 | [design guess] earshot in a fight |
| `BuffTuning.TRUMPET_NOISE` | 1.4 | [design guess] a trumpet is an alarm |
| `BuffTuning.TRUMPET_FALL_SHOCK` | 0.15 | acoup: as EMPEROR_FALL_SHOCK, smaller |
| `BuffTuning.BAND_AURA` | 0.11 | [design guess] synchrony: as TRUMPET_AURA |
| `BuffTuning.BAND_COHESION` | 1.08 | synchrony: moving in step raises cooperation; the size is a [design guess] |
| `BuffTuning.BAND_PERIOD_S` | 6.0 | [design guess] a riff |
| `BuffTuning.BAND_HEADS` | 5 | [design guess] a five-piece band |
| `BuffTuning.INVISIBLE_SQUADS` | 5 | premise: 50 potions, 5 squads of ten |
| `BuffTuning.POTION_S` | 120.0 | [design guess] long enough to run in and hold the plaza |
| `BuffTuning.UNSEEN_HOLD` | 1.2 | [design guess] nobody pushes back what nobody sees |
| `BuffTuning.AMBUSH_SHOCK` | 0.8 | acoup: an attack from nowhere, like a rear attack |
| `BuffTuning.AMBUSH_S` | 6.0 | [design guess] free blows before anybody understands |
| `BuffTuning.REVEAL_M` | 20.0 | [design guess] who sees it happen |
| `BuffTuning.REVEAL_FOE_SHOCK` | 0.3 | [design guess] men appear out of thin air |
| `BuffTuning.REVEAL_FRIEND_SHOCK` | 0.05 | [design guess] it startles friends too |
| `BuffTuning.BAT_MORALE` | 0.25 | [design guess] the ten strongest men |
| `BuffTuning.SHOTGUN_SHELLS` | 50 | premise: 50 shells |
| `BuffTuning.SHOTGUN_NEAR_M` | 18.0 | buckshot: beyond 18 m a pellet likely misses a man |
| `BuffTuning.SHOTGUN_FAR_M` | 27.0 | buckshot: beyond 27 m half the pattern is off target |
| `BuffTuning.SHOTGUN_NEAR_DOWN` | 0.55 | buckshot: a 25-35 cm pattern at 23 m is about one man |
| `BuffTuning.SHOTGUN_FAR_DOWN` | 0.25 | buckshot: as SHOTGUN_FAR_M |
| `BuffTuning.SHOTGUN_RELOAD_S` | 5.0 | [design guess] two barrels, then reload |
| `BuffTuning.SHOTGUN_FEAR` | 0.035 | [design guess] gun-noise: 150-165 dB thunder nobody here has heard; 15 % softened in tuning |
| `BuffTuning.SHOTGUN_FEAR_S` | 30.0 | [design guess] the fear fades over 30 s |
| `BuffTuning.SHOTGUN_FEAR_FLOOR` | 0.02 | [design guess] the squad it is aimed at |
| `BuffTuning.CATAPULTS` | 2 | [design guess] two portable catapults |
| `BuffTuning.CATAPULT_CREW` | 5 | [design guess] five men each, taken from the army |
| `BuffTuning.CATAPULT_MIN_M` | 50.0 | chunkin: a portable machine, 50-150 m |
| `BuffTuning.CATAPULT_MAX_M` | 110.0 | chunkin: as CATAPULT_MIN_M |
| `BuffTuning.CATAPULT_RELOAD_S` | 8.0 | [design guess] slow to reload |
| `BuffTuning.PUMPKIN_FLIGHT_S` | 2.5 | [design guess] a high arc |
| `BuffTuning.PUMPKIN_SCATTER_M` | 14.0 | [design guess] nobody aimed it |
| `BuffTuning.PUMPKIN_SPLASH_M` | 9.0 | [design guess] a 4-8 kg pumpkin bursts |
| `BuffTuning.PUMPKIN_DOWN` | 0.6 | [design guess] a direct hit fells a man |
| `BuffTuning.PUMPKIN_SHOCK` | 0.1 | [design guess] everybody near is covered in pumpkin |
| `BuffTuning.PUMPKIN_SAFE_M` | 14.0 | [design guess] the crew holds its fire near friends |
| `BuffTuning.CART_SQUADS` | 6 | premise: 30 carts, two seats each |
| `BuffTuning.CART_SPEED` | 6.7 | golf-cart: about 24 km/h |
| `BuffTuning.CART_NOISE` | 1.6 | [design guess] petrol engines are heard from about 300 m |
| `BuffTuning.CART_CRASH_DOWN` | 0.85 | golf-cart: 410-450 kg at 24 km/h into a crowd; the value is a [design guess] |
| `BuffTuning.CART_CRASH_SHOCK` | 0.12 | [design guess] nobody here has seen a cart without a horse |
| `BuffTuning.CART_CRASH_SELF` | 0.1 | [design guess] over the handlebars |
| `BuffTuning.MEDIC_SQUADS` | 2 | premise: 20 doctors |
| `BuffTuning.MEDIC_REACH_M` | 45.0 | [design guess] how far a doctor runs |
| `BuffTuning.HEAL_S` | 2.0 | dupuy-rtd: one lightly wounded man back per medic every about 2 min, shown about 15 times faster |
| `BuffTuning.HEAL_MORALE` | 0.1 | [design guess] a comrade back on his feet |
| `BuffTuning.HEAL_CAP` | 0.05 | [design guess] patched up and reassured |
| `BuffTuning.MEDIC_NERVES` | 0.1 | [design guess] how shaken a squad must be |
| `BuffTuning.MEDIC_CALM` | 0.58 | [design guess] a fallen comrade frightens less with a doctor at hand |
| `BuffTuning.MONSTER_FEAR_M` | 40.0 | [design guess] close enough to see the stitches |
| `BuffTuning.MONSTER_FEAR` | 0.25 | acoup: the onset of something terrible; the value is a [design guess] |
| `BuffTuning.MONSTER_BERSERK` | 0.015 | [design guess] it is not reliable |
| `BuffTuning.MONSTER_BERSERK_S` | 3.0 | [design guess] |
| `BuffTuning.MOOSE` | 3 | premise: 3 adult moose |
| `BuffTuning.MOOSE_PICK_S` | 4.0 | [design guess] moose: they do not chase far |
| `BuffTuning.MOOSE_BLUFF` | 0.3 | moose: most charges are bluffs |
| `BuffTuning.MOOSE_FRIENDLY` | 0.07 | moose: not under orders |
| `BuffTuning.MOOSE_DOWN` | 2.6 | moose: 380-700 kg, kicks in every direction |
| `BuffTuning.MOOSE_SHOCK` | 0.3 | [design guess] a charging moose |
| `BuffTuning.MOOSE_CHARGES` | 7 | [design guess] then it wanders off |
| `BuffTuning.WASPS` | 300 | premise: 300 paper wasps |
| `BuffTuning.WASP_RELEASE_M` | 35.0 | [design guess] a thrown nest |
| `BuffTuning.WASP_CLOUD_M` | 10.0 | [design guess] one nest makes one cloud |
| `BuffTuning.WASP_STING` | 0.17 | wasp: Schmidt pain 1.5-3, people run and swat |
| `BuffTuning.WASP_HOP_S` | 3.0 | [design guess] the cloud drifts |
| `BuffTuning.WASP_HOP_M` | 45.0 | [design guess] as far as it drifts |
| `BuffTuning.WASP_ANYONE` | 0.15 | wasp: they cannot tell sides |
| `BuffTuning.WASP_LOSS_PER_S` | 4 | [design guess] the swarm thins out in a minute |
| `BuffTuning.WASP_DAZE` | 0.3 | [design guess] nobody fights while swatting |
| `BuffTuning.UFO_SPEED` | 20.0 | [design guess] it leaves quickly |
