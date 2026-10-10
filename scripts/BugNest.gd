extends Node2D
class_name BugNest
## A rock-bug nest, in crag levels (CragsArchetype.place_nests): a burrow in the rock on a floor,
## in the towers' rooms and out on the cliff. While the wizard is within WAKE cells of it, it
## hatches a rock-bug (RockBug.crawl_out) every EVERY seconds (the first FIRST seconds after it
## wakes), as long as fewer than BROOD of its own are still about. It is an enemy itself: hex bolts
## wound it (its Wound, given as it is placed), and once destroyed the level record keeps it slain
## until the wizard dies. The bugs it hatches are not part of the level: none are kept, and they are
## gone when the level is left. Nothing here draws from the world RNG.

## How near the wizard wakes it (cells), how soon it hatches its first bug once woken and how
## often after that (seconds), and how many of its bugs may be about at once.
const WAKE: int = 7
const FIRST: float = 1.2
const EVERY: float = 5.0
const BROOD: int = 2
## How long it shows a bug hatching before the bug comes out (seconds).
const HATCH: float = 0.6

var map_info: MapInfo
## Its own open cell, the bugs it has hatched still about, how long until the next (seconds), and
## how long it has been hatching one (seconds, for the art; negative while it is not).
var cell: Vector2i = Vector2i.ZERO
var brood: Array[Node2D] = []
var wait: float = FIRST
var hatching: float = -1.0

func setup(info: MapInfo, v: Vector2i) -> void:
	map_info = info
	cell = v


## Whether the wizard is near enough to wake it.
func awake() -> bool:
	var player: Player = Stage.player()
	if map_info == null or player == null or not is_instance_valid(player):
		return false
	var at: Vector2i = map_info.cell_at(player.global_position)
	return absi(at.x - cell.x) <= WAKE and absi(at.y - cell.y) <= WAKE


func _physics_process(delta: float) -> void:
	for i: int in range(brood.size() - 1, -1, -1):
		if not is_instance_valid(brood[i]) or brood[i].is_queued_for_deletion():
			brood.remove_at(i)
	if hatching >= 0.0:
		hatching += delta
		if hatching >= HATCH:
			hatching = -1.0
			_hatch()
		return
	if not awake():
		wait = FIRST
		return
	if brood.size() >= BROOD:
		return
	# A harder preset hatches sooner (Difficulty.attack).
	wait -= delta * Difficulty.attack()
	if wait <= 0.0:
		wait = EVERY
		hatching = 0.0


## A new rock-bug, out of the burrow and onto the rock beside it.
func _hatch() -> void:
	if map_info == null or is_queued_for_deletion():
		return
	var bug: Node2D = Placeables.scene(LevelGen.Type.BUG).instantiate() as Node2D
	LevelLoader.arm(bug, map_info.here.depth)
	map_info.map_elements.add_child(bug)
	bug.global_position = global_position
	(bug.get_node("RockBug") as RockBug).crawl_out(cell)
	brood.append(bug)
	RisoFx.burst(&"rubble", global_position + Vector2(0.0, 40.0), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
