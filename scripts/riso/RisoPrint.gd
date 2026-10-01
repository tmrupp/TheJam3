class_name RisoPrint
extends Node
## Tarot-print presentation for the main game.
##
## Art nodes draw ink *coverage* onto six plates (night, blue, pink, accent, eye yellow,
## hat glow) by living on plate visibility layers. Each plate is a SubViewport that shares the
## game World2D and culls to its layer. A full-screen shader then prints the plates like a
## risograph (see shaders/riso_print.gdshader). Legacy sprites stay on the default layer, so they
## render under the print and reappear when the print is switched off (F6).
## F7 opens print controls, F8 cycles the realm. Launch with `-- --no-riso` to start without it.

const NIGHT: int = 0
const BLUE: int = 1
const PINK: int = 2
const ACCENT: int = 3
const EYE: int = 4
const GLOW: int = 5
const PLATE_COUNT: int = 6
const PLATE_BIT0: int = 12
const OVERLAY_BIT: int = 18
const PRINT_SHADER: Shader = preload("res://shaders/riso_print.gdshader")

const REALMS: Dictionary = {
	&"deep": {"paper": Color("#e4dfe8"), "inks": [Color("#161b3a"), Color("#3d5588"), Color("#ff48b0"), Color("#ffb511"), Color("#ffe800")]},
	&"twilight": {"paper": Color("#ebe1cf"), "inks": [Color("#2a2350"), Color("#3255a4"), Color("#ff48b0"), Color("#ffe800"), Color("#ffe800")]},
	&"aurora": {"paper": Color("#e2eadf"), "inks": [Color("#0f2a2c"), Color("#00838a"), Color("#ff48b0"), Color("#765ba7"), Color("#ffe800")]},
}
const REALM_ORDER: Array[StringName] = [&"deep", &"twilight", &"aurora"]
## Hat-tip glow ink per ability (real Riso ink colours).
const GLOWS: Dictionary = {
	&"dash": Color("#ff48b0"),
	&"blink": Color("#9d7ad2"),
	&"astral": Color("#5ec8e5"),
	&"parry": Color("#ffe800"),
	&"climb": Color("#00a95c"),
	&"double_jump": Color("#ff6c2f"),
	&"hex": Color("#e8335a"),
}
## Print-detail stops: heavy 0, medium 50, fine 80, extra fine 100 (sizes in 720p pixels).
const DETAIL_STOPS: Array[Array] = [
	[0.0, 5.8, 1.7, 0.34, 1.8, 0.25],
	[50.0, 4.4, 1.0, 0.22, 1.3, 0.17],
	[80.0, 3.4, 0.6, 0.14, 1.0, 0.12],
	[100.0, 2.6, 0.4, 0.1, 0.8, 0.09],
]
## Base misregistration per plate, in 720p pixels.
## Kept within ~1px of blue (night prints at blue's offset) so paper rims beside shapes stay slight.
const REGISTRATION: Array[Vector2] = [Vector2(-0.4, -0.35), Vector2(-0.35, 0.3), Vector2(0.35, -0.2), Vector2(0.15, 0.55), Vector2(0.0, 0.15), Vector2(0.05, 0.2)]
## Key colours as overprints of the realm inks: sun, ember (sun over pink), moss (sun over blue), plum (pink over blue).
const KEY_COLORS: Array[Array] = [[ACCENT], [ACCENT, PINK], [ACCENT, BLUE], [PINK, BLUE]]

static var instance: RisoPrint

@export var enabled: bool = true
var detail: float = 80.0
var sheet_rate: float = 8.0
var reprint_on_motion: bool = true
var blend_sheets: bool = true
var registration: StringName = &"sheet"
var realm: StringName = &"twilight"
## Camera zoom while printing, relative to the scene's own zoom (smaller shows more).
var zoom_factor: float = 0.72
var _camera: Camera2D
var _base_zoom: Vector2 = Vector2.ZERO
var glow_ability: StringName = &"dash"

var plates: Array[SubViewport] = []
var overlay: SubViewport
var print_layer: CanvasLayer
var print_rect: ColorRect
var overlay_rect: TextureRect
var print_material: ShaderMaterial
var background: Node2D
var terrain: Node2D
var hud: Node2D
var map_view: Node2D
var decor: Node2D
var light: Node2D
var ambient: Node2D
var transition: Node2D
var panel: Control

var sheet_index: int = 0
var sheet_frac: float = 0.0
var _was_on_floor: bool = true
var _old_scale_mode: Window.ContentScaleMode
var _old_cull_mask: int = 0
var _old_snap: bool = false
var _player: Player
var _map_info: Node
var _started: bool = false


