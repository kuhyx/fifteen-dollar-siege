# FEATURES: fifteen-dollar-siege

> Feature map + core-flow ground truth (skill: `e2e-ground-truth`). Keep it
> current: a user-visible change updates its row in the same commit. "How to
> reach it" is a path a driver can follow; "expected outcome" is something a
> check can observe.

- **Primary target:** Godot 4.7.2, Linux desktop and single-threaded Web
- **Driver:** the game's own `--autodrive=<mode>` bot on a private Xvfb
  (`scripts/autodrive_all.sh`), muted, under 60 s; never `godot-mcp-runtime`.
  The Web build: headless Chromium over CDP (`scripts/test_web.sh`)
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
| Volume | the pause menu, two rows under the buttons | music and effects: a quieter speaker, a bar of 10 steps, a louder speaker (keys 4 5 and 6 7; touch shows none); the bar, the bus and `audio.json` follow every press; a restart brings the levels back |
| Sound | any screen | the hub loop from boot (the browser: from the first touch); a cue for every menu action and every battle event, placed left to right on the map; a battle bed that follows alarm and morale; a stinger for the win and for the flames |
| Web build | the Web preset (`scripts/export.sh web`), `index.html?probe` for the gate | the same game in a browser, single-threaded; touch works through the same buttons; `scripts/test_web.sh` plays it |
| Build rounds | `scripts/build_round.sh <NN> "<note>"` | `builds/vNN/` with the Web export at the top, `linux/` and a `NOTES` line; an existing round is refused |
| Loadout | hub -> a mode button | 25 pictogram cards on five price shelves (5 dollars down to 1), each with its price as coin slots; a tray of 15 budget coins; the army size as a number and one figure per ten men; a green go button; no words |
| Buy / sell | click a card (touch: tap to look, tap again to buy) | coins fly from the tray into the card's slots, the card gets a green frame and a check; a second click sends the coins back; cards the dollars left do not reach are dimmed; the army number follows `fifty_men` / `double_men` |
| Budget refusal | click a card that costs more than is left | the tray shakes and its rim turns red, the card shakes; cost and loadout unchanged; nothing is written |
| Vignette | hover, focus or tap a card | the preview plays that buff's looping vector scene (2.4 s); its pictogram and price stand under it; with no card on show the army marches there |
| Remembered loadout | open a mode's loadout again | last time's picks for that mode are bought already |
| Watch | hub -> eye -> go | the real siege: every man and villager is a drawn figure on a map with the sim's church (north of the plaza, its bell where the map says); two morale bars, an alarm bell, a hold-the-centre ring and a clock, each equal to the snapshot's value; it ends by itself in about a minute at x2 (the siege lasts about 100 sim seconds) |
| Buff chips | battle, under the meters strip | one pictogram per bought buff; large above the army for 1.2 s at the start, then small; small while a beat plays. The buffs that only change numbers also get a moment on the field (rows below) |
| Weight of blows | battle: a smash, crash, blast, charge, splat, wipe, reveal, win or loss | the camera shakes (at most 16 px, decaying) and the world holds a few frames; the same kind kicks again only after 0.6 s |
| Pops and tally | battle: heads fall | a pop where each squad loses heads; every 10th villager down, a gold number over the fight, a rising bell, the men hop; one number at a time, a new milestone rolls it, so numbers never overlap at any speed |
| Heartbeat edge | battle: army morale under 0.3 | a red frame at the screen's edge pulses lub-dub with a heartbeat; back above 0.45 it flashes gold once |
| Finale | the siege is won | 8 rockets burst over the church, the men jump, invisible squads appear one by one |
| Buff moments | battle, 1.5 s in (or at the alarm) | stew: a bowl badge and steam; prep times: a sweeping clock with ticks; double or fifty men: the army number rolls up; sleepless village: its badge at the alarm; deaf village: its crossed ear a beat later |
| Live looks | battle, a squad in view | knight armour and helmets glint, cardboard flakes, booze hiccups bubbles, metal bats ping, each every 0.5 to 1.2 s |
| Shop dice | shop: the dice at the top right (key 2) | sells back, then buys a random legal loadout card by card, coins flying and dice rattling; the go button then starts it |
| Stars | result of a win | 1 star for the win, 2 for at most 10 dollars spent, 3 for at most 6; they pop in with rising chimes; the empty ones show their coins as a number |
| Try again | result: the dice (key 4) | a siege starts with a random new legal loadout; the dice breathe after a second |
| Hub life | hub | a mode button swells under the pointer or focus; a wave of light crosses the shelf every 4.5 s |
| Hero marks | battle | a gold ring and a pointer on the army's single figures (the great captain, the trumpet boy, the gunman, the monster) at any zoom |
| Speed and hold | battle: Space / 1 2 3 4, or the buttons bottom left | the sim stands still or runs at x1, x2 (the start), x4, x8; each button shows its key; the figures glide between the sim's 0.1 s ticks at every speed; once decided the siege plays on at x1 at most |
| Camera | battle: wheel or pinch, drag; 0 or the view-finder button | zoom and pan by hand; back to framing the action by itself, the planted rally flag included |
| Command | hub -> flag -> go | as Watch, plus: a click on the map plants a rally flag (a drag only pans), Enter / Backspace or the buttons charge and retreat; the bot's orders (`BotCommander`: rally short of the houses, retreat when worn down, charge when the village sags) win more sieges and keep more men than no orders (`tests/test_bot_commander.gd`) |
| Staged beats | a siege whose first snapshot has `ufo_abduct` or `pep_talk` | they play before the clock starts; Space, Enter, a tap or the skip button cuts one short |
| Payoff | the sim decides | on the battle screen: the camera frames the church and, when both fit one view, the army that took it; the army's flag climbs the tower (win, the village dimmed), or the army burns under a night veil with the village crowd dimmed (lose); any press after 0.3 s skips to the result |
| Every buff | `scripts/test_buffs.sh` | each of the 25 buffs alone on the battle screen: its chip, and as the buff has them its figure, look, men on the field, effect and the audio director's cue, then one frame named after it |
| Reel | `scripts/reel.sh out_dir ids seed` | one real siege, a frame every few sim seconds and the payoff |
| Showcase | `scripts/autodrive_all.sh showcase` | 24 frames: every kind in every state, six looks, every event, both beats, both payoffs, 2,400 figures inside the frame budget |
| Result | after the payoff | the same scene in its end state (the flag over the village, or the leader's ash; nothing plays twice) with four controls up at once: the same loadout again (1), change the loadout (2), hub (3), the dice (4); the bought buffs line up under it (new ones on the shelf spark) |
| Lab | hub -> flask -> go | N sieges (default 200) run in slices, the frame never waits: a ring fills with the win rate, the rate stands in it as a number, every siege drops a tick (tall green = won, short red = lost), an outer ring and two numbers show the runs done, a number the mean seconds |
| Lab ranking | the Lab screen, right side | every loadout tried, best first: place number, its pictograms, a bar and the rate; the one on the bench is framed; survives a restart |
| Lab controls | the Lab screen | again (a new batch of the same loadout, added to its line), change the loadout, hub |
| Dev annotate | `./run.sh`, then F12, the camera glyph or the pause menu's camera | the frame freezes; toolbar rect, arrow, circle, pen, text, select, undo, clear; a save writes the bundle folder and a Markdown entry under `~/data/fifteen-dollar-siege_binaries/feedback/` |
| Session recording | `./run.sh` (kuhy's own play only) | `feedback/recordings/<session>.mkv` with moments as chapters; `scripts/recordings.sh latest` lists them |
| Straight into a siege | `./run.sh --mode=watch --loadout=double_men,stew --seed=7` | the battle opens with that loadout and seed |

## Core flows

| id | goal | command | last green |
|---|---|---|---|
| F1 | Watch: the shop tour (vignette, buy, sell, touch, a refused buy), win once, combust once (the pinned fixtures of the real sim, the staged pep talk seen then skipped), the result's edit and retry controls, pause works | `scripts/autodrive_all.sh watch` | 2026-11-16 |
| F2 | Command: the same, the won siege played by `BotCommander` through the real controls: the flag planted where sent, the charge chevrons seen; the lost one gets all three controls | `scripts/autodrive_all.sh command` | 2026-11-16 |
| F3 | Lab: a batch per loadout seen arriving, mostly won for the winner and none for the loser (the fixtures), both ranked, equal to `Lab.run_batch`, edit and again lead on | `scripts/autodrive_all.sh lab` | 2026-11-16 |
| F4 | `run.sh` starts on a broken GPU GL and F12 saves a complete bundle | `scripts/test_launcher.sh` | 2026-11-16, scaffold |
| F5 | The exported Linux build plays without the dev tools | `scripts/test_export.sh` | 2026-11-16, scaffold |
| F6 | Battle screen: every kind, state, look and event is drawn; no frame of 2,400 figures over budget | `scripts/autodrive_all.sh showcase` | 2026-11-16, battle view |
| F7 | Touch: hub, shop (look, buy), go, battle (rally flag, speed, pause, resume, menu, a tap on quieter), payoff skipped, result, again; no key, pad or real-mouse event | `scripts/autodrive_all.sh touch` | 2026-11-16 |
| F8 | Web: the hub is drawn, the console shows no error, the first touch starts the audio context and the hub music, touch taps reach the shop and a battle whose music plays | `scripts/test_web.sh` | 2026-11-16 |
| F9 | Volume: both speakers, a key and a step move the row, the bus and the save; a restart restores them | `scripts/autodrive_all.sh watch` (hub beat) and `scripts/test.sh -gselect=test_volume` | 2026-11-16 |
| F10 | Every buff seen and heard (chip, figure, look, effect, cue), 25 frames | `scripts/test_buffs.sh` | 2026-11-16 |
| F11 | The sim's pinned balance checks (30) | `scripts/balance_gate.sh` | 2026-11-16 |
| F12 | The fun pass: the shop dice, a win's stars and dice, and one real siege per battle delight (shake, unmasking, looks, tally, finale, heartbeat edge) on screen | `scripts/autodrive_all.sh watch` and `scripts/autodrive_all.sh fun` | 2026-11-16 |

On failure a bot flow prints `AUTODRIVE FAIL: <the assert that broke>`, then
`<label>: FAILED (<why>; exit <n>, log <path>)`, keeps its run directory
(log, verdict, frames so far) and exits non-zero. F4 and F5 print the tail of
the game's log and the same `FAILED` line.

The fixtures (`SiegeFixtures`: a loadout and seed that win, one that loses) are
the sim agent's; after a tuning change `tools/sim/find_fixtures.gd` finds new
ones and the bot follows by itself.
