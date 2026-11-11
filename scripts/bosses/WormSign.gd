class_name WormSign
extends Node
## The worm's rumble through the levels near it (docs/REVIEW_PLAN.md §2.2): in a garden level the
## worm's nearness reaches (Bosses.near; not its own gate level, where it rumbles itself), now and
## then the ground shakes and dirt falls, the nearer the worm the more often (RUMBLE_FAR seconds
## apart at the edge of its reach, RUMBLE_NEXT next door) and the harder (SHAKE_FAR to SHAKE_NEXT).
## The dirt falls at the side of the view the worm's level lies to (along the top when it lies
## straight below), so a rumble says which way as well as how near. None once the worm is slain.
## MapInfo adds one to each level it lays out (_spawn_worm_sign). Timed by the game clock: it
## touches no layout and draws nothing from the world RNG.

const RUMBLE_FAR: float = 7.0
const RUMBLE_NEXT: float = 2.2
const SHAKE_FAR: float = 1.5
const SHAKE_NEXT: float = 5.0
## How long each shake lasts (seconds), and how many spits of dirt fall with it.
const SUSTAIN: float = 0.4
const DIRT: int = 3
## Salt for the level seed: how far into its first wait a level's rumble starts.
const PHASE_DEAL: int = 7100

## How near the worm is (Bosses.near; 0 where it does not rumble), which way its level lies (x:
## -1 left, 1 right, 0 this column), the seconds to the next rumble, and how many there have been.
var nearness: float = 0.0
var side: int = 0
var wait: float = 0.0
var rumbles: int = 0


func _ready() -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.run == null or info.run.bosses.has(&"worm") or Bosses.gate_at(info.coord.y) == &"worm":
		return
	nearness = Bosses.near(&"worm", info.coord, info.run.run_seed)
	side = signi(Bosses.column(&"worm", info.run.run_seed) - info.coord.x)
	wait = interval() * RisoDecor.h(Rules.level_seed(info.coord.x, info.coord.y), info.coord, PHASE_DEAL)


## Seconds between rumbles here.
func interval() -> float:
	return lerpf(RUMBLE_FAR, RUMBLE_NEXT, nearness)


func _physics_process(delta: float) -> void:
	var info: MapInfo = MapInfo.instance
	if nearness <= 0.0 or info == null or info.travelling or info.run_ending > 0.0:
		return
	if info.run.bosses.has(&"worm"):
		nearness = 0.0
		return
	wait -= delta
	if wait <= 0.0:
		wait = interval()
		rumble()


## A rumble: the view shakes, and dirt falls at its side toward the worm.
func rumble() -> void:
	rumbles += 1
	Wound.shake(lerpf(SHAKE_FAR, SHAKE_NEXT, nearness), SUSTAIN)
	var cam: Camera2D = Stage.camera()
	if cam == null:
		return
	var half: Vector2 = cam.get_viewport_rect().size / cam.zoom * 0.5
	var mid: Vector2 = cam.get_screen_center_position()
	for i: int in range(DIRT):
		var roll: float = RisoDecor.h(rumbles, Vector2i(i, side), PHASE_DEAL + 1)
		var at: Vector2
		if side == 0:
			at = mid + Vector2((roll * 2.0 - 1.0) * half.x * 0.8, -half.y * 0.85)
		else:
			at = mid + Vector2(float(side) * half.x * 0.85, (roll - 0.7) * half.y)
		RisoFx.burst(&"rubble", at, Vector2.DOWN, [RisoPrint.BLUE, RisoPrint.NIGHT])
