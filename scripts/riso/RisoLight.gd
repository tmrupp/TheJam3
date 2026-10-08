extends Node2D
class_name RisoLight
## Light and darkness, by line of sight. Your respawn lantern throws a warm pool that lifts the
## night ink off the rock and the sky around it, flickering softly, so the place you return to reads
## as a destination; every other lantern gives a faint glow, and open exits, portals, an ink well
## not yet dry and hex bolts in flight a small one. The lantern the wizard carries lights the way
## too: while a lit lantern protects them it throws a smaller warm pool round them wherever they
## go; while they are unprotected only a dim one, faintly pink (danger). Rock stops every light:
## a pool reaches only as far as its flame can see (RisoSight), so walls cast shadows.
##
## The wizard sees only past the rock too. What they cannot see from where they stand lies under
## more night ink (the place's `shade`), terrain, decor and props alike, still there to make out
## but dimmed; what they can see reaches to the edge of the view. In the deep dark (the place's
## `gloom`, the catacombs) night ink lies over everything no light falls on, in sight or not,
## lifting in steps ring by ring inside each pool, so most of what is seen is what a lantern lights.
##
## The pools print above the terrain and decor, under the props; the shade and the deep dark over
## the props, under the wizard's trail and the wizard.

## The pools of light, each [radius, how much night it lifts], widest first: the respawn
## lantern's, the carried lantern's while protected, and while not.
const RESPAWN_RINGS: Array = [[380.0, 0.16], [250.0, 0.18], [140.0, 0.22]]
const CARRIED_RINGS: Array = [[280.0, 0.12], [180.0, 0.14], [100.0, 0.16]]
const UNLIT_RINGS: Array = [[130.0, 0.08]]
## Any other lantern not yet burnt out: a faint glow.
const FAINT_RINGS: Array = [[110.0, 0.09]]
## Open exits, portals and an ink well not yet dry; and a hex bolt in flight.
const GLOW_RINGS: Array = [[210.0, 0.07], [120.0, 0.09]]
const BOLT_RINGS: Array = [[150.0, 0.10]]
## The pink tint of an unprotected wizard's dim pool.
const UNLIT_PINK: float = 0.06
## How high over its floor each glowing thing's light sits (px): an exit's doorway, a portal's
## middle, the ink well's beam; a rift (no floor) glows a little over where it hangs.
const EXIT_RISE: float = 56.0
const PORTAL_RISE: float = 70.0
const WELL_RISE: float = 60.0
const RIFT_RISE: float = 10.0
## The group the glowing things join (LevelExit, Portal, Inkwell, HexBolt).
const GLOWS: StringName = &"glows"
## How far above the wizard's middle their eyes are (px): sight is taken from there.
const EYE_RISE: float = 24.0
## How far past the view (px) sight and the darkness reach, so the camera's drift shows no edge.
const VIEW_MARGIN: float = 160.0
## Room left round a pool for its flicker (a share of its widest ring).
const FLICKER_ROOM: float = 1.1
## The print layer (absolute z) of the shade and the deep dark: over the props, under the trail.
const SHADE_Z: int = 8
## How many steps the deep dark lifts in by, ring by ring, inside a pool.
const GLOOM_STEPS: int = 3

## Whether light and sight stop at the rock (the F7 panel can turn it off to compare): off, the
## pools are plain circles and nothing is shaded out of sight (the deep dark stays).
static var by_sight: bool = true

var lanterns: Array[Node2D] = []
var ink: InkCanvas
## The canvas the shade and the deep dark print on (SHADE_Z).
var dark_ink: InkCanvas
var half: float = 64.0
var t: float = 0.0
## The carried lantern's pool as last printed: where (x, y) and its widest ring (z), 0 if none.
var carried: Vector3 = Vector3.ZERO
## The rock as sight meets it, and the cells in it that open and shut (cracked walls, doors,
## switch gates), by their LevelGen.Type.
var sight: RisoSight
var _changing: Dictionary = {}
## What the wizard sees, as last printed (empty with no wizard, or sight off).
var seen: PackedVector2Array = PackedVector2Array()
## Every pool as last printed: [where, then each ring's lit outlines, widest first].
var pools: Array = []
## What the lights that stay put see (they are worked out once), by where they are and how far
## they reach, until the rock changes (`_cache_version`).
var _cache: Dictionary = {}
var _cache_version: int = -1
## The shade's outlines as last worked out, and from where (the eye, the view and the rock's
## version), so a wizard standing still costs nothing.
var _shade_seen: PackedVector2Array = PackedVector2Array()
var _shade_pieces: Array[PackedVector2Array] = []
var _shade_key: Array = []


