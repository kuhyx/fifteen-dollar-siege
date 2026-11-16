# Design: the siege model

What `src/core` simulates and why. Rules and the Core API: `DOCS-design.md`.
Every number has a row in `DOCS-design-sources.md` (base model) or
`DOCS-design-buff-sources.md` (buffs); a number the research could not source
is marked `[design guess]` there.

## 1. Scale

- **Squads, not men.** An entity is a squad of about ten or one special
  (`SiegeSnapshot.Kind`); the view scatters `ent_count` figures around it. A
  siege has 60 to 90 entities in parallel packed arrays (`SiegeState`).
- **Time.** One tick is 0.1 s (`SiegeSim.STEP_S`): everybody moves. Every fifth
  tick is a decision step: who notices what, who fights whom, who runs
  (`SiegeAlarm`, `SiegeArmy`, `SiegeVillage`, `SiegeSpecials`, `SiegeBeasts`,
  `SiegeCombat`, `SiegeMorale`, `SiegeReferee`, in that order). The view
  interpolates between snapshots.
- **Compression.** A real fight of this size takes 20 to 40 minutes. Slow
  things (alarm, muster, tiring, treatment) run about 15 times faster so a
  siege takes 60 to 180 sim-seconds `[design guess]`. Walking and running
  speeds are real: the map is small enough.
- **Space.** 600 x 400 m. The village is a circle of 110 m with 14 buildings
  (`buildings[0]` is the church with the bell) around a plaza of 25 m. The
  army starts 130 m from the houses. Squads pass between buildings; "who is
  near me" goes through a 50 m grid (`SiegeGrid`).

## 2. The village of 2,000

About a quarter of a medieval village are men of fighting age, and about 0.6
of those turn out: 250 militia with farm tools (25 squads), 30 hunters with
bows (3 squads) and the lord's retinue of 20 in mail (2 squads). The other
1,700 are 17 crowds that run for the church or out of the far side and hide
(`State.HIDDEN`).

- **Noticing.** Nobody is on watch. A visible army squad within 105 m of the
  houses may be noticed each decision step (surely within 35 m). Size, golf
  carts and a trumpet carry further; a sleepless village notices later, a
  spooked one (abduction) sooner; a band is heard at once.
- **Alarm.** Once raised (`ALARM`), the alarm level climbs to 1 in 30 s by
  shouting, twice as fast once the bell rings (`BELL_RING`, 5 s after). Every
  village squad hears it at its own level, then needs 15 to 60 s to arm (the
  retinue 5 s). A squad attacked at home scrambles to arm and is shaken.
- **Fighting.** An armed squad goes for the nearest enemy within 50 m, else
  for the army squad nearest the plaza, else it waits in the plaza. Nobody
  chases further than 60 m beyond the houses. Archers stand off at 35 m.

So the alarm is a race: an army that arrives early or unnoticed meets the
defenders in ones and twos.

## 3. Fighting

- **Melee.** Squads within 6 m trade blows: expected casualties = men engaged
  x strength x 0.014 per second, over the target's toughness and armour. A
  club is 1, farm tools 1.3, the retinue 1.8. A squad can bring at most 1.5
  men per enemy head to bear.
- **Slings.** Each army squad has 12 volleys. In range (20 m) it slows to a
  walk and shoots while closing. A stone rarely puts a man down (15 %); mostly
  it stings and frightens. A volley into a melee can hit a friend.
- **Bows.** 50 m, one hit in ten per archer, 40 % of hits put a man down.
- **Fatigue** (0..1) grows with marching, faster with sprinting and fighting,
  and falls at rest. A tired squad is slower, weaker and breaks sooner.

## 4. Morale and rout

Each squad has a morale of 0..1 (army about 0.7, village about 0.9) and a
side-wide aura from its leaders and music. The army's aura counts in full only
for a squad with 0.25 of its own morale left: no leader holds men whose nerve
is gone.

- A casualty shocks the squad by 2.4 x (share of the squad lost) / cohesion,
  give or take half. Cohesion is 0.6 for strangers, 1.3 for neighbours at
  home, 1.0 for the same neighbours out in the fields. So strangers break
  after one or two men of ten, a community defending its homes after three or
  four: the research's "under 10 % losses" against "defenders near 40 %".
