class_name Golem
extends Shaped
## The lodestone golem (the crags' boss, docs/REGIONS_PLAN.md §6): the boss at the top of the
## crags, fought in its hall (LodeHall) at the top of their gate level. A hulking, hunched figure of
## buzzing magnets (RisoShapes.spindle: each bulging in the middle and tapering to its two poles),
## held together by their pull, tip to tip across a hairline gap at every joint (GAP), each pole a
## little paler than the rest of its magnet. Its body is one great lodestone leaning forward over its
## feet, rounded at its top, its eyes in it and its heart (a roundel) on its bulge, guarded by a ward
## of three pink plates turning round it (COVERS, printed as an enemy's shield is: RisoWard); caps stand on its shoulders and fins down its back; its long arms are an upper arm, a
## forearm and a palm with three knuckles, for it walks on its knuckles; its short legs are a thigh, a
## shin and a foot, hung from a bar under its body.
## - Its chunks (PART_SIZE: its arms' upper arms and forearms, its ward's three plates, its caps and
##   its fins) are what a blow can break; the rest of it (its body, its palms, its legs) only
##   stops a blow, which goes on to whatever of it is in the way to its heart.
## - It sleeps slumped in its lair until the wizard comes into its hall (or strikes it); then it hunts
##   them on all fours, its fists stepping in turn and its feet shuffling in turn (GAITS), each set down
##   where it lands and left there while its body goes on over it (planted), walking its floor after
##   them (WALK, gathering speed and slowing into its stops; never off the floor's end nor over its
##   gap, though it steps over a stair hole). It turns round only once they are well behind it
##   (TURN_SLACK): its body swings over through upright and it steps its feet and fists round
##   (TURN_TIME), with no flip.
## - The slam, its strong attack: the wizard near it on its floor, it rears back and raises both fists
##   in pink (SLAM_WARN) and brings them down in front of it (SLAM_HOLD), sending a shockwave along the
##   floor both ways (GolemShock), jumped. Its fists' touch hurts, and a guard up as they land parries
##   them: it is stunned (Parry.STUN), its pieces sagging loose, and SHARDS lode shards fly out of it
##   (shed_shards, LodeShard), each one taken making the wizard's spent empowered cast ready at once
##   (Empower.refill). In its hall every damage spell may be cast empowered (LodeHall.tempers).
## - The hurl: the wizard far off (HURL_MIN) and in its sight, every HURL_EVERY seconds at most, it
##   tears off a magnet of its own (HURLED: a cap, then the other, then its top fin), holds it up in
##   both fists (HURL_WARN) and lobs it to land where they are (GolemStone), its arms following
##   through. The magnet lies where it lands until called back.
## - The leap: the wizard on another storey of the hall (LEAP_AFTER), it goes to the gap between
##   (LodeHall's gaps) and, the spot it will land on marked in pink, crouches (LEAP_WARN) and leaps up
##   through it or drops down it in an arc (LEAP_TIME), tucking its feet and fists, landing with a
##   shockwave.
## - The recall: anything of it lying loose (shards, a hurled magnet) RECALL_DELAY seconds, it calls it
##   all back, pink lines warning (RECALL_WARN); then each flies home (RECALL_SPEED) through where the
##   wizard stood, hurting on the way. A hurled magnet is whole again; a shard regrows a shattered
##   chunk (one over its heart first).
## - The shockwave, a hurled magnet and a recalled shard each hurt as a hazard does: a guard catches
##   them, with nothing to strike. Only its fists are its own touch.
## - A blow meets the first chunk of it on the line from where the blow came from to its heart
##   (part_met): a spell's (blow), a parry's, an arrow's (arrow_hit). So what stands in the way is
##   broken first: from the side, an arm, then its ward.
## - Its chunks break only to an empowered spell (Empower): one shatters the chunk it meets; a plain
##   blow glances off it with grit.
## - Its heart is covered while any plate of its ward (COVERS) is whole. Bare, any blow, an arrow or a
##   parry wounds it: HEART wounds, shown as cracks in it. With the last it falls apart into a heap
##   (DIE_TIME), it is slain, and its relic waits where it stood (MapInfo.boss_slain).
## Its pose is worked out as it faces right and mirrored the way it faces; its body's lean and shift,
## its height and its fists and feet through the air all spring toward where its pose wants them, so
## it moves with weight. A harder preset runs its clock faster (Difficulty.haste); a stun's length is
## not changed. A lantern death brings it back whole, as the hall reloads. Nothing here draws from any
## RNG: its choices follow the wizard and the hall's layout.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const HIT_BOX: PackedScene = preload("res://prefabs/hit_box.tscn")
## What it is doing.
enum State { SLEEP, HUNT, SLAM_WARN, SLAM, HURL_WARN, LEAP_WARN, LEAP, RECALL_WARN, RECALL, REST }
## Its heart's wounds, its health.
const HEART: int = 3

## The gap (px) between two magnets' tips at a joint, where their poles meet.
const GAP: float = 4.0
## Its bones: how far (px) from joint to joint along its far arm (shoulder to elbow, elbow to wrist)
## and its near arm, its palms (wrist to knuckles) and its legs (hip to knee, knee to ankle). The far
## arm is the longer, reaching round behind it to the floor.
const BACK_UPPER_BONE: float = 80.0
const BACK_FORE_BONE: float = 180.0
const FRONT_UPPER_BONE: float = 74.0
const FRONT_FORE_BONE: float = 150.0
const PALM: float = 38.0
const THIGH: float = 50.0
const SHIN: float = 46.0
## Its chunks, the magnets of it a blow can break, by their places: its far arm's upper arm and
## forearm, its near arm's, its ward's first two plates, its shoulder caps (far, near) and
## the fins down its back (top first), and its ward's third plate.
const BACK_UPPER: int = 0
const BACK_FORE: int = 1
const FRONT_UPPER: int = 2
const FRONT_FORE: int = 3
const COVER_A: int = 4
const COVER_B: int = 5
const BACK_CAP: int = 6
const FRONT_CAP: int = 7
const FIN_TOP: int = 8
const FIN_MID: int = 9
const FIN_LOW: int = 10
const COVER_C: int = 11
## Each chunk's size, by place: half its length and half its width at its bulge (px).
const PART_SIZE: Array[Vector2] = [
	Vector2(BACK_UPPER_BONE * 0.5 - GAP, 20.0), Vector2(BACK_FORE_BONE * 0.5 - GAP, 30.0),
	Vector2(FRONT_UPPER_BONE * 0.5 - GAP, 20.0), Vector2(FRONT_FORE_BONE * 0.5 - GAP, 30.0),
	Vector2(38.0, 12.0), Vector2(38.0, 12.0),
	Vector2(36.0, 16.0), Vector2(36.0, 16.0),
	Vector2(32.0, 13.0), Vector2(28.0, 11.0), Vector2(24.0, 10.0),
	Vector2(38.0, 12.0),
]
## Its ward, the plates round its heart (PART_SIZE's places): while any is whole its heart is covered.
## A shard called home regrows one of these first.
const COVERS: Array[int] = [COVER_A, COVER_B, COVER_C]
## Its arms' chunks (PART_SIZE's places).
const ARMS: Array[int] = [BACK_UPPER, BACK_FORE, FRONT_UPPER, FRONT_FORE]
## The chunks it hurls, in the order it takes them (PART_SIZE's places): its caps, then its top fin.
const HURLED: Array[int] = [BACK_CAP, FRONT_CAP, FIN_TOP]
## What a blow's or an arrow's meeting is called when it meets the heart (part_met).
const AT_HEART: int = -1

