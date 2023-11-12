extends Node

class_name Health

@onready var player: Player = $".."
@onready var hud: Node = $"/root/Main/CanvasLayer/HUD/TopHUD"
@onready var hurt_sfx: AudioStreamPlayer = $AudioStreamPlayer

var max_health: int = 3
var health: int = 3
var health_icons: Array[Node]  = []
var heart_prefab: Resource = preload("res://prefabs/heart.tscn")

func modify_health (delta: int) -> void:
	health += delta
	
	if delta < 0:
		hurt_sfx.play()
	
	if health <= 0:
		health = max_health
		player.die()
		
	display_health()

func display_health () -> void:
	var d: int = len(health_icons) - health
	
	if d > 0:
		for i: int in range(d):
			var hi: Node = health_icons[-1]
			health_icons.erase(hi)
			hi.queue_free()
	else:
		for i: int in range(-d):
			var hi: Node = heart_prefab.instantiate()
			health_icons.append(hi)
			hud.add_child(hi)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	display_health()
