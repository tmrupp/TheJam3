extends Node
class_name DashStrike
## What the dash does on its way, now that it is a move and not an attack (the damage spells are,
## Abilities): it neither wounds nor stuns. The wizard passes through enemies while dashing (their
## bodies stop blocking, ENEMY_LAYER, until the wizard is clear of them after it), and touching an
## enemy (or a moth swarm) never hurts them while they dash. The worm's body still blocks the dash
## (WormSegment). It does nothing to cracked rock: only an empowered spell breaks that (Empower,
## CrackedWall). Every wizard has one (Player).

## The physics layer enemy bodies are on (project settings: "Enemy").
const ENEMY_LAYER: int = 2

var was_dashing: bool = false

@onready var player: Player = get_parent() as Player


func _physics_process(_delta: float) -> void:
	var dashing: bool = player.dash.is_acting()
	if dashing and not was_dashing:
		player.set_collision_mask_value(ENEMY_LAYER, false)
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


