extends Node2D
## The printed map. ShowMap (M, or the pad's Y) opens it on the level page and closes it; while it
## is open, Left/Right (A/D, the arrow keys) turn between the level and worlds pages, and Menu
## also closes it.
## It pauses the game while open. Laid out in the 320 x 180 UI space and printed with the art,
## like the HUD.
## - Level view: the level as far as it has been seen (MapInfo.seen), rock in blue ink and open
##   ground as a faint wash, with its exits, shrine, lanterns, doors, keys, the ghost and the
##   wizard marked where seen.
## - World view: every visited level as a tile on the (world, depth) grid, joined where a side
##   door has been opened or a deeper door paid, with the respawn lantern, the ghost and spent
##   shrines marked.
## Each page has a legend down its right edge, drawn with the same marks as the map.

enum View { CLOSED, LEVEL, WORLD }

const TEXT_PX: int = 64
const PANEL: Rect2 = Rect2(8, 8, 304, 164)
const AREA: Rect2 = Rect2(16, 30, 218, 136)
const LEGEND: Rect2 = Rect2(242, 30, 64, 136)
const TILE: Vector2 = Vector2(34, 18)
const PITCH: Vector2 = Vector2(42, 26)
## The size of a sigil (Sigils) by a switch, gate or bell on the map; a teleporter's is a little
## bigger.
const SIGIL_MARK: float = 1.5
## The size of a way out's chevron on the level map (RisoMarks.chevron), about a cell across.
const EXIT_MARK: float = 0.15

var view: int = View.CLOSED
var t: float = 0.0
var back: InkCanvas
var rock: Sprite2D
var open: Sprite2D
var marks: InkCanvas
## The node in the UI's canvas holding all the map's art.
var canvas: Node2D
var labels: Array[Label] = []
var labels_used: int = 0
var font: SystemFont
var _built_version: int = -1
var _built_coord: Vector2i = Vector2i(-99999, -99999)
var _paused_by_map: bool = false
## The level the level page shows (the one being played unless picked on the worlds page), and
## the worlds page's cursor.
var viewing: Vector2i = Vector2i.ZERO
var selected: Vector2i = Vector2i.ZERO


func _ready() -> void:
	z_index = 70
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"riso_art")
	font = RisoTheme.serif()
	# The map is UI: it draws in the UI's canvas (RisoPrint.ui_canvas), printed finer than the scene
	# and above the HUD and prompts there, kept on this node.
	canvas = RisoPrint.ui_canvas(self)
	canvas.z_index = 70
	canvas.z_as_relative = false
	canvas.visible = false
	back = InkCanvas.new()
	back.ui = true
	canvas.add_child(back)
	open = _layer(RisoPrint.BLUE, 0.22)
	rock = _layer(RisoPrint.BLUE, 1.0)
	marks = InkCanvas.new()
	marks.ui = true
	canvas.add_child(marks)
	visible = false


func _layer(plate: int, cover: float) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.visibility_layer = RisoPrint.plate_mask(plate)
	s.modulate = Color(1, 1, 1, cover)
	canvas.add_child(s)
	RisoPrint.share_layers(s)
	return s


func is_open() -> bool:
	return view != View.CLOSED


## Open on the level page, or close. Opening pauses the game; closing resumes it.
func toggle() -> void:
	_show(View.CLOSED if is_open() else View.LEVEL)


## Turn the page: +1 toward the worlds page, -1 back to the level.
func page(step: int) -> void:
	if is_open():
		_show(clampi(view + step, View.LEVEL, View.WORLD))


func _show(next: int) -> void:
	var info: MapInfo = MapInfo.instance
	if next != View.CLOSED:
		if info == null or info.world == null or info.travelling or info.run_ending > 0.0:
			return
		var menu: CanvasLayer = Stage.menu()
		if menu != null and menu.visible:
			return
	if view == View.CLOSED and next != View.CLOSED:
		viewing = info.coord
		selected = info.coord
	view = next
	visible = view != View.CLOSED and RisoPrint.is_on()
	canvas.visible = visible
	if view != View.CLOSED and not get_tree().paused:
		get_tree().paused = true
		_paused_by_map = true
	elif view == View.CLOSED and _paused_by_map:
		get_tree().paused = false
		_paused_by_map = false
	_built_version = -1


func close() -> void:
	_show(View.CLOSED)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ShowMap"):
		toggle()
		get_viewport().set_input_as_handled()
	elif not is_open():
		return
	elif event.is_action_pressed("Menu"):
		close()
		get_viewport().set_input_as_handled()
	elif view == View.WORLD:
		_world_input(event)
	elif event.is_action_pressed("Left") or event.is_action_pressed("ui_left"):
		page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Right") or event.is_action_pressed("ui_right"):
		page(1)
		get_viewport().set_input_as_handled()


## The worlds page: move the cursor, open the level under it, or click a tile.
func _world_input(event: InputEvent) -> void:
	var info: MapInfo = MapInfo.instance
	if info == null:
		return
	var step: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("Left") or event.is_action_pressed("ui_left"):
		step = Vector2i.LEFT
	elif event.is_action_pressed("Right") or event.is_action_pressed("ui_right"):
		step = Vector2i.RIGHT
	elif event.is_action_pressed("Up") or event.is_action_pressed("ui_up"):
		step = Vector2i.UP
	elif event.is_action_pressed("Down") or event.is_action_pressed("ui_down"):
		step = Vector2i.DOWN
	if step != Vector2i.ZERO:
		var next: Variant = _nearest_tile(info, selected, step)
		if next != null:
			selected = next
		elif step == Vector2i.LEFT:
			page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Discover") or event.is_action_pressed("Jump") or event.is_action_pressed("ui_accept"):
		open_level(selected)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = to_local(get_global_mouse_position())
		for c: Vector2i in pickable(info):
			var hit: bool = Geometry2D.is_point_in_polygon(at, _ribbon(side_curve(info, c), tile_size(c).x + 4.0, 0.0, MOUTH)) if Worlds.is_side(c) \
				else Rect2(tile_at(info, c) - tile_size(c) * 0.5, tile_size(c)).has_point(at)
			if hit:
				selected = c
				open_level(c)
				get_viewport().set_input_as_handled()
				return


## Show level `c`'s page (a visited level).
func open_level(c: Vector2i) -> void:
	var info: MapInfo = MapInfo.instance
	if info == null or not (info.run.records.has(c) or info.run.relic_hints.has(c)):
		return
	viewing = c
	_show(View.LEVEL)


