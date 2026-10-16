class_name BeastWound
extends Wound
## The eldritch beast's health (Beast): the blows its great eye takes once every soul is destroyed
## (BeastSouls). While any soul lives a strike glances off it (Beast.glance), waking it if it
## sleeps; once its eyes are all shut, any hex bolt, dash or parry wounds its great eye by one,
## even one that only stuns at its tier (least 1). With the last it dies (Beast.die): no stars,
## nothing kept in the level's record.


func _init() -> void:
	least = 1


func stunned() -> bool:
	var stunner: Stunner = Stunner.of(get_parent())
	return stunner != null and stunner.stunned()


func hit(_damage: int, dir: Vector2) -> void:
	var beast: Beast = get_parent() as Beast
	if beast == null or beast.dying():
		return
	if not beast.open():
		beast.glance(dir)
		return
	hp -= 1
	beast.wounded(dir)
	if hp <= 0:
		_die(beast)


func _die(host: Node2D) -> void:
	var beast: Beast = host as Beast
	if beast != null:
		beast.die()
