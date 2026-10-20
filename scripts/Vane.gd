extends Bell
class_name Vane
## A wind vane on its post, in sky levels, by a gap where a cemetery's bell would stand
## (Chasms.place_bells), chained the same way: by a padlock in a key colour or to a switch on its
## side. It points across its gap, away from its own side (`way`). Freed, switch it on (interact,
## or strike it with a hex bolt) and the level's wind turns its way, as strong as the vanes switched
## on that point that way (Rules.wind_of); switch it off again (the same) and the wind its way is a
## vane weaker. The level record keeps it freed and on (MapInfo.switch_vane).

## The way it points: +1 right, -1 left.
var way: int = 1


func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	super(info, v, extra)
	if chasm >= 0 and chasm < info.world.chasms.size():
		var gap: Dictionary = info.world.chasms[chasm]
		var middle: float = float((gap["left"] as Vector2i).x + (gap["right"] as Vector2i).x) * 0.5
		way = 1 if float(v.x) < middle else -1


## Whether it is switched on.
func rung() -> bool:
	return map_info != null and has_meta(&"cell") and map_info.vane_on(get_meta(&"cell"))


## Interact: unlock its padlock with a key if it has one, then switch it on or off.
func use() -> void:
	if map_info == null:
		return
	if not unchained():
		if lock >= 0 and (player.keyring.has(lock) or player.keyring.spend_skeleton()):
			open()
		else:
			rattle()
			return
	ring()


## Switch it on, or off.
func ring() -> void:
	if map_info == null or not unchained():
		return
	since_rung = 0.0
	map_info.switch_vane(get_meta(&"cell"), way)
	RisoFx.burst(&"gain", global_position + Vector2(0, -110), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(4.0, 0.2)


func _process(delta: float) -> void:
	super(delta)
	# Always to hand: it switches off as well as on.
	$Interactable.available = true