- Being fought by two squads at once, a rout or a wiped squad next door, and
  the special terrors (shotgun, monster, wasps, moose, pumpkins, carts) shock
  too.
- Under 0.2 the squad routs (`SQUAD_ROUT`): everybody in melee with it strikes
  as it turns, it takes 2.5 times the damage while it runs, and village squads
  sprint after it. **Most men fall in the rout.**
- A routed squad recovers out of contact and rallies at 0.45 (`SQUAD_RALLY`)
  with a ceiling a quarter lower; a second or third rout sends it home for
  good.
- **Side morale** is what the standing fighters still carry (heads x morale,
  routed-but-recoverable squads count half), relative to the start.

**Win:** the village's side morale falls to 0.465 of its start, or the army
holds the plaza for 30 s (10 heads or more, three to one over the armed
defenders there). **Lose:** the army's side morale falls to 0.25 (dead or
routed: it combusts), or 300 s pass.

## 5. Orders (Command mode)

With no order the army follows the default plan: march on the village, sling
at what comes into range, fight, take the plaza. An order stands until the
next one.

| order | what the squads do | what a player gets from it |
|---|---|---|
| `RALLY` at a point | form up around the flag and hold: fight or sling at whoever comes near | morale and breath come back three times as fast; routed squads gather there; the defenders who come out to the flag fight in the open, without home cohesion and cover |
| `CHARGE` | one rush: sprint at the nearest enemy, no slinging; then the default plan again | the first exchange hits up to twice as hard and shakes the target, the fresher the men the more; a long sprint wastes it |
| `RETREAT` | sprint back to the start line and hold | out of reach of the defenders (the leash), full recovery |

Played well, Command beats Watch: `tools/sim/commander.gd` rallies 25 m short
of the houses, lets the defenders come out piecemeal, and charges once the
village's morale has sagged. The balance gate checks that it wins more.

## 6. The 25 buffs

| buff | what it does | the catch |
|---|---|---|
| `fifty_men`, `double_men` | 150 / 200 men, 300 with both (+50 first) | more strangers: lower cohesion, noticed from further |
| `prep_hour`, `prep_ten_minutes` | drill on top of the base hour: cohesion +15 % / +3 %, better slinging | none |
| `pep_talk` | morale +0.1 before the first tick (`PEP_TALK`) | fades over two minutes |
| `booze` | courage: morale +0.05, shocks x0.77 | aim x0.85, melee x0.95, twice the friendly fire, a squad in four ignores a new order |
| `stew` | tires 5 % slower, morale +0.02 | nearly a dud: the effort is too short for a meal to matter |
| `knight_armor` | melee damage x0.3, arrows x0.4, shocks x0.85 | march x0.85, tires 1.3 times as fast, aim x0.9 |
| `football_helmets` | melee x0.8, arrows x0.7, friendly stones x0.3, bolder | risk compensation: they sling from less far |
| `cardboard_armor` | damage x0.93, morale +0.05 | soaked and torn 20 s into the fight |
| `metal_bats` | the ten strongest men: three times the blow, tougher, steadier | only ten men |
| `shotgun` | one man, 50 shells, a blast every 5 s within 27 m; the first blast frightens every villager who hears it for 30 s, and squads that run then do not come back | the thunder tells the whole village at once |
| `pumpkin_catapults` | two crews lob pumpkins 50 to 110 m: a splash of 9 m | the crews leave the line; a pumpkin lands on whoever is there |
| `golf_carts` | six squads ride: cart speed, no tiring, and every run at an enemy is a ram (`CART_CRASH`) | heard from afar; now and then a driver goes over the handlebars |
| `invisibility_potions` | 50 men nobody sees for 120 s run into the plaza and hold it unseen (each counts 1.2 there) | they strike no blow there and do not count toward the army's morale: when the visible men break, the siege is lost; a reveal (`REVEAL`) startles friends too |
| `emperor` | a great captain: aura +0.06, cohesion +10 % | he lines the men up for 4 s first; his fall shakes the army |
| `trumpet_boy` | aura +0.04, calls that lift morale and turn running squads | the trumpet is an alarm; nobody strikes the boy, but a pumpkin or a moose may |
| `rock_band` | plays at the start line: aura +0.11, cohesion +8 % (men in step) | the first chord is the alarm |
| `medics` | 20 doctors behind the line: casualties frighten less (x0.58), a treatment every 2 s puts a lightly wounded man back and steadies a squad | their oath does not ask which side a wounded man is on |
| `stitched_monster` | one giant: the blow of 22 men, takes 12; villagers who first see it up close take fright | slow; now and then turns on whoever is nearest |
| `moose` | three moose charge squads (2.6 men down and a fright each) | not under orders: bluff, charge your own now and then, wander off after seven charges |
| `wasps` | a nest thrown at the first defenders: everybody in the 10 m cloud is shaken and cannot fight; it drifts on for a minute | about one hop in seven takes the nearest squad of either side |
| `abduction` | 100 random villagers gone before the first tick (`UFO_ABDUCT`), the rest shaken (-0.22) | a spooked village keeps watch: it notices from further |
| `deaf_villagers` | a fifth of the squads never hear the alarm: they stay home until the enemy is at the door, and fight without their neighbours' steadiness | the alarm also spreads slower, not never |
| `sleepless_village` | notices later, reacts and arms slower, shoots worse, starts tired | modest: one short night |