## Its body, the great lodestone it is (as it faces right, from its feet; y up is negative): where its
## middle stands, half its length and half its width at its bulge (px), and how far it leans forward
## (radians from upright).
const BODY_AT: Vector2 = Vector2(14.0, -220.0)
const BODY_LEN: float = 100.0
const BODY_WID: float = 58.0
const LEAN: float = 0.42
## How round its top is: its width toward its top falls off as (1 - s²) to this power (a half is an
## ellipse's round end).
const BODY_ROUND: float = 0.5
## Where things are along its body, in px from its middle (toward its top negative): its shoulders
## (far, near), its caps (far, near), its fins, its heart and its eyes; how far (px) its shoulders
## stand out from its sides; how far its caps and fins turn from straight out (radians).
const SHOULDER_ALONG: Vector2 = Vector2(-30.0, -26.0)
const SHOULDER_OUT: float = 8.0
const CAP_ALONG: Vector2 = Vector2(-44.0, -42.0)
const CAP_TURN: float = 0.3
const FIN_ALONG: Array[float] = [-70.0, -30.0, 10.0]
const FIN_TURN: float = 0.35
## How much of a cap's or a fin's length is sunk behind its body, so it stands out of it rather than
## floating beside it.
const SINK: float = 0.25
const HEART_ALONG: float = 14.0
const EYES_ALONG: float = -54.0
## Its ward: the ring's radius round its heart (px), how thick its plates are, and how fast (radians a
## second) it turns. A plate is met as the chord across it, so far out (px) past its thickness.
const WARD_R: float = 48.0
const WARD_THICK: float = 11.0
const WARD_SPIN: float = 0.6
const WARD_REACH: float = 3.0
## The bar its legs hang from: where it is from its body's lower tip (px), half its length and width,
## and its turn (radians).
const PELVIS_BELOW: Vector2 = Vector2(3.0, 21.0)
const PELVIS_SIZE: Vector2 = Vector2(36.0, 14.0)
const PELVIS_TURN: float = 0.12
## Half the width (px) of its upper arms, forearms, palms, thighs and shins at their bulges; its
## knuckles' and its feet's half length and half width.
const UPPER_WID: float = 20.0
const FORE_WID: float = 30.0
const PALM_WID: float = 22.0
const THIGH_WID: float = 19.0
const SHIN_WID: float = 17.0
const KNUCKLE_SIZE: Vector2 = Vector2(15.0, 8.0)
const FOOT_SIZE: Vector2 = Vector2(30.0, 12.0)
## Its knuckles: how far apart (px), how far past the palm's end, and how they fan (radians each).
const KNUCKLE_APART: float = 14.0
const KNUCKLE_DOWN: float = 8.0
const KNUCKLE_FAN: float = 0.5
## Its feet and fists, the four it stands on (contacts), by their places: its far foot, its near foot,
## its far fist and its near fist (a fist is its palm's end).
const BACK_FOOT: int = 0
const FRONT_FOOT: int = 1
const BACK_FIST: int = 2
const FRONT_FIST: int = 3
## Where on the floor (as it faces right, from its feet) each rests, by contact (its stance); and from
## a foot's middle to its ankle.
const STANCE: Array[Vector2] = [Vector2(-80.0, -10.0), Vector2(24.0, -10.0), Vector2(-145.0, -16.0), Vector2(210.0, -16.0)]
const ANKLE: Vector2 = Vector2(-7.0, -14.0)
## How it walks: its fists step in turn, and its feet shuffle in turn on their own, in short, low,
## quick steps that never pass each other (the gaits: fists, feet, by contact). For each gait: seconds
## a step takes, how far (px) one falls behind its stance before it steps while walking, and how high
## (px) it lifts. How far one strays from its stance before it steps while it stands still; how far
## ahead it steps (of the way it walks in a step: twice, so it swings as far ahead of its stance as it
## falls behind); how much its body rises as a fist steps; and the shake as a fist lands.
const GAITS: Array[Vector2i] = [Vector2i(BACK_FIST, FRONT_FIST), Vector2i(BACK_FOOT, FRONT_FOOT)]
const STEP_TIME: Array[float] = [0.4, 0.2]
const STEP_REACH: Array[float] = [28.0, 10.0]
const STEP_LIFT: Array[float] = [34.0, 6.0]
const STEP_SETTLE: float = 6.0
const STEP_LEAD: float = 2.0
const BOB: float = 7.0
const STEP_SHAKE: float = 1.6
## How fast it walks (px/s), how fast it gathers speed and stops (px/s²), how much of the way left
## becomes its speed (per second) so it slows into its stop, and its least speed on the way; how near
## (px) its middle keeps to the hall's walls, and to a floor's end (its feet); and the widest hole in
## a floor (cells) it steps over (a stair hole, never its gap).
const WALK: float = 85.0
const WALK_ACCEL: float = 520.0
const WALK_EASE: float = 3.0
const MIN_WALK: float = 24.0
const EDGE: float = 190.0
const FOOT: float = 100.0
const STEP_OVER: int = 2
## Seconds it takes to swing round once it turns (it does not slam meanwhile), and how far (px)
## behind it the wizard must be before it does. Turning, it faces the other way at once, but its body
## and its feet and fists stay where they were: its lean swings over through upright, and it steps its
## feet and fists round to its new stance.
const TURN_TIME: float = 0.32
const TURN_SLACK: float = 48.0
## How many lode shards a parried slam sheds, and how hard (px/s, out and up) the outermost are
## thrown; the rest are spread between.
const SHARDS: int = 2
const SHARD_KICK: Vector2 = Vector2(260.0, -560.0)
## The slam: how near across (px) the wizard must be on its floor; seconds raising its fists (the
## warning), holding them down (their touch hurts, and a guard up then parries them) and resting
## after; how far (radians) each arm turns from straight up as it raises its fist (far, back; near,
## forward), and how much of its reach it stretches to, so its arms rise up and out from its
## shoulders; where its near fist's blow
## lands (px from its feet, facing the wizard: the shockwave starts there), how far each fist's touch
## reaches round the fist as drawn, and how far behind its feet (px) its far fist comes down (each arm
## on its own side, so neither swings across its body).
const SLAM_RANGE: float = 300.0
const SLAM_WARN: float = 0.7
const SLAM_HOLD: float = 0.35
const SLAM_REST: float = 0.8
const RAISE_TURN: Array[float] = [-0.5, 0.35]
const RAISE_REACH: float = 0.92
const FIST_AT: Vector2 = Vector2(176.0, -40.0)
const FIST_R: float = 46.0
const SLAM_BEHIND: float = 170.0
## How far (px) its raised fists tremble at the end of the warning, and for what share of it.
const TREMBLE: float = 3.0
const TREMBLE_SHARE: float = 0.3
## The hurl: seconds between hurls at least (the first this long after it wakes), how far (px) the
## wizard must be, seconds holding the magnet up (the warning), where it holds it up (px from its top,
## as it faces right: high over its head, so its arms reach up with their elbows bowed out to the
## sides) and how far (px) its fists grip it from either side (at its tips); how far back (px) it draws
## the magnet over its head toward the end of the warning, winding up, and from what share of the
## warning; seconds the magnet flies to where they were; and the follow-through: seconds its arms
## follow through after the throw, for what share of that they whip on as hard as a slam, where each
## swings to (radians from straight ahead: its far arm on up over its head, its near arm on down in
## front), and how much of their reach they stretch to; then seconds its fists swing back round to
## their places before they are set down.
const HURL_EVERY: float = 5.0
const HURL_MIN: float = 520.0
const HURL_WARN: float = 0.6
const HOLD_OVER: Vector2 = Vector2(-16.0, -160.0)
const GRIP: Vector2 = Vector2(44.0, 10.0)
const WIND_BACK: float = 60.0
const WIND_FROM: float = 0.35
const HURL_FLIGHT: float = 0.9
const THROW_FOLLOW: float = 0.5
const THROW_WHIP: float = 0.45
const THROW_TURN: Array[float] = [-0.8, 0.6]
const THROW_REACH: float = 0.95
const THROW_RETURN: float = 0.35
## The leap: seconds the wizard is on another storey before it goes after them; seconds crouching,
## the spot it will land on marked (the warning); seconds in the air, and how high (px) over the
## higher floor it rises; and how far (px) from the gap's edge it lands on a floor above.
const LEAP_AFTER: float = 1.0
const LEAP_WARN: float = 0.8
const LEAP_TIME: float = 0.9
const LEAP_OVER: float = 200.0
const LEAP_CLEAR: float = 40.0
## The recall: seconds anything of it lies loose before it calls it back, seconds of warning (pink
## lines along the ways home), and how fast (px/s) what it calls flies.
const RECALL_DELAY: float = 3.0
const RECALL_WARN: float = 0.8
const RECALL_SPEED: float = 900.0
## Seconds it rests after a hurl, a leap, a recall or a stun.
const REST: float = 0.6
## How finely (px) it looks along its sight for rock, and along a blow's way to its heart for what of
## it the blow meets first.
const SIGHT_STEP: float = 32.0
const MEET_STEP: float = 6.0
## Seconds: falling apart as it dies, a chunk flashing when struck, and a shattered chunk's bits
## flying.
const DIE_TIME: float = 1.4
const FLASH_TIME: float = 0.2
const SHATTER_TIME: float = 0.5
## Its poses: how much of its height it stands to asleep, crouched to leap, rearing and slamming, and
## stunned; seconds rising as it wakes; how its body shifts (x, y px) and leans (z, radians) asleep,
## rearing back to slam, slamming, rearing back to hurl, throwing, crouched to leap and stunned; how
## far it leans into its walk at full speed and as it rises and comes down in a leap; how far (px)
## its pieces sag out from its body while it is stunned, its pull gone slack; where (as it faces
## right) its feet tuck in the air (far, near); how far (radians) above level its arms are flung out
## from its shoulders as it leaves the ground (far back, near forward) and how far below as it comes
## down to land, and how much of their reach they stretch to; and how much (px) and how fast (radians
## a second) its body breathes.
const SLUMP: float = 0.93
const CROUCH: float = 0.94
const REARED: float = 1.01
const SLAMMED: float = 0.98
const SAGGED_HEIGHT: float = 0.98
const WAKE_TIME: float = 0.6
const SLUMPED: Vector3 = Vector3(6.0, 12.0, 0.16)
const REAR: Vector3 = Vector3(-14.0, -16.0, -0.22)
const STRIKE: Vector3 = Vector3(20.0, 12.0, 0.2)
const WIND: Vector3 = Vector3(-10.0, -12.0, -0.18)
const THROW: Vector3 = Vector3(16.0, 6.0, 0.16)
const HUNCH: Vector3 = Vector3(8.0, 10.0, 0.12)
const SAGGED: Vector3 = Vector3(0.0, 10.0, 0.1)
const WALK_LEAN: float = 0.05
const LEAP_LEAN: Vector2 = Vector2(-0.1, 0.1)
const LOOSE: float = 24.0
const TUCK: Array[Vector2] = [Vector2(-30.0, -56.0), Vector2(34.0, -56.0)]
const LEAP_SWING: Vector2 = Vector2(0.7, -0.6)
const LEAP_REACH: float = 0.85
const BREATH: float = 1.6
const BREATH_RATE: float = 2.0
## Its springs, each how stiff and how damped: the pull that brings its body to its pose; its fists
## and feet through the air; its fists coming down in a slam; and the pull that sets a foot or fist
## down on the floor, and how near (px) it comes before it is held there.
const POSE_PULL: Vector2 = Vector2(140.0, 18.0)
const LIMB_PULL: Vector2 = Vector2(220.0, 24.0)
const STRIKE_PULL: Vector2 = Vector2(1800.0, 70.0)
const PLANT_PULL: Vector2 = Vector2(900.0, 50.0)
const PLANT_HOLD: float = 1.5
## How hard (per second) its height springs down when it lands a leap, slams and sets down a step.
const LAND_KICK: float = 0.8
const SLAM_KICK: float = 0.4
const STEP_KICK: float = 0.1
## The print, after the lodestones' own (LodestoneArt): its magnets' blue darkened to iron with night,
## flat; their pole caps pale (all their night lifted off and half their blue, so they stand paler
## than the hall's stone behind); along
## each magnet's lit edge (the light from above at the left) a rim with night lifted off it, so magnets
## that overlap stay apart and its shape reads against the dark (how far the rim reaches in, px, and
## how much night it lifts); its heart's glow behind it all (how far out, of its heart's radius, and
## how much accent).
const STONE_BLUE: float = 0.95
const STONE_NIGHT: float = 0.85
const POLE_LIFT: float = 1.0
const POLE_PALE: float = 0.5
const RIM: Vector2 = Vector2(3.0, 4.0)
const RIM_LIFT: float = 0.55
const GLOW: float = 3.2
const GLOW_COVER: float = 0.5
## Its heart: its radius (px), the dark rim round it (of its radius), and its mark (an accent disc
## with a paper crescent cut from it: the disc's radius, and the crescent's offset and radius, of the
## heart's radius).
const HEART_R: float = 24.0
const HEART_RIM: float = 1.2
const HEART_MARK: float = 0.68
const HEART_CUT: Vector3 = Vector3(0.26, -0.16, 0.58)
## While its heart is covered: how much of the paper and the accent of it show, and how much of its
## glow, so that what draws the eye is its ward, not the heart behind it.
const COVERED_PAPER: float = 0.4
const COVERED_MARK: float = 0.4
const COVERED_GLOW: float = 0.45
## Its eyes: the dark band they sit in (px, half wide and half high), the slits (px, half long and half
## high) and how far apart (px, from the band's middle), each slanting (radians) in toward the way it
## faces; shut asleep and pink while it warns.
const EYE_BAND: Vector2 = Vector2(20.0, 7.0)
const EYE: Vector2 = Vector2(9.0, 3.5)
const EYES_APART: float = 12.0
const EYE_SLANT: float = 0.22
## Its heart's cracks (px wide), how far its bits fly, a warning's pink, the landing mark (px high)
## and a recall's lines (px wide).
const CRACK_W: float = 5.0
const BITS_FLY: float = 140.0
const WARN_PINK: float = 0.7
const MARK_H: float = 26.0
const RECALL_W: float = 16.0
## Salts for the hashes that lay its heart's cracks and its bits (one look everywhere).
const CRACK_DEAL: int = 6910
const BITS_DEAL: int = 6920


## One magnet of it as posed this step, as it faces right (from its feet): which chunk it is, where
## its middle is and the way it lies, half its length and width, and what it is to the print.
class Piece:
	## Which chunk it is (PART_SIZE's place), or -1 for a magnet that never breaks.
	var part: int = -1
	var c: Vector2 = Vector2.ZERO
	var ang: float = 0.0
	var hl: float = 0.0
	var hw: float = 0.0
	## Its body (the heart and eyes are printed over it), a palm or knuckle (pink while it warns of a
	## slam), and one of the plates of its ward (met as a magnet is, but printed as a ward's plate).
	var body: bool = false
	var hand: bool = false
	var guard: bool = false


