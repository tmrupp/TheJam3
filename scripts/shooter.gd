extends RigidBody2D

var cooldown = 0.2
var SPEED = 100
var projectile_prefab = preload("res://prefabs/bullet.tscn")
@onready var shoot_point = $ShootPoint
@onready var range_box = $RangeBox
@onready var player = $"/root/Main/Player"
@onready var main = $"/root/Main"

func setup (_map_info, _v):
	pass

func check_player_in_range():
	if player_in_range:
		if player in range_box.get_overlapping_bodies():
			return true
	
	player_in_range = false
	return player_in_range

func shooting ():
	while (check_player_in_range()):
		if try_shoot():
			await get_tree().create_timer(cooldown).timeout
		await get_tree().process_frame
	
func try_shoot ():
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(shoot_point.global_position, player.global_position)
	query.exclude = [self, range_box]
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	
#	print("range_box=", range_box)
#	print("trying shoot result", result, " shoot_point.global_position=", shoot_point.global_position, " to player.global_position=", player.global_position)
	
	if len(result) != 0 and result.collider == player:
		var projectile = projectile_prefab.instantiate()
		
		main.add_child.call_deferred(projectile)
		projectile.position = shoot_point.global_position
		projectile.setup((player.global_position - shoot_point.global_position).normalized()*SPEED, [self])
		return true
	return false
	
var player_in_range = false
func range_touch (other):
	if other == player:
		player_in_range = true
		shooting()

func range_stop_touch (other):
	if other == player:
		player_in_range = false

# Called when the node enters the scene tree for the first time.
func _ready():
	range_box.connect("body_entered", range_touch)
	range_box.connect("body_exited", range_stop_touch)
	modulate = Color.ORANGE_RED
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	if (check_player_in_range()):
#		try_shoot()
