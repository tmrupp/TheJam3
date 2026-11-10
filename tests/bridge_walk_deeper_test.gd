extends "res://tests/bridge_walk_test.gd"
## suite: full (over 15 s: the quick run leaves it to the full one, docs/PERF_PLAN.md 1.2)
## Walking a chasm's bridge, as bridge_walk_test does, over every bridge of the cemetery's second
## level: the two levels walked side by side rather than one after the other.
## godot --headless --path . --script res://tests/bridge_walk_deeper_test.gd


func levels() -> Array[int]:
	return [1]
