class_name BrambleBulb
extends Node2D
## One of the bramble's bulbs (Bramble), its weak points: set in a wall of its shaft, swelling out
## of the rock. Struck by bolts and dashes through its Wound (BrambleWound) as an enemy is; it has a
## Stunner only so a dash strikes it (the dash strikes only what can be stunned), and is never
## stunned (it is parry_only, and nothing of a bulb can be parried). While the wizard is within
## SEED_RANGE and in sight it swells, and every SEED_EVERY seconds it spits a seed at them: a shot
## (Bullet, its `seed` look) that a parry turns back into the bulb that spat it. Burst, it is gone
## for good and the vines it feeds wither (Bramble.burst).

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const SEED: PackedScene = preload("res://prefabs/bullet.tscn")
## How near (px) the wizard must be for it to spit, how long it swells before each seed (in sight),
## and how fast a seed flies (px/s; a watcher's shot flies at 260).
const SEED_RANGE: float = 900.0
const SEED_EVERY: float = 3.0
const SEED_SPEED: float = 250.0
## How far out of the rock face its middle sits (px), and where its seeds leave it.
const OUT: float = 34.0
const MOUTH: float = 72.0
## Salt for the level seed, for how far into its first swell each bulb starts (so they do not
## all spit together).
const SWELL_DEAL: int = 6640

## The bramble it belongs to, its wall cell, and the way out of the rock (into the shaft).
var bramble: Bramble
var cell: Vector2i = Vector2i.ZERO
var way: Vector2 = Vector2.RIGHT
var wound: BrambleWound
var stunner: Stunner
var alive: bool = true
## How far toward its next seed (0 to 1), and how many it has spat (for the tests).
var charge: float = 0.0
var spat: int = 0
## When (the bramble's clock) it was last struck, and when it burst.
var struck_t: float = -INF
var burst_t: float = -INF


func _init(of: Bramble, wall: Vector2i, out: Vector2, hp: int) -> void:
	bramble = of
	cell = wall
	way = out
	wound = BrambleWound.new()
	wound.name = "Wound"
	wound.hp = hp
	add_child(wound)
	stunner = STUNNER.instantiate() as Stunner
	stunner.name = "Stunner"
	stunner.parry_only = true
	add_child(stunner)
	add_to_group(&"hex_target")


## Place it at the face of its wall cell, and start its first swell part way through.
func place(face: Vector2, level_seed: int) -> void:
	global_position = face + way * OUT
	charge = RisoDecor.h(level_seed, cell, SWELL_DEAL) * 0.8


## Its hits left (0 once burst).
func hits_left() -> int:
	return maxi(wound.hp, 0) if alive else 0


## Where its seeds leave it.
func mouth() -> Vector2:
	return global_position + way * (MOUTH - OUT)


## It has been struck: it flashes.
func struck() -> void:
	struck_t = bramble.t


## It has burst: out of reach for good.
func pop() -> void:
	alive = false
	burst_t = bramble.t
	remove_from_group(&"hex_target")


func _physics_process(delta: float) -> void:
	if not alive or bramble == null or bramble.opening or bramble.map_info == null:
		return
	var player: Player = bramble.map_info.player
	if player == null or not is_instance_valid(player) or not sees(player):
		charge = maxf(0.0, charge - delta / SEED_EVERY)
		return
	# A harder preset readies its seeds sooner (Difficulty.haste).
	charge += delta * Difficulty.haste() / SEED_EVERY
	if charge >= 1.0:
		charge = 0.0
		spit(player.global_position)


## Whether `player` is near enough, and in sight past the rock.
func sees(player: Player) -> bool:
	var from: Vector2 = mouth()
	if from.distance_to(player.global_position) > SEED_RANGE:
		return false
	# The knot does not hide the wizard from its own bulbs.
	var skip: Array[RID] = []
	if bramble.knot != null:
		skip.append(bramble.knot.get_rid())
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, player.global_position, 1 | 4, skip)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == player


## Spit a seed at `at`.
func spit(at: Vector2) -> void:
	var shot: Bullet = SEED.instantiate() as Bullet
	shot.seed = true
	bramble.map_info.map_elements.add_child(shot)
	shot.global_position = mouth()
	shot.setup((at - mouth()).normalized() * SEED_SPEED, [], self)
	spat += 1
	RisoFx.burst(&"impact", mouth(), way, [RisoPrint.PINK, RisoPrint.ACCENT])
