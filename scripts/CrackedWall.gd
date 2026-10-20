extends StaticBody2D
class_name CrackedWall
## Cracked rock: solid like the rest until an empowered spell breaks it (Empower, crumble), in every
## band, then it crumbles for good (the level record keeps it broken, even across deaths). A plain
## hex bolt or blow only chips grit off it (hex_hit), and the dash does nothing to it. So cracks
## passed early in a run are locks to come back to once a lodestone has tempered the damage spell
## (LevelGen.place_cracks keeps them off the doors). A secret room's cells are cracked rock too (meta
## "secret", see LevelGen.place_secrets), with no cracks: they look like plain rock. Its entrance is
## a false wall, walked and shot straight through by the wizard (enemies take it for rock,
## LevelLoader.ENEMY_WALL); stepping into it, or an empowered spell breaking the hidden rock behind
## it, opens the whole room (MapInfo.open_secret).

## Every cracked wall in the level, for finding the one at a cell (at).
const GROUP: StringName = &"cracked_rock"


func setup(_info: MapInfo, _v: Vector2i) -> void:
	pass


func _ready() -> void:
	add_to_group(GROUP)


## A plain hit (an unempowered bolt or blow): grit flies, nothing breaks.
func hex_hit(_damage: int, dir: Vector2) -> void:
	if is_queued_for_deletion():
		return
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.BLUE, RisoPrint.NIGHT])


## Broken by an empowered spell heading `dir`: it crumbles for good, or, the hidden rock of a secret
## room, the whole room opens.
func crumble(dir: Vector2) -> void:
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


## The cracked wall standing at level cell `cell`, or null.
static func at(tree: SceneTree, cell: Vector2i) -> CrackedWall:
	for n: Node in tree.get_nodes_in_group(GROUP):
		if not n.is_queued_for_deletion() and n.has_meta(&"cell") and n.get_meta(&"cell") == cell:
			return n as CrackedWall
	return null


## Crumble the cracked walls at `cells` (an empowered spell heading `dir`); how many there were.
static func crumble_cells(tree: SceneTree, cells: Array[Vector2i], dir: Vector2) -> int:
	var n: int = 0
	for c: Vector2i in cells:
		var wall: CrackedWall = at(tree, c)
		if wall != null:
			wall.crumble(dir)
			n += 1
	return n