## Called just before an unlocked door is freed: leaves a printed opening in its place.
static func door_opened(door: Node2D) -> void:
	if not is_on() or door == null:
		return
	var fx: Node2D = Node2D.new()
	fx.set_script(preload("res://scripts/riso/RisoDoorOpen.gd"))
	var tm: TileMap = door.get_node_or_null("/root/Main/TileMap") as TileMap
	var ground: float = 64.0
	var half: float = 64.0
	if tm != null and tm.tile_set != null:
		half = float(tm.tile_set.tile_size.y) * tm.global_scale.y * 0.5
		var cell: Vector2i = tm.local_to_map(tm.to_local(door.global_position))
		ground = tm.to_global(tm.map_to_local(cell)).y + half - door.global_position.y
	fx.set("ground", ground)
	fx.set("half", half)
	fx.set("key_color", int(door.get_meta(&"key_color", 0)))
	door.get_parent().add_child(fx)
	fx.global_position = door.global_position


static func key_inks(color: int) -> Array[int]:
	var out: Array[int] = []
	for plate: int in KEY_COLORS[posmod(color, KEY_COLORS.size())]:
		out.append(plate)
	return out


static func plate_mask(p: int) -> int:
	return 1 << (PLATE_BIT0 + p)


static func overlay_mask() -> int:
	return 1 << OVERLAY_BIT


static func is_on() -> bool:
	return instance != null and instance.enabled


## Every plate/overlay bit, for ancestors of ink art.
static func all_ink_bits() -> int:
	var mask: int = overlay_mask()
	for i: int in range(PLATE_COUNT):
		mask |= plate_mask(i)
	return mask


## A viewport only renders a CanvasItem whose ancestors share its layer, so open the chain.
static func share_layers(node: Node) -> void:
	var p: Node = node.get_parent()
	while p != null:
		if p is CanvasItem:
			(p as CanvasItem).visibility_layer |= all_ink_bits()
		p = p.get_parent()


func _enter_tree() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _started:
		_restore_viewport()
		RisoTheme.restore()
	if instance == self:
		instance = null


func _ready() -> void:
	if "--no-riso" in OS.get_cmdline_user_args():
		enabled = false
	var root: Viewport = get_viewport()
	_old_scale_mode = get_window().content_scale_mode
	_old_cull_mask = root.canvas_cull_mask
	_old_snap = root.snap_2d_transforms_to_pixel
	_build()
	get_tree().node_added.connect(_on_node_added)
	_dress_existing(get_tree().root)
	_started = true
	_apply_enabled()


func _build() -> void:
	var main: Node = get_parent()
	for i: int in range(PLATE_COUNT):
		plates.append(_make_viewport(plate_mask(i)))
	overlay = _make_viewport(overlay_mask())
	print_layer = CanvasLayer.new()
	print_layer.layer = 1
	print_layer.name = "RisoPrintLayer"
	add_child(print_layer)
	print_rect = ColorRect.new()
	print_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	print_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print_material = ShaderMaterial.new()
	print_material.shader = PRINT_SHADER
	print_rect.material = print_material
	print_layer.add_child(print_rect)
	for i: int in range(PLATE_COUNT):
		print_material.set_shader_parameter("plate%d" % i, plates[i].get_texture())
	overlay_rect = TextureRect.new()
	overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay_rect.stretch_mode = TextureRect.STRETCH_SCALE
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_rect.texture = overlay.get_texture()
	print_layer.add_child(overlay_rect)
	background = Node2D.new()
	background.name = "RisoBackground"
	background.set_script(preload("res://scripts/riso/RisoBackground.gd"))
	main.add_child.call_deferred(background)
	if main is CanvasItem:
		(main as CanvasItem).visibility_layer |= all_ink_bits()
	terrain = Node2D.new()
	terrain.name = "RisoTerrain"
	terrain.set_script(preload("res://scripts/riso/RisoTerrain.gd"))
	main.add_child.call_deferred(terrain)
	decor = Node2D.new()
	decor.name = "RisoDecor"
	decor.set_script(preload("res://scripts/riso/RisoDecor.gd"))
	main.add_child.call_deferred(decor)
	light = Node2D.new()
	light.name = "RisoLight"
	light.set_script(preload("res://scripts/riso/RisoLight.gd"))
	main.add_child.call_deferred(light)
	ambient = Node2D.new()
	ambient.name = "RisoAmbient"
	ambient.set_script(preload("res://scripts/riso/RisoAmbient.gd"))
	ambient.set("decor", decor)
	ambient.set("light", light)
	main.add_child.call_deferred(ambient)
	transition = Node2D.new()
	transition.name = "RisoTransition"
	transition.set_script(preload("res://scripts/riso/RisoTransition.gd"))
	main.add_child.call_deferred(transition)
	hud = Node2D.new()
	hud.name = "RisoHud"
	hud.set_script(preload("res://scripts/riso/RisoHud.gd"))
	main.add_child.call_deferred(hud)
	map_view = Node2D.new()
	map_view.name = "RisoMap"
	map_view.set_script(preload("res://scripts/riso/RisoMap.gd"))
	main.add_child.call_deferred(map_view)
	var fx: Node2D = Node2D.new()
	fx.name = "RisoFx"
	fx.set_script(preload("res://scripts/riso/RisoFx.gd"))
	main.add_child.call_deferred(fx)
	_build_panel()


