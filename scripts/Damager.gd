extends Node

@onready var player: Player = $"/root/Main/Player"
@onready var collider: CollisionShape2D = $"../CollisionShape2D"
@onready var top: Node = $".."
var attacker: Node = null

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
		
