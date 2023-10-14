extends Area2D

var offset_rotation = {
	Vector2i(-1,0) : -90,
	Vector2i(1,0) : 90,
	Vector2i(0,1) : 180,
	Vector2i(0,-1) : 0,
}

func setup(_map_info, v):
	var world = _map_info.world
	var ns = world.get_neighbors(v)
	if len(ns) == 0:
		queue_free()
	else:
		for n in ns:
			if world.is_ground(n):
				rotation_degrees = offset_rotation[v - n]
				return
	queue_free()

