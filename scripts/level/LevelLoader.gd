class_name LevelLoader
extends Node
## Puts places into the scene for MapInfo (its parent). One worker thread lays levels out (the
## WFC collapse, then LevelGen), one at a time (the collapse is not shared safely): the level being
## travelled to always goes first, otherwise the worker lays out the current place's neighbours
## ahead of time, so most transitions find theirs already in the cache. A laid-out level is then
## built in the scene: rock in the TileMap, a node for each thing it holds (place_cell), the camera
## fitted to it. While it is played, the level is cut into chunks, and those far from the camera
## sleep (see sleep_far_chunks).

## Places kept laid out (and their collapsed cells), most recently used last.
const CACHE_SIZE: int = 12
## Solid rock around a level, flush against its edges (cells thick).
const BORDER: int = 3
## How many cells past a level that lies open to the sky (NextWorldDef.open) the camera may go.
const SKY_MARGIN: int = 6
## The rock tile laid: the print draws the rock's art over the TileMap, and every rock tile has the
## same full-square collision.
const PLAIN_ROCK: Vector2i = Vector2i(1, 1)
## Salts for where a floating pickup sits in its cell (across, then down; see place_cell).
const JITTER_DEAL: int = 9800
## How far a floating pickup may sit from its cell's centre, as a share of the cell.
const JITTER: float = 0.3

var info: MapInfo
var thread: Thread = Thread.new()
## Collapsed cells by place, and laid-out levels by _world_key.
var cache: Dictionary = {}
var cache_order: Array[Vector2i] = []
var worlds: Dictionary = {}
## Places to lay out ahead of time, and the one waiting to be shown (or null).
var prefetch: Array[Vector2i] = []
var wanted: Variant = null
var gen_busy: bool = false
## Everything placed in the level being played.
var map_elements: Node
const MAP_ELEMENTS: PackedScene = preload("res://prefabs/map_elements.tscn")

## Called with each laid-out level that was asked for (request), once it is ready to be built.
signal ready_to_build(built: LevelGen)


func _init(owner_info: MapInfo) -> void:
	info = owner_info
	name = "LevelLoader"


func _exit_tree() -> void:
	if thread.is_started():
		thread.wait_to_finish()


## Lay out place `at` (or take it from the cache) and signal ready_to_build when it is.
func request(at: Vector2i) -> void:
	wanted = at
	var built: LevelGen = laid_out(at)
	if built != null:
		wanted = null
		ready_to_build.emit.call_deferred(built)
	else:
		_pump()


## Start the worker on the wanted place, else on the next neighbour not yet cached.
func _pump() -> void:
	if gen_busy or not is_inside_tree():
		return
	var next: Variant = wanted
	while next == null and not prefetch.is_empty():
		var c: Vector2i = prefetch.pop_front()
		if laid_out(c) == null:
			next = c
	if next == null:
		return
	gen_busy = true
	if thread.is_started():
		thread.wait_to_finish()
	# Cells already collapsed are handed over, so the worker only lays the level out.
	thread.start(_generate_threaded.bind(next as Vector2i, cache.get(next, [])))


## On the worker: the place's cells (unless given) and its layout, so neither stalls a frame.
func _generate_threaded(at: Vector2i, cells: Array) -> void:
	if cells.is_empty():
		cells = info.wfc.generate_level(Rules.def_for(at))
	var built: LevelGen = LevelGen.new(cells, Rules.def_for(at))
	_generated.call_deferred(at, cells, built)


func _generated(at: Vector2i, cells: Array, built: LevelGen) -> void:
	if thread.is_started():
		thread.wait_to_finish()
	gen_busy = false
	# Left the scene (back to the start menu, or a test tearing down): the result is not wanted,
	# and no further work may start, or a thread would outlive this object.
	if not is_inside_tree():
		return
	_cache_put(at, cells, built)
	if wanted != null and wanted == at:
		wanted = null
		ready_to_build.emit(built)
	_pump()


## Another place's layout (for the map): one laid out already, or one laid out now from its seed
## (places are deterministic). Null while the worker is busy (try again next frame).
func world_at(at: Vector2i) -> LevelGen:
	var w: LevelGen = laid_out(at)
	if w != null:
		return w
	var cells: Variant = cache.get(at)
	if cells == null:
		if gen_busy:
			return null
		cells = info.wfc.generate_level(Rules.def_for(at))
	w = LevelGen.new(cells, Rules.def_for(at))
	_cache_put(at, cells, w)
	return w


