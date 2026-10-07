class_name RisoPrint
extends Node
## Tarot-print presentation for the main game.
##
## Art nodes draw ink *coverage* onto seven plates (night, blue, pink, accent, eye yellow,
## hat glow, robe) by living on plate visibility layers. Each plate is a SubViewport that shares the
## game World2D and culls to its layer. A full-screen shader then prints the plates like a
## risograph (see shaders/riso_print.gdshader). The print is always on: the prefabs' old sprites
## stay on the default layer, under the print, where nothing shows them.
## F7 opens print controls, F8 cycles the realm.

const NIGHT: int = 0
const BLUE: int = 1
const PINK: int = 2
const ACCENT: int = 3
const EYE: int = 4
const GLOW: int = 5
## The wizard's robe and hat, in the ink of the spell they carry (ROBES).
const ROBE: int = 6
const PLATE_COUNT: int = 7
const PLATE_BIT0: int = 12
const OVERLAY_BIT: int = 19
const PRINT_SHADER: Shader = preload("res://shaders/riso_print.gdshader")
const UI_SHADER: Shader = preload("res://shaders/riso_ui.gdshader")
## The UI (HUD, interaction prompts) is printed in its own pass, finer than the scene. At full UI
## detail these scale the scene's screen cell, wobble, grain, dot gain and misregistration for
## it; at none it prints like the scene (see ui_detail).
const UI_CELL: float = 0.35
const UI_WOBBLE: float = 0.1
const UI_GRAIN: float = 0.4
const UI_GAIN: float = 0.3
const UI_REGISTRATION: float = 0.1

const REALMS: Dictionary = {
	&"deep": {"paper": Color("#e4dfe8"), "inks": [Color("#161b3a"), Color("#3d5588"), Color("#ff48b0"), Color("#ffb511"), Color("#ffe800")]},
	&"twilight": {"paper": Color("#ebe1cf"), "inks": [Color("#2a2350"), Color("#3255a4"), Color("#ff48b0"), Color("#ffe800"), Color("#ffe800")]},
	&"aurora": {"paper": Color("#e2eadf"), "inks": [Color("#0f2a2c"), Color("#00838a"), Color("#ff48b0"), Color("#765ba7"), Color("#ffe800")]},
	## Hyperspace's own: violet rock, aqua stars, on a cold paper (not in the F8 cycle).
	&"hyperspace": {"paper": Color("#e6e4f0"), "inks": [Color("#0d0a26"), Color("#5a3d9a"), Color("#ff48b0"), Color("#5ec8e5"), Color("#ffe800")]},
	## The garden's own: green rock and sun-gold stars under a deep green night, on a warm paper
	## (not in the F8 cycle; NextWorldDef.realm).
	&"garden": {"paper": Color("#e7e6d6"), "inks": [Color("#13241c"), Color("#3f7a4c"), Color("#ff48b0"), Color("#ffb511"), Color("#ffe800")]},
	## The cemetery's own: slate rock, violet stars and candlelight, on bone paper (not in the F8
	## cycle; NextWorldDef.realm).
	&"cemetery": {"paper": Color("#e3e1d8"), "inks": [Color("#1d2125"), Color("#5e695e"), Color("#ff48b0"), Color("#9d7ad2"), Color("#ffe800")]},
	## The sky's own: islands of pale cloud and sun-gold stars under a deep indigo night, on a cool
	## white paper (not in the F8 cycle; NextWorldDef.realm).
	&"sky": {"paper": Color("#eef0f3"), "inks": [Color("#18203f"), Color("#8597c4"), Color("#ff48b0"), Color("#ffb511"), Color("#ffe800")]},
}
const REALM_ORDER: Array[StringName] = [&"deep", &"twilight", &"aurora"]
## The robe while the wizard is drowsy in sleep fog (SleepFog).
const DROWSY_ROBE: Color = Color("#8d8f96")
## Hat-tip glow ink per ability (real Riso ink colours).
const GLOWS: Dictionary = {
	&"dash": Color("#ff48b0"),
	&"blink": Color("#9d7ad2"),
	&"astral": Color("#5ec8e5"),
	&"parry": Color("#ffe800"),
	&"climb": Color("#00a95c"),
	&"double_jump": Color("#ff6c2f"),
	&"hex": Color("#e8335a"),
	&"levitate": Color("#7fd6c2"),
	&"awareness": Color("#f2c14e"),
	&"keyring": Color("#ffb511"),
	&"strike": Color("#ff48b0"),
}
## Robe ink per spell in the slot (real Riso ink colours); no spell is the old federal blue.
const ROBES: Dictionary = {
	&"": Color("#3d5588"),
	&"hex": Color("#914e72"),
	&"astral": Color("#00838a"),
	&"parry": Color("#bb8b41"),
	&"levitate": Color("#67b346"),
	&"awareness": Color("#ff6c2f"),
	&"rift": Color("#765ba7"),
	&"warp": Color("#aa60bf"),
	&"mend": Color("#ff665e"),
}
## Print-detail stops: heavy 0, medium 50, fine 80, extra fine 100 (sizes in 720p pixels):
## [detail, screen cell, wobble, grain, dot gain, laydown], the prototype's values.
const DETAIL_STOPS: Array[Array] = [
	[0.0, 5.8, 1.7, 0.32, 1.6, 0.24],
	[50.0, 4.4, 1.0, 0.2, 1.1, 0.16],
	[80.0, 3.4, 0.55, 0.1, 0.7, 0.1],
	[100.0, 2.6, 0.35, 0.06, 0.5, 0.07],
]
## Base misregistration per plate, in 720p pixels: the prototype's offsets (night, blue, pink,
## accent, eye, glow), which are in its world units at about 2.4 px each.
const REGISTRATION: Array[Vector2] = [Vector2(-0.48, -0.43), Vector2(-0.91, 0.82), Vector2(1.2, -0.72), Vector2(0.58, 1.06), Vector2(0.29, 0.36), Vector2(0.34, 0.43), Vector2(-0.66, 0.58)]
## How far each new sheet jitters a plate's registration (720p pixels, either way).
const SHEET_JITTER: float = 1.2
## Key colours as overprints of the realm inks: sun, ember (sun over pink), moss (sun over blue), plum (pink over blue).
const KEY_COLORS: Array[Array] = [[ACCENT], [ACCENT, PINK], [ACCENT, BLUE], [PINK, BLUE]]