var map_info: MapInfo
## Which boss it is (Bosses).
var boss: StringName = &""
## The level's cell size (px).
var cell: float = 128.0
## Which of its chunks are whole, and which are away (hurled, lying until called back) (PART_SIZE's
## places).
var whole: Array[bool] = []
var thrown: Array[bool] = []
var wound: GolemWound
var stunner: Stunner
## Its fists' touch, there only while they are down in a slam, each round its fist as drawn: its near
## fist's, and its far fist's.
var fists: HitBox
var far_fist: HitBox
var state: State = State.SLEEP
var timer: float = 0.0
## The way it faces: 1 right, -1 left; and seconds since it last turned round.
var face: int = 1
var turn_t: float = INF
## Its speed along its floor (px/s, right positive).
var vel: float = 0.0
## Its hall (LodeHall): the air inside, its galleries' rows (top first), the gaps through them, and
## the hall's walls (px).
var inside: Rect2i = Rect2i()
var floors: Array[int] = []
var gaps: Array[Rect2i] = []
var hall_left: float = 0.0
var hall_right: float = 0.0
## Seconds until it may hurl again; seconds the wizard has been on another storey; seconds anything
## of it has lain loose; seconds since it last hurled (its arms following through).
var hurl_wait: float = HURL_EVERY
var apart_t: float = 0.0
var loose_t: float = 0.0
var throw_t: float = INF
## The chunk it holds up to hurl (PART_SIZE's place), or -1.
var hurling: int = -1
## A leap: where from and where to (its feet), and whether it goes down.
var leap_from: Vector2 = Vector2.ZERO
var leap_to: Vector2 = Vector2.ZERO
var leap_down: bool = false
## The shards it has shed and the chunks it has hurled, not yet lost or home.
var shards: Array[LodeShard] = []
var stones: Array[GolemStone] = []
## What it calls home, each with its way home (`way`, set by the recall) and what it regrows.
var called: Array[Node2D] = []
var dying: bool = false
var slain: bool = false
var ink: InkCanvas
var t: float = 0.0
var dead_t: float = 0.0
## When each chunk was last struck and shattered (its clock, t), and its heart wounded; and where
## round the ring each plate of its ward broke (radians, as RisoWard lays it).
var struck_t: Array[float] = []
var shattered_t: Array[float] = []
var broke_at: Array[float] = []
var heart_t: float = -INF
var _was_stunned: bool = false
## Its pose's springs: how far risen it is (0 asleep, 1 awake); how much of its height it stands to;
## its body's shift (px) and lean (radians) from its rest; and how fast each is changing.
var rise: float = 0.0
var squash: float = SLUMP
var squash_v: float = 0.0
var shift: Vector2 = Vector2.ZERO
var shift_v: Vector2 = Vector2.ZERO
var lean: float = 0.0
var lean_v: float = 0.0
## Its feet and fists (contacts, by place): where each is (as it faces right, from its feet) and how
## fast it moves; whether each is set down on the floor, and where (px across, in the level); and how
## high each is lifted in a step.
var limb: Array[Vector2] = []
var limb_v: Array[Vector2] = []
## Where its shoulders are (far, near), as last posed: its fists swing round them.
var shoulder_at: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var planted: Array[bool] = []
var plant_x: Array[float] = []
var lift: Array[float] = []
## Its steps, by gait (GAITS: fists, feet): which contact is stepping (-1 none), seconds into it,
## where it left from and goes to (px across, in the level), and which of the two steps next.
var stepping: Array[int] = [-1, -1]
var step_t: Array[float] = [0.0, 0.0]
var step_from: Array[float] = [0.0, 0.0]
var step_to: Array[float] = [0.0, 0.0]
var next_step: Array[int] = [0, 0]
## Its magnets as posed this step, back to front (Piece), and which of them each chunk is.
var pieces: Array[Piece] = []
var chunk_piece: Array[int] = []
## As posed this step (as it faces right, from its feet): its heart, its eyes and their slant, its
## top, and the ends of its palms (far, near).
var heart_at: Vector2 = Vector2.ZERO
var eyes_at: Vector2 = Vector2.ZERO
var eyes_turn: float = 0.0
var top_at: Vector2 = Vector2.ZERO
var fist_end: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]


func _init() -> void:
	wound = GolemWound.new()
	wound.name = "Wound"
	wound.hp = HEART
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	stunner.parry_only = true
	add_child(stunner)
	# Its fists' touch, under a node of its own so the stun leaves it to sync_fists.
	var hands: Node2D = Node2D.new()
	hands.name = "Hands"
	add_child(hands)
	fists = _fist_touch("HitBox")
	far_fist = _fist_touch("FarHitBox")
	hands.add_child(fists)
	hands.add_child(far_fist)
	for i: int in range(PART_SIZE.size()):
		whole.append(true)
		thrown.append(false)
		struck_t.append(-INF)
		shattered_t.append(-INF)
		broke_at.append(0.0)
	for i: int in range(STANCE.size()):
		limb.append(STANCE[i])
		limb_v.append(Vector2.ZERO)
		planted.append(true)
		plant_x.append(0.0)
		lift.append(0.0)
	add_to_group(&"hex_target")


## A fist's touch named `called`, off until a slam.
func _fist_touch(called: String) -> HitBox:
	var box: HitBox = HIT_BOX.instantiate() as HitBox
	box.name = called
	var reach: CircleShape2D = CircleShape2D.new()
	reach.radius = FIST_R
	var shape: CollisionShape2D = box.get_node("CollisionShape2D") as CollisionShape2D
	shape.shape = reach
	shape.disabled = true
	(box.get_node("Damager") as Damager).attacker = self
	return box


func _ready() -> void:
	# Over the terrain with the other things in a place (props, z 2).
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	# It goes all over its hall: never put to sleep with the chunk its cell is in.
	remove_meta(&"cell")
	var tm: TileMap = info.tile_map
	cell = float(tm.tile_set.tile_size.x) * tm.global_scale.x
	# It stands on the floor of its cell.
	global_position.y += cell * 0.5
	var keep: Dictionary = info.world.keep
	if keep.has("lair"):
		inside = keep["inside"]
		floors = keep["floors"]
		gaps = keep["gaps"]
		hall_left = info.cell_position(inside.position).x - cell * 0.5
		hall_right = info.cell_position(Vector2i(inside.end.x - 1, inside.position.y)).x + cell * 0.5
	for i: int in range(STANCE.size()):
		limb[i] = STANCE[i]
		plant_x[i] = global_position.x + STANCE[i].x * float(face)
	_build_pose()


# ------------------------------------------------------------------ what it is

## Whether a parry has it stunned.
func stunned() -> bool:
	return stunner.stunned()


## Out of the fight (Shaped): dying or dead.
func done() -> bool:
	return dying or slain


## Whether its heart is covered: some chunk over it is whole.
func covered() -> bool:
	return COVERS.any(func(i: int) -> bool: return whole[i])


## How many of its chunks are whole.
func chunks_left() -> int:
	return whole.count(true)


## Whether it is turning round.
func turning() -> bool:
	return turn_t < TURN_TIME


## The way it is drawn across: its pose, worked out as it faces right, mirrored the way it faces.
func _across() -> float:
	return float(face)


## Turn round: it faces the other way at once, but where it is drawn does not jump. Its lean and
## shift are carried over mirrored (so its body swings over from there as they spring back), its feet
## and fists keep their places on the floor (the far ones becoming the near), and it steps them round.
func _turn_round() -> void:
	face = -face
	turn_t = 0.0
	lean = -2.0 * LEAN - lean
	lean_v = -lean_v
	shift = Vector2(-2.0 * BODY_AT.x - shift.x, shift.y)
	shift_v = Vector2(-shift_v.x, shift_v.y)
	stepping = [-1, -1]
	for pair: Vector2i in [Vector2i(BACK_FOOT, FRONT_FOOT), Vector2i(BACK_FIST, FRONT_FIST)]:
		var a: int = pair.x
		var b: int = pair.y
		var la: Vector2 = limb[a]
		var va: Vector2 = limb_v[a]
		limb[a] = Vector2(-limb[b].x, limb[b].y)
		limb_v[a] = Vector2(-limb_v[b].x, limb_v[b].y)
		limb[b] = Vector2(-la.x, la.y)
		limb_v[b] = Vector2(-va.x, va.y)
		var pa: bool = planted[a]
		planted[a] = planted[b]
		planted[b] = pa
		var xa: float = plant_x[a]
		plant_x[a] = plant_x[b]
		plant_x[b] = xa
		var ha: float = lift[a]
		lift[a] = lift[b]
		lift[b] = ha
	var sa: Vector2 = shoulder_at[0]
	shoulder_at[0] = Vector2(-shoulder_at[1].x, shoulder_at[1].y)
	shoulder_at[1] = Vector2(-sa.x, sa.y)


## Where a point of its pose (as it faces right, from its feet) is in the level.
func _world(p: Vector2) -> Vector2:
	return global_position + Vector2(p.x * _across(), p.y)


## Its pose's points (as it faces right, from its feet) to the level.
func _to_world() -> Transform2D:
	return Transform2D(Vector2(_across(), 0.0), Vector2(0.0, 1.0), global_position)


## Where its heart is.
func heart_center() -> Vector2:
	return _world(heart_at)


## Where chunk `i` is.
func part_center(i: int) -> Vector2:
	return _world(pieces[chunk_piece[i]].c)


## Where the end of its fist `k` is (0 its far one, 1 its near one).
func fist_at(k: int) -> Vector2:
	return _world(fist_end[k])


## The capsule a blow meets magnet `p` by: its two ends and its radius (px), in the level.
func _capsule(p: Piece) -> Array:
	var along: Vector2 = Vector2.from_angle(p.ang) * p.hl * 0.55
	return [_world(p.c - along), _world(p.c + along), p.hw * 0.85]


## Whether magnet `p` shows: a chunk only while it is whole.
func _shows(p: Piece) -> bool:
	return p.part < 0 or whole[p.part]


## What a blow can meet: its whole chunks (PART_SIZE's places), and its heart (AT_HEART) once bare.
func _targets() -> Array[int]:
	var out: Array[int] = []
	for i: int in range(PART_SIZE.size()):
		if whole[i]:
			out.append(i)
	if not covered():
		out.append(AT_HEART)
	return out


## How far `at` is from the edge of what `k` names (a chunk, or AT_HEART); inside it, below 0.
func _edge_distance(k: int, at: Vector2) -> float:
	if k == AT_HEART:
		return at.distance_to(heart_center()) - HEART_R
	var cap: Array = _capsule(pieces[chunk_piece[k]])
	return at.distance_to(Geometry2D.get_closest_point_to_segment(at, cap[0], cap[1])) - float(cap[2])


## Whether a way from `from` to `to` comes within `reach` of any magnet of it that shows.
func struck_by(from: Vector2, to: Vector2, reach: float) -> bool:
	for p: Piece in pieces:
		if not _shows(p):
			continue
		var cap: Array = _capsule(p)
		var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(from, to, cap[0], cap[1])
		if near[0].distance_to(near[1]) <= float(cap[2]) + reach:
			return true
	return false


## The part a blow from `from` meets (a chunk's place in PART_SIZE, or AT_HEART): of those a blow can
## meet, the first along the way from `from` to its heart; failing that (a blow from inside it), the
## one whose edge is nearest `from`. Its body and legs are passed by, on the way to what is behind. Its
## ward guards all the way round, gaps and all: a blow that comes within its ring while it is whole
## meets the whole plate nearest.
func part_met(from: Vector2) -> int:
	var to: Vector2 = heart_center()
	var targets: Array[int] = _targets()
	var steps: int = maxi(1, ceili(from.distance_to(to) / MEET_STEP))
	for s: int in range(steps + 1):
		var at: Vector2 = from.lerp(to, float(s) / float(steps))
		for k: int in targets:
			if _edge_distance(k, at) <= 0.0:
				return k
		if covered() and at.distance_to(to) <= WARD_R + WARD_REACH:
			return _nearest(COVERS.filter(func(i: int) -> bool: return whole[i]), at)
	return _nearest(targets, from)