## The visited (or hinted) level nearest `from` in direction `dir` (within a quarter turn of it), or null.
func _nearest_tile(info: MapInfo, from: Vector2i, dir: Vector2i) -> Variant:
	var best: Variant = null
	var best_score: float = INF
	for c: Vector2i in pickable(info):
		var d: Vector2 = grid_at(c) - grid_at(from)
		var along: float = d.dot(Vector2(dir))
		if along <= 0.0 or absf(d.dot(Vector2(dir).orthogonal())) > along:
			continue
		var score: float = d.length() + absf(d.dot(Vector2(dir).orthogonal())) * 2.0
		if score < best_score:
			best_score = score
			best = c
	return best


## The page tabs, top right: the open page on a tinted tab, with the keys that turn the page.
func _tabs() -> void:
	var names: Array[String] = ["level", "worlds"]
	var x: float = 302.0
	var spots: Array[float] = []
	for i: int in range(names.size() - 1, -1, -1):
		var w: float = font.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * 8.0 / float(TEXT_PX)
		spots.push_front(x - w)
		x -= w + 12.0
	for i: int in range(names.size()):
		var w: float = font.get_string_size(names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x * 8.0 / float(TEXT_PX)
		if view == i + 1:
			marks.ink(RisoPrint.BLUE, 0.25, [RisoShapes.rrect(spots[i] - 4.0, 11.0, w + 8.0, 13.0, 4.0)], false)
		_text(names[i], Vector2(spots[i], 12.0), 8.0, false)
	_text("A / D", Vector2(spots[0] - 9.0, 13.0), 7.0, true)


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
	canvas.global_position = global_position
	canvas.scale = scale
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return
	labels_used = 0
	back.begin()
	marks.begin()
	back.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE], [RisoShapes.rrect(PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y, 10)])
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
	if viewing != info.coord:
		_other_level(info, viewing)
		return
	_text(Rules.where(info.coord), Vector2(18, 12), 10.0, false)
	_tabs()
	if _built_version != info.seen_version or _built_coord != info.coord:
		_build_textures(info)
	var k: float = level_scale(info)
	var o: Vector2 = level_origin(info)
	for s: Sprite2D in [rock, open]:
		s.visible = true
		s.position = o
		s.scale = Vector2(k, k)
	_shown.clear()
	_noting = true
	var spot: Callable = func(v: Vector2i) -> Vector2: return o + (Vector2(v) + Vector2(0.5, 0.5)) * k
	var relic_shown: bool = _mark_level(info, info.coord, info.world, info.record(), info.is_seen, spot)
	# What only the scene knows: the wizard's rifts (a cross-world link's end among them), and the
	# ghost where it drifts.
	for node: Node in info.map_elements.get_children():
		if node.is_queued_for_deletion() or not (node is Node2D):
			continue
		var c: Vector2i = info.cell_at((node as Node2D).global_position)
		if node == info.ghost_node:
			_mark_ghost(spot.call(c), 0.22)
		elif node.has_meta(&"rift") and info.is_seen(c):
			_mark_portal(spot.call(c), 0, true)
	# A relic an ink well marked here, even before its room is found.
	var hinted: Variant = _hinted_relic(info, info.coord, info.world)
	if hinted != null and not relic_shown:
		_mark_relic(to_map(info, Vector2(hinted) + Vector2(0.5, 0.5)), info.run.relic_hints[info.coord], 0.7)
	# The wizard, always, bobbing.
	_mark_wizard(to_map(info, Vector2(info.cell_at(info.player.global_position)) + Vector2(0.5, 0.5)) + Vector2(0, sin(t * 4.0) * 0.6))
	_legend([["you", _mark_wizard]] + _level_rows())


## The level pages' legend rows, each listed only when the page shows it.
func _level_rows() -> Array:
	return [
		["way out", func(at: Vector2) -> void: _mark_exit(at, Vector2.RIGHT, false, -1, 0), "way out"],
		["deeper", func(at: Vector2) -> void: _mark_exit(at, Vector2.DOWN, true, -1, 0), "deeper"],
		["sealed", func(at: Vector2) -> void: _mark_exit(at, Vector2.DOWN, true, -1, 0, 1.0, true), "sealed"],
		["locked", func(at: Vector2) -> void: _mark_exit(at, Vector2.RIGHT, false, 1, 0), "locked"],
		["unpaid", func(at: Vector2) -> void: _mark_exit(at, Vector2.DOWN, true, -1, 8), "unpaid"],
		["shrine", func(at: Vector2) -> void: _mark_shrine(at, false), "shrine"],
		["lantern", func(at: Vector2) -> void: _mark_lantern(at, false), "lantern"],
		["respawn", func(at: Vector2) -> void: _mark_lantern(at, true), "respawn"],
		["spent lantern", func(at: Vector2) -> void: _mark_lantern(at, false, true), "spent lantern"],
		["teleporter", func(at: Vector2) -> void: _mark_portal(at, 1, false), "teleporter"],
		["rift", func(at: Vector2) -> void: _mark_portal(at, 0, true), "rift"],
		["door", func(at: Vector2) -> void: _mark_door(at, 2), "door"],
		["gate", func(at: Vector2) -> void: _mark_gate(at, 2), "gate"],
		["switch", func(at: Vector2) -> void: _mark_switch(at, false, 2), "switch"],
		["bell", func(at: Vector2) -> void: _mark_bell(at, false), "bell"],
		["vane", func(at: Vector2) -> void: _mark_bell(at, false, -2, "vane"), "vane"],
		["bridge", func(at: Vector2) -> void: _mark_bridge(at, true), "bridge"],
		["unrung bridge", func(at: Vector2) -> void: _mark_bridge(at, false), "unrung bridge"],
		["gondola", func(at: Vector2) -> void: _mark_gondola([at + Vector2(-3.0, 3.0), at + Vector2(-3.0, 1.0), at + Vector2(-1.0, 1.0), at + Vector2(-1.0, -1.0), at + Vector2(1.0, -1.0), at + Vector2(1.0, -3.0)], [at + Vector2(-3.0, 3.0), at + Vector2(1.0, -3.0)], at + Vector2(-3.0, 3.0)), "gondola"],
		["toll gate", _mark_toll, "toll gate"],
		["relic", func(at: Vector2) -> void: _mark_relic(at, &"blink", 0.7), "relic"],
	] + _door_rows() + [
		["key", func(at: Vector2) -> void: _mark_key(at, 2), "key"],
		["skeleton key", func(at: Vector2) -> void: _mark_key(at, KeyRing.SKELETON), "skeleton key"],
		["star cluster", _mark_cluster, "star cluster"],
		["ink well", func(at: Vector2) -> void: _mark_inkwell(at, false), "ink well"],
		["ghost", func(at: Vector2) -> void: _mark_ghost(at, 0.22), "ghost"],
	]


