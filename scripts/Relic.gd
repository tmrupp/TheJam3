extends Area2D
## A relic (see Relics): one of the big movement abilities, waiting in a secret room. Interact and
## pay its price (Relics.price, a lot) to take it: tier I of its move, or the next tier if the move
## is already known. A relic that brings a spell (levitate) replaces the one in the slot, which is
## left here to take back free, as at a shrine. Once nothing is left here, it is gone for good.

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo
## The move it holds.
var ability: StringName = &""


func setup(info: MapInfo, _v: Vector2i, move: Variant) -> void:
	map_info = info
	ability = StringName(move)


## What it holds now, as [ability, tier taking it gives]: its move, or a spell a swap left here.
func holds() -> Array:
	var left: Array = map_info.record().get("relic_left", []) if map_info != null else []
	if left.size() == 2:
		return [StringName(left[0]), int(left[1])]
	return [ability, mini(Abilities.tier(player, ability) + 1, int(Abilities.MAX[ability]))]


## Would taking it replace the spell in the slot?
func swap() -> bool:
	return Abilities.is_swap(player, holds()[0])


## Stars still owed to take it: its price, or nothing for a spell a swap left here.
func price() -> int:
	if map_info == null or map_info.record().has("relic_left"):
		return 0
	return Relics.price(map_info.coord.y)


func take() -> void:
	if map_info == null or ability == &"":
		return
	var cost: int = price()
	if player.coins.coins < cost:
		return
	player.collect(-cost)
	var held: Array = holds()
	var a: StringName = held[0]
	var was_left: bool = map_info.record().has("relic_left")
	var dropped: StringName = Abilities.spell(player) if Abilities.is_swap(player, a) else &""
	var dropped_tier: int = Abilities.tier(player, dropped) if dropped != &"" else 0
	Abilities.set_tier(player, a, int(held[1]))
	if not was_left:
		map_info.relic_taken()
	if dropped != &"":
		map_info.record()["relic_left"] = [dropped, dropped_tier]
	else:
		map_info.record().erase("relic_left")
		map_info.mark_taken(self)
		queue_free()
	map_info.save_run()
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(8.0, 0.2)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare({&"wall_climb": &"climb"}.get(a, a))


func _ready() -> void:
	$Interactable.interacted.connect(take)
