extends Node2D

@onready var player: Player = $"/root/Main/Player"
var go_to_pos: Vector2

func use_portal() -> void:
	print("used the portal named " + name)
	player.position = go_to_pos

func setup(map_info: MapInfo, _coord: Vector2, partner_coord: Vector2) -> void:
	#print("hello, I am a portal at: " + str(coord) + " whose partner is at: " + str(partner_coord))
	go_to_pos = map_info.tile_map.to_global(map_info.tile_map.map_to_local(partner_coord))

func _ready() -> void:
	$Area2D/Interactable.interacted.connect(use_portal)