## A legend row for each kind of side world's door.
func _door_rows() -> Array:
	var rows: Array = []
	for k: int in range(Worlds.KINDS.size()):
		rows.append(["%s door" % Worlds.proto(k).name, func(at: Vector2) -> void: _mark_plunge(at, 0), "plunge"])
	return rows


## A level other than the one being played, picked on the worlds page: its map as far as it was
## seen, rebuilt from its seed, with what is in it where seen, marked from the layout and its record
## as the level being played is (_mark_level), and its ghost.
func _other_level(info: MapInfo, c: Vector2i) -> void:
	_text(Rules.where(c), Vector2(18, 12), 10.0, false)
	_tabs()
	var w: LevelGen = info.world_at(c)
	if w == null:
		rock.visible = false
		open.visible = false
		_text("inking…", AREA.get_center() + Vector2(0, -5), 9.0, false, true)
		return
	var rec: LevelRecord = info.run.records.get(c, LevelRecord.new())
	var bytes: PackedByteArray = rec.seen
	var stamp: int = bytes.size() + bytes.count(1) * 7919
	if _built_coord != c or _built_version != stamp:
		_build_textures_for(w, bytes, rec.broken)
		_built_coord = c
		_built_version = stamp
	var k: float = minf(AREA.size.x / float(w.size.x), AREA.size.y / float(w.size.y))
	var o: Vector2 = AREA.position + (AREA.size - Vector2(w.size) * k) * 0.5
	for s: Sprite2D in [rock, open]:
		s.visible = true
		s.position = o
		s.scale = Vector2(k, k)
	var seen: Callable = func(v: Vector2i) -> bool: return v.x * w.size.y + v.y < bytes.size() and bytes[v.x * w.size.y + v.y] != 0
	var spot: Callable = func(v: Vector2i) -> Vector2: return o + (Vector2(v) + Vector2(0.5, 0.5)) * k
	_shown.clear()
	_noting = true
	var relic_shown: bool = _mark_level(info, c, w, rec, seen, spot)
	var hinted: Variant = _hinted_relic(info, c, w)
	if hinted != null and not relic_shown:
		_mark_relic(spot.call(hinted), info.run.relic_hints[c], 0.7)
	if info.run.has_ghost and info.run.ghost_coord == c:
		_mark_ghost(spot.call(info.cell_at(info.run.ghost_pos)), 0.22)
	_text("D: worlds", Vector2(AREA.position.x, AREA.end.y - 6.0), 6.5, false)
	_legend(_level_rows())


## The colour of each key and door laid out in `w` ({cell: colour}), as the level dealt them
## (LevelGen.deal_colors).
static func dealt_colors(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type in [LevelGen.Type.KEY, LevelGen.Type.DOOR]:
			out[v] = _dealt(cell)
	return out


## Everything laid out in level `w` (place `c`) where `seen`, marked at `spot` as its record `rec`
## leaves it (taken, opened, thrown, rung, spent, paid): exits, the shrine, the ink well, lanterns,
## teleporters, keys, doors, gates, switches, relics, star clusters, bells and vanes, bridges, what
## opened secret rooms hold, and the keys dropped there. The level being played is marked the same
## way: its record changes the moment its things do. Whether a relic was marked comes back.
func _mark_level(info: MapInfo, c: Vector2i, w: LevelGen, rec: LevelRecord, seen: Callable, spot: Callable) -> bool:
	var place: NextWorldDef = info.here if c == info.coord and info.here != null else Rules.def_for(c)
	var relic_shown: bool = false
	var done: Dictionary = {}
	for v: Vector2i in w.objects:
		if done.has(v) or not seen.call(v):
			continue
		done[v] = true
		relic_shown = _mark_cell(info, c, w, v, w.get_cell(v), rec, place, spot) or relic_shown
	# An opened secret room's rewards, which are not among the layout's cells.
	for id: int in rec.secrets:
		if id < 0 or id >= w.secrets.size():
			continue
		for reward: Array in w.secrets[id]["rewards"]:
			var v: Vector2i = reward[0]
			if not seen.call(v):
				continue
			var cell: LevelGen.Cell = LevelGen.Cell.new(reward[1])
			cell.extra_info = reward[2]
			relic_shown = _mark_cell(info, c, w, v, cell, rec, place, spot) or relic_shown
	var dropped: Dictionary = rec.dropped
	for id: Variant in dropped:
		var drop: Array = dropped[id]
		var v: Vector2i = info.cell_at(drop[0])
		if w.is_valid(v) and seen.call(v):
			_mark_key(spot.call(v), int(drop[1]))
	return relic_shown


## The mark for the thing in `cell` at `v` of level `c` (laid out as `w`, place `place`), as its
## record `rec` leaves it; nothing for what the map does not show, or what is gone. Whether it
## marked a relic comes back.
func _mark_cell(info: MapInfo, c: Vector2i, w: LevelGen, v: Vector2i, cell: LevelGen.Cell, rec: LevelRecord, place: NextWorldDef, spot: Callable) -> bool:
	var at: Vector2 = spot.call(v)
	var gone: bool = (rec.taken as Dictionary).has(v) or (rec.opened as Dictionary).has(v)
	match cell.type:
		LevelGen.Type.EXIT:
			var which: int = int(cell.extra_info)
			var owed: int = place.price(which, rec)
			if place.exit_grand(which):
				_mark_plunge(at, owed)
			else:
				_mark_exit(at, place.exit_dir(which), place.leads_on(which), LevelExit.lock_at(c, which, rec), owed, 1.0, place.seal(which, info.run) != &"")
		LevelGen.Type.SHRINE:
			_mark_shrine(at, bool(rec.shrine_used))
		LevelGen.Type.INKWELL:
			_mark_inkwell(at, bool(rec.mapped))
		LevelGen.Type.CHECKPOINT:
			var spent: bool = (rec.spent_lanterns as Dictionary).has(v)
			var lit: bool = not spent and not info.run.vulnerable and info.run.respawn_coord == c and info.run.respawn_cell == v
			_mark_lantern(at, lit, spent)
		LevelGen.Type.PORTAL:
			_mark_portal(at, w.sigil_at(v), false)
		LevelGen.Type.KEY:
			if not gone:
				_mark_key(at, _dealt(cell))
		LevelGen.Type.DOOR:
			if not gone:
				_mark_door(at, _dealt(cell))
		LevelGen.Type.SWITCH_GATE:
			# Shown while down (its switch off).
			if not (cell.extra_info is Vector2i and Switch.is_on_in(w, rec, cell.extra_info)):
				_mark_gate(at, w.sigil_at(v))
		LevelGen.Type.SWITCH:
			_mark_switch(at, Switch.is_on_in(w, rec, v), w.sigil_at(v))
		LevelGen.Type.RELIC:
			if gone:
				return false
			# A spell swapped onto the relic's plinth waits there instead (Relic.holds).
			var left: Array = rec.relic_left
			_mark_relic(at, StringName(left[0]) if left.size() == 2 else StringName(cell.extra_info), 0.7)
			return true
		LevelGen.Type.CLUSTER:
			if not gone:
				_mark_cluster(at)
		LevelGen.Type.BRIDGE:
			_mark_bridge(at, (rec.bridges as Dictionary).has(int(cell.extra_info)))
		LevelGen.Type.GONDOLA:
			var circuit: Dictionary = cell.extra_info
			var track: Array[Vector2i] = circuit["path"]
			var corners: Array[Vector2] = []
			for i: int in CragsArchetype.turns(track):
				corners.append(spot.call(track[i]))
			var stops: Array[Vector2] = []
			for stop: Vector2i in circuit["stops"]:
				stops.append(spot.call(stop))
			_mark_gondola(corners, stops, at)
		LevelGen.Type.TOLL:
			if not gone:
				_mark_toll(at)
		LevelGen.Type.BELL:
			var bell: Array = cell.extra_info
			var rung: bool = (rec.bridges as Dictionary).has(int(bell[0]))
			_mark_bell(at, rung, -2 if rung or Bell.free_in(w, rec, v, int(bell[1])) else int(bell[1]), "bell", w.sigil_at(v))
		LevelGen.Type.VANE:
			var vane: Array = cell.extra_info
			var blowing: bool = (rec.winds as Dictionary).get(int(vane[0])) == v
			_mark_bell(at, blowing, -2 if blowing or Bell.free_in(w, rec, v, int(vane[1])) else int(vane[1]), "vane", w.sigil_at(v))
	return false


## The key colour a key or door's cell was dealt (LevelGen.deal_colors).
static func _dealt(cell: LevelGen.Cell) -> int:
	return int(cell.extra_info) if cell.extra_info != null else 0


# ------------------------------------------------------------------ marks (map and legend)
# Marks are abstract and printed over whatever is under them (rock, ground, each other), never
# knocking it out: they overlap and intersect as the plates do. While a page is drawn, each mark
# notes its legend row (see _note), and the legend lists only what is on the page.

## Legend rows the page being drawn has shown (see _legend), and whether marks note theirs now.
var _shown: Dictionary = {}
var _noting: bool = false


func _note(row: String) -> void:
	if _noting:
		_shown[row] = true


## A grand door (a side world's door, or its way on): a deeper mark in an accent ring, with a
## second chevron.
func _mark_plunge(at: Vector2, owed: int, k: float = 1.0) -> void:
	_note("plunge")
	marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(at, 4.8 * k, 18)], false)
	var was: bool = _noting
	_noting = false
	_mark_exit(at, Vector2.DOWN, true, -1, owed, k)
	_noting = was
	marks.ink(RisoPrint.PINK, 1.0, [RisoMarks.chevron(at + Vector2(0, 1.6) * k, Vector2.DOWN, EXIT_MARK * 0.85 * k)], false)


