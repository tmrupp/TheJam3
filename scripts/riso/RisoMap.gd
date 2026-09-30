extends Node2D
## The printed map. ShowMap (M, or the pad's Y) cycles: the level, then the world, then closed.
## It pauses the game while open. Laid out in the 320 x 180 UI space and printed with the art,
## like the HUD.
## - Level view: the level as far as it has been seen (MapInfo.seen), rock in blue ink and open
##   ground as a faint wash, with its exits, shrine, lanterns, doors, keys, the ghost and the
##   wizard marked where seen.
## - World view: every visited level as a tile on the (world, depth) grid, joined where a side
##   door has been opened or a deeper door paid, with the respawn lantern, the ghost and spent
##   shrines marked.

enum View { CLOSED, LEVEL, WORLD }

const TEXT_PX: int = 64
const PANEL: Rect2 = Rect2(8, 8, 304, 164)
const AREA: Rect2 = Rect2(16, 30, 288, 136)
const TILE: Vector2 = Vector2(34, 18)
const PITCH: Vector2 = Vector2(42, 26)

var view: int = View.CLOSED
var t: float = 0.0
var back: InkCanvas
var rock: Sprite2D
var open: Sprite2D
var marks: InkCanvas
var labels: Array[Label] = []
var labels_used: int = 0
var font: SystemFont
var _built_version: int = -1
var _built_coord: Vector2i = Vector2i(-99999, -99999)
var _paused_by_map: bool = false


func _ready() -> void:
	z_index = 70
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"riso_art")
	font = RisoTheme.serif()
	back = InkCanvas.new()
	add_child(back)
	open = _layer(RisoPrint.BLUE, 0.22)
	rock = _layer(RisoPrint.BLUE, 1.0)
	marks = InkCanvas.new()
	add_child(marks)
	visible = false


func _layer(plate: int, cover: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.visibility_layer = RisoPrint.plate_mask(plate)
	s.modulate = Color(1, 1, 1, cover)
	add_child(s)
	RisoPrint.share_layers(s)
	return s


func is_open() -> bool:
	return view != View.CLOSED


## Level, world, closed. Opening pauses the game; closing resumes it.
func cycle() -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or info.travelling or info.run_ending > 0.0:
		return
	var menu: CanvasItem = get_node_or_null("/root/Main/Menu") as CanvasItem
	if menu != null and menu.visible:
		return
	view = (view + 1) % 3
	visible = view != View.CLOSED and RisoPrint.is_on()
	if view != View.CLOSED and not get_tree().paused:
		get_tree().paused = true
		_paused_by_map = true
	elif view == View.CLOSED and _paused_by_map:
		get_tree().paused = false
		_paused_by_map = false
	_built_version = -1


func close() -> void:
	if view != View.CLOSED:
		view = View.WORLD
		cycle()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ShowMap"):
		cycle()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("Menu"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	t += delta
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var base: Vector2 = Vector2(get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var size: Vector2 = base / cam.zoom
	global_position = cam.get_screen_center_position() - size * 0.5
	scale = Vector2.ONE / cam.zoom
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return
	labels_used = 0
	back.begin()
	marks.begin()
	back.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW], [RisoShapes.rrect(PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y, 10)])
	back.ink(RisoPrint.BLUE, 0.08, [RisoShapes.rrect(PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y, 10)], false)
	if view == View.LEVEL:
		_level(info)
	else:
		rock.visible = false
		open.visible = false
		_world(info)
	for i: int in range(labels_used, labels.size()):
		labels[i].visible = false
	back.finish()
	marks.finish()


# ------------------------------------------------------------------ level view

## Where cell `v` of the level lands on the map.
func level_origin(info: MapInfo) -> Vector2:
	var k: float = level_scale(info)
	var size: Vector2 = Vector2(info.world.size) * k
	return AREA.position + (AREA.size - size) * 0.5


func level_scale(info: MapInfo) -> float:
	return minf(AREA.size.x / float(info.world.size.x), AREA.size.y / float(info.world.size.y))


func to_map(info: MapInfo, v: Vector2) -> Vector2:
	return level_origin(info) + v * level_scale(info)


func _level(info: MapInfo) -> void:
	_text(MapInfo.where(info.coord), Vector2(18, 12), 10.0, false)
	_text("M: worlds", Vector2(302, 14), 7.0, true)
	if _built_version != info.seen_version or _built_coord != info.coord:
		_build_textures(info)
	var k: float = level_scale(info)
	var o: Vector2 = level_origin(info)
	for s: Sprite2D in [rock, open]:
		s.visible = true
		s.position = o
		s.scale = Vector2(k, k)
	for node: Node in info.map_elements.get_children():
		if node.is_queued_for_deletion() or not (node is Node2D):
			continue
		var c: Vector2i = info.cell_at((node as Node2D).global_position)
		var file: String = node.scene_file_path.get_file()
		if file != "corpse.tscn" and not info.is_seen(c):
			continue
		var at: Vector2 = to_map(info, Vector2(c) + Vector2(0.5, 0.5))
		match file:
			"level_exit.tscn":
				_exit_mark(node, at)
			"shrine.tscn":
				var used: bool = bool(node.call("used"))
				marks.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.arch(at.x - 2.5, at.y - 3.5, 5, 6, 6)], false)
			"checkpoint.tscn":
				var lit: bool = info.is_respawn_lantern(node)
				if lit:
					marks.ink(RisoPrint.EYE, 0.3, [RisoShapes.circle(at, 4.5, 16)], false)
				marks.ink(RisoPrint.EYE, 1.0 if lit else 0.5, [RisoShapes.circle(at, 1.6, 10)], false)
			"door.tscn":
				for plate: int in RisoPrint.key_inks(int(node.get_meta(&"key_color", 0))):
					marks.ink(plate, 1.0, [RisoShapes.rrect(at.x - 0.9, at.y - 2.6, 1.8, 5.2, 0.8)], false)
			"key.tscn":
				var sprite: CanvasItem = node.get_node_or_null("Sprite2D") as CanvasItem
				if sprite == null or sprite.visible:
					for plate: int in RisoPrint.key_inks(int(node.get_meta(&"key_color", 0))):
						marks.ink(plate, 1.0, [RisoShapes.circle(at, 1.3, 8)], false)
			"corpse.tscn":
				var ghost_at: Vector2 = to_map(info, Vector2(info.cell_at((node as Node2D).global_position)) + Vector2(0.5, 0.5))
				marks.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.22, 0.22), 0.0, ghost_at + Vector2(0, 3))), false)
	# The wizard, always: a hat over a lit eye, bobbing.
	var p: Vector2 = to_map(info, Vector2(info.cell_at(info.player.global_position)) + Vector2(0.5, 0.5)) + Vector2(0, sin(t * 4.0) * 0.6)
	marks.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [RisoShapes.circle(p, 3.6, 14)])
	marks.ink(RisoPrint.PINK, 1.0, [RisoShapes.tri(p + Vector2(-2.6, 0.6), p + Vector2(2.6, 0.6), p + Vector2(0.4, -4.2))], false)
	marks.ink(RisoPrint.EYE, 1.0, [RisoShapes.circle(p + Vector2(0, 1.8), 1.1, 8)], false)


