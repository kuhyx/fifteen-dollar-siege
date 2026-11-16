# Design: the fun pass (R16)

Record of the pass whose only brief was "make it a LOT more fun; surprise and
delight the player often". Everything here is view, audio and menu work: the
sim, its hash and its balance numbers are untouched. Nothing is a task.

## 1. What the playtest found flat

Read from the reel, buff and command frames and from the sim itself:

- **The sim wins by morale, not by killing.** A won siege fells about 100 of
  2,000 villagers and costs the army 3 of 100 men (measured with
  `BattleToll` over the win fixture). Nothing on screen marked a fall.
- **Heavy blows had no weight.** A monster's smash, a cart crash or a shotgun
  blast was an effect, but the world did not notice.
- **Five buffs were only a chip** (stew, both prep times, sleepless and deaf
  villages); the armour, helmet, cardboard, booze and bat looks vanish at the
  auto camera's zoom; double and fifty men changed a number nobody saw.
- **Invisible men never reveal themselves in Watch.** They sneak to the plaza
  and do not strike, so `REVEAL` never fires (probe: 0 of 3 seeds, the potion
  runs 120 s, a siege ends near 80 s). The ghosts stayed ghosts to the end.
- **The ends were plain:** no sign that a rout is near, a win ended on a flag,
  the result and hub offered nothing to do next.

## 2. Sources

| Idea | Source |
|---|---|
| Layers of feedback over unchanged rules; compare with and without | Jonasson and Purho, "Juice it or lose it" (Nordic Game 2012), summarised at gamejuice.pages.dev/articles/juice-it-or-lose-it-lessons |
| Hit pause ("sleep on hit"), camera kick, shake that decays fast | Nijman, "The Art of Screenshake" (Vlambeer, 2013); recreation notes at dkliao.itch.io/the-art-of-screenshake-recreation |
| Trauma value 0..1 that decays by itself, shake strength from it | Eiserloh, "Math for Game Programmers: Juicing Your Cameras With Math" (GDC 2016), as used by Bevy's 2d_screen_shake example; squaring it is the usual implementation detail `[design guess]` |
| Many small frequent rewards beat one big one; spectacle that never hides what is happening | Vampire Survivors write-ups (windowscentral.com, rogueranker.com): escalating effects, chests as spectacle, meta-progress that makes a loss feel productive |

The searches found nothing authoritative on auto-battler kill-streak
feedback, so the tally cadence below is a measured `[design guess]`.

## 3. The delights

Every one is something seen or heard without a word. Each has a check that
fails when it stops firing.

| Delight | Fires when | Check | Frame (`fun/`) |
|---|---|---|---|
| Weight of blows: camera shake and a hit pause | a smash, crash, blast, charge, splat, wipe, reveal, win, loss (`BattleImpact.HEAVY`), at most once a kind per 0.6 s | `tests/view/test_impact.gd` (incl. 300 frames of smashes keep the sim at 85 %) | `monster_shake_ring` |
| Pops | any squad loses heads, one pop a squad per 0.25 s | `tests/view/test_toll.gd`; the watch bot asserts pops in a win and a loss | `watch_win_tally` |
| Gold tally | every 10th villager down: a gold number over the fight, a rising bell, the men hop. ONE number at a time: a milestone that lands while one is up rolls its number (new pop, fresh stay), so tallies never overlap at x16 or x64 | `test_toll.gd`, `test_toll_stack.gd` (no two number rectangles meet at x1 to x64), `test_finale.gd`; the watch bot asserts it in the win | `watch_win_tally` |
| Heartbeat edge | army morale under 0.3: a red frame pulses lub-dub with a sound; above 0.45 a gold flash once | `tests/view/test_danger_edge.gd`; the watch bot asserts beats in a loss | `loss_heartbeat_edge` |
| Fireworks and a jump | the siege is won: 8 rockets over the church, the men jump | `test_finale.gd`; the watch bot asserts rockets in a win | `watch_win_fireworks` |
| Unmasking | a win with invisible squads: each appears in a flash, one by one | `test_finale.gd`; `--autodrive=fun` scene `reveal` | `invisible_unmasked` |
| Monster ring | the monster's hero ring is 1.9 times, the emperor's 1.3 times | `test_finale.gd` | `monster_shake_ring` |
| Buff badges | stew (a bowl and steam), sleepless and deaf (at the alarm, a beat apart): the buff's pictogram pops over the field | `tests/view/test_buff_moments.gd`, the buffs gate (`BuffSigns.MOMENTS`) | `buff_stew`, `buff_sleepless_village`, `buff_deaf_villagers` |
| Clocks | each prep time: a clock face sweeps (3 turns, half a turn) with ticks | same | `buff_prep_hour`, `buff_prep_ten_minutes` |
| Army roll-up | double or fifty men: the army number rolls from 100 up to what the buff made it | same | `buff_double_men`, `buff_fifty_men` |
| Looks alive | knight and helmets glint, cardboard flakes, booze hiccups (bubbles), bats ping, every 0.5 to 1.2 s on a squad in view | same; `fun` scene `looks` | `looks_glints`, `buff_knight_armor`, `buff_football_helmets`, `buff_cardboard_armor`, `buff_booze`, `buff_metal_bats` |
| Shop dice | a press sells back and buys a random legal loadout card by card, coins flying, dice rattling | `tests/test_fun_menus.gd`; the shop tour (`shop_dice` frame) | `shop_dice_roll` |
| Stars | a win: 1 star, 2 when bought for at most 10 dollars, 3 for at most 6; they pop in with rising chimes; the empty ones show the coins they ask for | `test_fun_menus.gd`; the result beat asserts them | `result_win_stars` |
| Try again with new dice | the result's fourth control starts a siege with a random new loadout; the dice breathe after a second | `test_fun_menus.gd` | `result_loss_dice` |
| Hub life | a mode button swells under the pointer; a wave of light crosses the shelf, brightening waiting slots and hopping won ones | `tests/test_hub_life.gd` | `hub_wave` |

