extends Stunnable
class_name Shooter
## The watcher: while it can see the wizard (in range, with a clear line), its eye slowly opens,
## charging toward a shot; when the charge is full it fires and starts again. The moment it loses
## sight the charge resets, so breaking line of sight buys a full cooldown.
## A sky watcher, whose shots rebound (SkyArchetype), hovers instead of growing from the floor: it
## rises up to HOVER_UP over the spot it was placed on (less under rock) and drifts slowly from side
## to side there, bobbing. Its spot in the level is the same, so layouts are unchanged.

## How high a hovering watcher rises, how far it drifts either way, and how fast it goes round.
const HOVER_UP: float = 170.0
const HOVER_DRIFT: float = 70.0
const HOVER_RATE: float = 0.35

## Seconds of charge (in sight) to a shot, and the shot's speed (px/s): few shots, but quick ones.
var cooldown: float = 3.5
var SPEED: int = 260
var projectile_prefab: Resource = preload("res://prefabs/bullet.tscn")
@onready var shoot_point: Node2D = $ShootPoint
@onready var range_box: Area2D = $RangeBox
@onready var player: Player = Stage.player()
@onready var main: Node = Stage.main()
@onready var rb: RigidBody2D = $".."
@onready var shoot_sfx: AudioStreamPlayer = $AudioStreamPlayer
var player_in_range: bool = false
## 0..1: how far toward the next shot (the eye's opening follows it).
var charge: float = 0.0
## Whether it can see the wizard this frame.
var sees: bool = false
## Whether it hovers (see HOVER_UP); where it hangs, how far it may drift there, and its own clock.
var hovering: bool = false
var home: Vector2 = Vector2.INF
var drift: float = 0.0
var hover_t: float = 0.0


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
	# A sky level's watcher fires shots that rebound off walls (SkyArchetype.populate).
	projectile.set("bounces", int(rb.get_meta(&"bounces", 0)))
	shoot_sfx.play()


func _physics_process(delta: float) -> void:
	if hovering and not stunned:
		_hover(delta)
	sees = can_see()
	if not sees:
		charge = 0.0
		return
	if stunned:
		return
	# A harder preset fires more often (Difficulty.attack).
	charge += delta * Difficulty.attack() / cooldown
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
	if int(rb.get_meta(&"bounces", 0)) > 0:
		hovering = true
		rb.gravity_scale = 0.0
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rb.freeze = true


## Hang in the air over its spot, drifting slowly side to side and bobbing. Its height and drift are
## found the first time, from the rock around it (the level is placed by then), never by chance.
func _hover(delta: float) -> void:
	if home == Vector2.INF:
		_find_home()
	hover_t += delta
	rb.global_position = home + Vector2(sin(hover_t * HOVER_RATE * TAU) * drift, sin(hover_t * 1.7) * 8.0)


## How high over its spot it can hang, and how far it can drift there, with clear air around it.
func _find_home() -> void:
	var at: Vector2 = rb.global_position
	var info: MapInfo = MapInfo.instance
	var clear: Callable = func(p: Vector2) -> bool: return info == null or info.world == null or not info.solid_at(p)
	var up: float = 0.0
	while up < HOVER_UP and clear.call(at + Vector2(0, -up - 60.0)):
		up += 10.0
	home = at + Vector2(0, -up)
	drift = 0.0
	while drift < HOVER_DRIFT and clear.call(home + Vector2(drift + 50.0, 0)) and clear.call(home - Vector2(drift + 50.0, 0)):
		drift += 10.0
	hover_t = RisoShapes.hash1(at.x * 0.013 + at.y * 0.007) * 10.0