func _make_viewport(mask: int) -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.world_2d = get_viewport().world_2d
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_cull_mask = mask
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.snap_2d_transforms_to_pixel = false
	vp.snap_2d_vertices_to_pixel = false
	# Antialiased coverage: soft edges become dot ramps in the print, as on a real screen.
	vp.msaa_2d = Viewport.MSAA_4X
	vp.size = _screen_size()
	add_child(vp)
	return vp


func _screen_size() -> Vector2i:
	var s: Vector2i = get_window().size
	if s.x < 16 or s.y < 16:
		s = Vector2i(1280, 720)
	return s


func set_enabled(value: bool) -> void:
	enabled = value
	_apply_enabled()


func _apply_enabled() -> void:
	var root: Viewport = get_viewport()
	if enabled:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		var hidden: int = overlay_mask()
		for i: int in range(PLATE_COUNT):
			hidden |= plate_mask(i)
		root.canvas_cull_mask = _old_cull_mask & ~hidden
		root.snap_2d_transforms_to_pixel = false
	else:
		_restore_viewport()
	_apply_zoom()
	print_layer.visible = enabled
	for vp: SubViewport in plates:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	overlay.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	for art: Node in get_tree().get_nodes_in_group(&"riso_art"):
		if art is CanvasItem:
			(art as CanvasItem).visible = enabled
	_apply_ui()


## Menus take the riso theme; the pixel HUD and title art give way to the printed HUD and sky.
func _apply_ui() -> void:
	if enabled:
		RisoTheme.apply(realm)
	else:
		RisoTheme.restore()
	var main: Node = get_parent()
	for path: String in ["CanvasLayer/HUD/TopHUD", "Menu/BigBossMenu"]:
		var item: CanvasItem = main.get_node_or_null(path) as CanvasItem
		if item != null:
			item.visible = not enabled
	var keys: CanvasItem = main.get_node_or_null("CanvasLayer/HUD/Keys") as CanvasItem
	if keys != null:
		keys.modulate.a = 0.0 if enabled else 1.0


func _apply_zoom() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		if _camera == null:
			return
		_base_zoom = _camera.zoom
	_camera.zoom = _base_zoom * (zoom_factor if enabled else 1.0)


func set_zoom_factor(value: float) -> void:
	zoom_factor = value
	_apply_zoom()


func _restore_viewport() -> void:
	var root: Viewport = get_viewport()
	if root == null:
		return
	get_window().content_scale_mode = _old_scale_mode
	var shown: int = overlay_mask()
	for i: int in range(PLATE_COUNT):
		shown |= plate_mask(i)
	root.canvas_cull_mask = _old_cull_mask & ~shown
	root.snap_2d_transforms_to_pixel = _old_snap


func _process(delta: float) -> void:
	if not enabled:
		return
	var root: Viewport = get_viewport()
	var size: Vector2i = _screen_size()
	var k: float = minf(1.0, 1080.0 / float(size.y))
	var plate_size: Vector2i = Vector2i(roundi(size.x * k), roundi(size.y * k))
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO) * root.get_final_transform() * root.canvas_transform
	for vp: SubViewport in plates:
		if vp.size != plate_size:
			vp.size = plate_size
		vp.canvas_transform = xf
	if overlay.size != plate_size:
		overlay.size = plate_size
	overlay.canvas_transform = xf
	_track_player()
	if not get_tree().paused:
		_advance_sheet(delta)
	_update_uniforms(Vector2(size))


