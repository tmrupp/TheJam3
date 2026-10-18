extends Node
class_name Push
## Push, a damage spell: the Spell button (Q, or the pad's X) blows a gust of spell light out in a
## cone in front of the wizard, aimed like the hex (the held direction, else facing), REACH px out
## and HALF either way. Everything it catches (SpellStrike) is wounded by its damage (none at tier
## I: a push I only shoves), never stunned; an enemy that a parry can stun, and is no boss, is
## shoved SHOVE px away over SHOVE_TIME, into thorns or off a ledge as it may be. Slammed into rock on the way (a
## wall, the floor), it stops there and is wounded SLAM more; what cannot be moved (a boss, the
## worm, a crossbow in its wall, a nest) takes the SLAM at once, with the gust's own wound. Shots in
## the cone (a watcher's, an arrow, the spider's web) are blown away. Every gust throws the wizard
## hard back the other way, whether it catches anything or not (SpellStrike.recoil, at RECOIL): a
## gust down from the air is a big bounce up. Ready again COOLDOWN after.
## Tiers (Abilities): I shoves; II also wounds 1; III reaches and shoves further and
## wider (REACH_III, HALF_III, SHOVE_III); IV wounds 2.

const COOLDOWN: float = 3.0
const REACH: float = 180.0
const HALF: float = 0.6
const SHOVE: float = 160.0
const REACH_III: float = 240.0
const HALF_III: float = 0.8
const SHOVE_III: float = 230.0
const SHOVE_TIME: float = 0.2
## How hard a gust throws the wizard back (SpellStrike.recoil's power: a slash that lands is 1).
const RECOIL: float = 1.6
## How near (px) the wizard a thing is caught whichever way it lies.
const CLOSE: float = 34.0
## The wound of a slam into rock, or against what cannot be moved (on top of the gust's own; a
## stunned enemy takes double, as ever: Wound).
const SLAM: int = 1
## How far ahead of its middle (px) a shoved thing meets rock: about the edge of its body.
const SLAM_PROBE: float = 20.0

var damage: int = 0
var reach: float = REACH
var half: float = HALF
var shove: float = SHOVE
## Seconds until it is ready again.
var wait: float = 0.0

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): see the class description.
func set_tier(n: int) -> void:
	damage = 2 if n >= 4 else (1 if n >= 2 else 0)
	reach = REACH_III if n >= 3 else REACH
	half = HALF_III if n >= 3 else HALF
	shove = SHOVE_III if n >= 3 else SHOVE


## The Spell button, with push in the slot.
func cast_spell() -> bool:
	return cast()


func readiness() -> float:
	return 1.0 - clampf(wait / COOLDOWN, 0.0, 1.0)


## A gust is over at once: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	wait = maxf(0.0, wait - delta)


## Whether a push can shove `e`: an enemy with a Stunner that is not stunned by a parry alone (no
## boss), whole (no worm segment).
static func movable(e: Node) -> bool:
	var stunner: Stunner = Stunner.of(e)
	return stunner != null and not stunner.parry_only and Wound.whole(e) == e


## Whether `p` is in the cone from `from` heading `dir`.
func in_cone(from: Vector2, dir: Vector2, p: Vector2) -> bool:
	var d: Vector2 = p - from
	if d.length() <= CLOSE:
		return true
	return d.length() <= reach and absf(dir.angle_to(d)) <= half


## Push heading `dir` (the aim when zero). False while it is not ready.
func cast(dir: Vector2 = Vector2.ZERO) -> bool:
	if wait > 0.0 or player == null:
		return false
	if dir == Vector2.ZERO:
		dir = SpellStrike.aim(player)
	dir = dir.normalized()
	var from: Vector2 = SpellStrike.origin(player)
	var catches: Callable = func(p: Vector2) -> bool: return in_cone(from, dir, p)
	var catches_spider: Callable = func(s: Spider) -> bool: return s.struck_by(from, from + dir * reach, 0.0)
	SpellStrike.recoil(player, dir, RECOIL)
	SpellStrike.thorns_caught(get_tree(), from, catches, dir)
	for e: Node in SpellStrike.caught(get_tree(), from, catches, catches_spider):
		if not movable(e):
			SpellStrike.strike(e, dir, damage + SLAM, &"push")
			continue
		SpellStrike.strike(e, dir, damage, &"push")
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			var gust: Shove = Shove.new()
			gust.velocity = dir * shove / SHOVE_TIME
			gust.left = SHOVE_TIME
			e.add_child(gust)
	if MapInfo.instance != null:
		for n: Node in MapInfo.instance.map_elements.get_children():
			var shot: Node2D = n as Node2D
			if (shot is Bullet or shot is WebShot) and not shot.is_queued_for_deletion() and in_cone(from, dir, shot.global_position):
				RisoFx.burst(&"hit", shot.global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
				shot.queue_free()
	SpellMark.leave(&"push", from, dir, reach, half, RisoPrint.ACCENT, player)
	wait = COOLDOWN
	return true


## A shove a push gives an enemy: it carries its host along at `velocity` for `left` seconds, then
## goes. Meeting rock on the way (SLAM_PROBE ahead of its middle), it stops there and the host is
## slammed: wounded SLAM, knocked back off the rock.
class Shove:
	extends Node
	var velocity: Vector2 = Vector2.ZERO
	var left: float = 0.0

	func _physics_process(delta: float) -> void:
		var host: Node2D = get_parent() as Node2D
		var info: MapInfo = MapInfo.instance
		if host == null or left <= 0.0 or velocity == Vector2.ZERO:
			queue_free()
			return
		left -= delta
		var to: Vector2 = host.global_position + velocity * delta
		if info != null and info.solid_at(to + velocity.normalized() * SLAM_PROBE):
			var wound: Wound = host.get_node_or_null("Wound") as Wound
			if wound != null and not host.is_queued_for_deletion():
				wound.hit(SLAM, -velocity.normalized())
			queue_free()
			return
		host.global_position = to
