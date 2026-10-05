extends Node

class_name Stunner
## Stuns its enemy (hex, parry): the listed nodes stop for a while. A new stun extends the
## current one if it would last longer. The ink art shows it (RisoProp: circling stars over the
## head, `fraction()` of the stun left).

var stunnable_nodes: Array[String] = ["Mover", "Shooter", "Hopper", "Wraith", "Bird", "HitBox"]
@onready var top: Node = $".."
@onready var sprite: Sprite2D = $Sprite2D
## Seconds of stun left, and the length of the current stun.
var left: float = 0.0
var total: float = 0.0

func set_stuns (value: bool) -> void:
#	sprite.visible = value
	for n: String in stunnable_nodes:
		var node: Node = top.get_node_or_null(n)
		if node:
			node.stunned = value

func stun (duration: float=2.0) -> void:
	set_stuns(true)
	if duration > left:
		left = duration
		total = duration


## Of the current stun, how much is left (1 just stunned, 0 not stunned).
func fraction() -> float:
	return clampf(left / total, 0.0, 1.0) if total > 0.0 and left > 0.0 else 0.0


func _process(delta: float) -> void:
	if left > 0.0:
		left = maxf(0.0, left - delta)
		if left == 0.0:
			set_stuns(false)
