extends Node2D
## A level's shrine, near its deeper exit, across three cells. It offers three things; taking any
## one spends it:
## - two boons: the next tier of two different abilities (picked by the level seed, new ones
##   before upgrades), cheaper deeper;
## - mending: healing to full, dearer deeper.
## Pay to learn. There is no menu: interact with the one you want.

const BOONS: int = 2

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


func depth() -> int:
	return map_info.coord.y if map_info != null else 0


func used() -> bool:
	return map_info == null or bool(map_info.record().get("shrine_used", false))


func offers() -> Array[StringName]:
	if map_info == null:
		return []
	return Abilities.offers(MapInfo.level_seed(map_info.coord.x, map_info.coord.y), player, BOONS)


## The ability in niche `i` (0 or 1), or &"" when there is nothing left to offer there.
func offer(i: int = 0) -> StringName:
	var all: Array[StringName] = offers()
	return all[i] if i < all.size() else &""


func offer_tier(i: int = 0) -> int:
	return Abilities.tier(player, offer(i)) + 1


## Learning niche `i` would replace the spell in the slot.
func swap(i: int = 0) -> bool:
	return Abilities.is_swap(player, offer(i))


func offer_price(i: int = 0) -> int:
	return Abilities.price(depth(), offer_tier(i))


func heal_price() -> int:
	return Abilities.heal_price(depth())


func can_mend() -> bool:
	return player.health.health < player.health.max_health


func buy_boon(i: int = 0) -> void:
	var a: StringName = offer(i)
	if used() or a == &"" or not _pay(offer_price(i)):
		return
	Abilities.grant(player, a)
	_spend(get_node("Boon" if i == 0 else "Boon2") as Node2D, [RisoPrint.ACCENT, RisoPrint.PINK])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare({&"wall_climb": &"climb"}.get(a, a))


func buy_mend() -> void:
	if used() or not can_mend() or not _pay(heal_price()):
		return
	player.health.health = player.health.max_health
	player.health.display_health()
	_spend($Mend as Node2D, [RisoPrint.EYE, RisoPrint.PINK])


func _pay(cost: int) -> bool:
	if player.coins.coins < cost:
		return false
	player.collect(-cost)
	return true


func _spend(side: Node2D, inks: Array[int]) -> void:
	map_info.record()["shrine_used"] = true
	map_info.save_run()
	RisoFx.burst(&"gain", side.global_position + Vector2(0, -40), Vector2.ZERO, inks)


func _ready() -> void:
	$Boon/Interactable.interacted.connect(buy_boon.bind(0))
	$Boon2/Interactable.interacted.connect(buy_boon.bind(1))
	$Mend/Interactable.interacted.connect(buy_mend)
