extends RigidBody2D
class_name Abomination
## An abomination: a thing of the eldritch beast's, risen into the institute's halls from the deep
## (docs/REGIONS_PLAN.md §7), out of a breach in the floor (Breach) or laid with the level
## (Institute.populate). A cluster of pink blobs, each with an eye or two, tentacles reaching up
## and out from them (AbominationArt). It goes for whatever is nearest of the wizard and the institute's people
## (Scholar) within SENSE px, no sight needed, along its floor, hopping a step of a cell and
## dropping off ledges after its quarry. It goes steadily along the floor, its tentacles
## writhing round it (they do not move it). As it goes it leaves a trail of pink slime (Slime) that hurts the wizard while it is fresh and soon fades. Its touch
## hurts the wizard (its HitBox); a scholar it touches it bites, wounding it every BITE_EVERY
## seconds. The scholars' bolts and spells wound it in turn, so a fight in the institute has three
## sides. A stun (the hex's, a parry) stops it.
##
## It grows and multiplies: its blobs are its health (its Wound's hit points, `lobes`), so every
## wound bursts one blob, and the last one kills it. Every GROW_EVERY seconds (a little more or
## less, by its own hash; sooner on a harder preset), unless stunned, it grows another blob, up to
## SPLIT. At SPLIT, once its launch has come round (LAUNCH_EVERY seconds after its last, longer than
## its growing), it braces for TELL seconds, quivering, its top blob swelling and throbbing (the
## tell), then launches that blob (shed): it flies a quadratic arc to a floor LAND cells off (the
## first whose arc is clear of rock, the side dealt by its hash; else it drops where it is), lands as
## a new abomination of one blob and starts growing in its turn. So left alone they spread out of
## control, up to MOST about in the level at once (at the cap it neither braces nor launches). A
## wound or a stun during the tell breaks it off. One laid with the level starts with its Wound's
## health for its depth (LevelLoader.arm: three blobs this deep); one out of a breach or launched
## off another starts with one, and drops no stars. Nothing here draws from any RNG.

## How far it senses a quarry (px), and how fast it crawls (px/s, a little faster on a harder
## preset, Difficulty.speed).
const SENSE: float = 760.0
const SPEED: float = 95.0
## The hop up a step (px/s up) and the fastest fall.
const HOP: float = -560.0
const MAX_FALL: float = 900.0
## How near a scholar must be to be bitten (px), and how often it bites (seconds).
const BITE_REACH: float = 70.0
const BITE_EVERY: float = 0.9
## How far ahead (px) it looks for a wall to hop.
const AHEAD: float = 24.0
## Seconds between looks for a quarry.
const RETARGET: float = 0.3
## How often it grows a blob (seconds, give or take GROW_SPREAD of it), how many it has when it
## launches one, how long after a launch the next may come (longer than its growing), how long it
## braces first, and the most about in a level.
const GROW_EVERY: float = 3.5
const GROW_SPREAD: float = 0.3
const SPLIT: int = 6
const LAUNCH_EVERY: float = 9.0
const TELL: float = 1.4
const MOST: int = 32
## A launched blob's flight: how long it takes (seconds), how high the arc rises over the higher of
## its ends (px), how far off it lands (cells across, from, to; as near a row up or down), and how
## many points along the arc are looked at for rock.
const FLIGHT: float = 0.85
const ARC: float = 170.0
const LAND: Vector2i = Vector2i(2, 5)
const ARC_CHECKS: int = 12
## How far its feet are under its middle (px: half its body's box): where its slime is laid and its art
## stands.
const FEET: float = 16.0
## Its shape, dealt for each abomination by its own hash (shape): the first, central blob's radius,
## the others' (px, from, to), the chance that a blob after the first two grows from the central
## one (the first two always do; else from any before it), how far a blob sits into the one it grows from (a share of their radii together),
## each blob's eyes (a second, smaller one on a blob at least TWO_EYES across, by a chance of
## TWO_EYES_SHARE) and their size against the blob's (from, to), and its tentacles: the central
## blob's (from, to) and any other blob's (from, to), reaching up and out (ARMS_UP: how far either
## side of straight up they may root, so most reach up and a few out to the sides), their length (px,
## from, to) and width.
const BASE_R: Vector2 = Vector2(22.0, 28.0)
const LOBE_R: Vector2 = Vector2(18.0, 25.0)
const ON_CENTRAL: float = 0.85
const NESTLE: float = 0.62
const TWO_EYES: float = 15.0
const TWO_EYES_SHARE: float = 0.35
const EYE_SIZE: Vector2 = Vector2(0.24, 0.48)
const BASE_ARMS: Vector2i = Vector2i(4, 6)
const LOBE_ARMS: Vector2i = Vector2i(1, 3)
const ARMS_UP: float = PI * 0.62
const ARM_LONG: Vector2 = Vector2(38.0, 60.0)
const ARM_WIDE: Vector2 = Vector2(6.0, 10.0)