## Of the parts `of` (places in PART_SIZE, or AT_HEART), the one whose edge is nearest `at`.
func _nearest(of: Array, at: Vector2) -> int:
	var nearest: int = AT_HEART
	var nearest_d: float = INF
	for k: int in of:
		var d: float = _edge_distance(k, at)
		if d < nearest_d:
			nearest_d = d
			nearest = k
	return nearest


## The storey of its hall a point is on, by the rows: 0 the top (over the top gallery), 1 the middle,
## 2 the ground storey.
func storey_of(at: Vector2) -> int:
	var row: int = map_info.cell_at(at).y
	for k: int in range(floors.size()):
		if row < floors[k]:
			return k
	return floors.size()


## Its own storey (by its feet).
func storey() -> int:
	return storey_of(global_position + Vector2(0.0, -cell * 0.5))


## The top (px) of storey `k`'s floor.
func floor_y(k: int) -> float:
	var row: int = floors[k] if k < floors.size() else inside.end.y
	return map_info.cell_position(Vector2i(inside.position.x, row)).y - cell * 0.5


## How far (px, its middle's least and most x) it may walk along storey `k`'s floor from `x`: to the
## floor's ends (stepping over holes no wider than STEP_OVER) less its feet, and no nearer the walls
## than EDGE.
func reach_along(k: int, x: float) -> Vector2:
	var row: int = floors[k] if k < floors.size() else inside.end.y
	var c: int = clampi(map_info.cell_at(Vector2(x, floor_y(k) + 1.0)).x, inside.position.x, inside.end.x - 1)
	var ends: Array[int] = []
	for step: int in [-1, 1]:
		var last: int = c
		var hole: int = 0
		var i: int = c
		while i >= inside.position.x and i < inside.end.x:
			if map_info.world.is_ground(Vector2i(i, row)):
				last = i
				hole = 0
			else:
				hole += 1
				if hole > STEP_OVER:
					break
			i += step
		ends.append(last)
	var lo: float = maxf(map_info.cell_position(Vector2i(ends[0], row)).x - cell * 0.5 + FOOT, hall_left + EDGE)
	var hi: float = minf(map_info.cell_position(Vector2i(ends[1], row)).x + cell * 0.5 - FOOT, hall_right - EDGE)
	if lo > hi:
		var mid: float = (lo + hi) * 0.5
		return Vector2(mid, mid)
	return Vector2(lo, hi)


## The middle (px across) of gap `g`, and its edges.
func _gap_mid(g: Rect2i) -> float:
	return (_gap_left(g) + _gap_right(g)) * 0.5


func _gap_left(g: Rect2i) -> float:
	return map_info.cell_position(g.position).x - cell * 0.5


func _gap_right(g: Rect2i) -> float:
	return map_info.cell_position(Vector2i(g.end.x - 1, g.position.y)).x + cell * 0.5


## Whether the wizard is in its hall.
func _in_hall(player: Player) -> bool:
	return not floors.is_empty() and (map_info.world.keep["box"] as Rect2i).has_point(map_info.cell_at(player.global_position))


## Whether it sees `at` from its heart: no rock between.
func sees(at: Vector2) -> bool:
	var from: Vector2 = heart_center()
	var steps: int = ceili(from.distance_to(at) / SIGHT_STEP)
	for i: int in range(1, steps):
		if map_info.world.is_ground(map_info.cell_at(from.lerp(at, float(i) / float(steps)))):
			return false
	return true


## The chunk it would hurl now (HURLED's first whole one), or -1.
func _to_hurl() -> int:
	for i: int in HURLED:
		if whole[i]:
			return i
	return -1


# ------------------------------------------------------------------ struck

## A blow (Shaped): it meets the first part in its way from `from` (part_met), and wakes it. It
## always takes the blow itself.
func blow(from: Vector2, dir: Vector2, _damage: int, empowered: bool) -> bool:
	if not done():
		_wake()
		_strike(part_met(from), dir, empowered)
	return true


## An arrow met it at `at`: as a plain blow from there (part_met).
func arrow_hit(at: Vector2, dir: Vector2) -> void:
	if not done():
		_wake()
		_strike(part_met(at), dir, false)


## A blow heading `dir` on `k` (a chunk, or AT_HEART): a bare heart is wounded by anything; a chunk
## shatters to an `empowered` blow and is glanced off by a plain one.
func _strike(k: int, dir: Vector2, empowered: bool) -> void:
	if k == AT_HEART:
		_wound(dir)
	elif empowered:
		shatter(k, dir)
	else:
		_glance(k, dir)


