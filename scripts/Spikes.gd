extends Area2D
@onready var player = $"../Player"
func touch(other):
	if other == player:
		other.die()

var offset_rotation = {
	Vector2i(-1,0) : -90,
	Vector2i(1,0) : 90,
	Vector2i(0,1) : 180,
	Vector2i(0,-1) : 0,
}

var world
func setup(_map_info, v):
	world = _map_info.world
	var ns = world.get_neighbors(v)
	if len(ns) == 0:
		queue_free()
	else:
		for n in ns:
			if world.is_ground(n):
				var offset = v - n
				position = position - Vector2(offset)*16
				rotation_degrees = offset_rotation[offset]
				return
	queue_free()

func _ready() -> void:
	connect("body_entered", touch)
