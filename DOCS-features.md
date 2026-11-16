# FEATURES: fifteen-dollar-siege

> Feature map + core-flow ground truth (skill: `e2e-ground-truth`). Keep it
> current: a user-visible change updates its row in the same commit. "How to
> reach it" is a path a driver can follow; "expected outcome" is something a
> check can observe.

- **Primary target:** Godot 4.7.2, Linux desktop and single-threaded Web
- **Driver:** the game's own `--autodrive=<mode>` bot on a private Xvfb
  (`scripts/autodrive_all.sh`), muted, under 60 s; never `godot-mcp-runtime`
- **Run one flow:** the command in the table (each is one call under 60 s)
- **Artefacts:** `~/data/claude-scratch/fifteen-dollar-siege/<checkout>/shots/<mode>/NN_<beat>.png`;
  a failed run keeps its log dir and prints the path

## Feature map

| feature | how to reach it | expected outcome |
|---|---|---|
| Hub | start the game | three picture buttons (Watch = eye, Command = rally flag and pointing hand, Lab = flask in a win-rate ring) with their keys 1 2 3, and a menu button, all inside the viewport, no words |
| Shelf (progress) | hub | 25 slots, one per buff: a buff that was part of a won Watch or Command siege stands there in colour, the rest are dark outlines; survives a restart |
| Best Lab rate | hub, under the Lab button | a small ring, the best win rate so far as a number and that loadout's pictograms; an empty ring before the first Lab run; survives a restart |
| Key hints | any menu screen | every big control shows its key on its corner (1 2 3, Backspace for back), read from the InputMap; a pad shows its accept button on the control in focus; touch shows none |
| Pause menu | Esc, pad B or the menu button on any screen | the tree pauses; resume, hub and quit buttons; Esc closes it; the hub button returns to the hub |
| Loadout | hub -> a mode button | 25 pictogram cards on five price shelves (5 dollars down to 1), each with its price as coin slots; a tray of 15 budget coins; the army size as a number and one figure per ten men; a green go button; no words |
| Buy / sell | click a card (touch: tap to look, tap again to buy) | coins fly from the tray into the card's slots, the card gets a green frame and a check; a second click sends the coins back; cards the dollars left do not reach are dimmed; the army number follows `fifty_men` / `double_men` |
| Budget refusal | click a card that costs more than is left | the tray shakes and its rim turns red, the card shakes; cost and loadout unchanged; nothing is written |
| Vignette | hover, focus or tap a card | the preview plays that buff's looping vector scene (2.4 s); its pictogram and price stand under it; with no card on show the army marches there |
| Remembered loadout | open a mode's loadout again | last time's picks for that mode are bought already |
| Watch | hub -> eye -> go | every man and villager is a drawn figure on a map with a church; two morale bars, an alarm bell, a hold-the-centre ring and a clock; it ends by itself |
| Speed and hold | battle: Space / 1 2 3 4, or the buttons bottom left | the sim stands still or runs at x1, x2, x4, x8; each button shows its key |
| Camera | battle: wheel or pinch, drag; 0 or the view-finder button | zoom and pan by hand; back to framing the action by itself |
| Command | hub -> flag -> go | as Watch, plus: a click on the map plants a rally flag (a drag only pans), Enter / Backspace or the buttons charge and retreat |
| Staged beats | a siege whose first snapshot has `ufo_abduct` or `pep_talk` | they play before the clock starts; Space, Enter, a tap or the skip button cuts one short |
| Payoff | the sim decides | on the battle screen: the camera goes to the church and the army's flag climbs its tower (win), or the army burns (lose), before the result opens |
| Showcase | `scripts/autodrive_all.sh showcase` | 22 frames: every kind in every state, six looks, every event, both beats, both payoffs, 2,400 figures inside the frame budget |
| Result | after the payoff | first a scene alone: the flag climbs over the village and the men cheer, or the leader burns to ash; the bought buffs line up under it (new ones on the shelf spark); after 1.4 s or any press three controls: the same loadout again (1), change the loadout (2), hub (3) |
| Lab | hub -> flask -> go | N sieges (default 200) run in slices, the frame never waits: a ring fills with the win rate, the rate stands in it as a number, every siege drops a tick (tall green = won, short red = lost), an outer ring and two numbers show the runs done, a number the mean seconds |
| Lab ranking | the Lab screen, right side | every loadout tried, best first: place number, its pictograms, a bar and the rate; the one on the bench is framed; survives a restart |
| Lab controls | the Lab screen | again (a new batch of the same loadout, added to its line), change the loadout, hub |
| Dev annotate | `./run.sh`, then F12, the camera glyph or the pause menu's camera | the frame freezes; toolbar rect, arrow, circle, pen, text, select, undo, clear; a save writes the bundle folder and a Markdown entry under `~/data/fifteen-dollar-siege_binaries/feedback/` |
| Session recording | `./run.sh` (kuhy's own play only) | `feedback/recordings/<session>.mkv` with moments as chapters; `scripts/recordings.sh latest` lists them |
| Straight into a siege | `./run.sh --mode=watch --loadout=double_men,stew --seed=7` | the battle opens with that loadout and seed |

## Core flows

| id | goal | command | last green |
|---|---|---|---|
| F1 | Watch: the shop tour (vignette, buy, sell, touch, a refused buy), win once, combust once, the result's edit and retry controls, pause works | `scripts/autodrive_all.sh watch` | 2026-11-16, stub sim |
| F2 | Command: the same plus rally, retreat and charge reach the sim | `scripts/autodrive_all.sh command` | 2026-11-16, stub sim |
| F3 | Lab: a batch per loadout seen arriving, 100 % for the winner and 0 % for the loser (stub rule), both ranked, edit and again lead on | `scripts/autodrive_all.sh lab` | 2026-11-16, stub sim |
| F4 | `run.sh` starts on a broken GPU GL and F12 saves a complete bundle | `scripts/test_launcher.sh` | 2026-11-16, scaffold |
| F5 | The exported Linux build plays without the dev tools | `scripts/test_export.sh` | 2026-11-16, scaffold |
| F6 | Battle screen: every kind, state, look and event is drawn; no frame of 2,400 figures over budget | `scripts/autodrive_all.sh showcase` | 2026-11-16, battle view |

On failure a bot flow prints `AUTODRIVE FAIL: <the assert that broke>`, then
`<label>: FAILED (<why>; exit <n>, log <path>)`, keeps its run directory
(log, verdict, frames so far) and exits non-zero. F4 and F5 print the tail of
the game's log and the same `FAILED` line.

F3's expected numbers are the stub's. When the real sim lands, F1-F3 keep
their steps and change only which loadouts they call a win and a loss
(`WIN_IDS`, `LOSE_IDS` in `src/autodrive/autodrive.gd`).
