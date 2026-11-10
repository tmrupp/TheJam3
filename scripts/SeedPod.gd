class_name SeedPod
extends Stunnable
## A seed pod, in the garden (GardenArchetype.finish): one of the bramble's bulbs (BrambleBulb),
## grown out of a garden wall on its own, printed as the bramble prints its bulbs in bloom
## (Bramble.ink_bulb, PodArt). While the wizard is within RANGE and in sight it swells,
## and every SEED_EVERY seconds (sooner on a harder preset, Difficulty.attack) it spits a seed at
## them, its bulb turning pink over the last POD_TELL of them (its tell, Difficulty.tell): a shot (Bullet, its `seed` look) that hurts, and that a parry turns back into the pod. Only
## a seed of its own turned back wounds it (Wound.parried_only): a slash, a bolt or a dash glances
## off its bark. Burst, it flings out a seed to carry (KeyRing.SEED, kept by the level's record as a
## dropped key until taken) for planting at a plot (Plot), and is slain until the wizard dies, as
## any enemy is (Wound). Its touch hurts. Its body is frozen where it grew: it never falls or moves.

const SHOT: PackedScene = preload("res://prefabs/bullet.tscn")
## How near (px) the wizard must be for it to spit (a watcher sees much further: a pod in a bad
## spot never pins the wizard down from afar), how long it swells before each seed (in sight), and
## how fast a seed flies (px/s).
const RANGE: float = 620.0
const SEED_EVERY: float = 2.4
## How long (seconds, at Normal) its tell lasts at the end of each swell: its bulb full, turning
## pink, then flashing in its last beat (Difficulty.last_beat) before it spits. A harder preset runs
## it faster, never under Difficulty.TELL_MIN, and its swell the rest of SEED_EVERY.
const POD_TELL: float = 0.6
const SEED_SPEED: float = 240.0
## How far from the wall its middle sits (px), and how far out from its middle its seeds leave it:
## as a bramble bulb's.
const OUT: float = BrambleBulb.OUT
const MOUTH: float = BrambleBulb.MOUTH - BrambleBulb.OUT
## Salt for the level seed, for how far into its first swell it starts (so pods do not spit together).
const SWELL_DEAL: int = 6650
## Burst, its seed is flung out the way it faces: SHOVE px from its middle, stopping SHOVE_CLEAR px
## short of any rock in the way (felt for every SHOVE_STEP px), over SHOVE_TIME seconds in an arc
## SHOVE_ARC px high.
const SHOVE: float = 280.0
const SHOVE_CLEAR: float = 44.0
const SHOVE_STEP: float = 8.0
const SHOVE_TIME: float = 0.45
const SHOVE_ARC: float = 40.0

## Its body (the prefab's root), the way out of the wall it grew from, its swell toward the next
## seed (0 to 1), how many it has spat, and whether it saw the wizard this frame.
var rb: RigidBody2D
var way: Vector2 = Vector2.RIGHT
var charge: float = 0.0
## How far through its tell it is (0 to 1), its swell full; -1 while it is not telling.
var telling: float = -1.0
var spat: int = 0
var sees: bool = false
## When (msec, Time.get_ticks_msec) a blow last wounded it and last glanced off it, for its flashes.
var struck_at: int = -100000
var warded_at: int = -100000
## When (msec) it last spat a seed, for its leaves (Bramble.leaves_parted).
var spat_at: int = -100000


func _ready() -> void:
	rb = get_parent() as RigidBody2D
	rb.gravity_scale = 0.0
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.freeze = true
	var wound: Wound = rb.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.parried_only = true
		wound.slain.connect(_drop_seed)
		wound.hurt.connect(func(_damage: int) -> void: struck_at = Time.get_ticks_msec())
		wound.warded.connect(func(_dir: Vector2) -> void: warded_at = Time.get_ticks_msec())
	# Once the loader has put it on its cell (LevelLoader.place_cell sets its place after adding it).
	_place.call_deferred()