## A relic: its move's mark in night ink over an accent ring.
func _mark_relic(at: Vector2, move: StringName, k: float = 1.0) -> void:
	_note("relic")
	marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(at, 6.4 * k, 18)], false)
	var fit: Transform2D = Transform2D(0.0, Vector2(0.15, 0.15) * k, 0.0, at)
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(move, Vector2.ZERO, t):
		mark.append(fit * poly)
	marks.ink(RisoPrint.NIGHT, 1.0, mark, false)


## A switch gate: a bar like a door's, in night ink, with the switch's accent dot.
## A switch gate: a night bar with its switch's sigil (Sigils) beside it.
func _mark_gate(at: Vector2, sigil_kind: int) -> void:
	_note("gate")
	marks.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.rrect(at.x - 0.9, at.y - 2.6, 1.8, 5.2, 0.8)], false)
	_mark_sigil(at + Vector2(2.9, -2.6), sigil_kind)


## A switch: a little lever, pink before it is thrown, accent after, with its sigil beside it.
func _mark_switch(at: Vector2, thrown: bool, sigil_kind: int) -> void:
	_note("switch")
	marks.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.rrect(at.x - 2.4, at.y + 0.6, 4.8, 1.8, 0.9), Transform2D(0.5 if thrown else -0.5, at + Vector2(0, 1.0)) * RisoShapes.rrect(-0.5, -4.0, 1.0, 4.2, 0.5)], false)
	marks.ink(RisoPrint.ACCENT if thrown else RisoPrint.PINK, 1.0, [RisoShapes.circle(at + Vector2(1.9 if thrown else -1.9, -3.2), 1.1, 8)], false)
	_mark_sigil(at + Vector2(4.4, -1.2), sigil_kind)


## The sigil a switch shares with what it works, small, in night ink (nothing for -1).
func _mark_sigil(at: Vector2, sigil_kind: int) -> void:
	if sigil_kind >= 0:
		marks.ink(RisoPrint.NIGHT, 1.0, RisoMarks.sigil(sigil_kind, at, SIGIL_MARK), false)


## A way out: a chevron the way it leads (pink for deeper), with a boss's seal while a boss bars it
## (Bosses), a key-colour dot while locked, or a star while unpaid.
func _mark_exit(at: Vector2, dir: Vector2, deeper: bool, needs: int, owed: int, k: float = 1.0, sealed: bool = false) -> void:
	_note("sealed" if sealed else ("locked" if needs >= 0 else ("unpaid" if owed > 0 else ("deeper" if deeper else "way out"))))
	marks.ink(RisoPrint.PINK if deeper else RisoPrint.NIGHT, 1.0, [RisoMarks.chevron(at + dir * 4.0 * EXIT_MARK * k, dir, EXIT_MARK * k)], false)
	var badge: Vector2 = at + Vector2(3.2, -3.2) * k
	if sealed:
		marks.ink(RisoPrint.PINK, 1.0, [RisoShapes.circle(badge, 1.9 * k, 12)], false)
		marks.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.circle(badge, 0.7 * k, 8)], false)
	elif needs >= 0:
		for plate: int in RisoPrint.key_inks(needs):
			marks.ink(plate, 1.0, [RisoMarks.key_bow(badge, 1.6 * k, needs)], false)
	elif owed > 0:
		marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.sparkle(badge, 2.1 * k)], false)


