extends TestKit
## Prints the game's icon and its boot splash from the game's own art, into sprites/: the wizard,
## close, on the ground behind them (icon.png, 256 px square, the project's icon before the
## simplified one below), and the boot splash, shown while the game loads: the wizard's mark
## alone on a sheet of night (splash.png; `-- simple` draws only it and the simplified icon). Rerun it
## after the wizard or the menu changes look.
## It also draws the simplified icon (icon_simple.png, 256 px square, and icon_simple_<n>.png at the
## small sizes a taskbar shows): the wizard's head alone as a flat mark (RisoMarks.wizard_mark), no
## halftone, on a rounded square of the garden's night, so it still reads at 16 px. It is the
## project's icon (project.godot's config/icon); icon.png, the whole wizard, is still drawn and kept.
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
## The simplified icon: how big it is drawn before it is scaled down (px a side), how round its
## ground's corners are and how big the mark is on it (shares of its side), where the mark's middle
## is (shares of its side), the realm whose night and paper it takes, and the small sizes also saved.
const SIMPLE_DRAWN: int = 1024
const SIMPLE_CORNER: float = 0.2
const SIMPLE_MARK: float = 0.45
const SIMPLE_AT: Vector2 = Vector2(0.5, 0.61)
const SIMPLE_REALM: StringName = &"garden"
const SIMPLE_SMALL: Array[int] = [64, 32, 16]
## The boot splash: its size (px), where the mark's middle is on it and how big the mark is (a share
## of its height).
const SPLASH_SIZE: Vector2i = Vector2i(1920, 1080)
const SPLASH_AT: Vector2 = Vector2(0.5, 0.56)
const SPLASH_MARK: float = 0.2


## Flat shapes drawn in plain colours, in order (the simplified icon's).
class Flat extends Node2D:
	var shapes: Array[PackedVector2Array] = []
	var colors: Array[Color] = []

	func _draw() -> void:
		for i: int in range(shapes.size()):
			draw_colored_polygon(shapes[i], colors[i])


func run() -> void:
	window()
	await _simple()
	await _splash()
	if "simple" in OS.get_cmdline_user_args():
		finish()
		return
	await boot()
	await _icon()
	finish()


## The simplified icon: the wizard's mark in flat inks on a rounded square of night.
func _simple() -> void:
	var realm: Dictionary = RisoPrint.REALMS[SIMPLE_REALM]
	var inks: Array = realm["inks"]
	var side: float = float(SIMPLE_DRAWN)
	var flat: Flat = Flat.new()
	flat.shapes.append(RisoShapes.rrect(0.0, 0.0, side, side, side * SIMPLE_CORNER, 10))
	flat.colors.append(inks[RisoPrint.NIGHT] as Color)
	_add_mark(flat, SIMPLE_AT * side, side * SIMPLE_MARK)
	var drawn: Image = await _drawn(flat, Vector2i(SIMPLE_DRAWN, SIMPLE_DRAWN))
	var image: Image = drawn.duplicate() as Image
	image.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
	_save(image, "icon_simple.png")
	for px: int in SIMPLE_SMALL:
		var small: Image = drawn.duplicate() as Image
		small.resize(px, px, Image.INTERPOLATE_LANCZOS)
		save_still("icon_simple_%d.png" % px, small)
	save_still("icon_simple.png", image)


## The boot splash: the wizard's mark alone, large, in the middle of a sheet of the same night as
## the simplified icon's ground (project.godot's boot_splash/bg_color is that night too, so the
## sheet has no edge whatever the window's shape).
func _splash() -> void:
	var realm: Dictionary = RisoPrint.REALMS[SIMPLE_REALM]
	var night: Color = (realm["inks"] as Array)[RisoPrint.NIGHT]
	var flat: Flat = Flat.new()
	flat.shapes.append(PackedVector2Array([Vector2.ZERO, Vector2(SPLASH_SIZE.x, 0), Vector2(SPLASH_SIZE), Vector2(0, SPLASH_SIZE.y)]))
	flat.colors.append(night)
	_add_mark(flat, Vector2(SPLASH_SIZE) * SPLASH_AT, float(SPLASH_SIZE.y) * SPLASH_MARK)
	var image: Image = await _drawn(flat, SPLASH_SIZE)
	image.convert(Image.FORMAT_RGB8)
	_save(image, "splash.png")
	save_still("splash.png", image)
	print("splash ground ", night.to_html(false))


## The wizard's mark added to `flat` in its flat inks, its middle at `at`, `r` to its edge.
func _add_mark(flat: Flat, at: Vector2, r: float) -> void:
	var realm: Dictionary = RisoPrint.REALMS[SIMPLE_REALM]
	var inks: Array = realm["inks"]
	var by_part: Dictionary = {
		RisoMarks.WizardMark.HAIR: realm["paper"], RisoMarks.WizardMark.FACE: (inks[RisoPrint.NIGHT] as Color).darkened(0.45),
		RisoMarks.WizardMark.CAP: RisoPrint.CLOTH_INK, RisoMarks.WizardMark.FEATHER: inks[RisoPrint.PINK],
		RisoMarks.WizardMark.EYES: inks[RisoPrint.EYE]}
	var mark: Array[Array] = RisoMarks.wizard_mark(at, r)
	for part: int in range(mark.size()):
		for shape: PackedVector2Array in mark[part]:
			flat.shapes.append(shape)
			flat.colors.append(by_part[part] as Color)


## `flat` drawn on a clear sheet of `size`, as an image.
func _drawn(flat: Flat, size: Vector2i) -> Image:
	var view: SubViewport = SubViewport.new()
	view.size = size
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.add_child(flat)
	root.add_child(view)
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	view.queue_free()
	return image


## The wizard, close, on a clear floor, standing still.
func _icon() -> void:
	freeze()
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
