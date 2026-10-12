extends Node
class_name DashStrike
## What the dash does on its way, now that it is a move and not an attack (the damage spells are,
## Abilities): it neither wounds nor stuns. The wizard passes through enemies while dashing (their
## bodies stop blocking, ENEMY_LAYER, until the wizard is clear of them after it), and touching an
## enemy (or a moth swarm) never hurts them while they dash. The worm's body still blocks the dash
## (WormSegment). Dashing into a cracked wall breaks it (not a secret room's hidden rock: that is
## found by walking in). A dash (or a blink, which jumps while the dash runs, Blink.gd) tears the
## spider's webs it passes through (SpiderWeb) and cuts a spider's thread it crosses (Spider),
## dropping it. Every wizard has one (Player).

## How far either way (px) a dash's way may pass a spider's thread to cut it.
const THREAD_REACH: float = Spider.DASH_THREAD_REACH
## The physics layer enemy bodies are on (project settings: "Enemy").
const ENEMY_LAYER: int = 2

var last: Vector2 = Vector2.ZERO
var was_dashing: bool = false

@onready var player: Player = get_parent() as Player


func _physics_process(_delta: float) -> void:
	var dashing: bool = player.dash.is_acting()
	if dashing and not was_dashing:
		last = player.global_position
		player.set_collision_mask_value(ENEMY_LAYER, false)
	if dashing:
		sweep(last, player.global_position)
		last = player.global_position
		_break_walls()
	# Enemies block the wizard again once the dash is over, but only when no enemy's body is where
	# the wizard is: turned back on with the wizard inside one, the push out could wedge them in
	# the rock or fling them across the level.
	if not dashing and not player.get_collision_mask_value(ENEMY_LAYER) and not _inside_enemy():
		player.set_collision_mask_value(ENEMY_LAYER, true)
	was_dashing = dashing


## Whether the wizard's body overlaps an enemy's.
func _inside_enemy() -> bool:
	var shape: CollisionShape2D = player.collider
	if shape == null or shape.shape == null:
		return false
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = 1 << (ENEMY_LAYER - 1)
	query.exclude = [player.get_rid()]
	return not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Whether touching `attacker` (a contact hit box, Damager) should not hurt the wizard just now:
## while they dash through an enemy or a moth swarm.
func guards(attacker: Node) -> bool:
	var enemy: Node = Damager.attacker_of(attacker)
	if enemy == null or (Stunner.of(enemy) == null and not enemy is MothSwarm):
		return false
	return player.dash.is_acting()


## The dash's way from `from` to `to`: the webs it passes through torn, a thread it crosses cut.
func sweep(from: Vector2, to: Vector2) -> void:
	SpiderWeb.tear_along(get_tree(), from, to)
	var thread: Dictionary = Spider.thread_across(get_tree(), from, to, THREAD_REACH)
	if not thread.is_empty():
		(thread["spider"] as Spider).cut(thread["at"])


## Cracked walls the dash ran into crumble (a secret room's rock is left for the wizard to find).
func _break_walls() -> void:
	for i: int in range(player.get_slide_collision_count()):
		var contact: KinematicCollision2D = player.get_slide_collision(i)
		var hit: Object = contact.get_collider()
		if hit is CrackedWall and not (hit as Node).has_meta(&"secret"):
			(hit as CrackedWall).hex_hit(1, -contact.get_normal())
