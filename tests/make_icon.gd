extends TestKit
## Prints the game's icon and its boot splash from the game's own art, into sprites/: the wizard,
## close, on the ground behind them (icon.png, 256 px square, the project's icon and
## so the exported program's), and the start menu's night with the title alone on it, no buttons
## (splash.png, shown while the game loads, so the menu comes up over the same picture). Rerun it
## after the wizard or the menu changes look.
## godot --path . --windowed --resolution 1280x720 --script res://tests/make_icon.gd

## Where the icon and the splash are written.
const OUT: String = "res://sprites"
## How big the icon is, a side.
const ICON_PX: int = 256
## How close the camera comes for the icon.
const ICON_ZOOM: float = 0.7
## The square of the window cut for the icon, the whole wizard in it, feather to boots (window px).
const ICON_CUT: Rect2i = Rect2i(462, 228, 338, 338)
## Where the camera looks, from the wizard's feet, for the icon.
const ICON_LOOK: Vector2 = Vector2(0, -46)


func run() -> void:
	window()
	await _splash()
	await boot()
	await _icon()
	finish()


## The start menu with only its title showing, as the splash.
func _splash() -> void:
	var scene: Node = (load("res://prefabs/scenes/main.tscn") as PackedScene).instantiate()
	RunState.save_path = "user://make_icon.save"
	root.add_child(scene)
	var menu: Menu = scene.get_node("Menu") as Menu
	for child: Node in menu.list.get_children():
		(child as CanvasItem).visible = child == menu.title
	await frames(40)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	_save(image, "splash.png")
	var c: Color = image.get_pixel(4, image.get_height() - 4)
	print("splash ground ", c.to_html(false))
	scene.queue_free()
	await frames(2)


## The wizard, close, on a clear floor, standing still.
func _icon() -> void:
	player.set_physics_process(false)
	player.end_invulnerable()
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED
	var wizard: RisoWizard = player.get_node("RisoWizard") as RisoWizard
	wizard.set_physics_process(false)
	wizard.t = 1.1
	wizard.head_y = 0.0
	wizard.bob = 0.0
	wizard.lean = 0.0
	wizard.fs = 1.0
	RisoPrint.instance.registration = &"locked"
	player.get_node("CameraControl").set_process(false)
	var floor: Vector2i = _clear_floor()
	player.global_position = info.cell_position(floor) + Vector2(0, 64 - wizard._feet_offset() * player.global_scale.y)
	info.loader.sleep_far_chunks(true)
	var camera: Camera2D = Stage.camera()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.zoom = Vector2.ONE * ICON_ZOOM
	camera.global_position = player.global_position + ICON_LOOK
	camera.reset_smoothing()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image().get_region(ICON_CUT)
	image.convert(Image.FORMAT_RGBA8)
	image.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
	_save(image, "icon.png")
	save_still("icon_window.png")


## A floor with open room round it, so nothing stands behind the wizard.
func _clear_floor() -> Vector2i:
	for spot: Vector2i in info.world.free_floors():
		var clear: bool = true
		for x: int in range(-3, 4):
			for y: int in range(-4, 1):
				var cell: Vector2i = spot + Vector2i(x, y)
				if not info.world.is_valid(cell) or info.world.get_cell(cell).type != LevelGen.Type.EMPTY:
					clear = false
		if clear:
			return spot
	return info.world.free_floors()[0]


func _save(image: Image, file: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT).path_join(file)
	check(image.save_png(path) == OK, "wrote %s" % file)
