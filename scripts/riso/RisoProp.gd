extends Node2D
## Ink art for one spawned prefab, dressed by RisoPrint by the prefab's art kind (Placeables,
## RisoPrint.DRESS). This is what every kind shares: when it prints (only in view, and once only
## for a still one), the ink and UI canvases, plaques and pop-ups. What a kind looks like is its own
## script in scripts/riso/props/ (see KINDS), which overrides _draw_art. Drawn in world pixels (the
## owner's scale is cancelled); the owner's rotation still applies, so wall and ceiling spikes point
## the right way. Presentation only. Shapes shared with the map and HUD are in RisoMarks.

class_name RisoProp

## Each art kind's script.
const KINDS: Dictionary = {
	&"mote": "res://scripts/riso/props/MoteArt.gd",
	&"cluster": "res://scripts/riso/props/ClusterArt.gd",
	&"key": "res://scripts/riso/props/KeyArt.gd",
	&"inkwell": "res://scripts/riso/props/InkwellArt.gd",
	&"portal": "res://scripts/riso/props/PortalArt.gd",
	&"door": "res://scripts/riso/props/GateArt.gd",
	&"gate": "res://scripts/riso/props/GateArt.gd",
	&"switch": "res://scripts/riso/props/SwitchArt.gd",
	&"relic": "res://scripts/riso/props/RelicArt.gd",
	&"lantern": "res://scripts/riso/props/LanternArt.gd",
	&"exit": "res://scripts/riso/props/ExitArt.gd",
	&"moon": "res://scripts/riso/props/MoonArt.gd",
	&"lift": "res://scripts/riso/props/LiftArt.gd",
	&"thorns": "res://scripts/riso/props/ThornsArt.gd",
	&"ghost": "res://scripts/riso/props/GhostArt.gd",
	&"shrine": "res://scripts/riso/props/ShrineArt.gd",
	&"cracked": "res://scripts/riso/props/CrackedArt.gd",
	&"wisp": "res://scripts/riso/props/WispArt.gd",
	&"watcher": "res://scripts/riso/props/WatcherArt.gd",
	&"hopper": "res://scripts/riso/props/HopperArt.gd",
	&"wraith": "res://scripts/riso/props/WraithArt.gd",
	&"bridge": "res://scripts/riso/props/BridgeArt.gd",
	&"bell": "res://scripts/riso/props/BellArt.gd",
	&"vane": "res://scripts/riso/props/VaneArt.gd",
	&"pad": "res://scripts/riso/props/PadArt.gd",
	&"puff": "res://scripts/riso/props/PuffArt.gd",
	&"wind": "res://scripts/riso/props/WindArt.gd",
	&"bird": "res://scripts/riso/props/BirdArt.gd",
	&"moths": "res://scripts/riso/props/MothsArt.gd",
	&"fog": "res://scripts/riso/props/FogArt.gd",
	&"laser": "res://scripts/riso/props/LaserArt.gd",
	&"shard": "res://scripts/riso/props/ShardArt.gd",
	&"sign": "res://scripts/riso/props/SignArt.gd",
	&"ferry": "res://scripts/riso/props/FerryArt.gd",
	&"gondola": "res://scripts/riso/props/GondolaArt.gd",
}


## The art for a prefab dressed as `kind_name` (see RisoPrint.art_kind).
static func make(kind_name: StringName) -> RisoProp:
	var art: RisoProp = (load(String(KINDS[kind_name])) as GDScript).new() if KINDS.has(kind_name) else RisoProp.new()
	art.kind = kind_name
	return art


var kind: StringName = &""
var ink: InkCanvas
## The prefab it dresses.
var host: Node2D
## Seconds since it was made, and a phase of its own (so neighbours do not move in step).
var t: float = 0.0
var phase: float = 0.0
## Half a level cell, in world pixels.
var half: float = 64.0
## Plaques and their text (prices, names, shrine pop-ups) are UI: they draw in the UI's canvas
## (RisoPrint.ui_canvas), printed finer than the scene, made the first time a plaque is needed.
var ui_node: Node2D = null
var ui_ink: InkCanvas = null
## Printed text (prices, names), reused frame to frame; see _text().
var labels: Array[Label] = []
var labels_used: int = 0
## This frame's step, capped (for the springs some kinds animate).
var _dt: float = 0.0
## Shrine labels pop up over an offer while the wizard is within POP_REACH of it (see _pop()).
const POP_REACH: Vector2 = Vector2(40, 110)
## Pop-up centre height over the ground: above the interact prompt over the wizard's head.
const POP_Y: float = 255.0
var pops: Array[float] = []


# ------------------------------------------------------------------ what a kind overrides

## Print this frame's art into `ink` (and the UI canvas, through _plaque and _text).
func _draw_art() -> void:
	pass


## Where a guard round it (an enemy's Shield) should centre, in world space: the middle of what
## is drawn. The host's own position, unless a kind draws its body away from it (a wisp).
func guard_center() -> Vector2:
	return host.global_position if host != null else global_position


## Whether it never changes: printed once, then it stops processing.
func still() -> bool:
	return false


## Whether it is only animated while in view (false for what reaches far, like a laser's beam).
func culled() -> bool:
	return true


## The area it covers, when that is wider than its cell (a wind), for telling whether it is in
## view; an empty rect for its cell alone.
func view_rect() -> Rect2:
	return Rect2()


## Each frame in view after the first print: print again (a kind that only moves its canvases
## does that instead).
func _tick() -> void:
	_redraw()


# ------------------------------------------------------------------ printing

