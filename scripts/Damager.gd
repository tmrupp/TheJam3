extends Node
class_name Damager
## Hurts the wizard while they touch its body (its parent, an Area2D), on behalf of `attacker`
## (the enemy, or the shooter of a shot).

@onready var player: Player = Stage.player()
@onready var collider: CollisionShape2D = $"../CollisionShape2D"
@onready var top: Node = $".."
var attacker: Node = null


## The enemy behind a hit on the wizard from `source` (what Player.hurt was given): a Damager's
## attacker, or a swarm of moths itself; null for hazards (thorns, lasers) that belong to no one.
static func attacker_of(source: Node) -> Node:
	if source is Damager:
		return (source as Damager).attacker
	if source is MothSwarm:
		return source
	return null


var knock_back_factor: float = 400
func touch(other: Node) -> void:
	if other == player:
		touching_player = true
		
func stop_touch(other: Node) -> void:
	if other == player:
		touching_player = false
	pass

var touching_player: bool = false

func _ready() -> void:
	top.connect("body_entered", touch)
	top.connect("body_exited", stop_touch)
	if attacker == null:
		attacker = $"../.."
	
func _physics_process(_delta: float) -> void:
	if touching_player:
		if player in top.get_overlapping_bodies():
			var d: Vector2 = (player.position - collider.get_global_position()).normalized()
			player.hurt(-1, d * knock_back_factor, self)
		else:
			touching_player = false
		
