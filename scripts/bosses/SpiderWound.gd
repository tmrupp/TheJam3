class_name SpiderWound
extends Wound
## The spider's health (Spider): its eyes. Its back is hard, so a strike glances off it, unless it
## is open (Spider.open: biting, stunned, fallen or scurrying on a floor); then any hex bolt, dash
## or parry puts out one of its eyes, even one that only stuns at its tier (least 1), and however
## hard it strikes. With the last eye out it dies (Spider.die): no stars, nothing kept in the
## level's record.


func _init() -> void:
	least = 1


func stunned() -> bool:
	var stunner: Stunner = Stunner.of(get_parent())
	return stunner != null and stunner.stunned()


func hit(_damage: int, dir: Vector2) -> void:
	var spider: Spider = get_parent() as Spider
	if spider == null or spider.dying():
		return
	if not spider.open():
		spider.glance(dir)
		return
	hp -= 1
	spider.lose_eye(dir)
	if hp <= 0:
		_die(spider)


func _die(host: Node2D) -> void:
	var spider: Spider = host as Spider
	if spider != null:
		spider.die()
