extends Node

class_name Stunner
## Stuns its enemy (hex, parry): what drives it (its Stunnable: Mover, Shooter, Hopper, Wraith, Bird)
## stops and its touch (HitBox) stops hurting, for a while. A new stun extends the current one if
## it would last longer. The ink art shows it (RisoProp: circling stars over the head,
## `fraction()` of the stun left).

@onready var top: Node = $".."
## Seconds of stun left, and the length of the current stun.
var left: float = 0.0
var total: float = 0.0


## The Stunner on `host`, or null.
static func of(host: Node) -> Stunner:
	return host.get_node_or_null("Stunner") as Stunner if host != null else null


func set_stuns (value: bool) -> void:
	for node: Node in top.get_children():
		if node is Stunnable:
			(node as Stunnable).stunned = value
		elif node is HitBox:
			(node as HitBox).stunned = value

## Stunned by nothing but a parry (the worm: only a parried bite to its face stuns it; bolts and
## dashes still wound it).
var parry_only: bool = false

## Stun it for `duration` (a `parried` stun is a parry's).
func stun (duration: float=2.0, parried: bool = false) -> void:
	if parry_only and not parried:
		return
	set_stuns(true)
	if duration > left:
		left = duration
		total = duration


## Whether it is stunned now.
func stunned() -> bool:
	return left > 0.0


## Of the current stun, how much is left (1 just stunned, 0 not stunned).
func fraction() -> float:
	return clampf(left / total, 0.0, 1.0) if total > 0.0 and left > 0.0 else 0.0


func _process(delta: float) -> void:
	if left > 0.0:
		left = maxf(0.0, left - delta)
		if left == 0.0:
			set_stuns(false)