## A plain blow glanced off chunk `i`: grit, and it shows.
func _glance(i: int, dir: Vector2) -> void:
	struck_t[i] = t
	RisoFx.burst(&"hit", part_center(i) - dir.normalized() * PART_SIZE[i].y, -dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(3.0, 0.06)


## Chunk `i` shatters (an empowered blow heading `dir`).
func shatter(i: int, dir: Vector2) -> void:
	if not whole[i]:
		return
	if i in COVERS:
		# The plate that goes is the ring's last whole one.
		var left: int = COVERS.filter(func(k: int) -> bool: return whole[k]).size()
		broke_at[i] = RisoWard.plate_angle(left - 1, COVERS.size(), _ward_spin())
	whole[i] = false
	shattered_t[i] = t
	var inks: Array[int] = [RisoPrint.PINK if i in COVERS else RisoPrint.BLUE, RisoPrint.NIGHT]
	RisoFx.burst(&"hit", part_center(i), dir, inks)
	Wound.shake(10.0, 0.2)


## Its bare heart is wounded (heading `dir`): one crack, and with the last it dies.
func _wound(dir: Vector2) -> void:
	wound.hp -= 1
	heart_t = t
	RisoFx.burst(&"hit", heart_center(), dir, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(8.0, 0.16)
	Wound.hit_stop(Wound.KILL_STOP if wound.hp <= 0 else Wound.HIT_STOP)
	if wound.hp <= 0:
		die()


## A parried slam: SHARDS lode shards fly out of it, spread from one side to the other, to fall and lie
## where they land (LodeShard).
func shed_shards() -> void:
	if map_info == null or done():
		return
	for i: int in range(SHARDS):
		var side: float = lerpf(-1.0, 1.0, float(i) / float(maxi(SHARDS - 1, 1)))
		var shard: LodeShard = LodeShard.new()
		shard.golem = self
		shard.cell = cell
		shard.velocity = Vector2(SHARD_KICK.x * side, SHARD_KICK.y)
		map_info.map_elements.add_child(shard)
		shard.global_position = heart_center()
		shards.append(shard)
	loose_t = 0.0
	RisoFx.burst(&"gain", heart_center(), Vector2.UP, [RisoPrint.ACCENT, RisoPrint.BLUE])


## Its heart's last wound: it falls apart.
func die() -> void:
	if done():
		return
	dying = true
	dead_t = 0.0
	remove_from_group(&"hex_target")
	Wound.shake(14.0, 0.4)
	RisoFx.burst(&"gain", heart_center(), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])


## Slain at once (the F7 panel's Slay boss, MapInfo.slay_boss).
func slay() -> void:
	if slain:
		return
	wound.hp = 0
	_slain()


## It is slain: its relic waits where it stood, and it is gone, all of it lying loose with it.
func _slain() -> void:
	slain = true
	for loose: Node2D in _loose():
		loose.queue_free()
	shards.clear()
	stones.clear()
	called.clear()
	if map_info != null:
		map_info.boss_slain(boss, relic_at())
	queue_free()


## Where its relic waits: in the middle of the cell it stands in, or, that over a hole it was
## stepping over, the nearest beside it with floor under it.
func relic_at() -> Vector2:
	if map_info == null:
		return global_position
	var at: Vector2i = map_info.cell_at(global_position + Vector2(0.0, -cell * 0.5))
	for d: int in range(STEP_OVER + 2):
		for side: int in [-d, d]:
			var c: Vector2i = at + Vector2i(side, 0)
			if map_info.world.is_ground(c + Vector2i.DOWN) and not map_info.world.is_ground(c):
				return map_info.cell_position(c)
	return map_info.cell_position(at)


# ------------------------------------------------------------------ what it does

func _physics_process(delta: float) -> void:
	_let_go()
	if dying:
		dead_t += delta
		if dead_t >= DIE_TIME and not slain:
			_slain()
		sync_fists()
		return
	if map_info == null or floors.is_empty() or slain:
		return
	# A harder preset runs it faster (Difficulty.haste).
	delta *= Difficulty.haste()
	var player: Player = map_info.player if map_info.player != null and is_instance_valid(map_info.player) else null
	var stun_now: bool = stunned()
	if stun_now and not _was_stunned and state == State.SLAM:
		shed_shards()
	if _was_stunned and not stun_now:
		state = State.REST
		timer = REST
	_was_stunned = stun_now
	if not _loose().is_empty() and not stun_now and state != State.RECALL:
		loose_t += delta
	throw_t += delta
	if not stun_now:
		match state:
			State.SLEEP:
				if player != null and _in_hall(player):
					_wake()
					if (player.global_position.x - global_position.x) * float(face) < -TURN_SLACK:
						_turn_round()
			State.HUNT:
				_hunt(delta, player)
			State.REST:
				timer -= delta
				if timer <= 0.0:
					state = State.HUNT
			State.SLAM_WARN:
				timer -= delta
				if timer <= 0.0:
					state = State.SLAM
					timer = SLAM_HOLD
					var at: Vector2 = global_position + Vector2(FIST_AT.x * float(face), 0.0)
					GolemShock.send(self, at, floor_y(storey()))
					Wound.shake(12.0, 0.2)
					squash_v -= SLAM_KICK
					RisoFx.burst(&"rubble", at, Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
			State.SLAM:
				timer -= delta
				if timer <= 0.0:
					state = State.REST
					timer = SLAM_REST
			State.HURL_WARN:
				timer -= delta
				if timer <= 0.0:
					_hurl(player)
			State.LEAP_WARN:
				timer -= delta
				if timer <= 0.0:
					state = State.LEAP
					timer = LEAP_TIME
			State.LEAP:
				_leap(delta)
			State.RECALL_WARN:
				timer -= delta
				if timer <= 0.0:
					state = State.RECALL
			State.RECALL:
				_recall(delta)
	if state != State.HUNT and state != State.LEAP:
		_walk_toward(global_position.x, reach_along(storey(), global_position.x), delta)
	turn_t += delta
	_animate(delta)
	_build_pose()
	sync_fists()


## Its fists hurt only while they are down in a slam, and not while it is stunned or dying; each
## touch is where its fist is drawn.
func sync_fists() -> void:
	var on: bool = state == State.SLAM and not stunned() and not done()
	for k: int in range(2):
		var box: HitBox = far_fist if k == 0 else fists
		box.position = fist_at(k) - global_position
		if box.collision != null and box.collision.disabled == on:
			box.collision.set_deferred("disabled", not on)


## Woken (the wizard in its hall, or struck): it hunts.
func _wake() -> void:
	if state == State.SLEEP:
		state = State.HUNT
		timer = 0.0


## Everything of it lying loose or flying: its shards and its hurled chunks.
func _loose() -> Array[Node2D]:
	var out: Array[Node2D] = []
	out.append_array(shards)
	out.append_array(stones)
	return out


## Shards taken and anything freed are let go (a typed filter cannot hold a freed one).
func _let_go() -> void:
	for i: int in range(shards.size() - 1, -1, -1):
		if not is_instance_valid(shards[i]) or shards[i].is_queued_for_deletion():
			shards.remove_at(i)
	for i: int in range(stones.size() - 1, -1, -1):
		if not is_instance_valid(stones[i]) or stones[i].is_queued_for_deletion():
			stones.remove_at(i)
	for i: int in range(called.size() - 1, -1, -1):
		if not is_instance_valid(called[i]) or called[i].is_queued_for_deletion():
			called.remove_at(i)
	if _loose().is_empty():
		loose_t = 0.0


## Walk toward `to` (px across) along its floor, within `span` (reach_along): gathering speed toward
## WALK, slowing into its stop, and stopping where it arrives or at the span's end.
func _walk_toward(to: float, span: Vector2, delta: float) -> void:
	var dist: float = to - global_position.x
	var want: float = 0.0
	if absf(dist) > 0.5:
		want = signf(dist) * clampf(absf(dist) * WALK_EASE, MIN_WALK, WALK)
	vel = move_toward(vel, want, WALK_ACCEL * delta)
	var next: float = global_position.x + vel * delta
	if absf(dist) > 0.5 and signf(to - next) != signf(dist):
		next = to
		vel = 0.0
	var held: float = clampf(next, span.x, span.y)
	if held != next:
		vel = 0.0
	global_position.x = held


## After the wizard: turning to face them once they are well behind it, it calls back what lies loose,
## slams them near, hurls at them far off, walks after them along its floor, or, them on another
## storey, goes to the gap between and leaps.
func _hunt(delta: float, player: Player) -> void:
	hurl_wait = maxf(0.0, hurl_wait - delta)
	var mine: int = storey()
	var span: Vector2 = reach_along(mine, global_position.x)
	if player == null or not _in_hall(player):
		apart_t = 0.0
		_walk_toward(global_position.x, span, delta)
		return
	var at: Vector2 = player.global_position
	if (at.x - global_position.x) * float(face) < -TURN_SLACK:
		_turn_round()
	if loose_t >= RECALL_DELAY:
		_call_back(at)
		return
	var theirs: int = storey_of(at)
	var far: bool = absf(at.x - global_position.x) >= HURL_MIN or theirs != mine
	if hurl_wait <= 0.0 and far and _to_hurl() >= 0 and sees(at):
		hurling = _to_hurl()
		state = State.HURL_WARN
		timer = HURL_WARN
		return
	if theirs == mine:
		apart_t = 0.0
		var ahead: float = (at.x - global_position.x) * float(face)
		if absf(at.x - global_position.x) <= SLAM_RANGE and ahead > -TURN_SLACK and not turning():
			state = State.SLAM_WARN
			timer = SLAM_WARN
			return
		_walk_toward(clampf(at.x, span.x, span.y), span, delta)
		return
	apart_t += delta
	var gap: Rect2i = gaps[mine - 1] if theirs < mine else gaps[mine]
	var to: float = clampf(_gap_mid(gap), span.x, span.y)
	_walk_toward(to, span, delta)
	if absf(global_position.x - to) < 4.0 and apart_t >= LEAP_AFTER:
		_plan_leap(theirs < mine, gap, at)


## Crouch to leap up through `gap` (`up`) to the gallery over it, beside the gap on the wizard's
## side, or down it to the floor under it; the spot marked (LEAP_WARN).
func _plan_leap(up: bool, gap: Rect2i, at: Vector2) -> void:
	var mine: int = storey()
	var to_storey: int = mine - 1 if up else mine + 1
	var x: float = _gap_mid(gap)
	if up:
		x = _gap_left(gap) - FOOT - LEAP_CLEAR if at.x < _gap_mid(gap) else _gap_right(gap) + FOOT + LEAP_CLEAR
	var span: Vector2 = reach_along(to_storey, x)
	leap_from = global_position
	leap_to = Vector2(clampf(x, span.x, span.y), floor_y(to_storey))
	leap_down = not up
	state = State.LEAP_WARN
	timer = LEAP_WARN
	apart_t = 0.0
	vel = 0.0


## In the air, along an arc rising out of where it leapt from and dropping onto where it lands, over
## the higher floor by LEAP_OVER; landing, a shockwave both ways.
func _leap(delta: float) -> void:
	timer -= delta
	var u: float = clampf(1.0 - timer / LEAP_TIME, 0.0, 1.0)
	var apex: float = minf(leap_from.y, leap_to.y) - LEAP_OVER
	global_position = leap_from.bezier_interpolate(Vector2(leap_from.x, apex), Vector2(leap_to.x, apex), leap_to, u)
	if u >= 1.0:
		global_position = leap_to
		GolemShock.send(self, leap_to, leap_to.y)
		Wound.shake(14.0, 0.25)
		squash_v -= LAND_KICK
		for i: int in [BACK_FOOT, FRONT_FOOT]:
			RisoFx.burst(&"lurch", _world(Vector2(limb[i].x, 0.0)), Vector2(-float(face) if i == BACK_FOOT else float(face), 0.0), [RisoPrint.BLUE])
		state = State.REST
		timer = REST


## Hurl the chunk it holds up at where the wizard is now: gone from it while it flies and lies
## (thrown), a GolemStone.
func _hurl(player: Player) -> void:
	var i: int = hurling
	hurling = -1
	state = State.REST
	timer = REST
	hurl_wait = HURL_EVERY
	if i < 0 or not whole[i] or player == null:
		return
	var from: Vector2 = part_center(i)
	whole[i] = false
	thrown[i] = true
	throw_t = 0.0
	var stone: GolemStone = GolemStone.new()
	stone.golem = self
	stone.part = i
	stone.cell = cell
	stone.velocity = GolemStone.lob(from, player.global_position, HURL_FLIGHT)
	map_info.map_elements.add_child(stone)
	stone.global_position = from
	stones.append(stone)
	Wound.shake(6.0, 0.12)


## Call back all that lies loose: each is given its way home, through `at` (where the wizard is) to
## where it belongs, and the warning starts (RECALL_WARN).
func _call_back(at: Vector2) -> void:
	called = _loose()
	var regrow: Array[int] = []
	for i: int in COVERS:
		if not whole[i] and not thrown[i]:
			regrow.append(i)
	for i: int in range(PART_SIZE.size()):
		if not whole[i] and not thrown[i] and not i in regrow:
			regrow.append(i)
	for loose: Node2D in called:
		var part: int = -1
		if loose is GolemStone:
			part = (loose as GolemStone).part
		elif not regrow.is_empty():
			part = int(regrow.pop_front())
		loose.set_meta(&"part", part)
		var home: Vector2 = part_center(part) if part >= 0 else heart_center()
		loose.set_meta(&"way", PackedVector2Array([loose.global_position, at, home]))
		if loose is LodeShard:
			(loose as LodeShard).called = true
		elif loose is GolemStone:
			(loose as GolemStone).called = true
	state = State.RECALL_WARN
	timer = RECALL_WARN
	loose_t = 0.0


## What it called flies home along its way, hurting on the way; home, a hurled chunk is whole again
## and a shard regrows the chunk it was given. All home, it rests.
func _recall(delta: float) -> void:
	for k: int in range(called.size() - 1, -1, -1):
		if not is_instance_valid(called[k]) or called[k].is_queued_for_deletion():
			continue
		var loose: Node2D = called[k]
		var way: PackedVector2Array = loose.get_meta(&"way")
		var part: int = int(loose.get_meta(&"part"))
		# Home moves with its pose; the rest of the way is as it was set.
		way[2] = part_center(part) if part >= 0 else heart_center()
		var leg: int = 1 if loose.global_position.distance_to(way[1]) > 1.0 and not loose.has_meta(&"passed") else 2
		var next: Vector2 = loose.global_position.move_toward(way[leg], RECALL_SPEED * delta)
		loose.global_position = next
		if leg == 1 and next.distance_to(way[1]) <= 1.0:
			loose.set_meta(&"passed", true)
		if leg == 2 and next.distance_to(way[2]) <= 1.0:
			_home(loose, part)
	_let_go()
	if called.is_empty():
		state = State.REST
		timer = REST


## `loose` is home: its chunk `part` whole again (none for a shard with nothing to regrow), and it is
## gone.
func _home(loose: Node2D, part: int) -> void:
	if part >= 0:
		whole[part] = true
		thrown[part] = false
	RisoFx.burst(&"hit", loose.global_position, Vector2.ZERO, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(4.0, 0.08)
	called.erase(loose)
	loose.queue_free()


# ------------------------------------------------------------------ how it moves

## A spring's step: `x` pulled toward `want` with `pull` (stiffness, damping) moving at `v`, over
## `delta` seconds; the new place and speed.
static func _spring(x: float, v: float, want: float, pull: Vector2, delta: float) -> Vector2:
	var nv: float = v + ((want - x) * pull.x - v * pull.y) * delta
	return Vector2(x + nv * delta, nv)


## The same spring for a point: its new place and speed, as [place, speed].
static func _spring2(x: Vector2, v: Vector2, want: Vector2, pull: Vector2, delta: float) -> Array[Vector2]:
	var nv: Vector2 = v + ((want - x) * pull.x - v * pull.y) * delta
	var out: Array[Vector2] = [x + nv * delta, nv]
	return out


## How far through the warning it is (0 to 1), eased out: quick at first, slowing to a hold.
func _warned(span: float) -> float:
	var u: float = clampf(1.0 - timer / span, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


## Its body's shift (x, y px) and lean (z, radians) for what it is doing, before its springs.
func _body_aim() -> Vector3:
	return SLUMPED.lerp(_awake_aim(), rise)


## Its body's shift and lean awake (see _body_aim).
func _awake_aim() -> Vector3:
	if stunned():
		return SAGGED
	match state:
		State.SLAM_WARN:
			return REAR * _warned(SLAM_WARN)
		State.SLAM:
			return STRIKE
		State.HURL_WARN:
			return WIND * _warned(HURL_WARN)
		State.LEAP_WARN:
			return HUNCH
		State.LEAP:
			return Vector3(0.0, 0.0, lerpf(LEAP_LEAN.x, LEAP_LEAN.y, clampf(1.0 - timer / LEAP_TIME, 0.0, 1.0)))
	if throw_t < THROW_FOLLOW * 2.0:
		return THROW * (1.0 - throw_t / (THROW_FOLLOW * 2.0))
	var bob: float = BOB * sin(PI * clampf(step_t[0] / STEP_TIME[0], 0.0, 1.0)) if stepping[0] >= 0 else 0.0
	return Vector3(0.0, -bob, WALK_LEAN * clampf(vel * float(face) / WALK, -1.0, 1.0))


## How much of its height it stands to for what it is doing, before its spring.
func _height_aim() -> float:
	return lerpf(SLUMP, _awake_height(), rise)


## How much of its height it stands to awake (see _height_aim).
func _awake_height() -> float:
	if stunned():
		return SAGGED_HEIGHT
	match state:
		State.SLAM_WARN:
			return lerpf(1.0, REARED, _warned(SLAM_WARN))
		State.SLAM:
			return SLAMMED
		State.LEAP_WARN:
			return CROUCH
	return 1.0


## Whether foot or fist `i` wants to be set down on the floor: its feet always but in a leap;
## its fists but while it raises or holds them up, slams, follows through a throw or leaps.
func _wants_down(i: int) -> bool:
	if state == State.LEAP:
		return false
	if i < BACK_FIST or stunned():
		return true
	if state in [State.SLAM_WARN, State.SLAM, State.HURL_WARN]:
		return false
	return throw_t >= THROW_FOLLOW + THROW_RETURN


## Where foot or fist `i` wants to be (as it faces right, from its feet): set down, where it was set
## (lifted as it steps); otherwise where what it is doing puts it.
func _limb_aim(i: int) -> Vector2:
	if planted[i]:
		return Vector2((plant_x[i] - global_position.x) * float(face), STANCE[i].y - lift[i])
	var k: int = i - BACK_FIST
	var side: float = -1.0 if k == 0 else 1.0
	if state == State.LEAP:
		if i < BACK_FIST:
			return TUCK[i]
		var a: float = lerpf(LEAP_SWING.x, LEAP_SWING.y, clampf(1.0 - timer / LEAP_TIME, 0.0, 1.0))
		return _reach(k, Vector2(side * cos(a), -sin(a)), LEAP_REACH)
	if i < BACK_FIST:
		return STANCE[i]
	match state:
		State.SLAM_WARN:
			var shake: Vector2 = Vector2.ZERO
			if timer < SLAM_WARN * TREMBLE_SHARE:
				shake = Vector2(sin(t * 61.0 + float(k)), cos(t * 53.0 + float(k) * 2.0)) * TREMBLE
			return _reach(k, Vector2.UP.rotated(RAISE_TURN[k]), RAISE_REACH) + shake
		State.SLAM:
			return Vector2(FIST_AT.x if k == 1 else -SLAM_BEHIND, STANCE[i].y)
		State.HURL_WARN:
			if hurling >= 0:
				# Its fists go straight up to where it will hold the magnet (not across its body to tear it
				# off), and the magnet rises up between them, called by its pull.
				return _hold_at() + Vector2(side * GRIP.x, GRIP.y)
	if throw_t < THROW_FOLLOW:
		return _reach(k, Vector2.from_angle(THROW_TURN[k]), THROW_REACH)
	return STANCE[i]


## Where it holds the magnet up to hurl (as it faces right): over its head, drawn back toward the end
## of the warning as it winds up.
func _hold_at() -> Vector2:
	var wind: float = smoothstep(WIND_FROM, 1.0, clampf(1.0 - timer / HURL_WARN, 0.0, 1.0))
	return top_at + HOLD_OVER + Vector2(-WIND_BACK * wind, 0.0)


## Where fist `k` (far 0, near 1) is when its arm reaches `share` of its whole length from its
## shoulder along `dir` (as it faces right, from its feet).
func _reach(k: int, dir: Vector2, share: float) -> Vector2:
	var bones: float = (BACK_UPPER_BONE + BACK_FORE_BONE if k == 0 else FRONT_UPPER_BONE + FRONT_FORE_BONE) + PALM
	return shoulder_at[k] + dir.normalized() * bones * share


## A step of its pose: rising as it wakes; its body's shift, lean and height springing toward its
## pose; its feet and fists set down and lifted as it wants, stepping as it walks, and springing to
## where they want to be.
func _animate(delta: float) -> void:
	rise = move_toward(rise, 0.0 if state == State.SLEEP else 1.0, delta / WAKE_TIME)
	var aim: Vector3 = _body_aim()
	var sx: Array[Vector2] = _spring2(shift, shift_v, Vector2(aim.x, aim.y), POSE_PULL, delta)
	shift = sx[0]
	shift_v = sx[1]
	var ln: Vector2 = _spring(lean, lean_v, aim.z, POSE_PULL, delta)
	lean = ln.x
	lean_v = ln.y
	var sq: Vector2 = _spring(squash, squash_v, _height_aim(), POSE_PULL, delta)
	squash = sq.x
	squash_v = sq.y
	for i: int in range(STANCE.size()):
		var down: bool = _wants_down(i)
		if down and not planted[i]:
			planted[i] = true
			plant_x[i] = global_position.x + limb[i].x * _across()
			lift[i] = 0.0
		elif not down and planted[i]:
			planted[i] = false
			lift[i] = 0.0
			for g: int in range(GAITS.size()):
				if stepping[g] == i:
					stepping[g] = -1
	_gait(delta)
	for i: int in range(STANCE.size()):
		var want: Vector2 = _limb_aim(i)
		var pull: Vector2 = LIMB_PULL
		if planted[i]:
			pull = PLANT_PULL
		elif i >= BACK_FIST and (state == State.SLAM or throw_t < THROW_FOLLOW * THROW_WHIP):
			pull = STRIKE_PULL
		if i >= BACK_FIST and not planted[i] and not pieces.is_empty():
			_swing(i, want, pull, delta)
		else:
			var lv: Array[Vector2] = _spring2(limb[i], limb_v[i], want, pull, delta)
			limb[i] = lv[0]
			limb_v[i] = lv[1]
		if planted[i] and limb[i].distance_to(want) < PLANT_HOLD:
			limb[i] = want
			limb_v[i] = Vector2.ZERO


## Swing fist `i` (off the floor) toward `want` on `pull`, round its shoulder: its arm turning and
## reaching on springs of their own, so the fist sweeps out in an arc with the arm held long, rather
## than cutting in across its body; the short way round, unless that would sweep it across its body,
## when it goes the long way, round over its head or behind; never lower than it rests on the floor.
func _swing(i: int, want: Vector2, pull: Vector2, delta: float) -> void:
	var sh: Vector2 = shoulder_at[i - BACK_FIST]
	var now: Vector2 = limb[i] - sh
	var to: Vector2 = want - sh
	var a: float = now.angle()
	var r: float = maxf(now.length(), 1.0)
	var away: float = angle_difference(a, to.angle())
	var body: float = angle_difference(a, (heart_at - sh).angle())
	if signf(body) == signf(away) and absf(body) < absf(away):
		away -= signf(away) * TAU
	var turn: Vector2 = _spring(a, now.cross(limb_v[i]) / (r * r), a + away, pull, delta)
	var reach: Vector2 = _spring(r, now.dot(limb_v[i]) / r, to.length(), pull, delta)
	var was: Vector2 = limb[i]
	limb[i] = sh + Vector2.from_angle(turn.x) * reach.x
	limb[i].y = minf(limb[i].y, STANCE[i].y)
	limb_v[i] = (limb[i] - was) / maxf(delta, 0.0001)


## Its walk on all fours: its fists step in turn, and its feet shuffle in turn on their own.
func _gait(delta: float) -> void:
	for g: int in range(GAITS.size()):
		_step(g, delta)


## A step of gait `g` (GAITS' place): a step under way goes on (swung from where it was set to where it
## goes, lifted in an arc) and lands, a fist with dust and a shake; otherwise, while it is up and about,
## the next of the two that has fallen behind its stance (or, standing still, strayed from it) steps,
## as far ahead of its stance as it will fall behind before its next step.
func _step(g: int, delta: float) -> void:
	var gait: Vector2i = GAITS[g]
	if stepping[g] >= 0:
		var i: int = stepping[g]
		step_t[g] += delta
		var u: float = clampf(step_t[g] / STEP_TIME[g], 0.0, 1.0)
		if planted[i]:
			plant_x[i] = lerpf(step_from[g], step_to[g], smoothstep(0.0, 1.0, u))
			lift[i] = sin(PI * u) * STEP_LIFT[g]
		if u >= 1.0:
			lift[i] = 0.0
			if planted[i] and i >= BACK_FIST:
				RisoFx.burst(&"lurch", Vector2(plant_x[i], global_position.y), Vector2(-signf(vel) if vel != 0.0 else -float(face), 0.0), [RisoPrint.BLUE])
				Wound.shake(STEP_SHAKE, 0.06)
				squash_v -= STEP_KICK
			stepping[g] = -1
		return
	if not state in [State.HUNT, State.REST, State.RECALL_WARN, State.RECALL]:
		return
	var walking: bool = absf(vel) > 8.0
	var forward: float = signf(vel) * float(face)
	for n: int in range(2):
		var k: int = (next_step[g] + n) % 2
		var i: int = gait.x if k == 0 else gait.y
		if not planted[i]:
			continue
		var off: float = (plant_x[i] - global_position.x) * float(face) - STANCE[i].x
		var behind: float = -off * forward if walking else absf(off)
		if behind > (STEP_REACH[g] if walking else STEP_SETTLE):
			var lands: float = global_position.x + float(face) * STANCE[i].x + vel * STEP_TIME[g] * STEP_LEAD
			step_from[g] = plant_x[i]
			step_to[g] = clampf(lands, hall_left + cell * 0.25, hall_right - cell * 0.25)
			stepping[g] = i
			step_t[g] = 0.0
			next_step[g] = (k + 1) % 2
			return


# ------------------------------------------------------------------ its pose

## How wide (px) its body is at `s` px along it from its middle: rounded toward its top (s below 0),
## tapering to a point toward its foot.
static func _width_at(s: float) -> float:
	var taper: float = BODY_ROUND if s < 0.0 else RisoShapes.SPINDLE_TAPER
	return BODY_WID * pow(maxf(0.0, 1.0 - (s / BODY_LEN) * (s / BODY_LEN)), taper)


## Its body's outline round `c`, lying `ang` (its point that way), `scale` times its size: a lodestone
## rounded at one end and tapering to a point at the other (see _width_at). The lodestones share it
## (LodestoneArt).
static func body_shape(c: Vector2, ang: float, scale: float = 1.0) -> PackedVector2Array:
	var n: int = 18
	var top: PackedVector2Array = PackedVector2Array()
	for k: int in range(n + 1):
		var s: float = -BODY_LEN * cos(PI * float(k) / float(n))
		top.append(Vector2(s, -_width_at(s)))
	var out: PackedVector2Array = top.duplicate()
	for k: int in range(n - 1, 0, -1):
		out.append(Vector2(top[k].x, -top[k].y))
	return Transform2D(ang, Vector2(scale, scale), 0.0, c) * out


## Where its body's edge is at `s` px along it, on its front (`side` 1) or its back (-1), its body's
## middle at `c`, running along `ax` with `nm` its front.
static func _edge(c: Vector2, ax: Vector2, nm: Vector2, s: float, side: float) -> Vector2:
	return c + ax * s + nm * side * _width_at(s)


## The elbow (or knee) of a limb from `from` reaching for `to` with bones `a` and `b`: bent outward
## (`out` 1 toward its front, -1 toward its back).
static func _bend(from: Vector2, to: Vector2, a: float, b: float, out: float) -> Vector2:
	var d: Vector2 = to - from
	var dir: Vector2 = d.normalized() if d.length() > 0.001 else Vector2.DOWN
	var l: float = clampf(d.length(), absf(a - b) + 0.01, a + b - 0.01)
	var turn: float = acos(clampf((a * a + l * l - b * b) / (2.0 * a * l), -1.0, 1.0))
	var e1: Vector2 = from + dir.rotated(turn) * a
	var e2: Vector2 = from + dir.rotated(-turn) * a
	return e1 if (e1.x - e2.x) * out >= 0.0 else e2


## Add a magnet round `c` lying `ang`, `size` (half long, half wide), chunk `part` (or -1), to its pose.
func _add(c: Vector2, ang: float, size: Vector2, part: int) -> Piece:
	var p: Piece = Piece.new()
	p.c = c
	p.ang = ang
	p.hl = size.x
	p.hw = size.y
	p.part = part
	if part >= 0:
		chunk_piece[part] = pieces.size()
		p.guard = part in COVERS
	pieces.append(p)
	return p


## Add the magnet from joint `a` to joint `b`, `wid` half wide, its tips short of the joints by GAP.
func _link(a: Vector2, b: Vector2, wid: float, part: int) -> Piece:
	return _add((a + b) * 0.5, (b - a).angle(), Vector2(maxf(a.distance_to(b) * 0.5 - GAP, 1.0), wid), part)


## Add an arm from `shoulder` reaching its fist (the palm's end) to `fist`, with bones `upper` and
## `fore`, chunks `upper_part` and `fore_part`, bent outward `out`; its palm and three knuckles at its
## end; and note where its fist ends (fist_end's place `k`).
func _arm(shoulder: Vector2, fist: Vector2, upper: float, fore: float, upper_part: int, fore_part: int, out: float, k: int) -> void:
	# The palm points down, or out along the arm once the fist is raised over the shoulder.
	var raised: float = clampf((shoulder.y - fist.y) / 120.0, 0.0, 1.0)
	var palm_dir: Vector2 = Vector2.DOWN.lerp((fist - shoulder).normalized(), raised).normalized()
	var wrist_aim: Vector2 = fist - palm_dir * PALM
	var elbow: Vector2 = _bend(shoulder, wrist_aim, upper, fore, out)
	var wrist: Vector2 = elbow + (wrist_aim - elbow).normalized() * fore
	_link(shoulder, elbow, UPPER_WID, upper_part)
	_link(elbow, wrist, FORE_WID, fore_part)
	var end: Vector2 = wrist + palm_dir * PALM
	_link(wrist, end, PALM_WID, -1).hand = true
	var base: Vector2 = end + palm_dir * KNUCKLE_DOWN
	var across: Vector2 = palm_dir.orthogonal()
	for j: int in [-1, 0, 1]:
		_add(base + across * float(j) * KNUCKLE_APART, palm_dir.angle() - PI * 0.5 + float(j) * KNUCKLE_FAN, KNUCKLE_SIZE, -1).hand = true
	fist_end[k] = end


## Add a leg from `hip` to foot `i` (its contact), its knee bent `out` (its far leg's back, its near
## leg's forward, so the two never cross); the foot stands where its contact is, whether or not the
## leg reaches it, and tips its toe up as it lifts.
func _leg(hip: Vector2, i: int, out: float) -> void:
	var foot: Vector2 = limb[i]
	var ankle_aim: Vector2 = foot + ANKLE
	var knee: Vector2 = _bend(hip, ankle_aim, THIGH, SHIN, out)
	var ankle: Vector2 = knee + (ankle_aim - knee).normalized() * SHIN
	_link(hip, knee, THIGH_WID, -1)
	_link(knee, ankle, SHIN_WID, -1)
	_add(foot, -0.25 * lift[i] / STEP_LIFT[1], FOOT_SIZE, -1)


## Add a cap standing out from its body `along` px from its middle on `side`, chunk `part`.
func _cap(c: Vector2, ax: Vector2, nm: Vector2, along: float, side: float, part: int) -> void:
	var dir: Vector2 = (nm * side).rotated(-side * CAP_TURN)
	_add(_edge(c, ax, nm, along, side) + dir * PART_SIZE[part].x * (1.0 - 2.0 * SINK), dir.angle(), PART_SIZE[part], part)


## Where each plate of its ward is: the whole ones take the ring's first places (as RisoWard prints
## them), the broken ones after; each is met as the chord across it, laid out as a piece of its pose
## (not printed as a magnet).
func _ward() -> void:
	var n: int = COVERS.size()
	var half: float = TAU / float(n) * RisoWard.PLATE_SHARE * 0.5
	var mid_r: float = WARD_R - WARD_THICK * 0.5
	var place: int = 0
	var order: Array[int] = []
	for i: int in COVERS:
		if whole[i]:
			order.append(i)
	for i: int in COVERS:
		if not whole[i]:
			order.append(i)
	for i: int in order:
		var a: float = RisoWard.plate_angle(place, n, _ward_spin())
		place += 1
		var d0: Vector2 = Vector2.from_angle(a - half)
		var d1: Vector2 = Vector2.from_angle(a + half)
		var p0: Vector2 = heart_at + Vector2(d0.x * _across(), d0.y) * mid_r
		var p1: Vector2 = heart_at + Vector2(d1.x * _across(), d1.y) * mid_r
		_add((p0 + p1) * 0.5, (p1 - p0).angle(), Vector2(p0.distance_to(p1) * 0.5, WARD_THICK * 0.5 + WARD_REACH), i)


## How far its ward has turned.
func _ward_spin() -> float:
	return t * WARD_SPIN


## Lay out its magnets for this step, back to front: its far leg, its caps and fins (standing out of
## its body, their roots hidden behind its edge), the bar its legs hang from, its body (its heart, ward
## and eyes over it), its far arm, its near leg and its near arm (both arms in front of its body). A chunk held up to hurl is where it is held; stunned, everything
## but its body and its ward sags out from it and wobbles.
func _build_pose() -> void:
	pieces.clear()
	chunk_piece.clear()
	chunk_piece.resize(PART_SIZE.size())
	chunk_piece.fill(-1)
	var c: Vector2 = Vector2(BODY_AT.x, BODY_AT.y * squash) + shift + Vector2(0.0, sin(t * BREATH_RATE) * BREATH * rise)
	var ang: float = PI * 0.5 + LEAN + lean
	var ax: Vector2 = Vector2.from_angle(ang)
	var nm: Vector2 = Vector2(ax.y, -ax.x)
	top_at = c - ax * BODY_LEN
	heart_at = c + ax * HEART_ALONG
	eyes_at = c + ax * EYES_ALONG + nm * 3.0
	eyes_turn = ang - PI * 0.5
	var shoulder_back: Vector2 = _edge(c, ax, nm, SHOULDER_ALONG.x, -1.0) - nm * SHOULDER_OUT
	var shoulder_front: Vector2 = _edge(c, ax, nm, SHOULDER_ALONG.y, 1.0) + nm * SHOULDER_OUT
	var pelvis: Vector2 = c + ax * BODY_LEN + PELVIS_BELOW
	var hip_dir: Vector2 = Vector2.from_angle(PELVIS_TURN) * (PELVIS_SIZE.x + GAP)
	shoulder_at[0] = shoulder_back
	shoulder_at[1] = shoulder_front
	_leg(pelvis - hip_dir, BACK_FOOT, 1.0)
	_cap(c, ax, nm, CAP_ALONG.x, -1.0, BACK_CAP)
	_cap(c, ax, nm, CAP_ALONG.y, 1.0, FRONT_CAP)
	for k: int in range(FIN_ALONG.size()):
		var out: Vector2 = -nm.rotated(-FIN_TURN)
		var size: Vector2 = PART_SIZE[FIN_TOP + k]
		_add(_edge(c, ax, nm, FIN_ALONG[k], -1.0) + out * size.x * (1.0 - 2.0 * SINK), out.angle(), size, FIN_TOP + k)
	_add(pelvis, PELVIS_TURN, PELVIS_SIZE, -1)
	_add(c, ang, Vector2(BODY_LEN, BODY_WID), -1).body = true
	_ward()
	_arm(shoulder_back, limb[BACK_FIST], BACK_UPPER_BONE, BACK_FORE_BONE, BACK_UPPER, BACK_FORE, -1.0, 0)
	_leg(pelvis + hip_dir, FRONT_FOOT, 1.0)
	_arm(shoulder_front, limb[FRONT_FIST], FRONT_UPPER_BONE, FRONT_FORE_BONE, FRONT_UPPER, FRONT_FORE, 1.0, 1)
	if hurling >= 0 and state == State.HURL_WARN:
		var held: Piece = pieces[chunk_piece[hurling]]
		var e: float = _warned(HURL_WARN)
		held.c = held.c.lerp(_hold_at(), e)
		held.ang = lerp_angle(held.ang, 0.0, e)
	if stunned():
		var sag: float = sqrt(stunner.fraction())
		for k: int in range(pieces.size()):
			var p: Piece = pieces[k]
			if p.body or p.guard:
				continue
			p.c += (p.c - c).normalized() * LOOSE * sag + Vector2(sin(t * 7.0 + float(k)), cos(t * 5.0 + float(k) * 2.0)) * 3.0


# ------------------------------------------------------------------ the print

## Its heart's glow behind it all; its magnets back to front, each iron-blue with pale poles, a chunk
## paler a moment when a blow glances off it; its ward round its heart; over its body its
## heart (accent on paper with a crescent cut from it, a dark rim round it, cracked in night as it is
## wounded) and its eyes (slits of paper in a dark band); a shattered chunk's bits flying off and
## fading. Asleep it is slumped and dim, its eyes shut; stunned, its pieces sag loose and stars circle
## its top. Its warnings in pink: its palms and knuckles as it raises its fists, and its eyes; the
## magnet it holds up to hurl; the spot it will land a leap on; and the ways home of what it calls
## back. Dying, its magnets fall to the floor in a heap and it all fades.
func _process(delta: float) -> void:
	t += delta
	if ink == null:
		return
	if pieces.is_empty():
		_build_pose()
	ink.global_position = Vector2.ZERO
	ink.begin()
	var u: float = clampf(dead_t / DIE_TIME, 0.0, 1.0) if dying else 0.0
	var fade: float = 1.0 - u
	var breath: float = 0.5 + 0.5 * sin(t * 2.4)
	var stun: bool = stunned()
	var warning: bool = state in [State.SLAM_WARN, State.HURL_WARN, State.LEAP_WARN, State.RECALL_WARN]
	var pulse: float = WARN_PINK * (0.7 + 0.3 * sin(t * 18.0))
	var xf: Transform2D = _to_world()
	var hc: Vector2 = heart_center()
	if not dying:
		var glow: float = GLOW_COVER * lerpf(0.35, 1.0, rise) * (0.8 + 0.2 * breath) * (0.5 if stun else 1.0) * (COVERED_GLOW if covered() else 1.0)
		_glow(hc, HEART_R, HEART_R * GLOW, glow)
	var rooted: Array[Piece] = _rooted()
	for p: Piece in pieces:
		if not _shows(p) or p.guard or p in rooted:
			continue
		var pc: Vector2 = p.c
		var pa: float = p.ang
		if dying:
			# Each magnet drops to the floor where it is and lies down flat.
			pc.y = lerpf(pc.y, -p.hw * 0.8, u * u)
			pa = lerp_angle(pa, roundf(pa / PI) * PI, u)
		var shape: PackedVector2Array = xf * (body_shape(pc, pa) if p.body else RisoShapes.spindle(pc, p.hl, p.hw, pa))
		# Its body is a lodestone, plain as the lodestones are: no pale poles on it.
		var poles: Array[PackedVector2Array] = []
		if not p.body:
			for cap: PackedVector2Array in RisoShapes.spindle_caps(pc, p.hl, p.hw, pa):
				poles.append(xf * cap)
		var pink: float = 0.0
		if (p.hand and state == State.SLAM_WARN) or (p.part >= 0 and p.part == hurling and state == State.HURL_WARN):
			pink = pulse
		var pale: float = 0.35 if p.part >= 0 and t - struck_t[p.part] < FLASH_TIME else 0.0
		if p.body:
			for r: Piece in rooted:
				shape = Geometry2D.merge_polygons(shape, xf * RisoShapes.spindle(r.c, r.hl, r.hw, r.ang))[0]
				var caps: Array[PackedVector2Array] = RisoShapes.spindle_caps(r.c, r.hl, r.hw, r.ang)
				var outer: PackedVector2Array = caps[0] if _middle_of(caps[0]).distance_to(pc) > _middle_of(caps[1]).distance_to(pc) else caps[1]
				poles.append(xf * outer)
		print_magnet(ink, shape, poles, pink, pale, fade)
		if p.body:
			_heart(_world(heart_at), fade, u)
			_print_ward(fade)
			if not dying:
				_eyes(warning, pulse)
	var bits: Array[PackedVector2Array] = []
	for i: int in range(PART_SIZE.size()):
		if not whole[i] and not thrown[i] and t - shattered_t[i] < SHATTER_TIME and not i in COVERS:
			_bits(i, (t - shattered_t[i]) / SHATTER_TIME, bits)
	ink.ink(RisoPrint.NIGHT, STONE_NIGHT + 0.3, bits)
	ink.ink(RisoPrint.BLUE, STONE_BLUE, bits, false)
	if stun and not dying:
		_stars(_world(top_at) + Vector2(0.0, -40.0))
	var marks: Array[PackedVector2Array] = []
	if state in [State.LEAP_WARN, State.LEAP]:
		marks.append(RisoShapes.rrect(leap_to.x - FOOT * 1.6, leap_to.y - MARK_H, FOOT * 3.2, MARK_H, MARK_H * 0.5))
	if state == State.RECALL_WARN:
		for k: int in range(called.size()):
			if not is_instance_valid(called[k]):
				continue
			var loose: Node2D = called[k]
			if loose.has_meta(&"way"):
				var way: PackedVector2Array = loose.get_meta(&"way")
				marks.append(RisoShapes.strand(loose.global_position, way[1], RECALL_W))
				marks.append(RisoShapes.strand(way[1], way[2], RECALL_W))
	ink.ink(RisoPrint.PINK, WARN_PINK * (0.6 + 0.4 * sin(t * 14.0)), marks)
	ink.finish()


## Print one magnet (`shape`, its pole caps `poles`) on `ink`, at `fade`: what was printed under it
## lifted (so it stands in front), then iron-blue, its poles pale, a paler rim along its lit edge; pink over it at `pink` (a warning, or a hazard on its way), and its ink lifted at `pale` (a
## blow glancing off).
static func print_magnet(on: InkCanvas, shape: PackedVector2Array, poles: Array[PackedVector2Array], pink: float, pale: float, fade: float) -> void:
	on.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.PINK], fade, [shape])
	on.ink(RisoPrint.BLUE, STONE_BLUE * fade, [shape])
	on.ink(RisoPrint.NIGHT, STONE_NIGHT * fade, [shape], false)
	on.lift_ink([RisoPrint.NIGHT], POLE_LIFT * fade, poles)
	on.lift_ink([RisoPrint.BLUE], POLE_PALE * fade, poles)
	var shaded: PackedVector2Array = Transform2D(0.0, RIM) * shape
	on.lift_ink([RisoPrint.NIGHT], RIM_LIFT * fade, Geometry2D.clip_polygons(shape, shaded))
	if pink > 0.0:
		on.ink(RisoPrint.PINK, pink, [shape], false)
	if pale > 0.0:
		on.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], pale, [shape])


