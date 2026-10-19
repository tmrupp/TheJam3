extends Node2D
class_name Breach
## A breach in an institute floor (Institute.populate), where the deep the eldritch beast lies in
## shows through: a crack glowing pink, the abominations' spawner. While the wizard is within WAKE
## cells of it, an abomination (Abomination) climbs out of it every EVERY seconds (the first FIRST
## seconds after it wakes), as long as fewer than Abomination.MOST are about in the level, and what
## comes out multiplies in its turn: a breach has to be closed. It is an enemy itself (its Wound,
## given as it is placed, set to HP): any bolt wounds it, even one of no damage (Wound.least),
## and once closed the level record keeps it so until the wizard dies. What climbs out is not part
## of the level: none are kept, and they are gone when the level is left. In the institute it lets
## out only a trickle, in a class or in passing time alike, a little sooner for every ring of the
## level's bell (pace). Nothing here draws from any RNG.

## How near the wizard wakes it (cells), how soon the first comes and how often after that
## (seconds), and the hits it takes to close.
const WAKE: int = 10
const FIRST: float = 1.5
const EVERY: float = 5.0
## How often one comes in the institute (seconds), before any ring: a trickle. Each ring of the
## level's bell makes it RING_SOONER sooner: one every TRICKLE / (1 + RING_SOONER × rings) seconds.
const TRICKLE: float = 12.0
const RING_SOONER: float = 0.05
const HP: int = 6
## How long it shows one coming before it is out (seconds), and how long the newcomer takes to rise.
const SURGE: float = 0.8
const RISE: float = 0.6

var map_info: MapInfo
## Its cell, what it has let out still about, the seconds until the next, and how long it has been
## surging with one (seconds, for the art; negative while it is not).
var cell: Vector2i = Vector2i.ZERO
var brood: Array[Node2D] = []
var wait: float = FIRST
var surging: float = -1.0


func setup(info: MapInfo, v: Vector2i) -> void:
	map_info = info
	cell = v
	# Wounded by any bolt, even one of no damage: it has nothing to stun.
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.least = 1
		wound.hp = HP


## How often one comes in an institute level whose bell has rung `rings` times (seconds): TRICKLE,
## a little sooner for every ring.
static func pace(rings: int) -> float:
	return TRICKLE / (1.0 + RING_SOONER * float(maxi(rings, 0)))


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
	if surging >= 0.0:
		surging += delta
		if surging >= SURGE:
			surging = -1.0
			_let_out()
		return
	if not awake():
		wait = FIRST
		return
	if get_tree().get_nodes_in_group(&"abomination").size() >= Abomination.MOST:
		return
	wait -= delta * Difficulty.attack()
	if wait <= 0.0:
		wait = pace(map_info.record().rings) if map_info.timetabled() else EVERY
		surging = 0.0


## A new abomination, up out of the crack.
func _let_out() -> void:
	if map_info == null or is_queued_for_deletion():
		return
	# The level may have filled up while it surged.
	if get_tree().get_nodes_in_group(&"abomination").size() >= Abomination.MOST:
		return
	var thing: Node2D = Placeables.scene(LevelGen.Type.ABOMINATION).instantiate() as Node2D
	LevelLoader.arm(thing, map_info.here.depth)
	(thing as Abomination).sprout(1)
	map_info.map_elements.add_child(thing)
	# Its feet on the floor at the crack (the breach stands at its cell's middle), so it grows up
	# out of it rather than in the air over it.
	var half: float = float(map_info.tile_map.tile_set.tile_size.y) * map_info.tile_map.global_scale.y * 0.5
	thing.global_position = global_position + Vector2(0, half - Abomination.FEET)
	(thing as Abomination).rise(RISE)
	brood.append(thing)
	RisoFx.burst(&"rubble", global_position + Vector2(0.0, 40.0), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
