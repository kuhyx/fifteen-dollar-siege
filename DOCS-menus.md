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
- **Palette.** The game's own `Palette` plus four hues (`PictoInk`: wood,
  violet, deep gold, slate). The procedural-art skill's "one 4-colour Lospec
  palette" was NOT used: `Palette` is shared with the battle screen and
  twelve colours are what 25 distinct buffs needed.
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
- **Keys.** 1 2 3 pick a screen's big controls left to right, Backspace goes
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
| `ResultScreen.PAYOFF_S` | 1.4 s (any press skips it) | `[design guess]`; lesson L13 |
| `ResultScene.FLAG_UP_S`, `BURN_S` | 0.7 s, 0.9 s | `[design guess]` |
| `LabScreen.REVEAL_S` | 0.9 s | `[design guess]` |
| `LabRunner.TICKS_PER_LOOK` | 8 sim ticks | `[design guess]` |
| `TickStrip.MAX_TICKS`, `PER_ROW` | 400, 50 | `[design guess]`: the default 200 runs make four rows |
| `LabRanking.ROWS` | 8 | `[design guess]` |
| `TrophyShelf` slots | 25, 13 on the first board | one per buff of the source |
| `ArmyMeter.PER_FIGURE`, `BuffVignettes.MEN_PER_FIGURE` | 10 men | `SiegeSim.SQUAD_SIZE` |
| `MenuKeys.DEFAULT_KEYS` | 1, 2, 3, Backspace | `[design guess]` |