## Print chunk `part` alone, round `c` lying `ang` (radians), on `ink` (GolemStone, a hurled chunk):
## as print_magnet, at `pink`.
static func piece_inks(on: InkCanvas, part: int, c: Vector2, ang: float, pink: float) -> void:
	var size: Vector2 = PART_SIZE[part]
	var poles: Array[PackedVector2Array] = RisoShapes.spindle_caps(c, size.x, size.y, ang)
	print_magnet(on, RisoShapes.spindle(c, size.x, size.y, ang), poles, pink, 0.0, 1.0)


## Its ward round its heart, as an enemy's shield is printed (RisoWard): a pink plate for each whole
## one, turning; flashing when a blow glances off one; a broken one's shards flying, at `fade`.
func _print_ward(fade: float) -> void:
	var hc: Vector2 = heart_center()
	var intact: int = 0
	var flash: float = 0.0
	for i: int in COVERS:
		if whole[i]:
			intact += 1
		flash = maxf(flash, clampf(1.0 - (t - struck_t[i]) / FLASH_TIME, 0.0, 1.0))
		if not whole[i] and not thrown[i]:
			RisoWard.shards(ink, hc, WARD_R, broke_at[i], (t - shattered_t[i]) / RisoWard.SHARD_TIME, RisoPrint.PINK)
	RisoWard.plates(ink, hc, WARD_R, COVERS.size(), intact, _ward_spin(), flash, RisoPrint.PINK, 0.0, 0, fade, WARD_THICK)


