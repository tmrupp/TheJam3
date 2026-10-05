extends Node2D
## The watcher: while it can see the wizard (in range, with a clear line), its eye slowly opens,
## charging toward a shot; when the charge is full it fires and starts again. The moment it loses
## sight the charge resets, so breaking line of sight buys a full cooldown.

## Seconds of charge (in sight) to a shot, and the shot's speed (px/s): few shots, but quick ones.
var cooldown: float = 3.5
var SPEED: int = 260
var projectile_prefab: Resource = preload("res://prefabs/bullet.tscn")
@onready var shoot_point: Node2D = $ShootPoint
@onready var range_box: Area2D = $RangeBox
@onready var player: Player = $"/root/Main/Player"
@onready var main: Node = $"/root/Main"
@onready var rb: RigidBody2D = $".."
@onready var shoot_sfx: AudioStreamPlayer = $AudioStreamPlayer
var stunned: bool = false
var player_in_range: bool = false
## 0..1: how far toward the next shot (the eye's opening follows it).
var charge: float = 0.0
## Whether it can see the wizard this frame.
var sees: bool = false


func can_see() -> bool:
	if not player_in_range or player == null or not is_instance_valid(player):
		return false
	if not (player in range_box.get_overlapping_bodies()):
		return false
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	# Only the wizard (layer 1) and the environment (layer 3) block the view: stars, pickups and
	# other areas floating in between used to hide the wizard and cut the eye's real range short.
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(shoot_point.global_position, player.global_position, 1 | 4, [rb.get_rid()])
	var result: Dictionary = space_state.intersect_ray(query)
	return len(result) != 0 and result.collider == player


func shoot() -> void:
	var projectile: Node = projectile_prefab.instantiate()
	main.add_child.call_deferred(projectile)
	projectile.position = shoot_point.global_position
	projectile.setup((player.global_position - shoot_point.global_position).normalized() * SPEED, [rb], rb)
	# A sky level's watcher fires shots that rebound off walls (MapInfo.World.populate_sky).
	projectile.set("bounces", int(rb.get_meta(&"bounces", 0)))
	shoot_sfx.play()


func _physics_process(delta: float) -> void:
	sees = can_see()
	if not sees:
		charge = 0.0
		return
	if stunned:
		return
	charge += delta / cooldown
	if charge >= 1.0:
		charge = 0.0
		shoot()


func range_touch(other: Node) -> void:
	if other == player:
		player_in_range = true


func range_stop_touch(other: Node) -> void:
	if other == player:
		player_in_range = false


func _ready() -> void:
	range_box.connect("body_entered", range_touch)
	range_box.connect("body_exited", range_stop_touch)
