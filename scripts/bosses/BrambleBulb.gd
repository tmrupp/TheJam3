class_name BrambleBulb
extends Node2D
## One of the bramble's bulbs (Bramble), its weak points: set in a wall of its shaft, swelling out
## of the rock. Struck by bolts and dashes through its Wound (BrambleWound) as an enemy is; it has a
## Stunner only so a dash strikes it (the dash strikes only what can be stunned), and is never
## stunned (it is parry_only, and nothing of a bulb can be parried). Only one bulb is in bloom at a
## time (Bramble.bloom): the rest are shut in their bark, and a blow glances off them (warded), all
## but a seed of their own parried back. While the wizard is within SEED_RANGE and in sight it
## swells, and every SEED_EVERY seconds it spits a seed at them (sooner, and two at once, as the
## bramble's fury grows: Bramble.fury), its swell ending in a tell as a pod's (SeedPod.POD_TELL,
## turning pink): a shot (Bullet, its `seed` look) that a parry turns back into the bulb that spat
## it. Each wound sends the bloom on to another bulb (Bramble.wounded).
## Burst, it is out of the fight and the vines it feeds wither (Bramble.burst), until the heart is
## bared: then it opens again, wild (rouse), and spits seeds at the wizard every WILD_EVERY seconds,
## but nothing wounds it.

const STUNNER: PackedScene = preload("res://prefabs/stunner.tscn")
const SEED: PackedScene = preload("res://prefabs/bullet.tscn")
## How near (px) the wizard must be for it to spit, how long it swells before each seed (in sight),
## and how fast a seed flies (px/s; a watcher's shot flies at 260).
const SEED_RANGE: float = 900.0
const SEED_EVERY: float = 3.0
const SEED_SPEED: float = 250.0
## The bramble's fury (Bramble.fury, a point for each bulb burst): how much sooner each point readies
## a seed (SEED_EVERY over 1 + SEED_FURY a point), the fury from which it spits two at once, and how
## far apart (radians) the two fly.
const SEED_FURY: float = 0.3
const TWIN_FURY: int = 2
const TWIN_SPREAD: float = 0.2
## Wild, once the heart is bared (rouse): how often it spits a seed (seconds, before
## Difficulty.haste; one at a time, whatever the fury).
const WILD_EVERY: float = 3.4
## How fast its bark opens and shuts as the bloom comes and goes (its full way a second, times).
const OPEN_RATE: float = 4.0
## How far out of the rock face its middle sits (px), and where its seeds leave it.
const OUT: float = 34.0
const MOUTH: float = 72.0
## Salt for the level seed, for how far into its first swell each bulb starts (so they do not
## all spit together), and how far into its first swell it starts once wild.
const SWELL_DEAL: int = 6640
const WILD_DEAL: int = 6641

## The bramble it belongs to, its wall cell, and the way out of the rock (into the shaft).
var bramble: Bramble
var cell: Vector2i = Vector2i.ZERO
var way: Vector2 = Vector2.RIGHT
var wound: BrambleWound
var stunner: Stunner
var alive: bool = true
## Whether it has opened again, burst, for the bramble's last stand (rouse): it spits, but nothing
## wounds it.
var wild: bool = false
## How far toward its next seed (0 to 1), and how many it has spat (for the tests).
var charge: float = 0.0
## How far through its tell it is (0 to 1; SeedPod.POD_TELL, as a pod's), its swell full; -1 while
## it is not telling.
var telling: float = -1.0
var spat: int = 0
## When (the bramble's clock) it was last struck, when a blow last glanced off its bark, and when
## it burst.
var struck_t: float = -INF
var warded_t: float = -INF
var burst_t: float = -INF
## When (the bramble's clock) it last spat a seed, for its leaves (Bramble.leaves_parted).
var spat_t: float = -INF
## How far its bark is open (0 shut, 1 in bloom), as printed.
var opened: float = 0.0


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


## Whether it is in bloom, and so can be wounded (Bramble.bloom).
func open() -> bool:
	return alive and bramble != null and bramble.bloom == self


## A blow (heading `dir`) has glanced off its shut bark: no wound, a pale burst.
func warded(dir: Vector2) -> void:
	warded_t = bramble.t
	bramble.quiver(global_position, Bramble.QUIVER_WARDED)
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	Wound.shake(4.0, 0.1)


## Seconds between its seeds at the bramble's fury now (before Difficulty.haste); WILD_EVERY wild.
func seed_every() -> float:
	if wild:
		return WILD_EVERY
	return SEED_EVERY / (1.0 + SEED_FURY * float(bramble.fury))


## Burst, it opens again for the bramble's last stand (its heart bared), part way into a swell.
func rouse() -> void:
	if alive:
		return
	wild = true
	charge = RisoDecor.h(bramble.level_seed, cell, WILD_DEAL) * 0.8
	# Blows reach it again, only to glance off (BrambleWound).
	add_to_group(&"hex_target")


## Its last stand is over (the heart burst): a husk again, its petals flying.
func calm() -> void:
	if not wild:
		return
	wild = false
	burst_t = bramble.t
	remove_from_group(&"hex_target")


## It has been struck: it flashes, and the bramble quivers from it.
func struck() -> void:
	struck_t = bramble.t
	bramble.quiver(global_position, Bramble.QUIVER_STRUCK)


## It has burst: out of reach for good.
func pop() -> void:
	alive = false
	burst_t = bramble.t
	remove_from_group(&"hex_target")


func _physics_process(delta: float) -> void:
	if bramble == null:
		return
	opened = move_toward(opened, 1.0 if open() or wild else 0.0, delta * OPEN_RATE)
	if bramble.dying or bramble.map_info == null or not (wild or (alive and bramble.heart == null)):
		return
	var player: Player = bramble.map_info.player
	if player == null or not is_instance_valid(player) or not sees(player):
		charge = maxf(0.0, charge - delta / SEED_EVERY)
		telling = -1.0
		return
	# Full, it tells (turning pink) for SeedPod.POD_TELL, never under Difficulty.TELL_MIN, then spits.
	if telling >= 0.0:
		telling += delta / Difficulty.boss_tell(SeedPod.POD_TELL)
		if telling < 1.0:
			return
		telling = -1.0
		charge = 0.0
		if bramble.fury >= TWIN_FURY and not wild:
			spit(player.global_position, -TWIN_SPREAD)
			spit(player.global_position, TWIN_SPREAD)
		else:
			spit(player.global_position)
		return
	# A harder preset readies its seeds sooner (Difficulty.haste), and so does the bramble's fury.
	charge = minf(1.0, charge + delta * Difficulty.haste() / (seed_every() - SeedPod.POD_TELL))
	if charge >= 1.0:
		telling = 0.0


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


## Spit a seed at `at`, turned `bend` radians off it.
func spit(at: Vector2, bend: float = 0.0) -> void:
	var shot: Bullet = SEED.instantiate() as Bullet
	shot.seed = true
	bramble.map_info.map_elements.add_child(shot)
	shot.global_position = mouth()
	shot.setup((at - mouth()).normalized().rotated(bend) * SEED_SPEED, [], self)
	spat += 1
	spat_t = bramble.t
	RisoFx.burst(&"impact", mouth(), way, [RisoPrint.PINK, RisoPrint.ACCENT])
