extends Node2D
class_name RisoLight
## Light and darkness, by line of sight. Your respawn lantern throws a warm light that lifts the
## night ink off the rock and the sky around it, brightest at its flame and fading smoothly with
## distance, flickering softly, so the place you return to reads as a destination; every other
## lantern gives a faint one, and open exits, portals, an ink well not yet dry and hex bolts in
## flight a small pool of rings. The lantern the wizard carries lights the way too, fading the same
## way: while a lit lantern protects them it throws a warm light round its flame wherever they go;
## while they are unprotected only a short, dim one, faintly pink (danger). Rock stops every light:
## a light reaches only as far as its flame can see (RisoSight), so walls cast shadows.
##
## The wizard sees only past the rock too. What they cannot see from where they stand lies under
## more night ink (the place's `shade`), terrain, decor and props alike, still there to make out
## but dimmed; what they can see reaches to the edge of the view. In the deep dark (the place's
## `gloom`, the catacombs) night ink lies over everything no light falls on, in sight or not,
## lifting smoothly inside each lantern's light and in steps ring by ring inside each pool, so most
## of what is seen is what a lantern lights.
##
## The pools print above the terrain and decor, under the props; the shade and the deep dark over
## the props, under the wizard's trail and the wizard.

## The lanterns' lights, each fading smoothly from its flame to nothing at its reach: how far it
## reaches (px) and how much night it lifts at the flame. The respawn lantern's, and how much its
## lift flickers; any other lantern not yet burnt out, a faint one.
const RESPAWN_REACH: float = 400.0
const RESPAWN_LIFT: float = 0.46
const RESPAWN_FLICKER: float = 0.06
const FAINT_REACH: float = 140.0
const FAINT_LIFT: float = 0.14
## The carried lantern's, while protected, and while not.
const CARRIED_REACH: float = 320.0
const CARRIED_LIFT: float = 0.38
const UNLIT_REACH: float = 150.0
const UNLIT_LIFT: float = 0.1
## How far short of the rock's face (px) a flame swung into the rock throws its light from.
const FLAME_GAP: float = 2.0
## How far apart (px) the steps of a light's fade are worked out: the print blends between them,
## so this only needs to be fine enough for the curve to read as smooth.
const FADE_STEP: float = 24.0
## The pools of light, each [radius, how much night it lifts], widest first: open exits, portals
## and an ink well not yet dry; and a hex bolt in flight.
const GLOW_RINGS: Array = [[210.0, 0.07], [120.0, 0.09]]
const BOLT_RINGS: Array = [[150.0, 0.10]]
## The pink tint of an unprotected wizard's dim light, where they stand.
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

## A light that fades smoothly from its flame to nothing at its reach, cut to what the flame sees:
## where it is, how far it reaches, the outline it lights (and its bounds), and that outline cut into
## small pieces fanning out from the flame with the falloff at their corners (`profile`). `covers`
## is the profile scaled by `lift`, kept while the lift stays the same.
class Fade:
	var at: Vector2
	var reach: float
	var outline: PackedVector2Array = PackedVector2Array()
	var box: Rect2
	var pieces: Array[PackedVector2Array] = []
	var profile: Array[PackedFloat32Array] = []
	var lift: float = -1.0
	var covers: Array[PackedFloat32Array] = []

	## How much of this light falls on `p`: none past its reach or outside what its flame sees.
	func light_at(p: Vector2) -> float:
		var d: float = p.distance_to(at)
		if d >= reach or not box.has_point(p) or not Geometry2D.is_point_in_polygon(p, outline):
			return 0.0
		return RisoLight.carried_falloff(d, reach)

	## The profile scaled by `amount` (kept for the next frame while it stays the same).
	func scaled(amount: float) -> Array[PackedFloat32Array]:
		if amount != lift:
			lift = amount
			covers = []
			for corners: PackedFloat32Array in profile:
				var c: PackedFloat32Array = corners.duplicate()
				for i: int in range(c.size()):
					c[i] *= amount
				covers.append(c)
		return covers


## Whether light and sight stop at the rock (the F7 panel can turn it off to compare): off, the
## pools are plain circles and nothing is shaded out of sight (the deep dark stays).
static var by_sight: bool = true

var lanterns: Array[Node2D] = []
var ink: InkCanvas
## The canvas the shade and the deep dark print on (SHADE_Z).
var dark_ink: InkCanvas
var half: float = 64.0
var t: float = 0.0
## The carried lantern's light as last printed: where (x, y) and its reach (z), 0 if none.
var carried: Vector3 = Vector3.ZERO
## What the carried light reaches (what its flame sees within its reach), empty if none. Its
## light is worked out again only when the flame moves, the rock changes or the wizard loses their
## protection (`_carried_key`).
var carried_seen: PackedVector2Array = PackedVector2Array()
var _carried: Fade
var _carried_key: Array = []
## Every fading light as last printed: the lanterns', then the carried one.
var fades: Array[Fade] = []
## The lanterns' lights, which stay put, by where they are and how far they reach, until the rock
## changes (`_cache_version`).
var _fade_cache: Dictionary = {}
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
	_fade_cache.clear()
	_shade_key = []
	_carried_key = []
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
	fades.clear()
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
			var flicker: float = 1.0 + RESPAWN_FLICKER * sin(t * 3.1) * sin(t * 1.7 + 0.6)
			_print_fade(_faded(at, RESPAWN_REACH, true), RESPAWN_LIFT * flicker)
		else:
			_print_fade(_faded(at, FAINT_REACH, true), FAINT_LIFT)
	for node: Node in get_tree().get_nodes_in_group(GLOWS):
		var glow: Array = _glow(node as Node2D, info)
		if not glow.is_empty() and near.has_point(glow[0]):
			_pool(glow[0], glow[1], 1.0, glow[2])
	_carried_light(info)
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


