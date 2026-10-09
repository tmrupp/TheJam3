extends StaticBody2D
class_name CrackedWall
## Cracked rock: solid like the rest until a hex bolt or a dash hits it (DashStrike), then it crumbles for good (the
## level record keeps it broken, even across deaths). A secret room's cells are cracked rock too
## (meta "secret", see LevelGen.place_secrets), with no cracks: they look like plain rock.
## Its entrance is a false wall, walked and shot straight through; stepping into it, or a bolt
## striking the hidden rock behind it, opens the whole room (MapInfo.open_secret).

func setup(_info: MapInfo, _v: Vector2i) -> void:
	pass


func hex_hit(_damage: int, dir: Vector2) -> void:
	if is_queued_for_deletion():
		return
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
	if has_meta(&"secret") and MapInfo.instance != null:
		MapInfo.instance.open_secret(int(get_meta(&"secret")))
		return
	if MapInfo.instance != null:
		MapInfo.instance.mark_broken(self)
	RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.BLUE])
	Wound.shake(14.0, 0.3)
	queue_free()
	# Reprint the rock without this cell.
	if RisoPrint.instance != null and MapInfo.instance != null:
		RisoPrint.instance.world_built(MapInfo.instance, MapInfo.instance.coord.y)
