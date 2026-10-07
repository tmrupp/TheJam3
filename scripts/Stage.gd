class_name Stage
extends RefCounted
## The main scene's standing nodes, found in one place so their paths are written once: the
## wizard, the TileMap a level's rock is laid in, the camera, the menu. Each is null when it is not
## there (the start menu has no wizard yet; a test may build only part of the scene). The place
## being played is MapInfo.instance.

const MAIN: String = "Main"


static func _root() -> Window:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


## The main scene's root.
static func main() -> Node:
	var root: Window = _root()
	return root.get_node_or_null(MAIN) if root != null else null


static func _child(path: String) -> Node:
	var m: Node = main()
	return m.get_node_or_null(path) if m != null else null


## The wizard.
static func player() -> Player:
	return _child("Player") as Player


## The TileMap the level's rock is laid in (MapInfo.cell_position and cell_at go through it).
static func tile_map() -> TileMap:
	return _child("TileMap") as TileMap


## The camera following the wizard (it shakes, see CameraEffects).
static func camera() -> CameraEffects:
	return _child("Camera2D") as CameraEffects


## The start menu, which is the pause menu while playing.
static func menu() -> CanvasLayer:
	return _child("Menu") as CanvasLayer