## Its caps and fins that stand out of its body, printed as one with it (no seam where they go in, only
## their outer poles pale): those whole and in place, not held up to hurl, flashing from a blow,
## sagging loose or falling.
func _rooted() -> Array[Piece]:
	var out: Array[Piece] = []
	if dying or stunned():
		return out
	for i: int in [BACK_CAP, FRONT_CAP, FIN_TOP, FIN_MID, FIN_LOW]:
		if not whole[i] or chunk_piece[i] < 0 or (i == hurling and state == State.HURL_WARN) or t - struck_t[i] < FLASH_TIME:
			continue
		out.append(pieces[chunk_piece[i]])
	return out


## The middle of a shape (the mean of its points).
static func _middle_of(shape: PackedVector2Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in shape:
		sum += v
	return sum / float(maxi(shape.size(), 1))


## Its heart's glow: accent from `r0` round `c` (at `cover`) fading out to `r1`.
func _glow(c: Vector2, r0: float, r1: float, cover: float) -> void:
	var quads: Array[PackedVector2Array] = []
	var fades: Array[PackedFloat32Array] = []
	var n: int = 32
	for i: int in range(n):
		var a: Vector2 = Vector2.from_angle(TAU * float(i) / float(n))
		var b: Vector2 = Vector2.from_angle(TAU * float(i + 1) / float(n))
		quads.append(PackedVector2Array([c + a * r0, c + a * r1, c + b * r1, c + b * r0]))
		fades.append(PackedFloat32Array([cover, 0.0, 0.0, cover]))
	ink.ink_graded(RisoPrint.ACCENT, quads, fades)


## Its heart at `hc`, at `fade` (shrinking `u` of the way as it dies): a dark rim, then paper with an
## accent disc and a paper crescent cut from it (dim asleep, and dim while covered), a pink flash when
## wounded, and a crack in
## night for each wound.
func _heart(hc: Vector2, fade: float, u: float) -> void:
	var r: float = HEART_R * (1.0 - 0.4 * u)
	var rim: PackedVector2Array = RisoShapes.circle(hc, r * HEART_RIM, 24)
	ink.ink(RisoPrint.NIGHT, 0.85 * fade, [rim], false)
	var face_paper: PackedVector2Array = RisoShapes.circle(hc, r, 24)
	var bare: bool = not covered()
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], fade * (1.0 if bare else COVERED_PAPER), [face_paper])
	var disc: PackedVector2Array = RisoShapes.circle(hc, r * HEART_MARK, 20)
	ink.ink(RisoPrint.ACCENT, fade * lerpf(0.6, 1.0, rise) * (1.0 if bare else COVERED_MARK), [disc])
	var cut: Vector2 = Vector2(HEART_CUT.x * float(signf(_across())), HEART_CUT.y) * r
	ink.lift_ink([RisoPrint.ACCENT], fade, [RisoShapes.circle(hc + cut, r * HEART_CUT.z, 20)])
	var flash: float = clampf(1.0 - (t - heart_t) / FLASH_TIME, 0.0, 1.0)
	if flash > 0.0:
		ink.ink(RisoPrint.PINK, 0.6 * flash * fade, [face_paper], false)
	var cracks: Array[PackedVector2Array] = []
	for k: int in range(HEART - maxi(wound.hp, 0)):
		var a: float = TAU * RisoDecor.h(0, Vector2i(k, 0), CRACK_DEAL)
		var from: Vector2 = hc + Vector2.from_angle(a) * r * 0.15
		var bend: Vector2 = hc + Vector2.from_angle(a + 0.4) * r * 0.55
		cracks.append(RisoShapes.strand(from, bend, CRACK_W))
		cracks.append(RisoShapes.strand(bend, hc + Vector2.from_angle(a - 0.2) * r, CRACK_W * 0.7))
	ink.ink(RisoPrint.NIGHT, fade, cracks)


