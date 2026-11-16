class_name SiegeTuning
extends RefCounted
## Tuning numbers of the base siege (no buffs): time, the village, detection,
## combat, morale, fatigue. Every constant has a row in DOCS-design-sim.md
## "Sources"; a value the research could not source is a [design guess] there.
## Buff numbers live in BuffTuning.

# --- time ---
## The fixed logic timestep (SiegeSim.STEP_S): 10 ticks per second; the view
## interpolates between snapshots.
const STEP_S := 0.1
## Logic ticks between two decisions (targets, combat, morale): 2 per second.
const THINK_TICKS := 5
const THINK_S := STEP_S * THINK_TICKS
## The siege ends in a loss when nothing decided it by then.
const TIME_CAP_S := 300.0
## Real slow processes (alarm, muster, tiring) run this many times faster.
const TIME_COMPRESSION := 15.0

# --- the map ---
const ARMY_SPAWN := Vector2(190.0, 200.0)
## The plaza the army must hold.
const CENTRE_R := 25.0
const HOLD_S := 30.0
## Army heads needed in the plaza, and how many times the defenders there.
const HOLD_MIN_HEADS := 10
const HOLD_RATIO := 3.0
## Defenders do not chase further than this beyond the village edge.
const LEASH_M := 60.0

# --- the village of 2,000 ---
const CROWDS := 17
const CROWD_HEADS := 100
const MILITIA_SQUADS := 25
const ARCHER_SQUADS := 3
const RETINUE_SQUADS := 2
const CROWD_SPEED := 2.2

# --- detection, alarm, muster ---
## A visible army squad this near the village edge can be noticed.
const DETECT_M := 105.0
## Chance per second of being noticed at the outer limit (3x at the edge).
const DETECT_PER_S := 0.2
## Nobody misses an enemy this close.
const SEE_M := 35.0
## Seconds for the shouted alarm to reach the whole village.
const ALARM_SPREAD_S := 30.0
const BELL_DELAY_S := 5.0
const BELL_PERIOD_S := 4.0
## The bell spreads the alarm this much faster than shouting.
const BELL_BOOST := 2.0
## Seconds a militia squad needs to arm after it heard the alarm.
const ARM_MIN_S := 15.0
const ARM_MAX_S := 60.0
const RETINUE_ARM_S := 5.0
## A squad caught unarmed is shaken.
const SURPRISE_SHOCK := 0.15

# --- movement (metres per second; walk and sprint derive from the march) ---
const WALK_SHARE := 0.4
const SPRINT_SHARE := 1.6
const ARRIVE_M := 2.0

# --- combat ---
## Squads this near (centre to centre) are in melee.
const CONTACT_M := 6.0
## How far a squad looks for an enemy, and for a fleeing one to run down.
const ACQUIRE_M := 50.0
const CHASE_M := 20.0
## Men one club-armed man puts down per second of melee.
const MELEE_RATE := 0.012
## A squad can bring at most this many men per enemy head to bear.
const FRONTAGE := 1.5
## A routing squad takes this many times the damage and deals none.
const ROUT_DAMAGE := 2.5
## Seconds of blows a squad takes from whoever it fights as it turns to run.
const PARTING_S := 2.0
## Share of the men put down who are only lightly wounded (a medic's work).
const LIGHT_WOUND_SHARE := 0.35
const SLING_RANGE_M := 20.0
const SLING_ACC := 0.15
## A sling hit that puts a man down (the rest bruise and frighten).
const SLING_DOWN := 0.15
const SLING_RELOAD_S := 2.5
const SLING_AMMO := 12
## Morale a squad of 10 loses per sling hit.
const SLING_STING := 0.02
const SLING_VS_MAIL := 0.2
## Chance that a volley into a melee also hits a friend.
const FRIENDLY_FIRE := 0.04
const BOW_RANGE_M := 50.0
const BOW_HOLD_M := 35.0
const BOW_ACC := 0.1
const BOW_DOWN := 0.4
const BOW_RELOAD_S := 3.0
## Shots into a melee are picked with care.
const BOW_INTO_MELEE := 0.5
## Ranged damage a squad among the houses takes.
const COVER := 0.7
## The first exchange after a CHARGE order, for fresh men: damage factor and
## morale shock. Both shrink to nothing as the men tire.
const CHARGE_IMPACT := 2.0
const CHARGE_SHOCK := 0.15

# --- morale ---
const ARMY_MORALE := 0.7
const VILLAGE_MORALE := 0.9
const MORALE_JITTER := 0.08
## Break-point scale: strangers, neighbours at home, neighbours in the open.
const COHESION_STRANGERS := 0.6
const COHESION_HOME := 1.3
const COHESION_AWAY := 1.0
## Morale lost when a tenth of the squad goes down, at cohesion 1: 0.3.
const CAS_SHOCK := 3.0
## The same loss frightens one squad more than another: the shock varies by
## this share either way.
const SHOCK_SPREAD := 0.5
const ROUT_AT := 0.2
const RALLY_AT := 0.45
## Each rout shrinks the squad's morale ceiling to this share.
const ROUT_CAP_SHARE := 0.75
## A rout or a wiped squad shakes friends this near.
const CONTAGION_M := 14.0
const CONTAGION := 0.08
## Morale per second lost while two or more squads fight one.
const GANG_SHOCK := 0.06
const RECOVER_PER_S := 0.03
## Seconds without a hit before a squad starts to recover.
const QUIET_S := 2.0
## Recovery factor for squads holding at the rally flag or the start.
const FLAG_RECOVER := 3.0
## No enemy this near: a routed squad may rally.
const RALLY_CLEAR_M := 30.0
## A routed squad that can still rally counts this much of its ceiling toward
## its side's morale.
const ROUTED_WEIGHT := 0.5
## Team morale (standing heads times morale, relative to the start) at which
## the side breaks.
const ARMY_BREAK := 0.25
const VILLAGE_BREAK := 0.6
## The lord's retinue steadies the village while it stands.
const LORD_AURA := 0.1
const LORD_FALL_SHOCK := 0.15
## Village fighters lose this when the army reaches a crowd of their kin.
const PANIC_SHOCK := 0.02
const PANIC_M := 12.0

# --- fatigue (per second) ---
const TIRE_MARCH := 0.004
const TIRE_SPRINT := 0.025
const TIRE_FIGHT := 0.015
const REST := 0.02
## At full fatigue: speed, melee strength and morale shocks change by this.
const FATIGUE_SLOW := 0.35
const FATIGUE_WEAK := 0.5
const FATIGUE_SHOCK := 0.5
