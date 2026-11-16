class_name AudioCues
extends RefCounted
## The cue sheet: which rendered file answers which siege event or menu
## action, and how often it may repeat. Files are named without ROOT and
## ".wav"; tools/audio renders them, tests/audio checks the two lists match.
## A cue: files (takes; one is picked per play), db (trim on top of the
## file's own loudness target), gap (seconds between two starts), voices
## (how many may sound at once), jitter (random pitch spread, a fraction),
## rank (a full pool drops rank 0 first; rank 2 and 3 take a voice).
## Every number here is a [design guess]; DOCS-audio.md has the table.

const ROOT := "res://assets/audio/"
const HUB := "music/hub_loop"
## The battle bed's stems, in BattleMix order, then the band's riff.
const STEMS: Array[String] = [
	"music/battle_base",
	"music/battle_alarm",
	"music/battle_hope",
	"music/battle_dread",
	"music/rock_riff",
]
const WIN := "music/win_stinger"
const LOSE := "music/lose_stinger"

## SiegeSim.Command -> cue (RALLY, CHARGE, RETREAT).
const COMMANDS: Array[StringName] = [&"command_rally", &"command_charge", &"command_retreat"]
## Menu cues, for the coverage test and the director.
const UI: Array[StringName] = [
	&"ui_buy",
	&"ui_unbuy",
	&"ui_refuse",
	&"ui_go",
	&"ui_button",
	&"ui_mode",
	&"ui_pause",
	&"ui_resume",
	&"ui_lab_tick",
	&"ui_lab_done",
]

## The small rewards and surprises (DOCS-design-fun.md), played by the view
## through `AudioDirector.play`.
const FUN: Array[StringName] = [
	&"fun_toll",
	&"fun_heartbeat",
	&"fun_glint",
	&"fun_dice",
	&"fun_star",
	&"fun_firework",
	&"fun_hic",
	&"fun_tick",
]