func _track_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var main: Node = get_parent()
	if main.has_node("Player"):
		_player = main.get_node("Player") as Player
		if _player != null:
			_player.visual_event.connect(_on_player_event)
			_player.parry.connect(func() -> void: flare(&"parry"))


func _on_player_event(kind: StringName, _at: Vector2) -> void:
	if kind == &"jump":
		var feet: Node2D = _player.get_node_or_null("RisoWizard") as Node2D
		RisoFx.burst(&"jump", feet.global_position if feet != null else _at)
	elif kind == &"hurt":
		RisoFx.burst(&"hit", _at + Vector2(0, -20), -_player.velocity.normalized())
	if kind == &"projection_start":
		flare(&"astral")
	elif kind == &"jump" and _player != null and _player.MAX_JUMPS > 1 and _player.jumps < _player.MAX_JUMPS and not _player.is_on_floor():
		flare(&"double_jump")
	if reprint_on_motion and registration == &"sheet" and sheet_rate > 0.0:
		if kind in [&"jump", &"dash", &"hurt", &"death", &"projection_start", &"projection_end"]:
			_new_sheet()


## Called by the wizard (or ability events) when an ability fires: the hat glow takes its ink.
func flare(ability: StringName) -> void:
	glow_ability = ability
	var wizard: Node = null
	if _player != null and is_instance_valid(_player):
		wizard = _player.get_node_or_null("RisoWizard")
	if wizard != null:
		wizard.call("flare")


func _new_sheet() -> void:
	sheet_index += 1
	sheet_frac = 0.0


func _advance_sheet(delta: float) -> void:
	var rate: float = sheet_rate
	if reprint_on_motion and _player != null and is_instance_valid(_player):
		var on_floor: bool = _player.is_on_floor()
		rate *= clampf(absf(_player.velocity.x) / Player.SPEED * 0.8 + (0.0 if on_floor else 0.6), 0.0, 1.5)
		if on_floor and not _was_on_floor and sheet_rate > 0.0:
			_new_sheet()
		_was_on_floor = on_floor
	# Each sheet lasts a random 0.6x-1.8x of the nominal interval, so reprints never fall into a beat.
	sheet_frac += rate * delta / (0.6 + RisoShapes.hash1(float(sheet_index) * 0.37 + 5.1) * 1.2)
	while sheet_frac >= 1.0:
		sheet_index += 1
		sheet_frac -= 1.0


func _sheet_seed(i: int) -> float:
	return RisoShapes.hash1(float(i) * 0.6180339 + 11.3) * 97.0 + 1.0


func _sheet_mix() -> float:
	if registration != &"sheet" or not blend_sheets:
		return 0.0
	return sheet_frac * sheet_frac * (3.0 - 2.0 * sheet_frac)


func _detail_params() -> PackedFloat32Array:
	for i: int in range(DETAIL_STOPS.size() - 1):
		var a: Array = DETAIL_STOPS[i]
		var b: Array = DETAIL_STOPS[i + 1]
		if detail <= float(b[0]):
			var u: float = (detail - float(a[0])) / (float(b[0]) - float(a[0]))
			var out: PackedFloat32Array = PackedFloat32Array()
			for k: int in range(1, 6):
				out.append(lerpf(float(a[k]), float(b[k]), u))
			return out
	var last: Array = DETAIL_STOPS[DETAIL_STOPS.size() - 1]
	return PackedFloat32Array([float(last[1]), float(last[2]), float(last[3]), float(last[4]), float(last[5])])


func _jitter(i: int, k: int) -> Vector2:
	return Vector2(RisoShapes.hash1(float(i) * 57.31 + float(k) * 13.77) - 0.5, RisoShapes.hash1(float(i) * 57.31 + float(k + 9) * 13.77) - 0.5)