## Its blobs, the lowest first, from its feet facing right (across, up, radius, px), SPLIT of them
## dealt as it is made (shape); the art draws the first `lobes` (AbominationArt), and a burst blob
## bursts from its place.
var layout: Array[Vector3] = []
## Which blob each grew from (its index in `layout`; the central blob's is its own, 0): a budding
## blob's foot faces the blob it grew from (AbominationArt).
var parents: Array[int] = []
## Each blob's eyes ([Vector3(across, up, radius)], from the blob's middle) and tentacles
## ([Vector4(angle from the blob's middle, length, width, phase)]), by blob.
var eyes: Array = []
var arms: Array = []

## Its blobs now (its Wound's hit points), when it last grew one and last lost one (its clock).
var lobes: int = 1
var grew_at: float = -9.0
var lost_at: float = -9.0
## Its quarry now (the wizard, a scholar or null), and the seconds to its next look and its next bite.
var quarry: Node2D = null
var look_in: float = 0.0
var bite_in: float = 0.0
## Seconds since it last bit (the art lunges), +1 facing right or -1 left, how fast it falls, and
## whether it stands on something; crawling now, and how far it has crawled (px).
var since_bite: float = 9.0
var facing: float = 1.0
var fall_speed: float = 0.0
var grounded: bool = false
var crawling: bool = false
var crawled: float = 0.0
## Rising out of a breach: seconds left of it (it does nothing else meanwhile), of how many.
var rising: float = 0.0
var rise_time: float = 0.0
## Seconds until it grows next, and until it may launch; the tell under way (seconds into it, -1
## while none).
var grow_in: float = GROW_EVERY
var launch_in: float = LAUNCH_EVERY * 0.5
var telling: float = -1.0
## A launched blob in flight: [from, the arc's control point, to, how far along (0 to 1)], or [].
var flight: Array = []
## Its trail of slime, and how far it has crawled since it last laid a smear (px).
var slime: Slime = null
var _since_smear: float = 0.0
## Its own clock (the art).
var t: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	if flight.is_empty():
		move_and_collide(Vector2(0, 64))
	add_to_group(&"abomination")
	if flight.is_empty():
		facing = -1.0 if RisoDecor.h(get_instance_id() % 9973, Vector2i.ZERO, 3) < 0.5 else 1.0
	grow_in = _next_growth()
	lobes = _wound_hp()
	shape(get_instance_id() % 99991)
	var info: MapInfo = MapInfo.instance
	if info != null and is_instance_valid(info.map_elements):
		slime = Slime.new()
		slime.source = self
		info.map_elements.add_child.call_deferred(slime)