func _ready() -> void:
	z_index = -12
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	dark_ink = InkCanvas.new()
	dark_ink.z_index = SHADE_Z
	dark_ink.z_as_relative = false
	add_child(dark_ink)


func rebuild(info: MapInfo) -> void:
	lanterns.clear()
	half = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y * 0.5
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "checkpoint.tscn" and not node.is_queued_for_deletion():
			lanterns.append(node as Node2D)
	sight = RisoSight.new(info.cell_position(Vector2i.ZERO) - Vector2(half, half), half * 2.0)
	for v: Vector2i in info.tile_map.get_used_cells(0):
		sight.solid[v] = true
	_changing.clear()
	if info.world != null:
		for x: int in range(info.world.size.x):
			for y: int in range(info.world.size.y):
				var type: LevelGen.Type = info.world.get_cell(Vector2i(x, y)).type
				if type == LevelGen.Type.CRACKED or type == LevelGen.Type.DOOR or type == LevelGen.Type.SWITCH_GATE:
					_changing[Vector2i(x, y)] = type
	_cache.clear()
	_shade_key = []
	_shut_or_open(info)


## Bring the cells that open and shut up to date: a cracked wall stops sight until it breaks (a
## secret's false wall too, as it prints as rock), a door until it opens, a gate while shut.
func _shut_or_open(info: MapInfo) -> void:
	if sight == null:
		return
	var rec: LevelRecord = info.record()
	for v: Vector2i in _changing:
		var shut: bool
		match _changing[v]:
			LevelGen.Type.CRACKED:
				shut = not rec.broken.has(v)
			LevelGen.Type.DOOR:
				shut = not rec.opened.has(v)
			_:
				shut = not info.gate_open(v)
		sight.set_solid(v, shut)


## Where a lantern's glass hangs (its prop draws the glass there).
func glass(lantern: Node2D, info: MapInfo) -> Vector2:
	return Vector2(lantern.global_position.x + 30.0, _floor(lantern, info) - 72.0)


## The floor under the cell `node` stands in.
func _floor(node: Node2D, info: MapInfo) -> float:
	return info.cell_position(info.cell_at(node.global_position)).y + half


## Where the wizard's eyes are.
static func eye(player: Player) -> Vector2:
	return player.global_position + Vector2(0, -EYE_RISE)


func _process(delta: float) -> void:
	t += delta
	var info: MapInfo = MapInfo.instance
	var cam: Camera2D = get_viewport().get_camera_2d()
	ink.begin()
	dark_ink.begin()
	pools.clear()
	seen = PackedVector2Array()
	if info == null or info.world == null or cam == null or info.travelling:
		ink.finish()
		dark_ink.finish()
		return
	_shut_or_open(info)
	var view: Rect2 = RisoLight.view_rect(self, cam).grow(VIEW_MARGIN)
	var near: Rect2 = view.grow(420.0)
	for lantern: Node2D in lanterns:
		if not is_instance_valid(lantern) or lantern.is_queued_for_deletion():
			continue
		if info.is_lantern_spent(lantern):
			continue
		var at: Vector2 = glass(lantern, info)
		if not near.has_point(at):
			continue
		if info.is_respawn_lantern(lantern):
			_pool(at, RESPAWN_RINGS, 1.0 + 0.035 * sin(t * 3.1) * sin(t * 1.7 + 0.6), true)
		else:
			_pool(at, FAINT_RINGS, 1.0, true)
	for node: Node in get_tree().get_nodes_in_group(GLOWS):
		var glow: Array = _glow(node as Node2D, info)
		if not glow.is_empty() and near.has_point(glow[0]):
			_pool(glow[0], glow[1], 1.0, glow[2])
	_carried_pool(info)
	_darkness(info, view)
	ink.finish()
	dark_ink.finish()


