extends Area2D

var offset_rotation = {
	Vector2i(-1,0) : -90,
	Vector2i(1,0) : 90,
	Vector2i(0,1) : 180,
	Vector2i(0,-1) : 0,
}

@onready var collider = $CollisionShape2D
var world
var map_info
func setup(_map_info, v):
	world = _map_info.world
	map_info = _map_info
	var ns = world.get_neighbors(v)
	if len(ns) == 0:
		map_info.remove_element(self)
		queue_free()
	else:
		for n in ns:
			if world.is_ground(n):
				var offset = v - n
				# print("$CollisionShape2D.position.y=", $CollisionShape2D.position.y, " scale.y=", scale.y)
				position = position # - (Vector2(offset)*$CollisionShape2D.position.y)
				rotation_degrees = offset_rotation[offset]
				return
	map_info.remove_element(self)
	queue_free()