## Keep a place's cells, and its layout when there is one (layouts are read-only once built, and
## depend on the debug flag, so they are kept per flag).
func _cache_put(at: Vector2i, cells: Array, built: LevelGen = null) -> void:
	cache[at] = cells
	if built != null:
		worlds[_world_key(at)] = built
	cache_order.erase(at)
	cache_order.append(at)
	while cache_order.size() > CACHE_SIZE:
		var old: Vector2i = cache_order.pop_front()
		cache.erase(old)
		worlds.erase(_world_key(old))


func _world_key(at: Vector2i) -> String:
	return "%s:%s" % [at, MapInfo.debug]


## The cached layout of place `at`, or null.
func laid_out(at: Vector2i) -> LevelGen:
	return worlds.get(_world_key(at))


## Queue the places `place` leads to for the worker (NextWorldDef.neighbours), keeping `place`
## itself from being evicted by them.
func prefetch_neighbours(place: NextWorldDef) -> void:
	prefetch.clear()
	for c: Vector2i in place.neighbours():
		if not cache.has(c):
			prefetch.append(c)
	if cache.has(place.coord):
		cache_order.erase(place.coord)
		cache_order.append(place.coord)
	_pump()


# ------------------------------------------------------------------ building it in the scene

## Take the last place out of the scene.
func clear() -> void:
	info.tile_map.clear()
	if map_elements != null and is_instance_valid(map_elements):
		map_elements.queue_free()


## Build level `w` in the scene: a node for every thing it holds (as its record leaves them).
func build(w: LevelGen) -> void:
	map_elements = MAP_ELEMENTS.instantiate()
	info.main.add_child(map_elements)
	for v: Vector2i in w.objects:
		place_cell(v, w.get_cell(v))


## The rock: the level's own, and a border round it (none round a place open to the sky), with the
## camera fitted to it.
func lay_terrain(w: LevelGen, open: bool) -> void:
	_lay_rock(w.grounds)
	if open:
		_fit_camera(w.size, SKY_MARGIN)
		return
	var rock: Array[Vector2i] = []
	for i: int in range(-BORDER, w.size.x + BORDER):
		for j: int in range(-BORDER, w.size.y + BORDER):
			if i < 0 or j < 0 or i >= w.size.x or j >= w.size.y:
				rock.append(Vector2i(i, j))
	_lay_rock(rock)
	_fit_camera(w.size)


func _lay_rock(cells: Array[Vector2i]) -> void:
	for v: Vector2i in cells:
		info.tile_map.set_cell(0, v, 0, PLAIN_ROCK)


## Keep the camera inside the level plus one cell of its border rock (or `margin` cells of sky).
func _fit_camera(size: Vector2i, margin: int = 1) -> void:
	var cam: Camera2D = info.camera()
	if cam == null:
		return
	var tm: TileMap = info.tile_map
	var cell: Vector2 = Vector2(tm.tile_set.tile_size) * tm.global_scale
	var top_left: Vector2 = tm.to_global(tm.map_to_local(Vector2i(-margin, -margin))) - cell * 0.5
	var bottom_right: Vector2 = tm.to_global(tm.map_to_local(Vector2i(size.x + margin - 1, size.y + margin - 1))) + cell * 0.5
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(bottom_right.x)
	cam.limit_bottom = int(bottom_right.y)