## The light of the lantern the wizard carries (see the class note), thrown from its flame and
## fading smoothly from there to nothing at its reach.
func _carried_light(info: MapInfo) -> void:
	carried = Vector3.ZERO
	carried_seen = PackedVector2Array()
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player) or player.phasing or info.run == null:
		return
	var at: Vector2 = _flame(player)
	var lit: bool = not info.run.vulnerable
	var reach: float = CARRIED_REACH if lit else UNLIT_REACH
	var key: Array = [at.round(), lit, by_sight, sight.version if sight != null else -1]
	if key != _carried_key or _carried == null:
		_carried_key = key
		_carried = _faded(at, reach, false)
	if not lit:
		# The pink first, as the scaled covers are kept for the lift that follows.
		ink.ink_graded(RisoPrint.PINK, _carried.pieces, _carried.scaled(UNLIT_PINK), false)
	_print_fade(_carried, CARRIED_LIFT if lit else UNLIT_LIFT)
	carried_seen = _carried.outline
	carried = Vector3(at.x, at.y, reach)


## Lift the night where `light` falls, `lift` at its flame, and keep it in `fades`.
func _print_fade(light: Fade, lift: float) -> void:
	ink.lift_ink_graded([RisoPrint.NIGHT], light.pieces, light.scaled(lift))
	fades.append(light)


## A light at `at` fading to nothing at `reach`, cut to what its flame sees; `still` lights keep
## what they light until the rock changes.
func _faded(at: Vector2, reach: float, still: bool) -> Fade:
	var key: Array = [roundi(at.x), roundi(at.y), roundi(reach), by_sight]
	if still:
		_fresh_cache()
		if _fade_cache.has(key):
			return _fade_cache[key]
	var light: Fade = Fade.new()
	light.at = at
	light.reach = reach
	var circle: PackedVector2Array = RisoShapes.circle(at, reach, 48)
	light.outline = circle
	var seen_here: PackedVector2Array = _seen_from(at, reach, false)
	if not seen_here.is_empty():
		# Sight and the circle are both seen whole from the flame, so where they meet is one
		# outline; a sliver Clipper splits off is too small to light.
		light.outline = PackedVector2Array()
		for piece: PackedVector2Array in RisoSight.lit(circle, seen_here):
			if piece.size() > light.outline.size():
				light.outline = piece
	light.box = RisoLight._bounds(light.outline)
	_fan(light)
	if still:
		_fade_cache[key] = light
	return light


## Where the carried lantern's flame is. Swung against a wall it can dip into the rock, where its
## light would shine through it, so then it is taken back towards the wizard's eyes to the rock's
## face.
func _flame(player: Player) -> Vector2:
	var at: Vector2 = player.global_position
	var wizard: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard
	if wizard != null and wizard.costume != null:
		at = wizard.to_global(wizard.costume.lantern_position())
	if sight == null or not sight.blocked(at):
		return at
	var from: Vector2 = RisoLight.eye(player)
	var far: float = from.distance_to(at)
	if far < 0.01 or sight.blocked(from):
		return from
	var d: Vector2 = (at - from) / far
	return from + d * maxf(sight.cast(from, d, far) - FLAME_GAP, 0.0)


## How much of a fading light reaches `d` px from its flame, of `reach`: all of it at the flame,
## easing off slowly and then quickly, and none at its reach.
static func carried_falloff(d: float, reach: float) -> float:
	var x: float = clampf(d / reach, 0.0, 1.0)
	return (1.0 - x * x) * (1.0 - x * x)


## Cut `light`'s outline (seen whole from its flame) into small pieces fanning out from the flame in
## steps, each with the falloff at its corners.
func _fan(light: Fade) -> void:
	var at: Vector2 = light.at
	var outline: PackedVector2Array = light.outline
	var n: int = outline.size()
	if n < 3:
		return
	for i: int in range(n):
		var a: Vector2 = outline[i] - at
		var b: Vector2 = outline[(i + 1) % n] - at
		var steps: int = clampi(ceili(maxf(a.length(), b.length()) / FADE_STEP), 1, 32)
		for k: int in range(steps):
			var s0: float = float(k) / float(steps)
			var s1: float = float(k + 1) / float(steps)
			var piece: PackedVector2Array
			if k == 0:
				piece = PackedVector2Array([at, at + a * s1, at + b * s1])
			else:
				piece = PackedVector2Array([at + a * s0, at + b * s0, at + b * s1, at + a * s1])
			var profile: PackedFloat32Array = PackedFloat32Array()
			for p: Vector2 in piece:
				profile.append(RisoLight.carried_falloff(p.distance_to(at), light.reach))
			light.pieces.append(piece)
			light.profile.append(profile)


