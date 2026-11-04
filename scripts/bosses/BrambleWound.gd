class_name BrambleWound
extends Wound
## The health of a bulb (BrambleBulb) or of the bramble's heart (BrambleHeart). It is soft, so any
## hex bolt or dash wounds it, even one that only stuns at its tier (least 1), and so does a seed or
## barb parried back into it. It is set in the rock, so a blow does not knock it about, and it is
## never stunned. A bulb shut in its bark (not in bloom, Bramble.bloom) shrugs blows off, pale,
## all but its own seed parried back into it (HexBolt.parried_blow). At 0 it bursts
## (Bramble.burst): no stars, nothing kept in the level's record.


func _init() -> void:
	least = 1


func stunned() -> bool:
	return false


func hit(damage: int, dir: Vector2) -> void:
	var bulb: BrambleBulb = get_parent() as BrambleBulb
	if bulb == null or not bulb.alive:
		return
	if not bulb.open() and not HexBolt.parried_blow:
		bulb.warded(dir)
		return
	hp -= damage
	bulb.struck()
	RisoFx.burst(&"hit", bulb.global_position, dir, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.felt(bulb, dir, hp <= 0)
	if hp <= 0:
		_die(bulb)


func _die(host: Node2D) -> void:
	var bulb: BrambleBulb = host as BrambleBulb
	if bulb != null and bulb.bramble != null:
		bulb.bramble.burst(bulb)