func _update_uniforms(size: Vector2) -> void:
	var s: float = size.y / 720.0
	var params: PackedFloat32Array = _detail_params()
	var info: Dictionary = REALMS[realm]
	var inks: Array = info["inks"]
	print_material.set_shader_parameter("res", size)
	print_material.set_shader_parameter("paper", info["paper"])
	for i: int in range(5):
		var c: Color = inks[i]
		print_material.set_shader_parameter("ink%d" % i, Vector3(c.r, c.g, c.b))
	var g: Color = GLOWS.get(glow_ability, GLOWS[&"dash"])
	print_material.set_shader_parameter("ink5", Vector3(g.r, g.g, g.b))
	var t: float = Time.get_ticks_msec() / 1000.0
	var m: float = _sheet_mix()
	for i: int in range(PLATE_COUNT):
		var o: Vector2 = REGISTRATION[i]
		if registration == &"sheet":
			o += _jitter(sheet_index, i).lerp(_jitter(sheet_index + 1, i), m) * 0.45
		elif registration == &"drift":
			o += Vector2(sin(t * 0.7 + float(i) * 2.1), cos(t * 0.53 + float(i) * 1.3)) * 1.2
		print_material.set_shader_parameter("off%d" % i, o * s)
	print_material.set_shader_parameter("cell", params[0] * s)
	print_material.set_shader_parameter("wob", params[1] * s)
	print_material.set_shader_parameter("grain", params[2])
	print_material.set_shader_parameter("gain", params[3] * s)
	print_material.set_shader_parameter("lay", params[4])
	print_material.set_shader_parameter("seed", _sheet_seed(sheet_index) if registration == &"sheet" else 3.1)
	print_material.set_shader_parameter("seed2", _sheet_seed(sheet_index + 1))
	print_material.set_shader_parameter("mixv", m)
	# Pin the print to the world: the shader adds the camera's pixel offset to every noise lookup.
	var root: Viewport = get_viewport()
	var view: Transform2D = root.get_final_transform() * root.canvas_transform
	print_material.set_shader_parameter("pin", -view.origin)


func set_realm(r: StringName) -> void:
	if REALMS.has(r):
		realm = r
		if background != null:
			background.queue_redraw()
		if enabled and _started:
			RisoTheme.apply(realm)
		_sync_panel()


func cycle_realm() -> void:
	var i: int = REALM_ORDER.find(realm)
	set_realm(REALM_ORDER[(i + 1) % REALM_ORDER.size()])


## Called by MapInfo when a world has been laid out.
func world_built(map_info: Node, _world_index: int) -> void:
	_map_info = map_info
	if terrain != null and is_instance_valid(terrain):
		var ledges: Array[Vector2] = []
		var cracked: Array[Vector2] = []
		var elements: Node = map_info.get("map_elements") as Node
		if elements != null:
			for node: Node in elements.get_children():
				if node.is_queued_for_deletion():
					continue
				if node.scene_file_path == "res://prefabs/platform.tscn":
					ledges.append((node as Node2D).global_position)
				elif node.scene_file_path == "res://prefabs/cracked_wall.tscn":
					cracked.append((node as Node2D).global_position)
		terrain.call("rebuild", map_info.get("tile_map"), ledges, cracked)
		if decor != null and is_instance_valid(decor):
			decor.call("rebuild", map_info, cracked)
		if light != null and is_instance_valid(light):
			light.call("rebuild", map_info)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F6:
		set_enabled(not enabled)
	elif key.keycode == KEY_F7:
		panel.visible = not panel.visible
	elif key.keycode == KEY_F8:
		cycle_realm()


# ---------------------------------------------------------------- dressing prefabs

const DRESS: Dictionary = {
	"res://prefabs/player.tscn": &"wizard",
	"res://prefabs/mover_enemy.tscn": &"wisp",
	"res://prefabs/shooter_enemy.tscn": &"watcher",
	"res://prefabs/bullet.tscn": &"shard",
	"res://prefabs/coin.tscn": &"mote",
	"res://prefabs/key.tscn": &"key",
	"res://prefabs/map_shard.tscn": &"inkwell",
	"res://prefabs/portal.tscn": &"portal",
	"res://prefabs/door.tscn": &"door",
	"res://prefabs/checkpoint.tscn": &"lantern",
	"res://prefabs/level_exit.tscn": &"exit",
	"res://prefabs/shrine.tscn": &"shrine",
	"res://prefabs/astral_projection_point.tscn": &"orb",
	"res://prefabs/spikes.tscn": &"thorns",
	"res://prefabs/corpse.tscn": &"ghost",
	"res://prefabs/moving_platform.tscn": &"lift",
	"res://prefabs/cracked_wall.tscn": &"cracked",
}


