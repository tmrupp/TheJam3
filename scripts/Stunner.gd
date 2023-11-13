extends Node

class_name Stunner

var stunnable_nodes: Array[String] = ["Mover", "Shooter", "HitBox"]
@onready var top: Node = $".."
@onready var sprite: Sprite2D = $Sprite2D
@onready var cooldown: Cooldown = $Cooldown

func set_stuns (value: bool) -> void:
#	sprite.visible = value
	for n: String in stunnable_nodes:
		var node: Node = top.get_node_or_null(n)
		if node:
			node.stunned = value

func stun (duration: float=2.0) -> void:
	set_stuns(true)
	cooldown.enable(duration, Color.GREEN_YELLOW, Color.DARK_SLATE_GRAY)
	await get_tree().create_timer(duration).timeout
	set_stuns(false)
