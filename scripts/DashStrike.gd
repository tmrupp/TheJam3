extends Node
class_name DashStrike
## The dash is the wizard's attack. The wizard passes through enemies while dashing (their
## bodies stop blocking, ENEMY_LAYER), and dashing (or blinking) through an enemy stuns it for STUN
## seconds, and with the strike perk wounds it first (Abilities: I 1 damage, II 2, III 3; a
## stunned enemy takes double, see Wound). Each enemy is struck once a dash. Touching an enemy
## never hurts the wizard while they dash, nor for GUARD seconds after from one they struck. A
## shield takes the dash whole (a hit off the shield, no wound or stun) and throws the wizard back.
## Dashing into a cracked wall breaks it (not a secret room's hidden rock: that is found by
## walking in). A blink strikes everything along the way it jumps, and hands back the dash for
## each full moon it passes (Blink.gd).
## Moth swarms scatter for six seconds when struck, and cannot sting through the dash.

const STUN: float = 2.5
## How near the wizard's path an enemy has to be (past its centre) to be struck.
const REACH: float = 64.0
const SPAN_DOWN: float = 20.0
const SPAN_UP: float = 56.0
const GUARD: float = 0.3
## How hard a shield throws the wizard back.
const RECOIL: float = 420.0
## The physics layer enemy bodies are on (project settings: "Enemy").
const ENEMY_LAYER: int = 2

## Wounds dealt per strike (0: the dash only stuns). Set by the strike tier (Abilities.apply).
var damage: int = 0
## The enemies this dash has struck.
var struck: Array[Node] = []
var last: Vector2 = Vector2.ZERO
var was_dashing: bool = false
var guard_left: float = 0.0

@onready var player: Player = get_parent() as Player


func _physics_process(delta: float) -> void:
	var dashing: bool = player.dash.is_acting()
	if dashing and not was_dashing:
		struck.clear()
		last = player.global_position
		player.set_collision_mask_value(ENEMY_LAYER, false)
	if dashing:
		sweep(last, player.global_position)
		last = player.global_position
		_break_walls()
	elif was_dashing:
		guard_left = GUARD
		player.set_collision_mask_value(ENEMY_LAYER, true)
	was_dashing = dashing
	guard_left = maxf(0.0, guard_left - delta)


## Whether touching `attacker` (a contact hit box, Damager) should not hurt the wizard just now.
func guards(attacker: Node) -> bool:
	var enemy: Node = attacker.get("attacker") as Node if attacker != null and "attacker" in attacker else null
	if enemy == null or (enemy.get_node_or_null("Stunner") == null and not enemy.has_method("scatter")):
		return false
	return player.dash.is_acting() or (guard_left > 0.0 and enemy in struck)


## Strike every enemy near the way from `from` to `to` not yet struck this dash, nearest first.
func sweep(from: Vector2, to: Vector2) -> void:
	var dir: Vector2 = (to - from).normalized() if to != from else player.velocity.normalized()
	var targets: Array[Node] = []
	for e: Node in get_tree().get_nodes_in_group(&"hex_target"):
		if e in struck or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if e.get_node_or_null("Stunner") == null and not e.has_method("scatter"):
			continue
		var at: Vector2 = (e as Node2D).global_position
		var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(from, to, at + Vector2(0, SPAN_DOWN), at - Vector2(0, SPAN_UP))
		if near[0].distance_to(near[1]) <= REACH:
			targets.append(e)
	targets.sort_custom(func(a: Node, b: Node) -> bool: return from.distance_squared_to((a as Node2D).global_position) < from.distance_squared_to((b as Node2D).global_position))
	for e: Node in targets:
		struck.append(e)
		if not strike(e, dir):
			return


## Strike `e` heading `dir`. False when a shield stopped the dash.
func strike(e: Node, dir: Vector2) -> bool:
	if e.has_method("scatter"):
		e.call("scatter", dir)
		return true
	var shield: Shield = Shield.of(e)
	if shield != null and shield.absorb(false, dir):
		player.dash.end()
		player.velocity = -dir * RECOIL
		return false
	var wound: Node = e.get_node_or_null("Wound")
	if wound != null and damage > 0:
		wound.call("hit", damage, dir)
	else:
		RisoFx.burst(&"hit", (e as Node2D).global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
		Wound.shake(5.0, 0.12)
	var stunner: Node = e.get_node_or_null("Stunner")
	if stunner != null and is_instance_valid(e) and not e.is_queued_for_deletion():
		stunner.call("stun", STUN)
	return true


## Cracked walls the dash ran into crumble (a secret room's rock is left for the wizard to find).
func _break_walls() -> void:
	for i: int in range(player.get_slide_collision_count()):
		var contact: KinematicCollision2D = player.get_slide_collision(i)
		var hit: Object = contact.get_collider()
		if hit is CrackedWall and not (hit as Node).has_meta(&"secret"):
			(hit as CrackedWall).hex_hit(maxi(damage, 1), -contact.get_normal())