static var instance: RisoPrint

var detail: float = 80.0
var sheet_rate: float = 8.0
var reprint_on_motion: bool = true
var blend_sheets: bool = false
var registration: StringName = &"sheet"
var realm: StringName = &"deep"
var _realm_outside: StringName = &"deep"
## Night trapped to blue and one shared wobble (edges close up), instead of every plate
## registering on its own (paper slivers and overlaps at the edges, as in the prototype).
var trapped: bool = false
## Scales every plate's misregistration (base offset, sheet jitter and drift): 0 prints in
## perfect register, 1 is the prototype's, 3 is a sloppy press.
var offset_scale: float = 1.0
## How many missed-ink specks (flecks of bare paper) the print shows: 0 none, 0.2 the default, 1 the
## prototype's.
var specks: float = 0.2
## What fills the portals' openings (see PortalArt._portal): bands of TV static (the default), or
## ripples on a pool of water.
const PORTAL_STYLES: Array[StringName] = [&"static", &"ripples"]
var portal_style: StringName = &"static"
## Cemetery fog experiments: switching changes only the art, with the same sleep volume.
const FOG_STYLES: Array[StringName] = [&"original", &"shroud", &"breath", &"bleed", &"faces", &"incense", &"shroud_breath"]
const FOG_STYLE_NAMES: Array[String] = ["Original bands", "Torn ribbons", "Billowing bank", "Ragged ink", "Spectral billows", "Smoke plumes", "Billows & ribbons"]
var fog_style: StringName = &"shroud"
## Sky underside experiments change only printed geometry, never the terrain's collisions.
const SKY_BOTTOM_STYLES: Array[StringName] = [&"tapered", &"roots", &"clouds", &"clouds_roots"]
const SKY_BOTTOM_NAMES: Array[String] = ["Tapered", "Roots", "Clouds", "Clouds & roots"]
var sky_bottom_style: StringName = &"tapered"
## How much finer than the scene the UI prints, 0 (the same) to 1 (UI_* in full).
var ui_detail: float = 0.7
## Camera zoom while printing, relative to the scene's own zoom (smaller shows more).
var zoom_factor: float = 0.72
var _camera: Camera2D
var _base_zoom: Vector2 = Vector2.ZERO
var glow_ability: StringName = &"dash"
## Robe in the spell's ink (ROBES), or always in the realm's blue.
var robe_by_spell: bool = true
var robe_color: Color = Color(-1, -1, -1)

var plates: Array[SubViewport] = []
## The UI's own canvas and plates (six inks, then paper), printed by `ui_material` over the scene.
## UI art draws under `ui_root` (see ui_canvas()), positioned in the scene's coordinates.
var ui_world: World2D
var ui_plates: Array[SubViewport] = []
var ui_root: Node2D
var ui_rect: ColorRect
var ui_material: ShaderMaterial
var print_layer: CanvasLayer
var print_rect: ColorRect
var print_material: ShaderMaterial
var background: Node2D
var terrain: RisoTerrain
var hud: RisoHud
var map_view: Node2D
var decor: RisoDecor
var light: RisoLight
var ambient: RisoAmbient
var transition: Node2D
var panel: Control

var sheet_index: int = 0
var sheet_frac: float = 0.0
var _was_on_floor: bool = true
var _old_scale_mode: Window.ContentScaleMode
var _old_cull_mask: int = 0
var _old_snap: bool = false
var _player: Player
var _map_info: MapInfo
var _started: bool = false


## Called just before an unlocked door is freed: leaves a printed opening in its place.
static func door_opened(door: Node2D) -> void:
	if not is_on() or door == null:
		return
	var fx: RisoDoorOpen = RisoDoorOpen.new()
	var tm: TileMap = Stage.tile_map()
	var ground: float = 64.0
	var half: float = 64.0
	if tm != null and tm.tile_set != null:
		half = float(tm.tile_set.tile_size.y) * tm.global_scale.y * 0.5
		var cell: Vector2i = tm.local_to_map(tm.to_local(door.global_position))
		ground = tm.to_global(tm.map_to_local(cell)).y + half - door.global_position.y
	fx.ground = ground
	fx.half = half
	fx.key_color = int(door.get_meta(&"key_color", 0))
	door.get_parent().add_child(fx)
	fx.global_position = door.global_position


## The wizard steps into `portal` (see portal.gd): prints them drawn into it, and hides them
## until portal_reveal. The portal flares.
static func portal_depart(portal: Node2D, player: Player) -> void:
	if not is_on() or portal == null or player == null:
		return
	var art: PortalArt = portal.get_node_or_null("RisoArt") as PortalArt
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard
	if art == null or wizard == null:
		return
	portal.set_meta(&"flare_at", Time.get_ticks_msec() / 1000.0)
	_portal_fx(portal, wizard, art.to_global(art.portal_center()), wizard.global_position, 0)
	wizard.vanished = true


