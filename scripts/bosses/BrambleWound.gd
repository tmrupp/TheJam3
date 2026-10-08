class_name BrambleWound
extends Wound
## A bulb's health (BrambleBulb). It is soft, so any hex bolt or dash wounds it, even one that only
## stuns at its tier (least 1), and so does a seed parried back into it. It is set in the rock, so a
## blow does not knock it about, and it is never stunned. At 0 it bursts (Bramble.burst): no stars,
## nothing kept in the level's record.


func _init() -> void:
	least = 1


func stunned() -> bool:
	return false


func hit(damage: int, dir: Vector2) -> void:
	var bulb: BrambleBulb = get_parent() as BrambleBulb
	if bulb == null or not bulb.alive:
		return
	hp -= damage
	bulb.struck()
	RisoFx.burst(&"hit", bulb.global_position, dir, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(7.0 if hp > 0 else 12.0, 0.14 if hp > 0 else 0.22)
	if hp <= 0:
		_die(bulb)


func _die(host: Node2D) -> void:
	var bulb: BrambleBulb = host as BrambleBulb
	if bulb != null and bulb.bramble != null:
		bulb.bramble.burst(bulb)
