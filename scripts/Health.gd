extends Node

@onready var player = $".."
@onready var hud = $"/root/Main/CanvasLayer/TopHUD"

var max_health = 3
var health : int = 3
var health_icons = []
var heart_prefab = preload("res://prefabs/heart.tscn")

func modify_health (delta):
	health += delta
	
	if health <= 0:
		health = max_health
		player.die()
		
	display_health()

func display_health ():
	var d = len(health_icons) - health
	
	if d > 0:
		for i in range(d):
			var hi = health_icons[-1]
			health_icons.erase(hi)
			hi.queue_free()
	else:
		for i in range(-d):
			var hi = heart_prefab.instantiate()
			health_icons.append(hi)
			hud.add_child(hi)

# Called when the node enters the scene tree for the first time.
func _ready():
	display_health()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
#	if Input.is_action_just_pressed("Jump"):
#		health -= 1
#		display_health()
		
	pass