## The wizard comes out of `exit` (the far portal, if known) at `to`: prints them pushed out of
## it. The far portal flares.
static func portal_arrive(portal: Node2D, exit: Node2D, player: Player, to: Vector2) -> void:
	if not is_on() or portal == null or player == null:
		return
	var art: PortalArt = (exit if exit != null else portal).get_node_or_null("RisoArt") as PortalArt
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard
	if art == null or wizard == null:
		return
	var center: Vector2 = art.to_global(art.portal_center()) if exit != null else to + (art.to_global(art.portal_center()) - portal.global_position)
	if exit != null:
		exit.set_meta(&"flare_at", Time.get_ticks_msec() / 1000.0)
	_portal_fx(portal, wizard, center, to + wizard.global_position - player.global_position, 1)


## A warp (see Warp): the wizard is drawn into a tear in the air where they stand, as into a
## portal's core, in the robe's ink (the warp's colour).
static func warp_depart(player: Player) -> void:
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard if player != null else null
	if not is_on() or wizard == null:
		return
	_warp_fx(player, wizard, wizard.global_position, 0)
	wizard.vanished = true


## The far end of a warp: pushed out of a tear in the air over `to`.
static func warp_arrive(player: Player, to: Vector2) -> void:
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard if player != null else null
	if not is_on() or wizard == null:
		return
	_warp_fx(player, wizard, to + wizard.global_position - player.global_position, 1)


static func _warp_fx(player: Player, wizard: RisoWizard, feet: Vector2, part: int) -> void:
	# The tear is at the wizard's middle, where a portal's core would be.
	var center: Vector2 = feet + Vector2(0, -RisoPortalWarp.MID * wizard.global_scale.y)
	player.get_parent().add_child(_warp(wizard, part, center, feet, ROBE))


## The wizard is seen again (see portal_depart).
static func portal_reveal(player: Player) -> void:
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard if player != null else null
	if wizard != null:
		wizard.vanished = false


static func _portal_fx(portal: Node2D, wizard: RisoWizard, center: Vector2, feet: Vector2, part: int) -> void:
	portal.get_parent().add_child(_warp(wizard, part, center, feet, EYE if portal.has_meta(&"rift") else ACCENT))


## The print of the wizard drawn into (`part` 0) or pushed out of (1) a portal's core at `center`,
## their feet at `feet`, ringed in `ring` ink.
static func _warp(wizard: RisoWizard, part: int, center: Vector2, feet: Vector2, ring: int) -> RisoPortalWarp:
	var fx: RisoPortalWarp = RisoPortalWarp.new()
	fx.part = part
	fx.center = center
	fx.feet = feet
	fx.facing = 1.0 if wizard.fs >= 0.0 else -1.0
	fx.art_scale = wizard.global_scale.y
	fx.ring = ring
	return fx


## Every plate: knocking or lifting them all leaves bare paper.
const ALL_PLATES: Array[int] = [NIGHT, BLUE, PINK, ACCENT, EYE, GLOW, ROBE]


## Print a key of `color` in `shapes` on `canvas`: overprinted in its colour's inks, or, for a
## skeleton key, bare paper, so it reads bone white.
static func ink_key(canvas: InkCanvas, color: int, cover: float, shapes: Array[PackedVector2Array]) -> void:
	if color == KeyRing.SKELETON:
		canvas.lift_ink(ALL_PLATES, cover, shapes)
		return
	for plate: int in key_inks(color):
		canvas.ink(plate, cover, shapes)


static func key_inks(color: int) -> Array[int]:
	# A skeleton key prints as bare paper (ink_key); where it needs an ink (its map marks, sparks)
	# it is night, screened to grey on the map.
	if color == KeyRing.SKELETON:
		return [NIGHT]
	var out: Array[int] = []
	for plate: int in KEY_COLORS[posmod(color, KEY_COLORS.size())]:
		out.append(plate)
	return out


static func plate_mask(p: int) -> int:
	return 1 << (PLATE_BIT0 + p)


static func overlay_mask() -> int:
	return 1 << OVERLAY_BIT


## The UI canvas's paper plate (plaques and discs the UI sits on). The UI has a canvas of its
## own, so it reuses the overlay's bit there.
static func paper_mask() -> int:
	return 1 << OVERLAY_BIT


## A node in the UI's canvas for `host` to draw into (InkCanvas with ui = true, labels on the
## plates), printed finer than the scene. The host positions it in the scene's coordinates each
## frame. Falls back to `host` itself when there is no print.
static func ui_canvas(host: Node2D) -> Node2D:
	if instance == null or instance.ui_root == null:
		return host
	var canvas: Node2D = Node2D.new()
	canvas.name = host.name + "Canvas"
	canvas.visibility_layer |= all_ink_bits()
	instance.ui_root.add_child(canvas)
	host.tree_exiting.connect(canvas.queue_free)
	return canvas


## Whether the print is running: always, wherever the game scene is (not in a bare test tree).
static func is_on() -> bool:
	return instance != null


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
	var root: Viewport = get_viewport()
	_old_scale_mode = get_window().content_scale_mode
	_old_cull_mask = root.canvas_cull_mask
	_old_snap = root.snap_2d_transforms_to_pixel
	_build()
	get_tree().node_added.connect(_on_node_added)
	_dress_existing(get_tree().root)
	_started = true
	_apply()