func _ready() -> void:
	host = get_parent() as Node2D
	if host != null and host.scale.x != 0.0 and host.scale.y != 0.0:
		scale = Vector2(1.0 / host.scale.x, 1.0 / host.scale.y)
	phase = RisoShapes.hash1(float(host.get_instance_id() % 997)) * TAU if host != null else 0.0
	var tm: TileMap = Stage.tile_map()
	if tm != null and tm.tile_set != null:
		half = float(tm.tile_set.tile_size.y) * tm.global_scale.y * 0.5
	ink = InkCanvas.new()
	add_child(ink)
	z_index = 2
	# First drawn when it first comes into view (see _process), so a level's hundreds of props are
	# not all printed in the frame it loads; still kinds then stop processing.
	set_process(true)


func _process(delta: float) -> void:
	t += delta
	_dt = minf(delta, 0.05)
	# Only animate what the camera can see; off-screen art keeps its last print. The camera's
	# reach is worked out once a frame and shared by every prop (a deep level has hundreds).
	var frame: int = Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		var cam: Camera2D = get_viewport().get_camera_2d()
		_view_on = cam != null
		if _view_on:
			_view_reach = Vector2(get_window().content_scale_size) / cam.zoom * 0.6 + Vector2(160, 160)
			_view_center = cam.get_screen_center_position()
	if _view_on and culled():
		var d: Vector2 = (host.global_position - _view_center).abs()
		# Something spread wide: by its nearest edge, not its middle.
		var r: Rect2 = view_rect()
		if r.has_area():
			d = ((r.get_center() - _view_center).abs() - r.size * 0.5).max(Vector2.ZERO)
		if d.x > _view_reach.x or d.y > _view_reach.y:
			return
	if not _drawn:
		_drawn = true
		_redraw()
		if still():
			set_process(false)
		return
	_tick()


## Printed at least once (props are first printed as they come into view).
var _drawn: bool = false
static var _view_frame: int = -1
static var _view_on: bool = false
static var _view_reach: Vector2 = Vector2.ZERO
static var _view_center: Vector2 = Vector2.ZERO


## Distance from the host's origin down to the ground surface of its cell, in world pixels.
## Measured live because some prefabs (checkpoints) shift themselves after spawning.
func _ground() -> float:
	var tm: TileMap = Stage.tile_map()
	if tm == null or host == null:
		return half
	var cell: Vector2i = tm.local_to_map(tm.to_local(host.global_position))
	return tm.to_global(tm.map_to_local(cell)).y + half - host.global_position.y


func _redraw() -> void:
	ink.begin()
	if ui_ink != null:
		ui_ink.begin()
		_sync_ui()
	labels_used = 0
	_draw_art()
	for i: int in range(labels_used, labels.size()):
		labels[i].visible = false
	ink.finish()
	if ui_ink != null:
		ui_ink.finish()


## The UI canvas, made on first use and kept on this node.
func _ui() -> InkCanvas:
	if ui_ink == null:
		ui_node = RisoPrint.ui_canvas(self)
		ui_node.z_index = 50
		ui_node.z_as_relative = false
		ui_ink = InkCanvas.new()
		ui_ink.ui = true
		ui_node.add_child(ui_ink)
		ui_ink.begin()
		_sync_ui()
	return ui_ink


func _sync_ui() -> void:
	ui_node.global_transform = global_transform
	ui_node.visible = is_visible_in_tree()


## Whether its text (_text) prints in the scene, under the wizard, rather than on the UI's finer
## print over everything (what is read up close, like a door's price, wants the scene).
var text_in_scene: bool = false


## Night-ink serif text centred on `at` (in this prop's pixels); returns its width.
func _text(text: String, at: Vector2, px: int, s: float = 1.0) -> float:
	if labels_used >= labels.size():
		var label: Label = Label.new()
		label.add_theme_font_override("font", RisoTheme.serif())
		label.add_theme_color_override("font_color", Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
		# A same-ink outline thickens the strokes so they print solid instead of screening away.
		label.add_theme_color_override("font_outline_color", Color.WHITE)
		if text_in_scene:
			add_child(label)
		else:
			_ui()
			ui_node.add_child(label)
		labels.append(label)
	var label: Label = labels[labels_used]
	labels_used += 1
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_constant_override("outline_size", maxi(2, px / 9))
	var w: float = RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	label.size = Vector2(w + 8.0, float(px) * 1.4)
	label.text = text
	label.scale = Vector2(s, s)
	label.position = at - label.size * s * 0.5
	label.visible = true
	return w * s


func _plaque_width(text: String, px: int) -> float:
	return RisoTheme.serif().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 22.0


## A bare-paper plaque with `text` on it, centred on `at`, scaled by `s`.
func _plaque(text: String, at: Vector2, px: int, tint: int, s: float = 1.0) -> void:
	var w: float = _plaque_width(text, px) * s
	var h: float = float(px) * 1.25 * s
	var plate: PackedVector2Array = RisoShapes.rrect(at.x - w * 0.5, at.y - h * 0.5, w, h, h * 0.35)
	var u: InkCanvas = _ui()
	u.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [plate])
	u.ink(tint, 0.2, [plate], false)
	_text(text, at, px, s)


## Pop-up `i` eased toward 1 while the wizard stands within reach of `at` (local, world pixels)
## and back to 0 as they leave; returns its scale, with a little overshoot as it opens.
func _pop(i: int, at: Vector2) -> float:
	var player: Player = Stage.player()
	var target: float = 0.0
	if player != null:
		var d: Vector2 = (to_global(at) - player.global_position).abs()
		target = 1.0 if d.x < POP_REACH.x and d.y < POP_REACH.y else 0.0
	while pops.size() <= i:
		pops.append(0.0)
	pops[i] = move_toward(pops[i], target, _dt * 5.0)
	var p: float = pops[i] - 1.0
	return 0.0 if pops[i] < 0.02 else 1.0 + 2.7 * p * p * p + 1.7 * p * p
