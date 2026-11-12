class_name Prefabs
extends RefCounted
## The one keeper of the prefabs gameplay makes for itself (a hit box, a stunner, the ghost, a
## trophy...): each is loaded by its path the first time it is wanted and kept, as Placeables.scene
## keeps what is laid in a cell. No gameplay script `preload`s a scene: a script that does is loaded
## with its scene, and where that scene's own scripts lead back to the script, the scene is kept
## without a part of itself for the rest of the game (docs/CODE_REVIEW.md 1.1, 2.1; unit_test
## checks none does).

## The prefabs more than one script makes.
const HIT_BOX: String = "res://prefabs/hit_box.tscn"
const STUNNER: String = "res://prefabs/stunner.tscn"

static var _scenes: Dictionary = {}


## The scene at `path`, loaded the first time it is asked for.
static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## A new one of the prefab at `path`, not yet in the scene.
static func make(path: String) -> Node:
	return scene(path).instantiate()