func _build() -> void:
	var main: Node = get_parent()
	for i: int in range(PLATE_COUNT):
		plates.append(_make_viewport(plate_mask(i)))
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
	# The UI: a canvas of its own (so its plates hold only UI), printed finer, on top.
	ui_world = World2D.new()
	for i: int in range(PLATE_COUNT + 1):
		var vp: SubViewport = _make_viewport(plate_mask(i) if i < PLATE_COUNT else paper_mask())
		vp.world_2d = ui_world
		ui_plates.append(vp)
	ui_root = Node2D.new()
	ui_root.name = "RisoUI"
	ui_root.visibility_layer |= all_ink_bits()
	ui_plates[0].add_child(ui_root)
	ui_rect = ColorRect.new()
	ui_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_material = ShaderMaterial.new()
	ui_material.shader = UI_SHADER
	ui_rect.material = ui_material
	for i: int in range(PLATE_COUNT):
		ui_material.set_shader_parameter("plate%d" % i, ui_plates[i].get_texture())
	ui_material.set_shader_parameter("plate_paper", ui_plates[PLATE_COUNT].get_texture())
	print_layer.add_child(ui_rect)
	background = Node2D.new()
	background.name = "RisoBackground"
	background.set_script(preload("res://scripts/riso/RisoBackground.gd"))
	main.add_child.call_deferred(background)
	if main is CanvasItem:
		(main as CanvasItem).visibility_layer |= all_ink_bits()
	terrain = RisoTerrain.new()
	terrain.name = "RisoTerrain"
	main.add_child.call_deferred(terrain)
	decor = RisoDecor.new()
	decor.name = "RisoDecor"
	main.add_child.call_deferred(decor)
	light = RisoLight.new()
	light.name = "RisoLight"
	main.add_child.call_deferred(light)
	ambient = RisoAmbient.new()
	ambient.name = "RisoAmbient"
	ambient.decor = decor
	ambient.light = light
	main.add_child.call_deferred(ambient)
	transition = Node2D.new()
	transition.name = "RisoTransition"
	transition.set_script(preload("res://scripts/riso/RisoTransition.gd"))
	main.add_child.call_deferred(transition)
	hud = RisoHud.new()
	hud.name = "RisoHud"
	main.add_child.call_deferred(hud)
	map_view = Node2D.new()
	map_view.name = "RisoMap"
	map_view.set_script(preload("res://scripts/riso/RisoMap.gd"))
	main.add_child.call_deferred(map_view)
	var menu_print: Node2D = Node2D.new()
	menu_print.name = "RisoMenu"
	menu_print.set_script(preload("res://scripts/riso/RisoMenu.gd"))
	main.add_child.call_deferred(menu_print)
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


## Set the window up for the print: the scale mode and zoom it prints at, the main view hiding the
## ink layers (the print shows them), the plates rendering, and the menus in the riso theme.
func _apply() -> void:
	var root: Viewport = get_viewport()
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var hidden: int = overlay_mask()
	for i: int in range(PLATE_COUNT):
		hidden |= plate_mask(i)
	root.canvas_cull_mask = _old_cull_mask & ~hidden
	root.snap_2d_transforms_to_pixel = false
	_apply_zoom()
	print_layer.visible = true
	for vp: SubViewport in plates:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for vp: SubViewport in ui_plates:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	RisoTheme.apply(realm)


func _apply_zoom() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
		if _camera == null:
			return
		_base_zoom = _camera.zoom
	_camera.zoom = _base_zoom * zoom_factor


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
	var root: Viewport = get_viewport()
	var size: Vector2i = _screen_size()
	var k: float = minf(1.0, 1080.0 / float(size.y))
	var plate_size: Vector2i = Vector2i(roundi(size.x * k), roundi(size.y * k))
	var xf: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO) * root.get_final_transform() * root.canvas_transform
	for vp: SubViewport in plates:
		if vp.size != plate_size:
			vp.size = plate_size
		vp.canvas_transform = xf
	for vp: SubViewport in ui_plates:
		if vp.size != plate_size:
			vp.size = plate_size
		vp.canvas_transform = xf
	_track_player()
	_ease_robe(delta)
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


## The robe's ink eases to its spell's over a moment, so learning a spell visibly re-dyes it.
func _ease_robe(delta: float) -> void:
	var target: Color = (REALMS[realm]["inks"] as Array)[BLUE]
	if robe_by_spell and _player != null and is_instance_valid(_player):
		target = ROBES.get(Abilities.spell(_player), ROBES[&""])
	# Drowsy in sleep fog: the spell is off, and the robe greys.
	if _player != null and is_instance_valid(_player) and _player.is_drowsy():
		target = DROWSY_ROBE
	robe_color = target if robe_color.r < 0.0 else robe_color.lerp(target, minf(1.0, delta * 4.0))


func _on_player_event(kind: StringName, _at: Vector2) -> void:
	if kind == &"jump":
		var feet: Node2D = _player.get_node_or_null("RisoWizard") as Node2D
		RisoFx.burst(&"jump", feet.global_position if feet != null else _at)
	elif kind == &"hurt":
		RisoFx.burst(&"hit", _at + Vector2(0, -20), -_player.velocity.normalized())
	if kind in [&"hurt", &"death"] and hud != null and is_instance_valid(hud):
		hud.flash = 1.0
	if kind == &"projection_start":
		flare(&"astral")
	elif kind == &"jump" and _player != null and _player.MAX_JUMPS > 1 and _player.jumps < _player.MAX_JUMPS and not _player.is_on_floor():
		flare(&"double_jump")
	if reprint_on_motion and registration == &"sheet" and sheet_rate > 0.0:
		if kind in [&"jump", &"dash", &"hurt", &"death", &"projection_start", &"projection_end", &"teleport"]:
			_new_sheet()


