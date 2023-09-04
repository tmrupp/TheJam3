extends Node

var stunnable_nodes = ["Mover", "Shooter", "HitBox"]
@onready var top = $".."
@onready var sprite = $Sprite2D
@onready var cooldown = $Cooldown
func set_stuns (value):
#	sprite.visible = value
	for n in stunnable_nodes:
		var node = top.get_node_or_null(n)
		if node:
			node.stunned = value

func stun (duration=0.5):
	set_stuns(true)
	cooldown.enable(duration, Color.GREEN_YELLOW, Color.DARK_SLATE_GRAY)
	await get_tree().create_timer(duration).timeout
	set_stuns(false)