func _mark_inkwell(at: Vector2, dry: bool) -> void:
	_note("ink well")
	marks.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(at.x - 2.4, at.y - 2.0, 4.8, 4.4, 1.6)], false)
	if not dry:
		marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(at + Vector2(0, -3.6), 1.2, 6)], false)


func _mark_shrine(at: Vector2, used: bool) -> void:
	_note("shrine")
	marks.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.arch(at.x - 2.5, at.y - 3.5, 5, 6, 6)], false)


## A lantern: an eye-yellow dot, haloed on your respawn; a night dot once spent.
func _mark_lantern(at: Vector2, lit: bool, spent: bool = false) -> void:
	_note("respawn" if lit else ("spent lantern" if spent else "lantern"))
	if lit:
		marks.ink(RisoPrint.EYE, 0.3, [RisoShapes.circle(at, 4.5, 16)], false)
	if spent:
		marks.ink(RisoPrint.NIGHT, 0.6, [RisoShapes.circle(at, 1.6, 10)], false)
	else:
		marks.ink(RisoPrint.EYE, 1.0 if lit else 0.5, [RisoShapes.circle(at, 1.6, 10)], false)


## A teleporter: a screened accent disc with its pair's sigil in night ink (the two ends of a pair
## share it, Sigils); a rift the wizard opened is an eye-yellow disc.
func _mark_portal(at: Vector2, sigil_kind: int, rift: bool) -> void:
	_note("rift" if rift else "teleporter")
	marks.ink(RisoPrint.EYE if rift else RisoPrint.ACCENT, 0.55, [RisoShapes.circle(at, 3.0, 14)], false)
	if not rift and sigil_kind >= 0:
		marks.ink(RisoPrint.NIGHT, 1.0, RisoMarks.sigil(sigil_kind, at, SIGIL_MARK * 1.2), false)


func _mark_door(at: Vector2, color: int) -> void:
	_note("door")
	_key_ink(color, [RisoShapes.rrect(at.x - 0.9, at.y - 2.6, 1.8, 5.2, 0.8)])
	_key_ink(color, [RisoMarks.key_bow(at + Vector2(2.6, -2.6), 1.8, color)])


func _mark_key(at: Vector2, color: int) -> void:
	_note("skeleton key" if color == KeyRing.SKELETON else "key")
	_key_ink(color, [RisoMarks.key_bow(at, 2.0, color)])


## A map mark in a key's colour: its inks, or for a skeleton key (bone white, which paper would
## hide) a grey screen of night.
func _key_ink(color: int, polys: Array[PackedVector2Array]) -> void:
	if color == KeyRing.SKELETON:
		marks.ink(RisoPrint.NIGHT, 0.5, polys, false)
		return
	for plate: int in RisoPrint.key_inks(color):
		marks.ink(plate, 1.0, polys, false)


## A plank of a chasm's bridge: a night bar once its bell is rung; before, a faint accent dash.
func _mark_bridge(at: Vector2, up: bool) -> void:
	_note("bridge" if up else "unrung bridge")
	if up:
		marks.ink(RisoPrint.NIGHT, 0.8, [RisoShapes.rrect(at.x - 2.6, at.y - 2.0, 5.2, 1.0, 0.5)], false)
	else:
		marks.ink(RisoPrint.ACCENT, 0.7, [RisoShapes.rrect(at.x - 1.2, at.y - 2.0, 2.4, 0.8, 0.4)], false)


## A gondola: its track through `corners` (from its first station up to its last), a fine night
## line, a blue tick at each of its `stops`, and the car, a small blue box, at `car` (the station it
## waits at when the level loads).
func _mark_gondola(corners: Array[Vector2], stops: Array[Vector2], car: Vector2) -> void:
	_note("gondola")
	var line: PackedVector2Array = PackedVector2Array()
	for c: Vector2 in corners:
		line.append(c + Vector2(0.5, -1.6))
	marks.ink(RisoPrint.NIGHT, 0.6, RisoDecor.strip(line, 0.35, 0.35), false)
	var ticks: Array[PackedVector2Array] = []
	for s: Vector2 in stops:
		ticks.append(RisoShapes.rrect(s.x - 0.2, s.y - 2.2, 1.4, 1.2, 0.3))
	marks.ink(RisoPrint.BLUE, 0.8, ticks, false)
	marks.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(car.x - 0.6, car.y - 1.6, 2.2, 1.8, 0.4)], false)


## A toll gate: a gate's bar with an accent coin beside it.
func _mark_toll(at: Vector2) -> void:
	_note("toll gate")
	marks.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.rrect(at.x - 0.9, at.y - 2.6, 1.8, 5.2, 0.8)], false)
	marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.circle(at + Vector2(2.6, -2.2), 1.2, 10)], false)


## A grave bell: an accent dot (faint once rung), with the key-colour bow of its padlock, or its
## switch's sigil if a switch holds its chain (`lock`: a key colour, -1 a switch, -2 free).
func _mark_bell(at: Vector2, rung: bool, lock: int = -2, row: String = "bell", sigil_kind: int = -1) -> void:
	_note(row)
	marks.ink(RisoPrint.ACCENT, 0.35 if rung else 1.0, [RisoShapes.circle(at, 1.8, 10)], false)
	if lock >= 0:
		for plate: int in RisoPrint.key_inks(lock):
			marks.ink(plate, 1.0, [RisoMarks.key_bow(at + Vector2(2.8, -2.8), 1.8, lock)], false)
	elif lock == -1:
		# Chained to a switch: the switch's sigil, or a night dot.
		if sigil_kind >= 0:
			_mark_sigil(at + Vector2(3.0, -3.0), sigil_kind)
		else:
			marks.ink(RisoPrint.NIGHT, 1.0, [RisoShapes.circle(at + Vector2(2.8, -2.8), 1.2, 8)], false)


## A star cluster: a small star in accent ink.
func _mark_cluster(at: Vector2) -> void:
	_note("star cluster")
	marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.sparkle(at, 2.8)], false)