## Movement (dash, blink, climb, double jump) lights the hat, which takes its glow ink; spells
## light the orb instead (accent ink) and leave the hat's colour alone.
func flare(ability: StringName) -> void:
	var wizard: RisoWizard = null
	if _player != null and is_instance_valid(_player):
		wizard = _player.get_node_or_null("RisoWizard") as RisoWizard
	if Abilities.is_spell(ability):
		if wizard != null:
			wizard.orb_flare()
		return
	glow_ability = ability
	if wizard != null:
		wizard.flare()


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
	print_material.set_shader_parameter("ink6", Vector3(robe_color.r, robe_color.g, robe_color.b))
	var t: float = Time.get_ticks_msec() / 1000.0
	var m: float = _sheet_mix()
	for i: int in range(PLATE_COUNT):
		var o: Vector2 = REGISTRATION[i]
		if registration == &"sheet":
			o += _jitter(sheet_index, i).lerp(_jitter(sheet_index + 1, i), m) * SHEET_JITTER
		elif registration == &"drift":
			o += Vector2(sin(t * 0.7 + float(i) * 2.1), cos(t * 0.53 + float(i) * 1.3)) * 1.2
		print_material.set_shader_parameter("off%d" % i, o * offset_scale * s)
	print_material.set_shader_parameter("cell", params[0] * s)
	print_material.set_shader_parameter("wob", params[1] * s)
	print_material.set_shader_parameter("grain", params[2])
	print_material.set_shader_parameter("gain", params[3] * s)
	print_material.set_shader_parameter("lay", params[4])
	print_material.set_shader_parameter("specks", specks)
	print_material.set_shader_parameter("seed", _sheet_seed(sheet_index) if registration == &"sheet" else 3.1)
	print_material.set_shader_parameter("seed2", _sheet_seed(sheet_index + 1))
	print_material.set_shader_parameter("mixv", m)
	print_material.set_shader_parameter("trapped", 1.0 if trapped else 0.0)
	# Pin the print to the world: the shader adds the camera's pixel offset to every noise lookup.
	var root: Viewport = get_viewport()
	var view: Transform2D = root.get_final_transform() * root.canvas_transform
	print_material.set_shader_parameter("pin", -view.origin)
	# The UI's print: the same sheet and inks, finer, and pinned to the screen (the HUD is).
	for p: String in ["res", "paper", "ink0", "ink1", "ink2", "ink3", "ink4", "ink5", "ink6", "lay", "specks", "seed", "seed2", "mixv"]:
		ui_material.set_shader_parameter(p, print_material.get_shader_parameter(p))
	for i: int in range(PLATE_COUNT):
		ui_material.set_shader_parameter("off%d" % i, (print_material.get_shader_parameter("off%d" % i) as Vector2) * _ui_scale(UI_REGISTRATION))
	ui_material.set_shader_parameter("cell", params[0] * s * _ui_scale(UI_CELL))
	ui_material.set_shader_parameter("wob", params[1] * s * _ui_scale(UI_WOBBLE))
	ui_material.set_shader_parameter("grain", params[2] * _ui_scale(UI_GRAIN))
	ui_material.set_shader_parameter("gain", params[3] * s * _ui_scale(UI_GAIN))
	ui_material.set_shader_parameter("pin", Vector2.ZERO)


## A UI print setting's scale at the current UI detail: from 1 (as the scene) to `finest`.
func _ui_scale(finest: float) -> float:
	return lerpf(1.0, finest, ui_detail)


func set_realm(r: StringName) -> void:
	if REALMS.has(r):
		realm = r
		if background != null:
			background.queue_redraw()
		if _started:
			RisoTheme.apply(realm)
		_sync_panel()


func cycle_realm() -> void:
	var i: int = REALM_ORDER.find(realm)
	set_realm(REALM_ORDER[(i + 1) % REALM_ORDER.size()])


## Called by MapInfo when a world has been laid out. A place with a realm of its own
## (NextWorldDef.realm, as hyperspace has) prints in it; leaving brings back the realm it was
## entered from.
func world_built(map_info: MapInfo, _world_index: int) -> void:
	_map_info = map_info
	var here: NextWorldDef = map_info.here
	var own: StringName = here.realm() if here != null else &""
	if own != &"" and REALMS.has(own) and realm != own:
		if REALM_ORDER.has(realm):
			_realm_outside = realm
		set_realm(own)
	elif own == &"" and not REALM_ORDER.has(realm):
		set_realm(_realm_outside)
	_rebuild_ground(map_info)


func _rebuild_ground(map_info: MapInfo) -> void:
	if terrain != null and is_instance_valid(terrain):
		var ledges: Array[Vector2] = []
		var cracked: Array[Vector2] = []
		var elements: Node = map_info.map_elements
		if elements != null:
			for node: Node in elements.get_children():
				if node.is_queued_for_deletion():
					continue
				var type: int = Placeables.type_of(node)
				if type == LevelGen.Type.PLATFORM:
					ledges.append((node as Node2D).global_position)
				elif type == LevelGen.Type.CRACKED:
					cracked.append((node as Node2D).global_position)
		terrain.rebuild(map_info.tile_map, ledges, cracked)
		if decor != null and is_instance_valid(decor):
			decor.rebuild(map_info, cracked)
		if light != null and is_instance_valid(light):
			light.rebuild(map_info)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F7:
		set_pad_panel(not panel.visible)
	elif key.keycode == KEY_F8:
		cycle_realm()


## The F7 panel by controller, in debug runs: Back (Select) opens it, pausing the game and focusing
## its first control so the D-pad or stick moves through it (A picks, left and right change
## sliders or choices); Back again, or B, closes it and the game goes on. F7 shares this focus.
var _pad_paused: bool = false


func _input(event: InputEvent) -> void:
	var pad: InputEventJoypadButton = event as InputEventJoypadButton
	if pad != null and pad.pressed and pad.button_index == JOY_BUTTON_BACK and MapInfo.debug and panel != null:
		set_pad_panel(not panel.visible)
		get_viewport().set_input_as_handled()
	elif panel != null and panel.visible and event.is_action_pressed(&"ui_cancel"):
		set_pad_panel(false)
		get_viewport().set_input_as_handled()


