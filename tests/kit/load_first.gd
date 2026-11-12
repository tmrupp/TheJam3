extends SceneTree
## Loads one scene or script first of all, in a process of its own, and says whether it loaded
## (tests/load_sweep.sh, docs/CODE_REVIEW.md 2.1 and 2.6). It names none of the project's classes,
## so nothing is loaded before the resource asked for: a scene that a cycle of loads leaves without
## a part shows as a "Parse Error" in what Godot prints.
## godot --headless --path . --script res://tests/kit/load_first.gd -- res://prefabs/bullet.tscn


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var loaded: Resource = load(path)
	print("LOADED ", path, " ", loaded != null)
	quit()
