extends Node2D

var cooldown: float = 1.0
var SPEED: int = 100
var projectile_prefab: Resource = preload("res://prefabs/bullet.tscn")
@onready var shoot_point: Node2D = $ShootPoint
@onready var range_box: Area2D = $RangeBox
@onready var player: Player = $"/root/Main/Player"
@onready var main: Node = $"/root/Main"
@onready var rb: RigidBody2D = $".."
@onready var cooldown_indicator: TextureProgressBar = $Cooldown
var stunned: bool = false

func check_player_in_range() -> bool:
	if player_in_range:
		if player in range_box.get_overlapping_bodies():
			return true
	
	player_in_range = false
	return player_in_range

func shooting () -> void:
	while (check_player_in_range()):
		if not stunned and try_shoot():
			cooldown_indicator.enable(cooldown, Color.RED)
			await get_tree().create_timer(cooldown).timeout
		await get_tree().process_frame
	
func try_shoot () -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(shoot_point.global_position, player.global_position)
	query.exclude = [self, range_box]
	query.collide_with_areas = true
	var result: Dictionary = space_state.intersect_ray(query)
	
	if len(result) != 0 and result.collider == player:
		var projectile: Node = projectile_prefab.instantiate()
		
		main.add_child.call_deferred(projectile)
		projectile.position = shoot_point.global_position
		projectile.setup((player.global_position - shoot_point.global_position).normalized()*SPEED, [rb], rb)
		return true
	return false
	
var player_in_range: bool = false
func range_touch (other: Node) -> void:
	if other == player:
		player_in_range = true
		shooting()

func range_stop_touch (other: Node) -> void:
	if other == player:
		player_in_range = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	range_box.connect("body_entered", range_touch)
	range_box.connect("body_exited", range_stop_touch)