func _exit_mark(node: Node, at: Vector2) -> void:
	var which: int = int(node.get("exit"))
	var dir: Vector2 = Vector2.DOWN
	match which:
		MapInfo.Exit.BACK: dir = Vector2.UP
		MapInfo.Exit.LEFT: dir = Vector2.LEFT
		MapInfo.Exit.RIGHT: dir = Vector2.RIGHT
	var needs: int = int(node.call("lock"))
	var owed: int = int(node.call("price"))
	var ink: int = RisoPrint.PINK if which == MapInfo.Exit.DEEPER else RisoPrint.NIGHT
	marks.knock([RisoPrint.BLUE, RisoPrint.NIGHT], [RisoShapes.circle(at, 5.2, 16)])
	marks.ink(ink, 1.0, [RisoProp.chevron(at - dir * 2.0, dir, 0.24)], false)
	if needs >= 0:
		for plate: int in RisoPrint.key_inks(needs):
			marks.ink(plate, 1.0, [RisoShapes.circle(at + Vector2(4.2, -4.2), 1.6, 8)], false)
	elif owed > 0:
		marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.sparkle(at + Vector2(4.2, -4.2), 2.6)], false)


## Seen rock and seen open ground as two one-pixel-per-cell textures on their plates.
func _build_textures(info: MapInfo) -> void:
	_built_version = info.seen_version
	_built_coord = info.coord
	var w: MapInfo.World = info.world
	var rock_img: Image = Image.create(w.size.x, w.size.y, false, Image.FORMAT_LA8)
	var open_img: Image = Image.create(w.size.x, w.size.y, false, Image.FORMAT_LA8)
	var bytes: PackedByteArray = info.seen()
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if bytes[x * w.size.y + y] == 0:
				continue
			if w.get_cell(Vector2i(x, y)).type == MapInfo.Type.GROUND:
				rock_img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				open_img.set_pixel(x, y, Color(1, 1, 1, 1))
	rock.texture = ImageTexture.create_from_image(rock_img)
	open.texture = ImageTexture.create_from_image(open_img)