func _dress_existing(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_dress_existing(child)


func _on_node_added(node: Node) -> void:
	if node.scene_file_path != "" and DRESS.has(node.scene_file_path):
		_dress.call_deferred(node, DRESS[node.scene_file_path])
	elif node.name == "Interactable":
		_add_prompt.call_deferred(node)
	elif node.name == "Cooldown":
		_lift_to_overlay.call_deferred(node)


func _dress(node: Node, kind: StringName) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node.has_node("RisoWizard") or node.has_node("RisoArt"):
		return
	var art: Node2D = Node2D.new()
	if kind == &"wizard":
		art.name = "RisoWizard"
		art.set_script(preload("res://scripts/riso/RisoWizard.gd"))
	else:
		art.name = "RisoArt"
		art.set_script(preload("res://scripts/riso/RisoProp.gd"))
		art.set("kind", kind)
	art.add_to_group(&"riso_art")
	art.visible = enabled
	node.add_child(art)
	share_layers(art)


func _add_prompt(interactable: Node) -> void:
	if not is_instance_valid(interactable) or not (interactable.get_parent() is Node2D):
		return
	var host: Node2D = interactable.get_parent() as Node2D
	if host.has_node("RisoPrompt"):
		return
	var prompt: Node2D = Node2D.new()
	prompt.name = "RisoPrompt"
	prompt.set_script(preload("res://scripts/riso/RisoPrompt.gd"))
	prompt.set("interactable", interactable)
	host.add_child(prompt)


## Cooldown rings stay readable above the print.
func _lift_to_overlay(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var items: Array[Node] = [node]
	items.append_array(node.get_children())
	for item: Node in items:
		if item is CanvasItem:
			(item as CanvasItem).visibility_layer |= overlay_mask()
	share_layers(node)


# ---------------------------------------------------------------- print controls (F7)

var _detail_label: Label
var _rate_label: Label
var _zoom_label: Label
var _options: Dictionary = {}


func _build_panel() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(4, 4)
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "Riso print  (F6 on/off, F7 panel, F8 realm)"
	title.add_theme_font_size_override("font_size", 6)
	box.add_child(title)
	_detail_label = _slider_row(box, "Print detail", 0.0, 100.0, 1.0, detail, _on_detail)
	_rate_label = _slider_row(box, "Sheet rate", 0.0, 24.0, 1.0, sheet_rate, _on_rate)
	_zoom_label = _slider_row(box, "Zoom", 0.5, 1.0, 0.02, zoom_factor, _on_zoom)
	_option_row(box, &"registration", "Registration", ["New sheet", "Locked", "Drift"], _on_registration)
	_option_row(box, &"reprint", "Reprint on", ["Clock", "Motion"], _on_reprint)
	_option_row(box, &"between", "Between sheets", ["Cut", "Blend"], _on_between)
	_option_row(box, &"realm", "Realm", ["Deep night", "Twilight", "Aurora"], _on_realm_picked)
	_sync_panel()


func _on_detail(v: float) -> void:
	detail = v
	_sync_panel()


func _on_rate(v: float) -> void:
	sheet_rate = v
	_sync_panel()


func _on_zoom(v: float) -> void:
	set_zoom_factor(v)
	_sync_panel()


func _on_registration(i: int) -> void:
	var modes: Array[StringName] = [&"sheet", &"locked", &"drift"]
	registration = modes[i]


func _on_reprint(i: int) -> void:
	reprint_on_motion = i == 1


func _on_between(i: int) -> void:
	blend_sheets = i == 1


func _on_realm_picked(i: int) -> void:
	set_realm(REALM_ORDER[i])


func _slider_row(box: VBoxContainer, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = text
	name_label.custom_minimum_size = Vector2(52, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)
	var slider: HSlider = HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(70, 8)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.add_theme_font_size_override("font_size", 6)
	row.add_child(value_label)
	return value_label


func _option_row(box: VBoxContainer, key: StringName, text: String, items: Array[String], on_pick: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = text
	name_label.custom_minimum_size = Vector2(52, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)
	var pick: OptionButton = OptionButton.new()
	pick.add_theme_font_size_override("font_size", 6)
	for item: String in items:
		pick.add_item(item)
	pick.item_selected.connect(on_pick)
	row.add_child(pick)
	_options[key] = pick


func _sync_panel() -> void:
	if _detail_label == null:
		return
	_detail_label.text = "Heavy" if detail < 25.0 else ("Medium" if detail < 65.0 else ("Fine" if detail < 90.0 else "Extra fine"))
	_rate_label.text = "held" if sheet_rate <= 0.0 else "%d / s" % int(sheet_rate)
	_zoom_label.text = "%d%%" % roundi(100.0 / zoom_factor)
	if _options.has(&"realm"):
		(_options[&"realm"] as OptionButton).select(REALM_ORDER.find(realm))
	if _options.has(&"reprint"):
		(_options[&"reprint"] as OptionButton).select(1 if reprint_on_motion else 0)
	if _options.has(&"between"):
		(_options[&"between"] as OptionButton).select(1 if blend_sheets else 0)
