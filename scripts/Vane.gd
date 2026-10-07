extends Bell
class_name Vane
## A wind vane on its post, in sky levels, standing by a chasm where a cemetery's bell would
## (Chasms.place_bells), chained the same way: by a padlock in a key colour or to a switch on
## its side. Freed, turn it (interact, or strike it with a hex bolt) and the wind over the chasm
## (Wind) blows from its side across, carrying the wizard over. Turn the one on the far side to
## send the wind back. The level record keeps it freed, and which way the wind blows.


## Whether the chasm's wind blows from this vane.
func rung() -> bool:
	return map_info != null and has_meta(&"cell") and map_info.wind_from(chasm) == get_meta(&"cell")


func unchained() -> bool:
	return map_info != null and has_meta(&"cell") and (map_info.bell_free(get_meta(&"cell")) or rung())


func ring() -> void:
	if map_info == null or rung() or not unchained():
		return
	since_rung = 0.0
	map_info.turn_vane(chasm, get_meta(&"cell"))
	RisoFx.burst(&"gain", global_position + Vector2(0, -110), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(4.0, 0.2)