## Put the thing in cell `v` of the level being played into the scene, unless its record says it
## is gone (taken, opened, slain or broken). What it is comes from Placeables.
func place_cell(v: Vector2i, cell: LevelGen.Cell) -> void:
	# Nothing here draws from the world RNG: a level's LevelGen is kept and reused (see laid_out),
	# so a draw here would differ from one visit to the next. What varies is hashed from the seed
	# and cell.
	var w: LevelGen = info.world
	var rec: LevelRecord = info.record()
	var gone: Array[Dictionary] = [rec.taken, rec.opened, rec.slain]
	# Broken only ever means cracked rock: a secret room's rewards stand on its broken cells.
	if cell.type == LevelGen.Type.CRACKED:
		gone.append(rec.broken)
	if gone.any(func(d: Dictionary) -> bool: return d.has(v)):
		return
	# A boss slain this run is never met again (Bosses).
	if cell.type == LevelGen.Type.BOSS and info.run.bosses.has(StringName(cell.extra_info)):
		return
	var jitter: Vector2 = Vector2.ZERO
	if Placeables.has_flag(cell.type, &"floats"):
		# Floating pickups sit anywhere inside their cell rather than on the grid.
		var cell_size: Vector2 = Vector2(info.tile_map.tile_set.tile_size) * info.tile_map.global_scale
		var roll: Vector2 = Vector2(RisoDecor.h(w.seed_for_colors, v, JITTER_DEAL), RisoDecor.h(w.seed_for_colors, v, JITTER_DEAL + 1))
		jitter = (roll * 2.0 - Vector2.ONE) * JITTER * cell_size
	# A boss is fought as its own prefab once it is built, else as the stand-in (Bosses.scene).
	var node: Node = (Bosses.scene(StringName(cell.extra_info)) if cell.type == LevelGen.Type.BOSS else Placeables.scene(cell.type)).instantiate()
	node.set_meta(&"cell", v)
	# A key's or door's colour was dealt with the level (LevelGen.deal_colors).
	var colored: bool = Placeables.has_flag(cell.type, &"colored")
	if colored:
		node.set_meta(&"key_color", int(cell.extra_info) if cell.extra_info != null else 0)
	if cell.type == LevelGen.Type.CRACKED and cell.extra_info != null:
		# Part of a secret room: hidden rock, or its entrance, a false wall that looks like rock but
		# is walked (and shot) straight through.
		node.set_meta(&"secret", int(cell.extra_info))
		node.set_meta(&"hidden", not (w.secrets[int(cell.extra_info)]["entrance"] as Array).has(v))
		if not bool(node.get_meta(&"hidden")):
			(node as CollisionObject2D).collision_layer = 0
	if cell.type == LevelGen.Type.CLUSTER:
		# A vault's lesser cluster is worth a share of a full one (LevelGen.VAULT_LOOT).
		var share: float = float(cell.extra_info) if cell.extra_info != null else 1.0
		(node as Coin).value = maxi(2, roundi(Rules.cluster_value(info.here.depth) * share))
	# The worm keeps its health on its segments (WormSegment), not on itself.
	if Placeables.has_flag(cell.type, &"enemy") and not node is Worm:
		arm(node, info.here.depth)
	if cell.mods.has("shield"):
		var shield: Shield = Shield.new()
		shield.name = "Shield"
		shield.hp = int(cell.mods["shield"])
		node.add_child(shield)
	if cell.mods.has("bounces"):
		node.set_meta(&"bounces", int(cell.mods["bounces"]))
	map_elements.add_child(node)
	node.set_owner(map_elements)
	node.position = info.cell_position(v) + jitter
	# Set up as its Placeables entry says. A key's extra info is its colour, already given as
	# key_color, and a cracked cell's is its secret: theirs take two.
	match Placeables.setup_args(cell.type):
		2:
			node.call("setup", info, v)
		3:
			node.call("setup", info, v, cell.extra_info)


## Make `node` an enemy of a place `depth` from the start: a Wound with that depth's health (hex
## bolts and the dash hurt it), and a hex target. Whatever brings an enemy into a level calls it
## (place_cell, and a gondola calling up its wraiths, Gondola).
static func arm(node: Node, depth: int) -> void:
	var wound: Wound = Wound.new()
	wound.name = "Wound"
	wound.hp = Wound.hp_for(depth)
	node.add_child(wound)
	node.add_to_group(&"hex_target")


# ------------------------------------------------------------------ chunks
# The level is cut into CHUNK x CHUNK cell chunks. A few times a second, every chunk is woken or
# put to sleep by its distance from the camera: everything in a sleeping chunk stops (no
# processing, its physics bodies out of the world) and is hidden, so a big level costs about what
# its neighbourhood of the camera does (only things placed with the level; bolts, ghosts and
# rifts always run). Chunks wake with a margin past the view (wider than a watcher's sight) and
# only sleep a little further out, so nothing flickers at the edge.

const CHUNK: int = 8
## Chunks within this many pixels of the view's edge (in world pixels) are awake; awake ones sleep
## only past CHUNK_SLEEP. Checked every CHUNK_EVERY physics frames.
const CHUNK_WAKE: float = 640.0
const CHUNK_SLEEP: float = 896.0
const CHUNK_EVERY: int = 6
var _chunk_tick: int = 0
## Chunk -> whether it is awake.
var _chunk_awake: Dictionary = {}