## 7. Events

Names: `src/core/siege_event.gd`. Every event has `kind` and `pos`. Extra
data: `COMMAND` `command`; `SLING_VOLLEY`, `ARROW_VOLLEY` `team`, `to`;
`MELEE_CLASH`, `SQUAD_ROUT`, `SQUAD_RALLY`, `SQUAD_WIPED` `team`;
`SHOTGUN_BLAST`, `PUMPKIN_LAUNCH` `to`; `PUMPKIN_SPLAT` `from`; `HEAL` `team`,
`entity`, `heads` (0 = nerves only); `UFO_ABDUCT` `heads`; `CENTRE_HELD`
`progress`. No event changes the sim: a Lab run records none and ends the same.

## 8. Speed, determinism, tests

- **Speed.** Budget: a median headless siege of 0.4 s. Measured 2026-11-16
  under `capped.sh` (`CAP_CPU_PCT=20`): median 54 ms, 90th percentile 77 ms,
  slowest 113 ms over 100 sieges of the random sample, 101 sim-seconds each on
  average. `tools/sim/siege_bench.gd` measures it and fails over the budget.
- **Determinism.** One seeded RNG, fixed iteration order, no clock: the same
  loadout, seed and orders give the same `state_hash()` after every tick.
- **Tests** (`tests/core/`): the contract (`test_siege_sim`, `test_lab`), the
  village, the buffs, the orders, the pinned fixtures, the Sources tables, and
  property tests over generated loadouts, seeds and orders
  (`test_siege_properties`).

## 9. Balance

kuhy's bar: no buffs under 5 % wins; a random legal loadout about 35 % (25 to
45 is fine); the best loadout found 85 % or more; each of the 25 buffs in at
least one of the top 50 loadouts found. "A random legal loadout" buys the 25
buffs in a random order, each when it still fits (`tools/sim/loadout_space.gd`).

**Tools** (headless, each call under 60 s, results cached per sim hash under
`~/data/claude-scratch/fifteen-dollar-siege/balance/`):
`scripts/balance_search.sh` (the empty loadout, a fixed random sample of 300,
then hill-climbing from the best loadouts and from each buff's best three;
sharded, resumable), `scripts/balance_report.sh` (the tables below),
`scripts/balance_lift.sh <base>` (what each buff adds to one loadout),
`scripts/balance_quick.sh` (a rough look after a tuning change),
`scripts/balance_gate.sh` (the pinned gate, in `scripts/check.sh`).

