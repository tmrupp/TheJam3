extends Node2D

@onready var player = $"/root/Main/Player"
var go_to_pos

func use_portal():
	print("used the portal named " + name)
	player.position = go_to_pos

func setup(map_info, coord, partner_coord):
	print("hello, I am a portal at: " + str(coord) + " whose partner is at: " + str(partner_coord))
	go_to_pos = map_info.tile_map.to_global(map_info.tile_map.map_to_local(partner_coord))

func _ready():
	$Area2D/Interactable.interacted.connect(use_portal)