## Its eyes in its body: slits of paper in a dark band, slanting in toward the way it faces, opening
## as it wakes (dark lines asleep), pink while it warns (`warning`, at `pulse`).
func _eyes(warning: bool, pulse: float) -> void:
	var xf: Transform2D = _to_world() * Transform2D(eyes_turn, eyes_at)
	var band: PackedVector2Array = xf * PackedVector2Array([Vector2(-EYE_BAND.x, -EYE_BAND.y), Vector2(EYE_BAND.x, -EYE_BAND.y * 1.3), Vector2(EYE_BAND.x, EYE_BAND.y * 0.9), Vector2(-EYE_BAND.x, EYE_BAND.y)])
	ink.ink(RisoPrint.NIGHT, 0.8, [band], false)
	var slits: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var slit: Transform2D = Transform2D(-side * EYE_SLANT, Vector2(side * EYES_APART, 0.0))
		slits.append(xf * slit * RisoShapes.almond(Vector2.ZERO, EYE.x, maxf(EYE.y * rise, 0.8), 8))
	if rise < 0.3:
		ink.ink(RisoPrint.NIGHT, 0.9, slits, false)
		return
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], 1.0, slits)
	if warning:
		ink.ink(RisoPrint.PINK, pulse, slits)


## Stars circling over its top at `at` while it is stunned, fewer as the stun wears off.
func _stars(at: Vector2) -> void:
	var frac: float = stunner.fraction()
	var stars: Array[PackedVector2Array] = []
	for i: int in range(3):
		var a: float = t * 2.6 + TAU * float(i) / 3.0
		var p: Vector2 = at + Vector2(cos(a) * 70.0, sin(a) * 16.0)
		stars.append(Transform2D(t * 1.8 + float(i), p) * RisoShapes.sparkle(Vector2.ZERO, 10.0 + 6.0 * frac))
	ink.ink(RisoPrint.ACCENT, 0.9, stars)


## The bits of shattered chunk `i`, `u` of the way through flying off (0 to 1), into `out`.
func _bits(i: int, u: float, out: Array[PackedVector2Array]) -> void:
	var c: Vector2 = part_center(i)
	var size: float = PART_SIZE[i].y * 1.4 * (1.0 - u)
	for k: int in range(5):
		var a: float = TAU * RisoDecor.h(0, Vector2i(i, k), BITS_DEAL)
		var at: Vector2 = c + Vector2.from_angle(a) * BITS_FLY * u + Vector2(0.0, BITS_FLY * u * u)
		out.append(RisoShapes.tri(at + Vector2.from_angle(a) * size, at + Vector2.from_angle(a + 2.2) * size, at + Vector2.from_angle(a + 4.1) * size))