func set_pad_panel(open: bool) -> void:
	panel.visible = open
	if open:
		_travel_reset()
	_sync_panel()
	if open:
		# Not over a pause the menu made: that one stays.
		_pad_paused = _pad_paused or not get_tree().paused
		get_tree().paused = true
		_wire_panel_focus()
		var first: Control = _first_focusable(panel)
		if first != null:
			first.grab_focus()
	else:
		if _pad_paused:
			get_tree().paused = false
		_pad_paused = false
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null and panel.is_ancestor_of(focus):
			focus.release_focus()


func _first_focusable(node: Node, headers: bool = false) -> Control:
	for child: Node in node.get_children():
		var c: Control = child as Control
		# The scroll container's scrollbar is focusable too; open on an actual setting (a section's
		# header only when every section is folded shut).
		if (c is BaseButton or c is Slider) and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree() and (headers or not c.has_meta(&"section")):
			return c
		var deeper: Control = _first_focusable(child, headers)
		if deeper != null:
			return deeper
	return null if headers or node != panel else _first_focusable(node, true)


## Explicit links keep navigation in the panel and preserve the column across neighbouring
## rows. Geometry-based focus can skip these tiny controls or choose the scrollbar instead.
func _wire_panel_focus() -> void:
	var rows: Array[Array] = []
	_panel_focus_rows(panel, rows)
	for i: int in range(rows.size()):
		var row: Array = rows[i]
		for j: int in range(row.size()):
			var control: Control = row[j]
			var above: Array = rows[maxi(0, i - 1)]
			var below: Array = rows[mini(rows.size() - 1, i + 1)]
			control.focus_neighbor_left = control.get_path_to(row[maxi(0, j - 1)])
			control.focus_neighbor_right = control.get_path_to(row[mini(row.size() - 1, j + 1)])
			control.focus_neighbor_top = control.get_path_to(above[mini(j, above.size() - 1)])
			control.focus_neighbor_bottom = control.get_path_to(below[mini(j, below.size() - 1)])


func _panel_focus_rows(node: Node, rows: Array[Array]) -> void:
	for child: Node in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is HBoxContainer:
			var controls: Array = []
			for item: Node in child.get_children():
				if (item is BaseButton or item is Slider) and (item as Control).focus_mode != Control.FOCUS_NONE:
					controls.append(item)
			if not controls.is_empty():
				rows.append(controls)
		else:
			_panel_focus_rows(child, rows)


# ---------------------------------------------------------------- dressing prefabs

## The ink art for prefabs that are not things a level holds (those are in Placeables.TABLE).
const DRESS: Dictionary = {
	"res://prefabs/player.tscn": &"wizard",
	"res://prefabs/bullet.tscn": &"shard",
	"res://prefabs/corpse.tscn": &"ghost",
}


## The ink art a prefab at `path` is dressed in (a RisoProp kind, or &"wizard"), or &"" for none.
static func art_kind(path: String) -> StringName:
	if DRESS.has(path):
		return DRESS[path]
	return Placeables.art_for_scene(path)


