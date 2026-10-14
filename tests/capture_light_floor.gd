extends TestKit
## Stills of the carried lantern's light on a floor and under a low ceiling (RisoSight's band into
## the faces it meets, the same depth all along them): in the institute (light_floor_institute.png)
## and the garden (light_floor_garden.png), the wizard standing on a long stretch of floor with the
## ceiling a few cells over it; and in each, the wizard a little way out from a corner where a wall
## rises from the floor (light_corner_*.png), where the bands meet in a mitre.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_light_floor.gd

## How long the stretch of floor is (cells), and how high the ceiling over it may be.
const LONG: int = 7
const HEADROOM: Vector2i = Vector2i(2, 4)

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	for band: StringName in [&"institute", &"garden"]:
		info.coord = Vector2i(28, NextWorldDef.first_depth(band) if band != &"garden" else 0)
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.get_node("CameraControl").set_process(false)
		var spot: Variant = _low_floor()
		if spot == null:
			print("no low stretch of floor in the %s" % band)
			continue
		var at: Vector2i = spot
		player.global_position = info.cell_position(at + Vector2i(LONG / 2, 0))
		var was: Vector2 = camera.zoom
		for i: int in range(40):
			camera.global_position = player.global_position + Vector2(0, -60)
			camera.zoom = was * 1.3
			camera.reset_smoothing()
			await process_frame
		save_still("light_floor_%s.png" % band)
		var corner: Variant = _corner(1)
		var way: int = 1
		if corner == null:
			corner = _corner(-1)
			way = -1
		if corner != null:
			var c: Vector2i = corner
			player.global_position = info.cell_position(c + Vector2i(2 * way, 0))
			for i: int in range(40):
				camera.global_position = info.cell_position(c) + Vector2(60 * way, -60)
				camera.zoom = was * 1.6
				camera.reset_smoothing()
				await process_frame
			save_still("light_corner_%s.png" % band)
		camera.zoom = was
	RunState.delete_save()
	finish()


## The first open floor cell with a wall rising from it (two cells high at least) on its left
## (`way` 1) or its right (-1), and open floor for two cells on from it the other way, or null.
func _corner(way: int) -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		if not (w.is_ground(v + Vector2i(-way, 0)) and w.is_ground(v + Vector2i(-way, -1))):
			continue
		var ok: bool = true
		for k: int in range(0, 3):
			var c: Vector2i = v + Vector2i(k * way, 0)
			if not w.is_valid(c) or w.is_ground(c) or w.is_ground(c + Vector2i.UP) or not w.is_ground(c + Vector2i.DOWN):
				ok = false
				break
		if ok:
			return v
	return null


## The first stretch of open floor LONG cells long with a ceiling HEADROOM cells over it all
## along, as its left cell, or null.
func _low_floor() -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		var roof: int = -1
		for k: int in range(LONG):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.is_ground(c + Vector2i.DOWN):
				ok = false
				break
			var up: int = 1
			while up <= HEADROOM.y and not w.is_ground(c + Vector2i(0, -up)):
				up += 1
			if up < HEADROOM.x or up > HEADROOM.y or (roof != -1 and up != roof):
				ok = false
				break
			roof = up
		if ok:
			return v
	return null
