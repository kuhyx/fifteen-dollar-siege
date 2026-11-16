# fifteen-dollar-siege

A text-free siege sandbox made from one meme: you lead 100 random men with
clubs and slingshots against a 1100 AD village of 2,000, and you have 15
dollars to spend on 25 buffs, from "+50 men" to 300 paper wasps. Buy a
loadout, then:

- **Watch** the siege play itself,
- **Command** it with a rally flag, charge and retreat, or
- send it to the **Lab**, which runs it many times and shows how often it wins.

Godot 4.7.2, GDScript. Linux desktop and a single-threaded Web build.

**State:** the menus, the battle screen, the sound (music, effects, a volume
control), the dev tools and the gates are real, on desktop and in the browser.
The sim is being rewritten: see `DOCS-design.md` section 6.

## Run

```bash
./install.sh     # once, and after a pull: tools, GUT, binaries links, hooks
./run.sh         # windowed, sound on, dev feedback mode (F12 annotates)
./run.sh --mode=watch --loadout=double_men,fifty_men --seed=7
```

Esc (or the menu button, top left) opens the pause menu. `run.sh` records
your play; `scripts/recordings.sh latest` lists the moments.

## Check

```bash
scripts/test.sh            # GUT, headless
scripts/autodrive_all.sh   # the bot plays all three modes on a private Xvfb
scripts/check.sh --group fast   # lint, greps, saves; then play, tools, build, web
scripts/test_web.sh        # the Web build, played in headless Chromium
```

Agents: read `CLAUDE.md` first (run rules, contracts, the save guard).

## Where things are

| Path | What |
|---|---|
| `src/core/` | buffs, loadout rules, the sim, the Lab: pure logic |
| `src/view/`, `src/ui/` | the flow, the screens, the pictograms |
| `src/autodrive/` | the bot behind `--autodrive=<mode>` |
| `src/dev/` | this game's side of the dev feedback mode (host glue); the mode itself is `kuhyx/utils` `godot_dev_tools`, mounted at `addons/dev_tools` by `install.sh` |
| `tools/recording/` | the session recorder |
| `tests/`, `scripts/` | GUT and unittest suites, every gate |
| `DOCS-design.md` | goal, rules, Core API, constant sources |
| `DOCS-features.md` | feature map and the five core flows |
| `CREDITS.md` | where code, tools and (later) assets come from |
