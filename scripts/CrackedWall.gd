extends StaticBody2D
## Cracked rock: solid like the rest until a hex bolt hits it, then it crumbles for good (the
## level record keeps it broken, even across deaths).

func setup(_info: MapInfo, _v: Vector2i) -> void:
	pass


func hex_hit(_damage: int, dir: Vector2) -> void:
	if is_queued_for_deletion():
		return
	if MapInfo.instance != null:
		MapInfo.instance.mark_broken(self)
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.BLUE])
	Wound.shake(14.0, 0.3)
	queue_free()
	# Reprint the rock without this cell.
	if RisoPrint.instance != null and MapInfo.instance != null:
		RisoPrint.instance.world_built(MapInfo.instance, MapInfo.instance.coord.y)