## The bounds of an outline.
static func _bounds(outline: PackedVector2Array) -> Rect2:
	if outline.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(outline[0], Vector2.ZERO)
	for p: Vector2 in outline:
		box = box.expand(p)
	return box


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
	_fresh_cache()
	var key: Vector3i = Vector3i(roundi(at.x), roundi(at.y), roundi(reach))
	if not _cache.has(key):
		_cache[key] = sight.polygon(at, box)
	return _cache[key]


## Forget what the still lights see once the rock has changed.
func _fresh_cache() -> void:
	var version: int = sight.version if sight != null else -1
	if _cache_version != version:
		_cache.clear()
		_fade_cache.clear()
		_cache_version = version


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
		for light: Fade in fades:
			lit.append(light.outline)
		dark_ink.ink(RisoPrint.NIGHT, gloom / float(GLOOM_STEPS), RisoSight.outside(view, lit), false)
	# Inside the fading lights the deep dark lifts with them, smoothly: at each point, what the
	# pools' rings leave of it, less each light's share there. Where lights overlap, the first
	# prints it and the others leave that part out.
	for i: int in range(fades.size()):
		var light: Fade = fades[i]
		var others: Array[Fade] = []
		var earlier: Array[Fade] = []
		for j: int in range(fades.size()):
			if j != i and fades[j].box.intersects(light.box):
				others.append(fades[j])
				if j < i:
					earlier.append(fades[j])
		var rings: Array = _rings_over(light.box)
		var pieces: Array[PackedVector2Array] = light.pieces
		var profile: Array[PackedFloat32Array] = light.profile
		if not earlier.is_empty():
			pieces = []
			profile = []
			_leave_out(light, earlier, pieces, profile)
		# Neighbouring pieces share their corners: each corner is worked out once.
		var left: Dictionary = {}
		var covers: Array[PackedFloat32Array] = []
		for k: int in range(pieces.size()):
			var cover: PackedFloat32Array = PackedFloat32Array()
			for c: int in range(pieces[k].size()):
				var p: Vector2 = pieces[k][c]
				if not left.has(p):
					left[p] = _dark_left(p, rings, others)
				cover.append(gloom * float(left[p]) * (1.0 - profile[k][c]))
			covers.append(cover)
		dark_ink.ink_graded(RisoPrint.NIGHT, pieces, covers, false)


## The pools' rings, step by step, that come within `box`: for each step, [the outlines, their
## bounds].
func _rings_over(box: Rect2) -> Array:
	var rings: Array = []
	for step: int in range(GLOOM_STEPS):
		var shapes: Array[PackedVector2Array] = []
		var boxes: Array[Rect2] = []
		for pool: Array in pools:
			if step + 1 >= pool.size():
				continue
			for shape: PackedVector2Array in pool[step + 1]:
				var bounds: Rect2 = RisoLight._bounds(shape)
				if bounds.intersects(box):
					shapes.append(shape)
					boxes.append(bounds)
		rings.append([shapes, boxes])
	return rings


## How much of the deep dark is left at `p` by the pools' `rings` (a step lifted for each ring it is
## in) and the `others` fading lights.
func _dark_left(p: Vector2, rings: Array, others: Array[Fade]) -> float:
	var steps: int = GLOOM_STEPS
	for ring: Array in rings:
		for j: int in range(ring[0].size()):
			if (ring[1][j] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, ring[0][j]):
				steps -= 1
				break
	var dark: float = float(steps) / float(GLOOM_STEPS)
	for other: Fade in others:
		dark *= 1.0 - other.light_at(p)
	return dark


## `light`'s pieces less where the `earlier` lights fall, with the falloff at their new corners,
## into `pieces` and `profile`.
func _leave_out(light: Fade, earlier: Array[Fade], pieces: Array[PackedVector2Array], profile: Array[PackedFloat32Array]) -> void:
	for piece: PackedVector2Array in light.pieces:
		var parts: Array[PackedVector2Array] = [piece]
		var bounds: Rect2 = RisoLight._bounds(piece)
		for other: Fade in earlier:
			if not other.box.intersects(bounds):
				continue
			var cut: Array[PackedVector2Array] = []
			for part: PackedVector2Array in parts:
				for rest: PackedVector2Array in Geometry2D.clip_polygons(part, other.outline):
					if not Geometry2D.is_polygon_clockwise(rest):
						cut.append(rest)
			parts = cut
		for part: PackedVector2Array in parts:
			var corners: PackedFloat32Array = PackedFloat32Array()
			for p: Vector2 in part:
				corners.append(RisoLight.carried_falloff(p.distance_to(light.at), light.reach))
			pieces.append(part)
			profile.append(corners)


## The camera's view in world space.
static func view_rect(node: CanvasItem, cam: Camera2D) -> Rect2:
	var base: Vector2 = Vector2(node.get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var size: Vector2 = base / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)