**The claim from the repo alone.** The sweep behind the result below is
committed in `tools/sim/data/<sim hash>/` (two JSON shards, 183 KB, the
store's own format: `tools/sim/balance_store.gd`). `scripts/balance_report.sh
--strict` reads it by default and exits 0 only when the four targets hold;
`tests/test_balance_committed.gd` (in `scripts/check.sh --group play`) fails
when the folder is not the current sim hash, or a target is missed. After any
change to `src/core`, regenerate it:

1. `scripts/balance_search.sh` until every shard prints `left=0` (several
   calls, each under 60 s; add `--carry=<old hash>` to start from the best
   loadouts of the old sweep), then `scripts/balance_report.sh --scratch
   --strict` (reads the working folder, not the commit).
2. Replace the folder: `git rm -r tools/sim/data`, then `mkdir -p
   tools/sim/data/<hash>` and copy the non-empty `shard-*.json` from
   `~/data/claude-scratch/fifteen-dollar-siege/balance/<hash>/` into it
   (under 300 KB; larger means commit only the loadouts the four targets need).
3. `scripts/balance_report.sh --strict` and `scripts/check.sh --group play`
   green, then `find_pins.gd --write` for the quick gate (see "The gate").

**Result**, 2026-11-16, sim hash `07d46f192f9a`: 1,485 loadouts, 38,189
sieges, run r of a loadout on seed 1000 + r. Ranked loadouts have 48 sieges or
more, the top 25 and each buff's best three have 96. The search was stopped
with about 1,700 sieges of climbing still planned. The last changes touched
single buffs (the band, the aura rule); results of loadouts without those
buffs were carried over from the previous hash and spot-checked equal.

| target | measured | from |
|---|---|---|
| no buffs < 5 % | 0.0 % | 300 sieges |
| random 25-45 % | 39.7 % | 300 loadouts x 8 sieges |
| best >= 85 % | 95.8 % | 96 sieges |
| 25 buffs in the top 50 | 25 | 344 ranked loadouts |

| rank | loadout | wins | sieges | sim s |
|---|---|---|---|---|
| 1 | double_men invisibility_potions stitched_monster | 96 % | 96 | 100 |
| 2 | booze invisibility_potions knight_armor pumpkin_catapults | 94 % | 96 | 128 |
| 3 | cardboard_armor invisibility_potions knight_armor pumpkin_catapults stew | 94 % | 96 | 133 |
| 4 | booze cardboard_armor double_men fifty_men football_helmets | 92 % | 96 | 91 |
| 5 | cardboard_armor invisibility_potions knight_armor pumpkin_catapults | 92 % | 96 | 128 |
| 6 | deaf_villagers double_men invisibility_potions stew | 92 % | 96 | 92 |
| 7 | booze cardboard_armor double_men fifty_men prep_hour | 91 % | 96 | 92 |
| 8 | booze double_men fifty_men football_helmets pep_talk | 91 % | 96 | 90 |
| 9 | booze invisibility_potions medics pumpkin_catapults | 91 % | 96 | 98 |
| 10 | booze cardboard_armor deaf_villagers football_helmets golf_carts pep_talk | 90 % | 96 | 79 |

Each buff's best rank (and the win rate of that loadout):
`invisibility_potions` 1 (96 %), `double_men` 1, `stitched_monster` 1,
`knight_armor` 2 (94 %), `pumpkin_catapults` 2, `booze` 2, `cardboard_armor` 3,
`stew` 3, `fifty_men` 4 (92 %), `football_helmets` 4, `deaf_villagers` 6,
`prep_hour` 7 (91 %), `pep_talk` 8, `medics` 9, `golf_carts` 10 (90 %),
`emperor` 11, `rock_band` 15, `prep_ten_minutes` 16 (89 %), `moose` 17,
`abduction` 22 (88 %), `shotgun` 24, `wasps` 29, `trumpet_boy` 29,
`metal_bats` 30, `sleepless_village` 33 (86 %).

**The gate** (`tools/sim/balance_pins.gd`, written by `tools/sim/find_pins.gd`)
replays pinned seeds: the empty loadout, the best loadout, 40 loadouts of the
random sample, for every buff a loadout where buying it wins more of 12
sieges, and the scripted commander against Watch. After a tuning change: search
again, then `find_pins.gd --write` and `find_fixtures.gd`.