func _dress_existing(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_dress_existing(child)


func _on_node_added(node: Node) -> void:
	var kind: StringName = art_kind(node.scene_file_path) if node.scene_file_path != "" else &""
	if kind != &"":
		_dress.call_deferred(node, kind)
	elif node.name == "Interactable":
		_add_prompt.call_deferred(node)


func _dress(node: Node, kind: StringName) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node.has_node("RisoWizard") or node.has_node("RisoArt"):
		return
	var art: Node2D
	if kind == &"wizard":
		art = RisoWizard.new()
		art.name = "RisoWizard"
	else:
		art = RisoProp.make(kind)
		art.name = "RisoArt"
	art.add_to_group(&"riso_art")
	node.add_child(art)
	share_layers(art)


func _add_prompt(interactable: Node) -> void:
	if not is_instance_valid(interactable) or not interactable is Interactable or not (interactable.get_parent() is Node2D):
		return
	var host: Node2D = interactable.get_parent() as Node2D
	if host.has_node("RisoPrompt"):
		return
	var prompt: RisoPrompt = RisoPrompt.new()
	prompt.name = "RisoPrompt"
	prompt.interactable = interactable as Interactable
	host.add_child(prompt)


# ---------------------------------------------------------------- print controls (F7)

var _detail_label: Label
var _rate_label: Label
var _zoom_label: Label
var _offset_label: Label
var _ui_detail_label: Label
var _specks_label: Label
var _skeleton_label: Label
var _key_capacity_label: Label
var _options: Dictionary = {}


func _build_panel() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Vector2(4, 4)
	layer.add_child(panel)
	# The rows outgrow the 180-unit UI height, so they scroll (wheel or drag the bar).
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(176, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	# Moving through it by controller scrolls to the focused control.
	scroll.follow_focus = true
	panel.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title: Label = Label.new()
	title.text = "Riso print  (F6 on/off, F7 panel, F8 realm; pad: Back in debug)"
	title.add_theme_font_size_override("font_size", 6)
	box.add_child(title)
	# First, so a controller lands on it (debug runs only).
	_build_travel(box)
	var print_box: VBoxContainer = _section(box, "Print", true)
	_detail_label = _slider_row(print_box, "Print detail", 0.0, 100.0, 1.0, detail, _on_detail)
	_rate_label = _slider_row(print_box, "Sheet rate", 0.0, 24.0, 1.0, sheet_rate, _on_rate)
	_zoom_label = _slider_row(print_box, "Zoom", 0.5, 1.0, 0.02, zoom_factor, _on_zoom)
	_offset_label = _slider_row(print_box, "Plate offset", 0.0, 3.0, 0.1, offset_scale, func(v: float) -> void:
		offset_scale = v
		_sync_panel())
	_specks_label = _slider_row(print_box, "Specks", 0.0, 1.0, 0.05, specks, func(v: float) -> void:
		specks = v
		_sync_panel())
	_ui_detail_label = _slider_row(print_box, "UI detail", 0.0, 1.0, 0.05, ui_detail, func(v: float) -> void:
		ui_detail = v
		_sync_panel())
	_option_row(print_box, &"registration", "Registration", ["New sheet", "Locked", "Drift"], _on_registration)
	_option_row(print_box, &"reprint", "Reprint on", ["Clock", "Motion"], _on_reprint)
	_option_row(print_box, &"between", "Between sheets", ["Cut", "Blend"], _on_between)
	_option_row(print_box, &"plates", "Plates", ["Independent", "Trapped"], func(i: int) -> void: trapped = i == 1)
	var look: VBoxContainer = _section(box, "Look", false)
	_option_row(look, &"realm", "Realm", ["Deep night", "Twilight", "Aurora"], _on_realm_picked)
	_option_row(look, &"portal", "Portals", ["TV static", "Ripples"], func(i: int) -> void: portal_style = PORTAL_STYLES[i])
	_option_row(look, &"fog", "Fog shape", FOG_STYLE_NAMES, func(i: int) -> void: fog_style = FOG_STYLES[i])
	_option_row(look, &"robe", "Robe", ["Spell colour", "Blue"], func(i: int) -> void: robe_by_spell = i == 0)
	_option_row(look, &"sky_bottoms", "Sky bottoms", SKY_BOTTOM_NAMES, func(i: int) -> void:
		sky_bottom_style = SKY_BOTTOM_STYLES[i]
		if _map_info != null and is_instance_valid(_map_info) and _map_info.here.open():
			_rebuild_ground(_map_info)
		_sync_panel())
	var keys: VBoxContainer = _section(box, "Keys", false)
	_key_capacity_label = Label.new()
	_key_capacity_label.add_theme_font_size_override("font_size", 6)
	keys.add_child(_key_capacity_label)
	var shapes: Array[String] = ["Square", "Triangle", "Circle", "Diamond"]
	for color: int in range(MapInfo.KEY_COLOR_COUNT):
		_option_row(keys, StringName("key_" + str(color)), shapes[color] + " key", ["None", "Equipped"], func(i: int) -> void: _equip_panel_key(color, i == 1))
	_skeleton_label = _stepper_row(keys, "Skeleton keys", func(d: int) -> void:
		if _player != null and is_instance_valid(_player):
			_player.keyring.set_skeletons(maxi(0, _player.keyring.skeletons() + d)))
	# Abilities: set any tier outright (a spell above 0 takes the slot).
	var abilities: VBoxContainer = _section(box, "Abilities", false)
	for a: StringName in Abilities.ids():
		var items: Array[String] = ["none"]
		for n: int in range(1, Abilities.max_tier(a) + 1):
			items.append(Abilities.roman(n))
		_option_row(abilities, StringName("ability_" + String(a)), Abilities.label(a) + (" (spell)" if Abilities.is_spell(a) else ""), items, func(i: int) -> void:
			if _player != null and is_instance_valid(_player):
				Abilities.set_tier(_player, a, i)
				if a == &"keyring":
					_player.keyring.set_all(_player.keyring.all())
			_sync_panel())
	_sync_panel()


## The panel's sections, by title: [its header button, its rows]. Each folds open or shut from its
## header (a click, or A on a controller), so the panel stays short; which are open is remembered
## while the game runs (it is rebuilt with each scene). Travel and Print start open.
var _sections: Dictionary = {}
static var _section_open: Dictionary = {}


## A section titled `title` in `box`: its header, and the box its rows go in (returned).
func _section(box: VBoxContainer, title: String, open: bool) -> VBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var header: Button = Button.new()
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", 6)
	header.set_meta(&"section", title)
	row.add_child(header)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	box.add_child(rows)
	_sections[title] = [header, rows]
	if not _section_open.has(title):
		_section_open[title] = open
	header.pressed.connect(func() -> void: set_section(title, not bool(_section_open[title])))
	_show_section(title)
	return rows


## Fold section `title` open or shut.
func set_section(title: String, open: bool) -> void:
	if not _sections.has(title):
		return
	_section_open[title] = open
	_show_section(title)
	if panel != null and panel.visible:
		_wire_panel_focus()


func section_open(title: String) -> bool:
	return bool(_section_open.get(title, false))


func _show_section(title: String) -> void:
	var parts: Array = _sections[title]
	var open: bool = bool(_section_open[title])
	(parts[1] as Control).visible = open
	(parts[0] as Button).text = ("- " if open else "+ ") + title


## Debug equipment uses the same ring as pickups: a full ring replaces its oldest key.
func _equip_panel_key(color: int, equipped: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if equipped:
		if not _player.keyring.has(color):
			_player.keyring.take(color)
	else:
		_player.keyring.set_all(_player.keyring.all().filter(func(c: int) -> bool: return c != color))
	_sync_panel()


# ---------------------------------------------------------------- debug travel

## Debug runs only: travel straight to any world and depth (MapInfo.debug_travel), or to the
## nearest band of an archetype, or into hyperspace, from the F7 panel (by controller too).
var _travel_box: VBoxContainer
var _travel_world_label: Label
var _travel_depth_label: Label
## The place the Go button travels to (set to where you are when the panel opens).
var _travel_at: Vector2i = Vector2i.ZERO


func _build_travel(box: VBoxContainer) -> void:
	_travel_box = VBoxContainer.new()
	_travel_box.add_theme_constant_override("separation", 1)
	box.add_child(_travel_box)
	var rows: VBoxContainer = _section(_travel_box, "Travel (debug)", true)
	_travel_world_label = _stepper_row(rows, "World", func(d: int) -> void: _travel_at.x += d)
	_travel_depth_label = _stepper_row(rows, "Depth", func(d: int) -> void: _travel_at.y = maxi(0, _travel_at.y + d))
	var row: HBoxContainer = HBoxContainer.new()
	rows.add_child(row)
	_button(row, "Go", func() -> void: _travel(_travel_at))
	for a: StringName in NextWorldDef.archetype_names():
		_button(row, String(a).capitalize(), func() -> void: _travel(Vector2i(_travel_at.x, _nearest_band(a, _travel_at.y))))
	for k: int in range(Worlds.KINDS.size()):
		var kind: int = k
		_button(row, Worlds.proto(k).name.capitalize(), func() -> void: _travel(Worlds.side_at(kind, Vector2i(_travel_at.x, maxi(1, _travel_at.y)))))


## A row: its name, a "-" button, the value, a "+" button; `on_step` gets -1 or +1.
func _stepper_row(box: VBoxContainer, text: String, on_step: Callable) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	var name_label: Label = Label.new()
	name_label.text = text
	name_label.custom_minimum_size = Vector2(52, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)
	_button(row, "-", func() -> void:
		on_step.call(-1)
		_sync_panel())
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(44, 0)
	value.add_theme_font_size_override("font_size", 6)
	row.add_child(value)
	_button(row, "+", func() -> void:
		on_step.call(1)
		_sync_panel())
	return value


func _button(row: HBoxContainer, text: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 6)
	b.pressed.connect(on_press)
	row.add_child(b)
	return b


## The depth nearest `from` (the shallower on a tie) whose levels are of archetype `a`.
static func _nearest_band(a: StringName, from: int) -> int:
	for d: int in range(0, 1000):
		for depth: int in [from - d, from + d]:
			if depth >= 0 and NextWorldDef.archetype_at(depth) == a:
				return depth
	return from


func _travel_reset() -> void:
	if _map_info != null and is_instance_valid(_map_info):
		var at: Vector2i = _map_info.coord
		_travel_at = Vector2i(at.x, maxi(0, at.y))


## Close the panel (and its pause) and go.
func _travel(to: Vector2i) -> void:
	if not MapInfo.debug or MapInfo.instance == null:
		return
	if _pad_paused:
		set_pad_panel(false)
	else:
		panel.visible = false
	MapInfo.instance.debug_travel(to)


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
	pick.gui_input.connect(func(event: InputEvent) -> void:
		var direction: int = 0
		if event.is_action_pressed(&"ui_left"):
			direction = -1
		elif event.is_action_pressed(&"ui_right"):
			direction = 1
		if direction != 0:
			var next: int = wrapi(pick.selected + direction, 0, pick.item_count)
			pick.select(next)
			pick.item_selected.emit(next)
			pick.accept_event())
	row.add_child(pick)
	_options[key] = pick


func _sync_panel() -> void:
	if _detail_label == null:
		return
	if _travel_box != null:
		_travel_box.visible = MapInfo.debug
		_travel_world_label.text = str(_travel_at.x)
		_travel_depth_label.text = "%d  (%s)" % [_travel_at.y, NextWorldDef.archetype_at(_travel_at.y)]
	_detail_label.text = "Heavy" if detail < 25.0 else ("Medium" if detail < 65.0 else ("Fine" if detail < 90.0 else "Extra fine"))
	_rate_label.text = "held" if sheet_rate <= 0.0 else "%d / s" % int(sheet_rate)
	_zoom_label.text = "%d%%" % roundi(100.0 / zoom_factor)
	_offset_label.text = "%.1f×" % offset_scale
	_ui_detail_label.text = "%d%%" % roundi(ui_detail * 100.0)
	_specks_label.text = "none" if specks <= 0.0 else "%d%%" % roundi(specks * 100.0)
	if _options.has(&"portal"):
		(_options[&"portal"] as OptionButton).select(PORTAL_STYLES.find(portal_style))
	if _options.has(&"fog"):
		(_options[&"fog"] as OptionButton).select(FOG_STYLES.find(fog_style))
	if _options.has(&"sky_bottoms"):
		(_options[&"sky_bottoms"] as OptionButton).select(SKY_BOTTOM_STYLES.find(sky_bottom_style))
	if _options.has(&"realm"):
		(_options[&"realm"] as OptionButton).select(REALM_ORDER.find(realm))
	if _options.has(&"reprint"):
		(_options[&"reprint"] as OptionButton).select(1 if reprint_on_motion else 0)
	if _options.has(&"between"):
		(_options[&"between"] as OptionButton).select(1 if blend_sheets else 0)
	if _options.has(&"plates"):
		(_options[&"plates"] as OptionButton).select(1 if trapped else 0)
	if _options.has(&"robe"):
		(_options[&"robe"] as OptionButton).select(0 if robe_by_spell else 1)
	if _player != null and is_instance_valid(_player):
		_key_capacity_label.text = "Ring: %d / %d  (Keyring adds slots)" % [_player.keyring.all().size(), _player.keyring.capacity()]
		_skeleton_label.text = str(_player.keyring.skeletons())
		for color: int in range(MapInfo.KEY_COLOR_COUNT):
			(_options[StringName("key_" + str(color))] as OptionButton).select(1 if _player.keyring.has(color) else 0)
		for a: StringName in Abilities.ids():
			var key: StringName = StringName("ability_" + String(a))
			if _options.has(key):
				(_options[key] as OptionButton).select(Abilities.tier(_player, a))
