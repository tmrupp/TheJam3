extends Node2D
## A level's shrine, near its deeper exit. It offers two things; taking either spends it:
## - the boon: the next tier of an ability (picked by the level seed), cheaper deeper;
## - mending: healing to full, dearer deeper.
## Pay to learn. There is no menu: interact with the side you want.

@onready var player: Player = $"/root/Main/Player"

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


func depth() -> int:
	return map_info.coord.y if map_info != null else 0


func used() -> bool:
	return map_info == null or bool(map_info.record().get("shrine_used", false))


func offer() -> StringName:
	if map_info == null:
		return &""
	return Abilities.offer(MapInfo.level_seed(map_info.coord.x, map_info.coord.y), player)


func offer_tier() -> int:
	return Abilities.tier(player, offer()) + 1


## Learning the offer would replace the spell in the slot.
func swap() -> bool:
	return Abilities.is_swap(player, offer())


func offer_price() -> int:
	return Abilities.price(depth(), offer_tier())


func heal_price() -> int:
	return Abilities.heal_price(depth())


func can_mend() -> bool:
	return player.health.health < player.health.max_health


func buy_boon() -> void:
	var a: StringName = offer()
	if used() or a == &"" or not _pay(offer_price()):
		return
	Abilities.grant(player, a)
	_spend($Boon as Node2D, [RisoPrint.ACCENT, RisoPrint.PINK])
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
	$Boon/Interactable.interacted.connect(buy_boon)
	$Mend/Interactable.interacted.connect(buy_mend)