`--autodrive=fun` (`scripts/autodrive_all.sh fun`) plays one real siege per
battle delight and fails when it never shows; the buffs gate does the same
for the looks and moments of each buff alone.

## 4. Rules that came out of it

- The rare moments live 2.5 s (`BattleFlair.KEEP_S`), past
  `BattleEffects.SHED_BELOW_S`: a busy frame sheds pops and glints, never a
  tally, a badge or a rocket. (On the software rasteriser they were shed the
  moment they spawned.)
- A badge never starts smaller than a chip, so no pictogram mesh is built on
  first sight (lesson L7; `test_buff_moments.gd` is red at 20 % start).
- Hit pause is per kind on a cooldown: a monster in a long melee smashes on
  nearly every step and held the world 4 frames in 5 before.
- The delights play through `FunCue` on the battle voice pool, so they follow
  the audio rules: a pause stops them, one with a position (`FunCue.play(cue,
  pitch, at)`: tally, rocket, unmasking, looks, badges) is placed left to right
  against the view the battle last gave, and every one counts in
  `AudioDirector.heard` (`tests/audio/test_fun_cues.gd`).

## 5. Constants (all `[design guess]`, tuned on the fun bot's frames)

| constant | value |
|---|---|
| `BattleImpact.MAX_PX`, `MAX_HOLD_S`, `CALM_PER_S`, `COOLDOWN_S` | 16 px, 0.12 s, 1.7 per s, 0.6 s |
| `BattleImpact.HEAVY` | per event: trauma 0.18 to 0.7, hold 0 to 0.12 s |
| `BattleToll.MILESTONE`, `POP_GAP_S`, `MAX_POPS` | 10 villagers, 0.25 s, 8 |
| `DangerEdge.DANGER_BELOW`, `CALM_ABOVE`, `BEAT_S`, `DUB_S`, `GLOW`, `DEPTH` | 0.3, 0.45, 0.9 s, 0.17 s, 0.4, 0.2 |
| `BattleFlair.KEEP_S`, `ROCKETS`, `ROCKET_GAP_S`, `UNMASK_GAP_S` | 2.5 s, 8, 0.32 s, 0.18 s |
| `BuffMoments.START_AT_S`, `CLOCKS`, `BASE_MEN` | 1.5 s, 3 turns and 0.5, 100 |
| `BuffLooks.LOOKS` | glint 0.5 and 0.65 s, flake 0.55 s, hiccup 1.2 s, ping 0.8 s |
| `FxSigns.BADGE_PX`, `CLOCK_PX`, `NUMBER_PX`; `FxGlints.STAR_PX` | 112, 44, 56, 34 canvas px |
| `FxHeroes.RING_SCALE` | monster 1.9, emperor 1.3 |
| `StarRating.TWO_AT`, `THREE_AT` | 10 dollars, 6 dollars: measured over 30 random loadouts per cap, 8 seeds each (seeds 500 to 507): at most 10 wins 15 % on average, 75 % at best; 8: 11 %, 50 %; 7: 8 %, 50 %; 6: 3.8 %, 37.5 %; 5: 0.8 %, 12.5 % (so 5 was dropped as near-impossible) |
| `ResultStars.FIRST_S`, `STEP_S` | 0.45 s, 0.5 s |
| `ShopDice.STEP_S`; `ResultScreen.BECKON_S` | 0.11 s; 1 s |
| `TrophyShelf.PERIOD_S`, `SWEEP_S`; `HubScreen.HOVER_SCALE` | 4.5 s, 1.8 s; 1.07 |

## 6. Audio added

Seven short rendered cues (`tools/audio/sfx_fun.py`, loudness-gated like the
rest) and one alias: `fun_toll` (a bright bell, played higher with each
tally), `fun_heartbeat`, `fun_glint`, `fun_dice`, `fun_star` (a chime that
climbs with each star), `fun_firework`, `fun_hic`, and `fun_tick` (the
existing `centre_tick`). `DOCS-audio.md` lists them. The unmasking reuses the
`reveal` cue.

## 7. Still flat, and not verified

- Nobody has listened to any of the new sounds; the offline gate checks only
  loudness, peak and shrillness.
- The glints, flakes and bubbles are small by design at the auto camera's
  zoom; only the close frames show them well.
- The shop pictograms for emperor, shotgun, rock_band and booze are as before.
- Stars are not saved; the hub does not show them. A saved best-stars record
  per loadout would be the next hook.
- The reveal in a Command siege (a rallied invisible squad strikes) already
  fired the sim's `REVEAL`; the unmasking is the Watch-mode answer.
