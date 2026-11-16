# fifteen-dollar-siege

A siege game made from one meme. You lead 100 random men with clubs and
slingshots against a village of 2,000 in 1100 AD, and you have 15 dollars to
spend on buffs from a list of 25, from "+50 men" to 300 paper wasps. The game
has no words: pictograms, coins, numbers, motion and sound.

Godot 4.7.2, GDScript. Linux desktop and a single-threaded Web build.

## Install and run

```bash
./install.sh     # once, and after a pull: tools, GUT, binaries links, hooks
./run.sh         # windowed, sound on, dev feedback mode (F12 annotates)
./run.sh --mode=watch --loadout=double_men,fifty_men --seed=7   # straight into a siege
```

## The three modes

Pick one on the hub, buy up to 15 dollars of buffs in the shop, press go.

- **Watch**: the siege plays itself.
- **Command**: the same, and you lead it with a rally flag, charge and retreat.
- **Lab**: runs your loadout many times and shows how often it wins.

A win earns up to three stars (the cheaper the army, the more stars). The hub
keeps the best stars per mode, the buffs you have won with, and the best Lab rate.

## Keys

| Where | Key |
|---|---|
| Hub, shop, result | `1` `2` `3` (`4`) pick the big controls left to right; `Backspace` goes back |
| Shop | the dice (key `2`) roll a random loadout |
| Battle | `Space` pause; `1` `2` `3` `4` speed x1 x2 x4 x8; `Enter` charge; `Backspace` retreat; `0` frame the action; wheel zooms, drag pans, click plants the rally flag |
| Anywhere | `Esc` the pause menu (volume `4` `5` music, `6` `7` effects); `F12` annotate the frame (dev mode) |

A pad works through focus and its face buttons; touch works through the same
buttons (the menu button stands in for `Esc`).

## Playtest

```bash
scripts/playtest.sh      # every item in order: it opens the game in a state, asks one yes/no
scripts/playtest.sh 04   # only the item whose file starts with 04
```

Each item under `scripts/handoff/` opens the game (or the browser) on one thing
only you can judge and asks one question; a "no" asks for one line of what was
wrong. Answers go to `feedback/playtest-answers.jsonl`. Only the audio item plays
sound. Every item also takes `--check`: the same launch, muted, on a private
screen, no question.

## Check

```bash
scripts/test.sh                  # GUT, headless
scripts/autodrive_all.sh         # the bot plays every mode on a private Xvfb
scripts/check.sh --list          # the gate groups; each runs under 60 s
scripts/check.sh --group fast    # then play, bots, tools, sim, build, web, handoff
```

Agents: read `CLAUDE.md` first (run rules, contracts, the save guard).

## Where things are

| Path | What |
|---|---|
| `src/core/` | buffs, loadout rules, the sim, the Lab: pure logic |
| `src/view/`, `src/ui/` | the flow, the screens, the pictograms |
| `src/audio/`, `tools/audio/` | the sound director and the music and effects rendered from code |
| `src/autodrive/` | the bot behind `--autodrive=<mode>` |
| `src/dev/`, `tools/recording/` | dev feedback mode and the session recorder |
| `scripts/handoff/`, `scripts/playtest.sh` | the playtest items and their runner |
| `tests/`, `scripts/` | GUT and unittest suites, every gate |
| `DOCS-design.md` | goal, rules, Core API, constant sources |
| `DOCS-features.md` | feature map and the core flows |
| `CREDITS.md` | where code, tools and assets come from |