## Where a glowing thing's light is, its rings and whether it stays put, or [] if it is dark (an
## exit shut by a price, a lock or a boss; a dry ink well).
func _glow(node: Node2D, info: MapInfo) -> Array:
	if node == null or node.is_queued_for_deletion():
		return []
	if node is HexBolt:
		return [node.global_position, BOLT_RINGS, false]
	if node is LevelExit:
		var door: LevelExit = node as LevelExit
		if door.sealed() != &"" or door.lock() >= 0 or door.price() > 0:
			return []
		return [Vector2(node.global_position.x, _floor(node, info) - EXIT_RISE), GLOW_RINGS, true]
	if node is Portal:
		if node.has_meta(&"rift"):
			return [node.global_position + Vector2(0, -RIFT_RISE), GLOW_RINGS, true]
		return [Vector2(node.global_position.x, _floor(node, info) - PORTAL_RISE), GLOW_RINGS, true]
	if node is Inkwell:
		if (node as Inkwell).used():
			return []
		return [Vector2(node.global_position.x, _floor(node, info) - WELL_RISE), GLOW_RINGS, true]
	return []


## The light of the lantern the wizard carries, round its flame (see the class note).
func _carried_pool(info: MapInfo) -> void:
	carried = Vector3.ZERO
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player) or player.phasing or info.run == null:
		return
	var at: Vector2 = player.global_position
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard
	if wizard != null and wizard.costume != null:
		at = wizard.to_global(wizard.costume.lantern_position())
	var lit: bool = not info.run.vulnerable
	var rings: Array = CARRIED_RINGS if lit else UNLIT_RINGS
	var pool: Array = _pool(at, rings, 1.0 + 0.05 * sin(t * 4.3) * sin(t * 2.3 + 1.1), false)
	if not lit:
		ink.ink(RisoPrint.PINK, UNLIT_PINK, pool[1], false)
	carried = Vector3(at.x, at.y, float(rings[0][0]))


## A pool of rings (each [radius, lift]) round `at`, every radius scaled by `flicker`, each cut to
## what its flame can see; `still` lights keep what they see. Returns it as kept in `pools`.
func _pool(at: Vector2, rings: Array, flicker: float, still: bool) -> Array:
	var seen_here: PackedVector2Array = _seen_from(at, float(rings[0][0]) * FLICKER_ROOM, still)
	var pool: Array = [at]
	for ring: Array in rings:
		var circle: PackedVector2Array = RisoShapes.circle(at, float(ring[0]) * flicker, 40)
		var shapes: Array[PackedVector2Array] = [circle]
		if not seen_here.is_empty():
			shapes = RisoSight.lit(circle, seen_here)
		ink.lift_ink([RisoPrint.NIGHT], float(ring[1]), shapes)
		pool.append(shapes)
	pools.append(pool)
	return pool


## What a light at `at` sees within `reach`, or nothing (no cut) with sight off or no level.
func _seen_from(at: Vector2, reach: float, still: bool) -> PackedVector2Array:
	if not by_sight or sight == null:
		return PackedVector2Array()
	var box: Rect2 = Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	if not still:
		return sight.polygon(at, box)
	if _cache_version != sight.version:
		_cache.clear()
		_cache_version = sight.version
	var key: Vector3i = Vector3i(roundi(at.x), roundi(at.y), roundi(reach))
	if not _cache.has(key):
		_cache[key] = sight.polygon(at, box)
	return _cache[key]


## The shade over what the wizard cannot see, and the deep dark over what no light falls on.
func _darkness(info: MapInfo, view: Rect2) -> void:
	var player: Player = Stage.player()
	var shade: float = info.here.shade()
	if by_sight and sight != null and shade > 0.0 and player != null and is_instance_valid(player):
		var from: Vector2 = RisoLight.eye(player)
		var key: Array = [from.round(), view.position.round(), view.size.round(), sight.version]
		if key != _shade_key:
			_shade_key = key
			_shade_seen = sight.polygon(from, view)
			_shade_pieces = RisoSight.outside(view, [_shade_seen])
		seen = _shade_seen
		dark_ink.ink(RisoPrint.NIGHT, shade, _shade_pieces, false)
	var gloom: float = info.here.gloom()
	if gloom <= 0.0:
		return
	for step: int in range(GLOOM_STEPS):
		var lit: Array[PackedVector2Array] = []
		for pool: Array in pools:
			if step + 1 < pool.size():
				lit.append_array(pool[step + 1])
		dark_ink.ink(RisoPrint.NIGHT, gloom / float(GLOOM_STEPS), RisoSight.outside(view, lit), false)


## The camera's view in world space.
static func view_rect(node: CanvasItem, cam: Camera2D) -> Rect2:
	var base: Vector2 = Vector2(node.get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var size: Vector2 = base / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)
