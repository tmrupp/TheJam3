class_name NecromancerWound
extends Wound
## The necromancer's health (Necromancer): the candles on its staff. In the dark a strike passes
## through it (Necromancer.glance); while light falls on it (Necromancer.lit) any hex bolt, dash or
## parry puts out a candle, even one of no damage (least 1), however hard it strikes.
## With the last it crumbles (Necromancer.die): no stars, nothing kept in the level's record.


func _init() -> void:
	least = 1


func stunned() -> bool:
	var stunner: Stunner = Stunner.of(get_parent())
	return stunner != null and stunner.stunned()


func hit(_damage: int, dir: Vector2) -> void:
	var necromancer: Necromancer = get_parent() as Necromancer
	if necromancer == null or necromancer.dying():
		return
	if not necromancer.lit():
		necromancer.glance(dir)
		return
	hp -= 1
	necromancer.wounded(dir)
	Wound.hit_stop(KILL_STOP if hp <= 0 else HIT_STOP)
	if hp <= 0:
		_die(necromancer)


func _die(host: Node2D) -> void:
	var necromancer: Necromancer = host as Necromancer
	if necromancer != null:
		necromancer.die()
