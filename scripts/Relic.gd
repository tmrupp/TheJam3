extends Area2D
class_name Relic
## A relic (see Relics): one of the big movement abilities, waiting in a secret room. Interact and
## pay its price (Relics.price, a lot) to take it: tier I of its move, or the next tier if the move
## is already known. A relic whose move takes a slot replaces what is in it, which comes back as an
## exam paper at its tier (MapInfo.put_back), as at a shrine. Taken, it is gone for good.

@onready var player: Player = Stage.player()

var map_info: MapInfo
## The move it holds.
var ability: StringName = &""


func setup(info: MapInfo, _v: Vector2i, move: Variant) -> void:
	map_info = info
	ability = StringName(move)


## What it holds now, as [ability, tier taking it gives]: its move, a tier past what is known.
func holds() -> Array:
	return [ability, mini(Abilities.tier(player, ability) + 1, Abilities.max_tier(ability))]


## Would taking it replace what is in its slot?
func swap() -> bool:
	return Abilities.is_swap(player, holds()[0])


## Stars still owed to take it: its price, or nothing for a boss's relic (the fight was its price).
func price() -> int:
	if map_info == null or has_meta(&"boss"):
		return 0
	return Relics.price(map_info.here.depth)


func take() -> void:
	if map_info == null or ability == &"":
		return
	var cost: int = price()
	if player.coins.coins < cost:
		return
	player.collect(-cost)
	var held: Array = holds()
	var a: StringName = held[0]
	var dropped: StringName = Abilities.spell(player, Abilities.slot_of(a)) if Abilities.is_swap(player, a) else &""
	var dropped_tier: int = Abilities.tier(player, dropped) if dropped != &"" else 0
	Abilities.set_tier(player, a, int(held[1]))
	map_info.relic_taken()
	if dropped != &"":
		map_info.put_back(dropped, dropped_tier, global_position + Vector2(0, -40))
	map_info.mark_taken(self)
	# A boss's relic, taken: it waits there no more.
	if has_meta(&"boss"):
		map_info.run.boss_relics.erase(get_meta(&"boss"))
	queue_free()
	map_info.save_run()
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(8.0, 0.2)


func _ready() -> void:
	$Interactable.interacted.connect(take)