func _mark_ghost(at: Vector2, size: float) -> void:
	_note("ghost")
	marks.ink(RisoPrint.GLOW, 1.0, RisoMarks.ghost_shape(Transform2D(0.0, Vector2(size, size), 0.0, at + Vector2(0, 3))), false)


## The wizard: a hat over a lit eye.
func _mark_wizard(at: Vector2) -> void:
	marks.ink(RisoPrint.PINK, 1.0, [RisoShapes.tri(at + Vector2(-2.6, 0.6), at + Vector2(2.6, 0.6), at + Vector2(0.4, -4.2))], false)
	marks.ink(RisoPrint.EYE, 1.0, [RisoShapes.circle(at + Vector2(0, 1.8), 1.1, 8)], false)


## The key down the right edge: each entry's mark beside its name, behind a faint rule.
## A row with a third entry (the name its marks note, see _note) is only listed when the page
## showed it.
func _legend(all: Array) -> void:
	_noting = false
	var entries: Array = all.filter(func(e: Array) -> bool: return e.size() < 3 or _shown.has(e[2]))
	marks.ink(RisoPrint.BLUE, 0.3, [RisoShapes.rrect(LEGEND.position.x - 4.0, LEGEND.position.y + 2.0, 0.8, LEGEND.size.y - 4.0, 0.4)], false)
	var step: float = minf(11.0, (LEGEND.size.y - 6.0) / float(entries.size()))
	for i: int in range(entries.size()):
		var y: float = LEGEND.position.y + 6.0 + step * (float(i) + 0.5)
		(entries[i][1] as Callable).call(Vector2(LEGEND.position.x + 6.0, y))
		_text(String(entries[i][0]), Vector2(LEGEND.position.x + 15.0, y - 4.6), 6.5, false)


## Seen rock and seen open ground as two one-pixel-per-cell textures on their plates.
func _build_textures(info: MapInfo) -> void:
	_build_textures_for(info.world, info.seen(), info.record().broken)
	_built_version = info.seen_version
	_built_coord = info.coord


func _build_textures_for(w: LevelGen, bytes: PackedByteArray, broken: Dictionary) -> void:
	var rock_img: Image = Image.create(w.size.x, w.size.y, false, Image.FORMAT_LA8)
	var open_img: Image = Image.create(w.size.x, w.size.y, false, Image.FORMAT_LA8)
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if x * w.size.y + y >= bytes.size() or bytes[x * w.size.y + y] == 0:
				continue
			var kind: int = w.get_cell(Vector2i(x, y)).type
			# Cracked walls look like rock on the map until they are broken.
			if kind == LevelGen.Type.GROUND or (kind == LevelGen.Type.CRACKED and not broken.has(Vector2i(x, y))):
				rock_img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				open_img.set_pixel(x, y, Color(1, 1, 1, 1))
	rock.texture = ImageTexture.create_from_image(rock_img)
	open.texture = ImageTexture.create_from_image(open_img)


# ------------------------------------------------------------------ world view

## Every visited level: coord -> its record.
func tiles(info: MapInfo) -> Dictionary:
	return info.run.records


## Every level the cursor can pick: the visited ones, and those an ink well has marked a relic in.
func pickable(info: MapInfo) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in info.run.records:
		out.append(c)
	for c: Vector2i in info.run.relic_hints:
		if not out.has(c):
			out.append(c)
	return out


## Where level `c`'s relic waits, if an ink well marked it and it is not taken yet; else null.
func _hinted_relic(info: MapInfo, c: Vector2i, w: LevelGen) -> Variant:
	if w == null or not info.run.relic_hints.has(c) or info.run.relics_found.has(c):
		return null
	for secret: Dictionary in w.secrets:
		for reward: Array in secret["rewards"]:
			if reward[1] == LevelGen.Type.RELIC:
				return reward[0]
	for v: Vector2i in w.objects:
		if w.get_cell(v).type == LevelGen.Type.RELIC:
			return v
	return null


## Pairs of visited levels joined by an opened side door, a paid way on (away from the start, up or
## down), the start's paid way up, or an ordinary way back taken from a level a side world leads
## into.
func links(info: MapInfo) -> Array[Array]:
	var out: Array[Array] = []
	var known: Dictionary = {}
	for c: Vector2i in info.run.records:
		var rec: LevelRecord = info.run.records[c]
		var open_sides: Dictionary = rec.lateral_open
		if open_sides.has(MapInfo.Exit.RIGHT):
			_link(out, known, [c, c + Vector2i(1, 0)])
		if open_sides.has(MapInfo.Exit.LEFT):
			_link(out, known, [c + Vector2i(-1, 0), c])
		var on: int = NextWorldDef.away(c.y)
		if bool(rec.deeper_paid):
			_link(out, known, [c, c + Vector2i(0, on)])
		if bool(rec.up_paid):
			_link(out, known, [c, c + Vector2i(0, -1)])
		if (rec.ways_taken as Dictionary).has(MapInfo.Exit.RETURN):
			_link(out, known, [c - Vector2i(0, on), c])
	return out


func _link(out: Array[Array], known: Dictionary, pair: Array) -> void:
	var key: String = "%s>%s" % [pair[0], pair[1]]
	if not known.has(key):
		known[key] = true
		out.append(pair)


## Where place `c` sits on the worlds grid, in tiles. A side world hangs where its definition
## says (NextWorldDef.grid_at): hyperspace centred between the level it is entered from and the
## one its gate drops to, so it reads as the long way between them.
func grid_at(c: Vector2i) -> Vector2:
	return Rules.def_for(c).grid_at() if Worlds.is_side(c) else Vector2(c)


## A tile's size: levels are boxes; for a side world, x is its ribbon's width and y its span.
func tile_size(c: Vector2i) -> Vector2:
	if Worlds.is_side(c):
		var side: SideWorld = Rules.def_for(c) as SideWorld
		var rows: int = absi(side.destination().y - side.origin().y)
		return Vector2(9, maxf(PITCH.y - TILE.y - 2.0, rows * PITCH.y - TILE.y - 2.0))
	return TILE


## Where level `c`'s tile sits on the worlds page, centred on the cursor.
func tile_at(_info: MapInfo, c: Vector2i) -> Vector2:
	return AREA.get_center() + (grid_at(c) - grid_at(selected)) * PITCH