## Deal its shape from `seed_value` (see the consts): the central blob on the floor, each blob after
## it grown mostly from the central one (ON_CENTRAL; else from any before it), up or out to a side
## as low as beside it on the floor (never into the floor), its eyes somewhere on its face, and its
## tentacles round the edges, reaching up and out.
func shape(seed_value: int) -> void:
	var r: Callable = func(i: int, salt: int) -> float: return RisoDecor.h(seed_value, Vector2i(i, salt), 77)
	layout.clear()
	parents.clear()
	eyes.clear()
	arms.clear()
	var base: float = lerpf(BASE_R.x, BASE_R.y, r.call(0, 0))
	layout.append(Vector3(0.0, -base, base))
	parents.append(0)
	for i: int in range(1, SPLIT):
		var from: int = 0 if i <= 2 or r.call(i, 1) < ON_CENTRAL else int(r.call(i, 6) * float(i)) % i
		var parent: Vector3 = layout[from]
		parents.append(from)
		var rad: float = lerpf(LOBE_R.x, LOBE_R.y, r.call(i, 2)) * (1.0 - 0.04 * float(i))
		# Up or out to a side, as low as beside it on the floor (the floor keeps it out of the rock).
		var ang: float = lerpf(-PI * 1.08, PI * 0.08, r.call(i, 3))
		var at: Vector2 = Vector2(parent.x, parent.y) + Vector2.from_angle(ang) * (parent.z + rad) * NESTLE
		layout.append(Vector3(at.x, minf(at.y, -rad), rad))
	for i: int in range(SPLIT):
		var lobe: Vector3 = layout[i]
		var mine: Array[Vector3] = []
		var count: int = 2 if lobe.z >= TWO_EYES and r.call(i, 4) < TWO_EYES_SHARE else 1
		for k: int in range(count):
			var size: float = lerpf(EYE_SIZE.x, EYE_SIZE.y, r.call(i, 5 + k)) * (0.7 if count == 2 else 1.0)
			var off: Vector2 = Vector2.from_angle(r.call(i, 7 + k) * TAU) * lobe.z * (0.1 + 0.35 * r.call(i, 9 + k))
			if count == 2:
				off.x += (float(k) - 0.5) * lobe.z * 0.7
			mine.append(Vector3(off.x, off.y, lobe.z * size))
		eyes.append(mine)
		# Spread from one side over the top to the other, crowding towards the top: up and out,
		# never down into the blobs under it.
		var angles: Array[float] = []
		var most: Vector2i = BASE_ARMS if i == 0 else LOBE_ARMS
		var n: int = most.x + int(r.call(i, 11) * float(most.y - most.x + 1))
		for k: int in range(n):
			var span: float = (float(k) + 0.2 + 0.6 * r.call(i, 12 + k)) / float(n) * 2.0 - 1.0
			angles.append(-PI * 0.5 + ARMS_UP * span * absf(span))
		var tentacles: Array[Vector4] = []
		for k: int in range(angles.size()):
			var long: Vector2 = ARM_LONG * (1.0 if i == 0 else 0.85)
			tentacles.append(Vector4(angles[k], lerpf(long.x, long.y, r.call(i, 20 + k)), lerpf(ARM_WIDE.x, ARM_WIDE.y, r.call(i, 28 + k)), r.call(i, 36 + k) * TAU))
		arms.append(tentacles)


## Blob `i` of its layout (its last for any past it).
func lobe_at(i: int) -> Vector3:
	return layout[clampi(i, 0, layout.size() - 1)] if not layout.is_empty() else Vector3(0, -22, 22)


## Start it with `n` blobs (before it enters the scene: a breach's, or one launched off another).
func sprout(n: int) -> void:
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hp = n
		wound.stars = false
	lobes = n


## Coming up out of a breach: it rises for `seconds` before it moves.
func rise(seconds: float) -> void:
	rising = seconds
	rise_time = seconds


## Launched: it flies a quadratic arc from `from` to `to` (world, its middle), FLIGHT seconds long.
func fly(from: Vector2, to: Vector2) -> void:
	var top: float = minf(from.y, to.y) - ARC
	# The control point of a quadratic whose highest point is `top`: twice as high over the line.
	var ctrl: Vector2 = Vector2((from.x + to.x) * 0.5, 2.0 * top - (from.y + to.y) * 0.5)
	flight = [from, ctrl, to, 0.0]


## Whether it is in flight (launched, not yet landed).
func flying() -> bool:
	return not flight.is_empty()