## Set it against the wall beside its cell: the side with rock (the left first), its body pushed
## up to the rock and facing out. Its first swell starts part way in, by the level seed.
func _place() -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or not rb.has_meta(&"cell"):
		return
	var cell: Vector2i = rb.get_meta(&"cell")
	way = SeedPod.facing(info.world, cell)
	var cell_px: float = (info.cell_position(cell + Vector2i.RIGHT) - info.cell_position(cell)).x
	rb.global_position = info.cell_position(cell) - way * (cell_px * 0.5 - OUT)
	charge = RisoDecor.h(info.world.seed_for_colors, cell, SWELL_DEAL) * 0.8


## The way out of the wall a pod in `cell` of `w` grew from: away from the rock beside it, the left
## first, else up off a floor, else right.
static func facing(w: LevelGen, cell: Vector2i) -> Vector2:
	if w.is_ground(cell + Vector2i.LEFT):
		return Vector2.RIGHT
	if w.is_ground(cell + Vector2i.RIGHT):
		return Vector2.LEFT
	if w.is_ground(cell + Vector2i.UP):
		return Vector2.DOWN
	return Vector2.UP


## Where its seeds leave it.
func mouth() -> Vector2:
	return rb.global_position + way * MOUTH


func _physics_process(delta: float) -> void:
	var player: Player = Stage.player()
	sees = player != null and is_instance_valid(player) and _sees(player)
	if not sees:
		charge = maxf(0.0, charge - delta / SEED_EVERY)
		telling = -1.0
		return
	if stunned:
		# A stun breaks off its tell: it tells again in full once it is over.
		telling = -1.0
		return
	if telling >= 0.0:
		telling += delta / Difficulty.tell(POD_TELL)
		if telling >= 1.0:
			telling = -1.0
			charge = 0.0
			spit(player.global_position)
		return
	charge = minf(1.0, charge + delta * Difficulty.attack() / (SEED_EVERY - POD_TELL))
	if charge >= 1.0:
		telling = 0.0


## Whether `player` is near enough, on its open side, and in sight past the rock.
func _sees(player: Player) -> bool:
	var from: Vector2 = mouth()
	var to: Vector2 = player.global_position
	if from.distance_to(to) > Lamplight.notice(RANGE) or (to - rb.global_position).dot(way) < 0.0:
		return false
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1 | 4, [rb.get_rid()])
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == player


## Spit a seed at `at`. Its sender is the pod's body, so a parry sends it home there (HexBolt.home).
func spit(at: Vector2) -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.map_elements == null:
		return
	var shot: Bullet = SHOT.instantiate() as Bullet
	shot.seed = true
	info.map_elements.add_child(shot)
	shot.global_position = mouth()
	shot.setup((at - mouth()).normalized() * SEED_SPEED, [rb], rb)
	spat += 1
	spat_at = Time.get_ticks_msec()
	RisoFx.burst(&"impact", mouth(), way, [RisoPrint.PINK, RisoPrint.ACCENT])


## Burst: its seed is flung out away from it (shoved), to be carried (KeyRing.SEED).
func _drop_seed() -> void:
	var info: MapInfo = MapInfo.instance
	if info != null and info.world != null:
		info.drop_seed(SeedPod.shoved(info, rb.global_position, way), rb.global_position)


## Where the seed of a pod at `from` facing `way` comes to rest: SHOVE px out along its way, or as
## far as it goes short of rock (SHOVE_CLEAR from it).
static func shoved(info: MapInfo, from: Vector2, way: Vector2) -> Vector2:
	var w: LevelGen = info.world
	var at: Vector2 = from
	var d: float = SHOVE_STEP
	while d <= SHOVE:
		var next: Vector2 = from + way * d
		var ahead: Vector2i = info.cell_at(next + way * SHOVE_CLEAR)
		if w.is_ground(ahead) or not w.is_valid(ahead):
			break
		at = next
		d += SHOVE_STEP
	return at
