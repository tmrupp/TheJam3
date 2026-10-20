class_name MendWell
extends Area2D
## A mending bowl standing on its own (a crag tower's top room, CragsArchetype.place_tower_rewards):
## the shrine's mending station (Shrine.buy_mend) without the shrine. While the wizard is hurt,
## interacting with it heals them to full for its price (Abilities.heal_price, dearer deeper); it is
## then spent for good (the level record keeps it, LevelRecord.mended) and its bead goes out. At
## full health it is left for later.

@onready var player: Player = Stage.player()
var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


## Its price: the shrine's mending price for the depth.
func heal_price() -> int:
	return Abilities.heal_price(map_info.here.depth if map_info != null and map_info.here != null else 0)


## Whether it has been used.
func used() -> bool:
	return map_info == null or not has_meta(&"cell") or (map_info.record().mended as Dictionary).has(get_meta(&"cell"))


## Whether there is anything to mend.
func can_mend() -> bool:
	return player != null and player.health.health < player.health.max_health


## Heal to full, if hurt, not yet used and the wizard has its price.
func buy_mend() -> void:
	if used() or not can_mend() or player.coins.coins < heal_price():
		return
	player.collect(-heal_price())
	player.health.health = player.health.max_health
	map_info.record().mended[get_meta(&"cell")] = true
	map_info.save_run()
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.EYE, RisoPrint.PINK])


func _process(_delta: float) -> void:
	($Interactable as Interactable).available = not used() and can_mend()


func _ready() -> void:
	($Interactable as Interactable).interacted.connect(buy_mend)