func _world(info: MapInfo) -> void:
	_text("world %d  ·  furthest %d" % [info.run.run_seed, info.run.deepest], Vector2(18, 12), 10.0, false)
	_tabs()
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
	# Side worlds first: they run alongside the levels they skip, which print over them.
	var order: Array[Vector2i] = []
	for c: Vector2i in tiles(info):
		order.append(c)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Worlds.is_side(a) and not Worlds.is_side(b))
	for c: Vector2i in order:
		var at: Vector2 = tile_at(info, c)
		var size: Vector2 = tile_size(c)
		if Worlds.is_side(c):
			var place: SideWorld = Rules.def_for(c) as SideWorld
			var curve: PackedVector2Array = side_curve(info, c)
			var bounds: Rect2 = Rect2(curve[0], Vector2.ZERO)
			for p: Vector2 in curve:
				bounds = bounds.expand(p)
			if not bounds.grow(6.0).intersects(area):
				continue
			_mark_side(curve, size.x, c == info.coord, area)
			# Marks sit on the curve as far along it as they are across the world, on a clear spot.
			if c == info.run.respawn_coord:
				var lit: Vector2 = _along(curve, place.progress(info.run.respawn_cell))
				if area.has_point(lit):
					marks.knock([RisoPrint.ACCENT, RisoPrint.PINK], [RisoShapes.circle(lit, 3.2, 12)])
					_mark_respawn_level(lit)
			if info.run.has_ghost and c == info.run.ghost_coord:
				var lost: Vector2 = _along(curve, place.progress(info.cell_at(info.run.ghost_pos)))
				if area.has_point(lost):
					marks.knock([RisoPrint.ACCENT, RisoPrint.PINK], [RisoShapes.circle(lost, 6.5, 18)])
					_mark_ghost(lost, 0.2)
			continue
		if not area.encloses(Rect2(at - size * 0.5, size)):
			continue
		_mark_tile(at, TILE, c == info.coord)
		_text("%d · %d" % [c.x, c.y], at + Vector2(0, -3.5), 6.5, false, true)
		var rec: LevelRecord = info.run.records[c]
		if c == info.run.respawn_coord:
			_mark_respawn_level(at + Vector2(-TILE.x * 0.5 + 4.0, TILE.y * 0.5 - 4.0))
		if bool(rec.shrine_used):
			_mark_spent_shrine(at + Vector2(0, TILE.y * 0.5 - 4.75))
		if info.run.has_ghost and c == info.run.ghost_coord:
			_mark_ghost(at + Vector2(TILE.x * 0.5 - 4.0, TILE.y * 0.5 - 4.0), 0.2)
	# The cursor: a night-ink frame round the picked level (or a side world's ribbon), breathing.
	var cur: Vector2 = tile_at(info, selected)
	var cur_size: Vector2 = tile_size(selected)
	var grow: float = 2.0 + sin(t * 5.0) * 0.6
	var outer: Array[PackedVector2Array] = [RisoShapes.rrect(cur.x - cur_size.x * 0.5 - grow, cur.y - cur_size.y * 0.5 - grow, cur_size.x + grow * 2.0, cur_size.y + grow * 2.0, 6.0)]
	var inner: Array[PackedVector2Array] = [RisoShapes.rrect(cur.x - cur_size.x * 0.5 - grow + 1.2, cur.y - cur_size.y * 0.5 - grow + 1.2, cur_size.x + grow * 2.0 - 2.4, cur_size.y + grow * 2.0 - 2.4, 5.0)]
	if Worlds.is_side(selected):
		var curve: PackedVector2Array = side_curve(info, selected)
		var ring: Array[PackedVector2Array] = [_ribbon(curve, cur_size.x + grow * 2.0, grow, MOUTH)]
		# The hole runs on past the ring's ends, so the frame is open where it meets the levels.
		var hole: Array[PackedVector2Array] = [_ribbon(curve, cur_size.x + grow * 2.0 - 2.4, grow + 3.0, MOUTH)]
		outer = _clipped(ring, _box(area))
		inner = _clipped(hole, _box(area))
	marks.ink(RisoPrint.NIGHT, 1.0, outer, false)
	marks.knock([RisoPrint.NIGHT], inner)
	# Relics a shrine marked: on the top right corner of the level's tile (a faint one for a level
	# not yet visited); off the page, on its edge, pointing the way.
	var page_in: Rect2 = area.grow(-9.0)
	for c: Vector2i in info.run.relic_hints:
		var at: Vector2 = tile_at(info, c)
		if info.run.relics_found.has(c):
			continue
		if not area.encloses(Rect2(at - TILE * 0.5, TILE)):
			var way: Vector2 = (at - page_in.get_center()).normalized()
			var reach: float = minf(page_in.size.x * 0.5 / maxf(absf(way.x), 0.001), page_in.size.y * 0.5 / maxf(absf(way.y), 0.001))
			var edge: Vector2 = page_in.get_center() + way * reach
			_mark_relic(edge, info.run.relic_hints[c], 0.8)
			marks.ink(RisoPrint.ACCENT, 1.0, [RisoMarks.chevron(edge + way * 7.5, way, 0.16)], false)
			continue
		# A level not yet visited: a faint tile where it lies, labelled like the rest.
		if not info.run.records.has(c):
			marks.ink(RisoPrint.ACCENT, 0.12, [RisoShapes.rrect(at.x - TILE.x * 0.5, at.y - TILE.y * 0.5, TILE.x, TILE.y, 5.0)], false)
			_text("%d · %d" % [c.x, c.y], at + Vector2(0, -3.5), 6.5, false, true)
		# The mark on the tile's top right corner, clear of its label.
		_mark_relic(at + Vector2(TILE.x * 0.5 - 1.0, -TILE.y * 0.5 + 1.0), info.run.relic_hints[c], 0.75)
	_text("W A S D pick  ·  E open", Vector2(AREA.position.x, AREA.end.y - 6.0), 6.5, false)
	_legend([
		["you are here", func(at: Vector2) -> void: _mark_tile(at, Vector2(9, 6), true)],
		["visited", func(at: Vector2) -> void: _mark_tile(at, Vector2(9, 6), false)],
		["way opened", func(at: Vector2) -> void: marks.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(at.x - 5.0, at.y - 1.6, 10.0, 3.2, 1.6)], false)],
	] + _side_rows() + [
		["respawn", _mark_respawn_level],
		["relic", func(at: Vector2) -> void: _mark_relic(at, &"blink")],
		["shrine used", _mark_spent_shrine],
		["ghost", func(at: Vector2) -> void: _mark_ghost(at, 0.2)],
	])


func _mark_tile(at: Vector2, size: Vector2, here: bool) -> void:
	var rect: PackedVector2Array = RisoShapes.rrect(at.x - size.x * 0.5, at.y - size.y * 0.5, size.x, size.y, minf(5.0, size.y * 0.3))
	marks.ink(RisoPrint.ACCENT if here else RisoPrint.BLUE, 0.55 if here else 0.25, [rect], false)


