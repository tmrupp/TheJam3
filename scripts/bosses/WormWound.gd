class_name WormWound
extends Wound
## A worm segment's health (WormSegment). Its flesh is soft, so any hex bolt or dash cuts it, even
## one that only stuns at its tier (least 1), but a strike from its thorny side glances off. It is
## stunned while its worm is (the whole worm goes still together, Worm), taking double then as any
## stunned enemy does. At 0 it is not slain like an enemy (no stars, nothing kept in the level's
## record): the worm is cut there (Worm.cut).


func _init() -> void:
	least = 1


## A strike from the thorny side glances off the thorns: sparks, and no wound.
func hit(damage: int, dir: Vector2) -> void:
	var segment: WormSegment = get_parent() as WormSegment
	if segment != null and segment.guarded(dir):
		RisoFx.burst(&"hit", segment.global_position - dir.normalized() * segment.radius, -dir, [RisoPrint.PINK, RisoPrint.ACCENT])
		Wound.shake(4.0, 0.08)
		return
	super(damage, dir)


func stunned() -> bool:
	var stunner: Stunner = Stunner.of(get_parent())
	return stunner != null and stunner.stunned()


func _die(host: Node2D) -> void:
	var segment: WormSegment = host as WormSegment
	if segment != null and segment.worm != null:
		segment.worm.cut(segment)