func chunk_of(pos: Vector2) -> Vector2i:
	var c: Vector2i = info.cell_at(pos)
	return Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))


## Whether `node`'s chunk is awake (things outside every chunk's reach are asleep).
func is_awake(node: Node2D) -> bool:
	return bool(_chunk_awake.get(chunk_of(node.global_position), true))


## Wake every chunk again from scratch, around `around` (a new level, before the camera catches up).
func wake_around(around: Vector2) -> void:
	_chunk_awake.clear()
	sleep_far_chunks(true, around)


func sleep_far_chunks(force: bool = false, around: Vector2 = Vector2.INF) -> void:
	_chunk_tick += 1
	if not force and _chunk_tick % CHUNK_EVERY != 0:
		return
	if map_elements == null or not is_instance_valid(map_elements) or info.world == null:
		return
	var cam: Camera2D = info.camera()
	if cam == null:
		return
	var tm: TileMap = info.tile_map
	var half: Vector2 = Vector2(get_window().content_scale_size) / cam.zoom * 0.5
	var center: Vector2 = cam.get_screen_center_position() if around == Vector2.INF else around
	var cell_px: Vector2 = Vector2(tm.tile_set.tile_size) * tm.global_scale
	var chunk_px: Vector2 = cell_px * float(CHUNK)
	var origin: Vector2 = tm.to_global(tm.map_to_local(Vector2i.ZERO)) - cell_px * 0.5
	var player: Player = info.player
	var has_wizard: bool = player != null and is_instance_valid(player)
	var wizard: Vector2 = player.global_position if has_wizard else Vector2.ZERO
	# Wake or sleep each chunk by the gap between its rectangle and the view.
	var states: Dictionary = {}
	var size: Vector2i = info.world.size + Vector2i(BORDER, BORDER) * 2
	for cx: int in range(floori(-float(BORDER) / CHUNK) - 1, ceili(float(size.x) / CHUNK) + 1):
		for cy: int in range(floori(-float(BORDER) / CHUNK) - 1, ceili(float(size.y) / CHUNK) + 1):
			var key: Vector2i = Vector2i(cx, cy)
			var lo: Vector2 = origin + Vector2(key) * chunk_px
			var gap: Vector2 = (((lo + chunk_px * 0.5) - center).abs() - (chunk_px * 0.5 + half)).max(Vector2.ZERO)
			var d: float = maxf(gap.x, gap.y)
			if has_wizard:
				# Also around the wizard: the camera lags a jump (a rift, a respawn) for a moment.
				var gap_w: Vector2 = (((lo + chunk_px * 0.5) - wizard).abs() - (chunk_px * 0.5 + half)).max(Vector2.ZERO)
				d = minf(d, maxf(gap_w.x, gap_w.y))
			var was: bool = bool(_chunk_awake.get(key, false))
			states[key] = d < (CHUNK_SLEEP if was else CHUNK_WAKE)
	_chunk_awake = states
	for node: Node in map_elements.get_children():
		var n2: Node2D = node as Node2D
		# Only the level's own placed things sleep; bolts, ghosts and rifts always run.
		if n2 == null or node.is_queued_for_deletion() or not node.has_meta(&"cell"):
			continue
		var awake: bool = bool(states.get(chunk_of(n2.global_position), false))
		# Something spread over several chunks (a wind, Wind.extent) is awake if any of them is.
		var wind: Wind = node as Wind
		if not awake and wind != null:
			var r: Rect2 = wind.extent()
			var x: float = r.position.x
			while not awake and x <= r.end.x + chunk_px.x:
				var y: float = r.position.y
				while not awake and y <= r.end.y + chunk_px.y:
					awake = bool(states.get(chunk_of(Vector2(minf(x, r.end.x), minf(y, r.end.y))), false))
					y += chunk_px.y
				x += chunk_px.x
		# A gondola is awake while either of its stations is, so it can be called from the far one.
		var gondola: Gondola = node as Gondola
		if not awake and gondola != null:
			awake = gondola.stations.any(func(p: Vector2) -> bool: return bool(states.get(chunk_of(p), false)))
		var mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
		if node.process_mode != mode:
			node.process_mode = mode
			n2.visible = awake