## A legend row for each kind of side world.
func _side_rows() -> Array:
	var rows: Array = []
	for k: int in range(Worlds.KINDS.size()):
		rows.append([Worlds.proto(k).name, func(at: Vector2) -> void: _mark_side(_bezier(at + Vector2(-1, -5), at + Vector2(3, -2), at + Vector2(3, 2), at + Vector2(-1, 5)), 4.0, false, Rect2(), 0.0)])
	return rows


## A side world on the worlds page: a smooth curve out of the middle of the bottom of the level it
## is entered from and into the middle of the top of the one its way on leads to, leaving and
## arriving straight down so it reads as poured from one into the other (out of the top and into
## the bottom, rising, when it leads up). In between it bows out
## of the straight line through a point in the gutter between columns, so it runs past the levels
## it skips rather than over them (away from the far level's column when it drifts). A dead end
## hangs a short way under its level.
func side_curve(info: MapInfo, c: Vector2i) -> PackedVector2Array:
	var place: SideWorld = Rules.def_for(c) as SideWorld
	var from: Vector2i = place.origin()
	var to: Vector2i = place.destination()
	# The ends tuck half a unit under the tiles, so no paper shows between.
	var a: Vector2 = tile_at(info, from) + Vector2(0, TILE.y * 0.5 - 0.5)
	if place.dead_end():
		return _bezier(a, a + Vector2(0, 4), a + Vector2(0, 8), a + Vector2(0, PITCH.y - TILE.y + 6.0))
	var rise: float = 1.0 if to.y > from.y else -1.0
	a = tile_at(info, from) + Vector2(0, (TILE.y * 0.5 - 0.5) * rise)
	var b: Vector2 = tile_at(info, to) - Vector2(0, (TILE.y * 0.5 - 0.5) * rise)
	var drift: int = to.x - from.x
	var side: float = -float(drift) if drift != 0 else (1.0 if posmod(c.x, 2) == 0 else -1.0)
	var d: Vector2 = b - a
	var heading: Vector2 = d.normalized()
	var mid: Vector2 = (a + b) * 0.5 + heading.orthogonal() * side * (PITCH.x * 0.5 if drift == 0 else PITCH.x * 0.3)
	var reach: float = d.length()
	var first: PackedVector2Array = _bezier(a, a + Vector2(0, reach * 0.3 * rise), mid - heading * reach * 0.22, mid, 16)
	var second: PackedVector2Array = _bezier(mid, mid + heading * reach * 0.22, b - Vector2(0, reach * 0.3 * rise), b, 16)
	first.remove_at(first.size() - 1)
	first.append_array(second)
	return first


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int = 24) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var u: float = float(i) / float(steps)
		out.append(p0.bezier_interpolate(p1, p2, p3, u))
	return out


## The point `frac` (0..1) of the way along `curve`, by length.
func _along(curve: PackedVector2Array, frac: float) -> Vector2:
	var total: float = 0.0
	for i: int in range(1, curve.size()):
		total += curve[i - 1].distance_to(curve[i])
	var left: float = clampf(frac, 0.0, 1.0) * total
	for i: int in range(1, curve.size()):
		var step: float = curve[i - 1].distance_to(curve[i])
		if left <= step and step > 0.0:
			return curve[i - 1].lerp(curve[i], left / step)
		left -= step
	return curve[curve.size() - 1]


## How wide a side world's spline is drawn on the worlds page.
const SPLINE_W: float = 1.8
## Where a side world's ribbon meets a level it widens into a mouth: MOUTH times as wide at the
## tile, easing back to its own width over MOUTH_LEN units.
const MOUTH: float = 0.9
const MOUTH_LEN: float = 9.0


## A ribbon `width` wide along `curve`, carried on `extend` past each end, and flared by `mouth`
## at each end (see MOUTH).
func _ribbon(curve: PackedVector2Array, width: float, extend: float = 0.0, mouth: float = 0.0) -> PackedVector2Array:
	var pts: PackedVector2Array = curve.duplicate()
	if extend > 0.0:
		# Carried on as new points, so the curve's own ends keep their place (and their width).
		pts.insert(0, pts[0] + (pts[0] - pts[1]).normalized() * extend)
		pts.append(pts[-1] + (pts[-1] - pts[-2]).normalized() * extend)
	# Distance along the curve, for the flare at each end.
	var run: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, pts.size()):
		run.append(run[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total: float = run[pts.size() - 1]
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(pts.size()):
		var along: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		# Measured from the curve's own ends, so ribbons carried on by different amounts flare alike.
		var flare: float = 1.0 - smoothstep(0.0, MOUTH_LEN, maxf(0.0, minf(run[i], total - run[i]) - extend))
		var n: Vector2 = along.orthogonal() * width * 0.5 * (1.0 + mouth * flare)
		left.append(pts[i] + n)
		right.append(pts[i] - n)
	right.reverse()
	left.append_array(right)
	return left


func _box(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A side world: a plain pink spline along `curve`, a little bolder while you are in it, cut to
## `clip` when one is given. (Its tile, for picking and the cursor, is still `width` wide.)
func _mark_side(curve: PackedVector2Array, _width: float, here: bool, clip: Rect2 = Rect2(), _mouth: float = MOUTH) -> void:
	var line: Array[PackedVector2Array] = [_ribbon(curve, SPLINE_W * (1.4 if here else 1.0))]
	if clip.has_area():
		line = _clipped(line, _box(clip))
	marks.ink(RisoPrint.PINK, 1.0, line, false)


func _clipped(polys: Array[PackedVector2Array], box: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in polys:
		out.append_array(Geometry2D.intersect_polygons(poly, box))
	return out


func _mark_respawn_level(at: Vector2) -> void:
	marks.ink(RisoPrint.EYE, 1.0, [RisoShapes.circle(at, 1.8, 10)], false)


func _mark_spent_shrine(at: Vector2) -> void:
	marks.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.arch(at.x - 1.8, at.y - 2.25, 3.6, 4.5, 6)], false)


# ------------------------------------------------------------------ text

func _text(text: String, at: Vector2, px: float, right: bool, centred: bool = false) -> void:
	if labels_used >= labels.size():
		var label: Label = Label.new()
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", TEXT_PX)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.visibility_layer = RisoPrint.plate_mask(RisoPrint.NIGHT)
		canvas.add_child(label)
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
