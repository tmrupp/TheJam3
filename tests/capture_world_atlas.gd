extends TestKit
## Stills of the world atlas (tools/world_atlas): the demo's garden as it opens, its sums over many
## runs, zoomed in on the start (steps and relic letters printed), and the whole game's layout.
## Written to ../art-captures/riso-frames/world_atlas/.
## godot --path . --windowed --resolution 1600x900 --screen 1 --script res://tests/capture_world_atlas.gd
## suite: window


func run() -> void:
	window(Vector2i(1600, 900))
	MapInfo.debug = false
	Bands.use(Bands.DEMO)
	var atlas: Control = (load("res://tools/world_atlas/world_atlas.tscn") as PackedScene).instantiate() as Control
	root.add_child(atlas)
	await frames(3)
	save_still("world_atlas/garden.png")
	atlas.call("_over_runs")
	check(String((atlas.get("_runs") as Label).text).contains("Worm"), "the sums over many runs come up")
	await frames(2)
	save_still("world_atlas/garden_runs.png")
	atlas.set("_tile", 40.0)
	atlas.set("_hover", Vector2i(int(atlas.get("run_seed")) + 1, 2))
	atlas.call("_show_detail")
	atlas.call("_centre")
	await frames(2)
	save_still("world_atlas/garden_zoomed.png")
	atlas.set("_tile", 10.0)
	(atlas.get("_layout_pick") as OptionButton).select(Bands.LAYOUTS.keys().find(Bands.DEFAULT))
	Bands.use(Bands.DEFAULT)
	atlas.call("_relayout")
	await frames(2)
	save_still("world_atlas/full.png")
	finish()
