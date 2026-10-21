class_name Shaped
extends Node2D
## A foe struck only where a blow meets its own shape, not round its middle as other enemies are
## (the golem's chunks, Golem): a hex bolt's way, an arrow's or a spell's reach must come near the
## shape itself (struck_by). The bolt (HexBolt), the arrows (Bullet) and the spells that strike
## where the wizard stands (SpellStrike) ask it so, whatever the foe is. One is in the hex_target
## group, as every enemy is, and may take a blow itself (blow), knowing where it came from and
## whether it was empowered, and says itself what an arrow does to it (arrow_hit).

## How near (px) past its shape a hex bolt's way strikes it.
const BOLT_REACH: float = 12.0


## Whether a way from `from` to `to` (a bolt's step, an arrow's, a spell's reach; a point when the
## two are one) comes within `reach` px of its shape.
func struck_by(_from: Vector2, _to: Vector2, _reach: float) -> bool:
	return false


## Whether it is out of the fight (dying): blows and arrows pass it by.
func done() -> bool:
	return false


## A blow from `from` heading `dir`, of `damage`, `empowered` or not (Empower), from a spell or a
## parry: whether it took the blow itself (true), or it is struck as any enemy is, by its Wound
## (false).
func blow(_from: Vector2, _dir: Vector2, _damage: int, _empowered: bool) -> bool:
	return false


## An arrow (Bullet) met its shape at `at`, heading `dir`.
func arrow_hit(_at: Vector2, _dir: Vector2) -> void:
	pass


## The first foe of this kind whose shape a way from `from` to `to` meets (struck_by), nearest
## `from` first, or null.
static func across(tree: SceneTree, from: Vector2, to: Vector2) -> Shaped:
	var best: Shaped = null
	for node: Node in tree.get_nodes_in_group(&"hex_target"):
		var shaped: Shaped = node as Shaped
		if shaped == null or shaped.is_queued_for_deletion() or shaped.done() or not shaped.struck_by(from, to, 0.0):
			continue
		if best == null or from.distance_squared_to(shaped.global_position) < from.distance_squared_to(best.global_position):
			best = shaped
	return best
