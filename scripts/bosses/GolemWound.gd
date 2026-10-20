class_name GolemWound
extends Wound
## The golem's health (Golem): its heart's wounds. Every blow on the golem is the golem's own to take
## (Golem.blow), meeting the part of it nearest where it came from; one that comes here (a parry,
## Parry) is taken so too, from a little way back along its way. No stars, nothing kept in the
## level's record.

## How far back (cells) along its way a blow that comes here is taken to come from.
const BACK: float = 2.0


func _init() -> void:
	least = 1
	stars = false


func stunned() -> bool:
	var stunner: Stunner = Stunner.of(get_parent())
	return stunner != null and stunner.stunned()


func hit(damage: int, dir: Vector2) -> void:
	var golem: Golem = get_parent() as Golem
	if golem == null or golem.done():
		return
	golem.blow(golem.heart_center() - dir.normalized() * golem.cell * BACK, dir, damage, false)