const CUES := {
	&"command_rally": {"files": ["sfx/command_rally"], "gap": 0.15, "voices": 1, "rank": 2},
	&"command_charge": {"files": ["sfx/command_charge"], "gap": 0.15, "voices": 1, "rank": 2},
	&"command_retreat": {"files": ["sfx/command_retreat"], "gap": 0.15, "voices": 1, "rank": 2},
	&"alarm": {"files": ["sfx/alarm"], "gap": 2.0, "voices": 1, "rank": 2},
	&"bell_ring": {"files": ["sfx/bell"], "db": -3.0, "gap": 1.5, "voices": 2, "rank": 1},
	&"sling_volley":
	{
		"files": ["sfx/sling_1", "sfx/sling_2", "sfx/sling_3"],
		"db": -3.0,
		"gap": 0.12,
		"voices": 3,
		"jitter": 0.08,
	},
	&"arrow_volley":
	{"files": ["sfx/arrow_1", "sfx/arrow_2"], "db": -3.0, "gap": 0.14, "voices": 3, "jitter": 0.07},
	&"melee_clash":
	{
		"files": ["sfx/club_1", "sfx/club_2", "sfx/club_3"],
		"db": -2.0,
		"gap": 0.09,
		"voices": 4,
		"jitter": 0.1,
	},
	&"squad_rout": {"files": ["sfx/rout"], "gap": 0.5, "voices": 2, "jitter": 0.05, "rank": 1},
	&"squad_rally": {"files": ["sfx/rally"], "gap": 0.6, "voices": 2, "jitter": 0.03, "rank": 1},
	&"squad_wiped": {"files": ["sfx/wiped"], "gap": 0.4, "voices": 2, "jitter": 0.05, "rank": 1},
	&"shotgun_blast":
	{"files": ["sfx/shotgun"], "gap": 0.25, "voices": 2, "jitter": 0.04, "rank": 1},
	&"pumpkin_launch":
	{"files": ["sfx/catapult"], "gap": 0.4, "voices": 2, "jitter": 0.04, "rank": 1},
	&"pumpkin_splat": {"files": ["sfx/splat"], "gap": 0.2, "voices": 2, "jitter": 0.08, "rank": 1},
	&"heal": {"files": ["sfx/heal"], "db": -2.0, "gap": 0.8, "voices": 1, "jitter": 0.03},
	&"wasp_swarm": {"files": ["sfx/wasps"], "gap": 1.0, "voices": 2, "jitter": 0.05, "rank": 1},
	&"moose_charge": {"files": ["sfx/moose"], "gap": 0.8, "voices": 2, "jitter": 0.05, "rank": 1},
	&"cart_crash":
	{"files": ["sfx/cart_crash"], "gap": 0.5, "voices": 2, "jitter": 0.05, "rank": 1},
	&"monster_smash": {"files": ["sfx/smash"], "gap": 0.35, "voices": 2, "jitter": 0.05, "rank": 1},
	&"trumpet_call": {"files": ["sfx/trumpet"], "gap": 1.5, "voices": 1, "rank": 1},
	&"band_riff": {"files": ["sfx/guitar_stab"], "gap": 2.0, "voices": 1, "rank": 1},
	&"reveal": {"files": ["sfx/reveal"], "gap": 0.3, "voices": 2, "jitter": 0.05},
	&"ufo_abduct": {"files": ["sfx/ufo"], "gap": 0.8, "voices": 2, "jitter": 0.03, "rank": 2},
	&"pep_talk": {"files": ["sfx/pep_talk"], "gap": 2.0, "voices": 1, "rank": 2},
	&"centre_held": {"files": ["sfx/centre_tick"], "gap": 0.4, "voices": 2, "rank": 2},
	&"victory": {"files": ["sfx/cheer"], "gap": 3.0, "voices": 1, "rank": 3},
	&"combust": {"files": ["sfx/combust"], "gap": 3.0, "voices": 1, "rank": 3},
	&"fun_toll": {"files": ["sfx/fun_toll"], "gap": 0.3, "voices": 2, "jitter": 0.0},
	&"fun_heartbeat": {"files": ["sfx/fun_heartbeat"], "gap": 0.5, "voices": 1},
	&"fun_glint": {"files": ["sfx/fun_glint"], "gap": 0.12, "voices": 3, "jitter": 0.06},
	&"fun_dice": {"files": ["sfx/fun_dice"], "gap": 0.3, "voices": 1, "jitter": 0.03},
	&"fun_star": {"files": ["sfx/fun_star"], "gap": 0.1, "voices": 3},
	&"fun_firework": {"files": ["sfx/fun_firework"], "gap": 0.25, "voices": 3, "jitter": 0.05},
	&"fun_hic": {"files": ["sfx/fun_hic"], "gap": 0.6, "voices": 1, "jitter": 0.08},
	&"fun_tick": {"files": ["sfx/centre_tick"], "gap": 0.2, "voices": 2},
	&"ui_buy": {"files": ["ui/ui_buy"], "gap": 0.05, "voices": 2},
	&"ui_unbuy": {"files": ["ui/ui_unbuy"], "gap": 0.05, "voices": 2},
	&"ui_refuse": {"files": ["ui/ui_refuse"], "gap": 0.15, "voices": 1},
	&"ui_go": {"files": ["ui/ui_go"], "gap": 0.3, "voices": 1},
	&"ui_button": {"files": ["ui/ui_button"], "gap": 0.03, "voices": 2},
	&"ui_mode": {"files": ["ui/ui_mode"], "gap": 0.1, "voices": 1},
	&"ui_pause": {"files": ["ui/ui_pause"], "gap": 0.05, "voices": 1},
	&"ui_resume": {"files": ["ui/ui_resume"], "gap": 0.05, "voices": 1},
	&"ui_lab_tick": {"files": ["ui/ui_lab_tick"], "gap": 0.05, "voices": 3, "jitter": 0.02},
	&"ui_lab_done": {"files": ["ui/ui_lab_done"], "gap": 0.5, "voices": 1},
}


## The cue that answers a siege event (&"" for a kind this sheet does not know).
static func for_event(event: Dictionary) -> StringName:
	var kind: StringName = event.get("kind", &"")
	if kind == SiegeEvent.COMMAND:
		return COMMANDS[clampi(int(event.get("command", 0)), 0, COMMANDS.size() - 1)]
	return kind if CUES.has(kind) else &""


## Pitch that carries an event's data: a village squad sounds higher than an
## army squad, and the centre-held drum climbs with `progress`.
static func pitch_for(event: Dictionary) -> float:
	var kind: StringName = event.get("kind", &"")
	if kind == SiegeEvent.CENTRE_HELD:
		return lerpf(0.85, 1.35, clampf(float(event.get("progress", 0.0)), 0.0, 1.0))
	if kind in [SiegeEvent.SQUAD_ROUT, SiegeEvent.SQUAD_RALLY, SiegeEvent.SQUAD_WIPED]:
		return 1.1 if int(event.get("team", 0)) == SiegeSnapshot.Team.VILLAGE else 0.92
	return 1.0


static func value(cue: StringName, field: String, fallback: float) -> float:
	return float((CUES[cue] as Dictionary).get(field, fallback))


## Every file the game plays: the loops, the stingers, each cue's takes.
static func files() -> PackedStringArray:
	var out := PackedStringArray([HUB, WIN, LOSE])
	out.append_array(PackedStringArray(STEMS))
	for cue: StringName in CUES:
		out.append_array(PackedStringArray((CUES[cue] as Dictionary)["files"] as Array))
	return out


## The files that must loop.
static func loops() -> PackedStringArray:
	var out := PackedStringArray([HUB])
	out.append_array(PackedStringArray(STEMS))
	return out