# ------------------------------------------------------------------ world view

## Every visited level: coord -> its record.
func tiles(info: MapInfo) -> Dictionary:
	return info.records


## Pairs of visited levels joined by an opened side door or a paid deeper door.
func links(info: MapInfo) -> Array[Array]:
	var out: Array[Array] = []
	var known: Dictionary = {}
	for c: Vector2i in info.records:
		var rec: Dictionary = info.records[c]
		var open_sides: Dictionary = rec.get("lateral_open", {})
		if open_sides.has(MapInfo.Exit.RIGHT):
			_link(out, known, [c, c + Vector2i(1, 0)])
		if open_sides.has(MapInfo.Exit.LEFT):
			_link(out, known, [c + Vector2i(-1, 0), c])
		if bool(rec.get("deeper_paid", false)):
			_link(out, known, [c, c + Vector2i(0, 1)])
	return out


func _link(out: Array[Array], known: Dictionary, pair: Array) -> void:
	var key: String = "%s>%s" % [pair[0], pair[1]]
	if not known.has(key):
		known[key] = true
		out.append(pair)


func tile_at(info: MapInfo, c: Vector2i) -> Vector2:
	return Vector2(160, 98) + Vector2(c - info.coord) * PITCH


func _world(info: MapInfo) -> void:
	_text("world %d  ·  deepest %d" % [info.run_seed, info.deepest], Vector2(18, 12), 10.0, false)
	_text("M: close", Vector2(302, 14), 7.0, true)
	var area: Rect2 = AREA.grow(-2.0)
	var bars: Array[PackedVector2Array] = []
	for pair: Array in links(info):
		var a: Vector2 = tile_at(info, pair[0])
		var b: Vector2 = tile_at(info, pair[1])
		if not (area.has_point(a) or area.has_point(b)):
			continue
		var d: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-d.y, d.x)
		var s: Vector2 = a + d * (TILE.x * 0.5 if d.x != 0.0 else TILE.y * 0.5)
		var e: Vector2 = b - d * (TILE.x * 0.5 if d.x != 0.0 else TILE.y * 0.5)
		bars.append(PackedVector2Array([s + side * 1.6, e + side * 1.6, e - side * 1.6, s - side * 1.6]))
	marks.ink(RisoPrint.BLUE, 1.0, bars, false)
	for c: Vector2i in tiles(info):
		var at: Vector2 = tile_at(info, c)
		if not area.encloses(Rect2(at - TILE * 0.5, TILE)):
			continue
		var rect: PackedVector2Array = RisoShapes.rrect(at.x - TILE.x * 0.5, at.y - TILE.y * 0.5, TILE.x, TILE.y, 5)
		var here: bool = c == info.coord
		marks.ink(RisoPrint.ACCENT if here else RisoPrint.BLUE, 0.55 if here else 0.25, [rect], false)
		_text("%d · %d" % [c.x, c.y], at + Vector2(0, -3.5), 6.5, false, true)
		var rec: Dictionary = info.records[c]
		if c == info.respawn_coord:
			marks.ink(RisoPrint.EYE, 1.0, [RisoShapes.circle(at + Vector2(-TILE.x * 0.5 + 4.0, TILE.y * 0.5 - 4.0), 1.8, 10)], false)
		if bool(rec.get("shrine_used", false)):
			marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.arch(at.x - 1.8, at.y + TILE.y * 0.5 - 7.0, 3.6, 4.5, 6)], false)
		if info.has_ghost and c == info.ghost_coord:
			marks.ink(RisoPrint.GLOW, 1.0, RisoProp.ghost_shape(Transform2D(0.0, Vector2(0.2, 0.2), 0.0, at + Vector2(TILE.x * 0.5 - 4.0, TILE.y * 0.5 - 1.0))), false)


# ------------------------------------------------------------------ text

func _text(text: String, at: Vector2, px: float, right: bool, centred: bool = false) -> void:
	if labels_used >= labels.size():
		var label: Label = Label.new()
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", TEXT_PX)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
		add_child(label)
		labels.append(label)
	var label: Label = labels[labels_used]
	labels_used += 1
	var k: float = px / float(TEXT_PX)
	label.scale = Vector2(k, k)
	label.text = text
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * k
	var x: float = at.x - w if right else (at.x - w * 0.5 if centred else at.x)
	label.position = Vector2(x, at.y)
	label.visible = true