## Point `u` (0 to 1) of the arc from `a` through control `c` to `b`.
static func arc_at(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a * (1.0 - u) * (1.0 - u) + c * 2.0 * (1.0 - u) * u + b * u * u


func stunned() -> bool:
	var stunner: Stunner = Stunner.of(self)
	return stunner != null and stunner.stunned()


## How far through its tell it is (0 to 1), or -1 while not telling.
func tell() -> float:
	return clampf(telling / TELL, 0.0, 1.0) if telling >= 0.0 else -1.0


## Its Wound's hit points (its blobs), at least 0.
func _wound_hp() -> int:
	var wound: Wound = get_node_or_null("Wound") as Wound
	return maxi(0, wound.hp) if wound != null else lobes


func _physics_process(delta: float) -> void:
	t += delta
	since_bite += delta
	_count_lobes()
	if flying():
		_fly_step(delta)
		return
	if rising > 0.0:
		rising = maxf(0.0, rising - delta)
		return
	_fall(delta)
	crawling = false
	if stunned():
		telling = -1.0
		return
	launch_in -= delta * Difficulty.attack()
	if telling >= 0.0:
		telling += delta
		if lobes < SPLIT:
			telling = -1.0
		elif telling >= TELL:
			telling = -1.0
			launch_in = LAUNCH_EVERY
			shed()
		return
	if lobes >= SPLIT and launch_in <= 0.0 and get_tree().get_nodes_in_group(&"abomination").size() < MOST:
		telling = 0.0
		return
	grow_in -= delta * Difficulty.attack()
	if grow_in <= 0.0:
		grow_in = _next_growth()
		grow()
	look_in -= delta
	if look_in <= 0.0:
		look_in = RETARGET
		quarry = _find_quarry()
	if quarry == null or not is_instance_valid(quarry) or quarry.is_queued_for_deletion():
		quarry = null
		return
	var to: Vector2 = quarry.global_position - global_position
	if absf(to.x) > 10.0:
		facing = signf(to.x)
	_bite(delta)
	if absf(to.x) <= 10.0:
		return
	if grounded and test_move(global_transform.translated(Vector2(0, -4)), Vector2(AHEAD * facing, 0)):
		fall_speed = HOP
		grounded = false
	var step: float = SPEED * Difficulty.speed() * facing * delta
	var hit: KinematicCollision2D = move_and_collide(Vector2(step, 0))
	if hit == null or absf(hit.get_normal().x) < 0.7:
		crawling = true
		crawled += absf(step)
		_since_smear += absf(step)
		if grounded and _since_smear >= Slime.GAP and slime != null and is_instance_valid(slime):
			_since_smear = 0.0
			slime.lay(global_position + Vector2(0, FEET), 0.6 + 0.12 * float(lobes))


## In flight: along its arc; landed, it settles onto the floor.
func _fly_step(delta: float) -> void:
	var u: float = minf(1.0, float(flight[3]) + delta / FLIGHT)
	flight[3] = u
	global_position = arc_at(flight[0], flight[1], flight[2], u)
	if u >= 1.0:
		flight = []
		fall_speed = 0.0
		var hit: KinematicCollision2D = move_and_collide(Vector2(0, 64))
		grounded = hit != null and hit.get_normal().y < -0.7
		RisoFx.burst(&"hit", global_position + Vector2(0, FEET), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
		if slime != null and is_instance_valid(slime):
			slime.lay(global_position + Vector2(0, FEET), 1.3)


## Its blobs follow its Wound: one fewer for each wound, a blob bursting from its place.
func _count_lobes() -> void:
	var now: int = _wound_hp()
	if now < lobes:
		for i: int in range(now, lobes):
			var at: Vector3 = lobe_at(i)
			RisoFx.burst(&"hit", global_position + Vector2(at.x * facing, at.y), Vector2.UP, [RisoPrint.PINK, RisoPrint.NIGHT])
		lost_at = t
	lobes = now


## How long until it grows next: GROW_EVERY, give or take GROW_SPREAD of it, by its own hash and
## how long it has lived.
func _next_growth() -> float:
	return GROW_EVERY * (1.0 + GROW_SPREAD * (RisoDecor.h(get_instance_id() % 9973, Vector2i(int(t), 0), 5) * 2.0 - 1.0))


## Grow a blob, up to SPLIT (the launch is its tell's, see the class description).
func grow() -> void:
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound == null or lobes >= SPLIT:
		return
	wound.hp += 1
	lobes = wound.hp
	grew_at = t


## Launch its top blob as a new abomination of one blob, on a quadratic arc to a floor LAND cells
## off (see the class description). Returns the new one, or null at the level's cap.
func shed() -> Abomination:
	var info: MapInfo = MapInfo.instance
	var wound: Wound = get_node_or_null("Wound") as Wound
	if info == null or wound == null or not is_instance_valid(info.map_elements) or get_tree().get_nodes_in_group(&"abomination").size() >= MOST:
		return null
	wound.hp -= 1
	lobes = wound.hp
	var top: Vector3 = lobe_at(lobes)
	var from: Vector2 = global_position + Vector2(top.x * facing, top.y)
	var to: Vector2 = _landing(info, from)
	var spawn: Abomination = (load(scene_file_path) as PackedScene).instantiate() as Abomination
	LevelLoader.arm(spawn, info.here.depth if info.here != null else 0)
	spawn.sprout(1)
	spawn.facing = signf(to.x - from.x) if to.x != from.x else facing
	spawn.fly(from, to)
	info.map_elements.add_child(spawn)
	spawn.global_position = from
	RisoFx.burst(&"hit", from, Vector2(signf(to.x - from.x), -1.0).normalized(), [RisoPrint.PINK, RisoPrint.NIGHT])
	return spawn


## Where a launched blob lands (its middle, world): over a floor LAND cells off, the side dealt by
## its hash first, the nearest first, the first whose arc is clear of rock; else where it is.
func _landing(info: MapInfo, from: Vector2) -> Vector2:
	var here: Vector2i = info.cell_at(global_position)
	var w: LevelGen = info.world
	var floor_up: float = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y * 0.5 - FEET
	var first: int = 1 if RisoDecor.h(get_instance_id() % 9973, Vector2i(int(crawled), int(t)), 9) < 0.5 else -1
	if w != null:
		for side: int in [first, -first]:
			for d: int in range(LAND.x, LAND.y + 1):
				for dy: int in [0, -1, 1]:
					var c: Vector2i = here + Vector2i(side * d, dy)
					if not w.is_valid(c) or w.is_ground(c) or not w.is_ground(c + Vector2i.DOWN):
						continue
					var to: Vector2 = info.cell_position(c) + Vector2(0, floor_up)
					if _arc_clear(info, from, to):
						return to
	return global_position


## Whether the arc from `from` to `to` passes through nothing solid.
func _arc_clear(info: MapInfo, from: Vector2, to: Vector2) -> bool:
	var top: float = minf(from.y, to.y) - ARC
	var ctrl: Vector2 = Vector2((from.x + to.x) * 0.5, 2.0 * top - (from.y + to.y) * 0.5)
	for k: int in range(1, ARC_CHECKS):
		if info.solid_at(arc_at(from, ctrl, to, float(k) / float(ARC_CHECKS))):
			return false
	return true


## The nearest of the wizard and the scholars within SENSE, or null.
func _find_quarry() -> Node2D:
	var best: Node2D = null
	var best_d: float = SENSE
	var player: Player = Stage.player()
	if player != null and is_instance_valid(player) and not player.phasing:
		best_d = minf(best_d, global_position.distance_to(player.global_position))
		if best_d < SENSE:
			best = player
	for node: Node in get_tree().get_nodes_in_group(&"scholar"):
		var s: Node2D = node as Node2D
		if s == null or s.is_queued_for_deletion():
			continue
		var d: float = global_position.distance_to(s.global_position)
		if d < best_d:
			best = s
			best_d = d
	return best


## Bite a scholar within BITE_REACH, every BITE_EVERY seconds.
func _bite(delta: float) -> void:
	bite_in -= delta * Difficulty.attack()
	if bite_in > 0.0 or not (quarry is Scholar):
		return
	if quarry.global_position.distance_to(global_position) > BITE_REACH:
		return
	bite_in = BITE_EVERY
	since_bite = 0.0
	var shield: Shield = Shield.of(quarry)
	var dir: Vector2 = (quarry.global_position - global_position).normalized()
	if shield != null and shield.absorb(false, dir):
		return
	var wound: Wound = quarry.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hit(1, dir)


## Fall until something is underfoot; resting on the floor, stay put (no bounce).
func _fall(delta: float) -> void:
	fall_speed = minf(fall_speed + gravity * delta, MAX_FALL)
	var hit: KinematicCollision2D = move_and_collide(Vector2(0, fall_speed * delta))
	grounded = hit != null and hit.get_normal().y < -0.7
	if hit != null:
		fall_speed = 0.0
