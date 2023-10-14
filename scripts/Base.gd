extends Node2D

func shift ():
	var tm : TileMap = $"/root/Main/TileMap"
	var d0 = tm.to_global((tm.map_to_local(Vector2i(0,1)) - tm.map_to_local(Vector2i(0,0))))/2
	$"..".position += (d0.y - (position*$"..".scale).y)*Vector2.DOWN
	
func _ready():
	shift.call_deferred()
