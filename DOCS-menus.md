# Menu screens: hub, shop, Lab, result

Record of what is decided for the menu-side screens (`src/view/hub_screen.gd`,
`loadout_screen.gd`, `lab_screen.gd`, `result_screen.gd`, `src/view/shop/`,
`src/view/lab/`, `src/ui/pictograms/`). The game's rules and the Core API are
in `DOCS-design.md`; nothing here is a task.

## Conventions copied

What was copied, from the research notes' "Copy this" (Super Auto Pets, TABS,
Teamfight Tactics):

- **The budget is coins, not a number.** 15 coins lie in a tray; a card's
  price is that many coin slots; buying flies the coins from the tray into
  the card and the tray empties. Every coin is in one place (tray, air, card).
- **One picture per buff, lit when bought.** No captions; the army count
  changes live beside the cards (a number and one figure per ten men).
- **The result is a symbol and one retry.** A flag over the village or the
  leader in flames, then "again" keeps the same loadout and coins.

## Decisions

Each is a `[design guess]` unless a source is named.

- **Art.** Every pictogram is a `Pictogram`: layers of `VectorGlyph` shapes
  in the 128-unit square, drawn as one triangle array with a one-pixel
  feathered rim built for the size on screen. Vignettes and the result
  scenes are drawn per frame with a `VignettePen` in stage units. No raster,
  no AI, no external asset.
- **Palette.** The one `Palette` (design-system tokens and mixes of two; see
  `DOCS-design-battle.md`); `PictoInk` names its hues. The procedural-art
  skill's "one 4-colour Lospec palette" was NOT used: twelve colours are
  what 25 distinct buffs needed.
- **No brand, no real person.** The pep-talk man is a grey tough guy with a
  red headband, the emperor a small man under a wide two-cornered hat, the
  band four plain figures, the monster a stitched green head without bolts.
- **Second channels.** Bought: green frame AND check AND gold coins. Out of
  reach: dimmed art AND darker price coins. Refused: the tray shakes AND its
  rim turns red, the card shakes AND its coins flash red. Lab tick: colour
  AND height. `LoadoutScreen.changed` / `refused` are the hooks for sound.
- **Progress (R4, R18).** `WinShelf` keeps the buffs a won Watch or Command
  siege was won with (Lab wins do not count); `LabBook` keeps wins and runs
  per loadout, added up over batches, keyed by the sorted buff ids.
- **Lab slicing.** `LabRunner` steps the sims itself (a few ticks, then a
  look at the clock) instead of calling `Lab.run_one` per frame, so one slow
  siege cannot freeze a frame. `tests/test_menu_screens.gd` holds it equal to
  `Lab.run_batch`.
- **The fun pass's menu delights** (`DOCS-design-fun.md`): the shop's dice
  (`ShopDice`, key 2, top right) sell back and buy a random legal loadout
  (`LoadoutDice`) card by card; a win's result shows 1 to 3 stars
  (`StarRating`, `ResultStars`: a win, at most 10 dollars, at most 5 dollars)
  and a fourth control, the dice (key 4), starts a siege with a random new
  loadout; the hub's mode buttons swell under the pointer and a wave of light
  crosses the shelf (`TrophyShelf.glow`). `UiFunMarks` holds the dice and the
  two stars. Key 4 is `menu_pick_4`.
- **Keys.** One `KeyHint` draws them (`InputDevice` picks the event for the device). 1 2 3 (4) pick a screen's big controls left to right, Backspace goes
  back from the shop: keys whose glyph needs no letter. A pad uses focus and
  its accept button.

## Constants

| constant | value | source |
|---|---|---|
| `BuffVignettes.LOOP_S` | 2.4 s | the brief asked for about 2 s; the exact value is a `[design guess]` |
| `VignettePen.STAGE`, `VIEW` | 192 x 128, 160 x 107 units | `[design guess]` |
| `CoinFlight.FLY_S`, `STAGGER_S`, `ARC` | 0.26 s, 0.045 s, 70 units | `[design guess]` |
| `CoinTray.SHAKE_S`, `BuffCard.SHAKE_S`, `BuffCard.POP_S` | 0.4 s, 0.3 s, 0.2 s | `[design guess]` |
| `BuffCard.DIM` | 0.66 toward the panel | `[design guess]` |
| `ResultScene.SETTLED_S` | 2.4 s: the result opens on the end state, no second payoff | `[design guess]` |
| `ResultScene.FLAG_UP_S`, `BURN_S` | 0.7 s, 0.9 s | `[design guess]` |
| `LabScreen.REVEAL_S` | 0.9 s | `[design guess]` |
| `LabRunner.TICKS_PER_LOOK` | 8 sim ticks | `[design guess]` |
| `TickStrip.MAX_TICKS`, `PER_ROW` | 400, 50 | `[design guess]`: the default 200 runs make four rows |
| `LabRanking.ROWS` | 8 | `[design guess]` |
| `TrophyShelf` slots | 25, 13 on the first board | one per buff of the source |
| `ArmyMeter.PER_FIGURE`, `BuffVignettes.MEN_PER_FIGURE` | 10 men | `SiegeSim.SQUAD_SIZE` |
| `MenuKeys.DEFAULT_KEYS` | 1, 2, 3, Backspace | `[design guess]` |

## Pause menu and volume

Esc, pad B or the menu button (top left, every screen) pauses the tree and
opens one card (`src/view/pause_menu.gd`): resume (it has the focus and shows
the key that closes the menu), back to the hub, quit, and under them the
volume of the two sound channels (`src/view/volume/`). No words.

- **One row per channel**, music (a quaver) and effects (a burst): a quieter
  speaker button (one wave), a bar of 10 steps lit up to the level, a louder
  speaker button (three waves). A click on a step sets it. Every button has an
  `accessibility_name` and the key that does the same, drawn by `KeyHint` from
  the InputMap for the device in use: music 4 and 5, effects 6 and 7 (digits
  because `KeyGlyph` draws digits; they only act while the menu is open)
  `[design guess]`. A touch screen shows no key.
- **The level is the director's.** A row asks `AudioDirector.live()` for the
  level and sets it through `set_music_volume` / `set_sfx_volume`, which put it
  on the bus and save it in `audio.json` (`SaveStore`). Boot restores it. At
  level 0 the bus is muted. Defaults: music 7 of 10, effects 10 of 10
  (`AudioSettings`).
- **Checked by** `tests/test_volume.gd` (frees and rebuilds the whole scene
  and finds the volumes on the buses again) and by the bots: the watch bot
  clicks both speakers, presses a key and clicks a step, checking the row, the
  bus and the save after each move; the touch bot taps quieter.
