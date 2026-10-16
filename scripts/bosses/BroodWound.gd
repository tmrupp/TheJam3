class_name BroodWound
extends Wound
## The health of the spider's brood (EggSac, Spiderling): one blow of anything, a hex bolt or a
## dash, even one of no damage (least 1), and it bursts. Unlike a level's enemies it drops no
## stars and nothing is kept in the level's record: the spider makes more.


func _init() -> void:
	hp = 1
	least = 1


func _die(host: Node2D) -> void:
	slain.emit()
	RisoFx.burst(&"gain", host.global_position, Vector2.ZERO, [RisoPrint.PINK, RisoPrint.NIGHT])
	host.queue_free()
