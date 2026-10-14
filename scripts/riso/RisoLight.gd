extends Node2D
class_name RisoLight
## Light and darkness, by line of sight. Your respawn lantern throws a warm light that lifts the
## night ink off the rock and the sky around it, brightest at its flame and fading smoothly with
## distance, flickering softly, so the place you return to reads as a destination; every other
## lantern gives a faint one. Everything else that shines gives the same diffuse light, fading
## smoothly from where it shines: open exits (doors once their way is open), portals and rifts, an
## ink well not yet dry, hex bolts in flight, and the small things that shine (stars, keys, moons,
## relics, shrines, a freed bell or vane, a thrown switch, an opened temple: RisoProp.light), each
## faintly tinted in its own ink. The lantern the wizard carries lights the way too, fading the same
## way: while a lit lantern protects them it throws a warm light round its flame wherever they go;
## while they are unprotected only a short, dim one, faintly pink (danger). Rock stops every light:
## a light reaches only as far as its flame can see (RisoSight), so walls cast shadows.
##
## The wizard sees only past the rock too. What they cannot see from where they stand lies under
## more night ink (the place's `shade`), terrain, decor and props alike, still there to make out
## but dimmed; what they can see reaches to the edge of the view. In the deep dark (the place's
## `gloom`, which no band sets now) night ink lies over everything no light falls on, in sight or not,
## lifting smoothly inside each light, so most of what is seen is what a light lights. Inside a
## crypt (Crypts) it is darker still, in every band: the deep dark lies there alone, Crypts.DARK
## deep, so the moonlit terraces outside stay as they are.
##
## The lights print above the terrain and decor, under the props; the shade and the deep dark over
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
## How many times a second the respawn lantern's flicker changes: it reprints its light that often
## rather than every frame.
const FLICKER_RATE: float = 12.0
## How far apart (px) the places are that the carried light and the wizard's sight are worked out
## from: each is worked out again only once the flame or the eyes reach another, and the carried
## light is printed shifted to wherever its flame is in between, so it follows the lantern smoothly.
const LIGHT_SNAP: float = 4.0
## They take turns: on a frame when the wizard moves, at most one of them is worked out again, the
## carried light on even frames and sight on odd ones (a frame late at most). Anything that changes
## what they see (the rock, sight switched off, the lantern lit or not) has them worked out at once.
## The lights of the other things that shine, each fading from where it shines as a lantern's
## does: how far it reaches (px) and how much night it lifts there. Open exits, portals, rifts and
## an ink well not yet dry; and a hex bolt in flight.
const GLOW_REACH: float = 230.0
const GLOW_LIFT: float = 0.2
const BOLT_REACH: float = 170.0
const BOLT_LIFT: float = 0.18
## The small things that shine (RisoProp.light), each as (how far it reaches in px, how much night
## it lifts, how much it tints in its own ink): a star's spark (untinted: a level has hundreds, and
## each tint is a print of its own); the gleam of a key, a moon, a freed
## bell or vane or a thrown switch; the beacon of a star cluster, a relic, a shrine or an opened
## temple.
const SPARK: Vector3 = Vector3(90.0, 0.08, 0.0)
const GLEAM: Vector3 = Vector3(150.0, 0.12, 0.14)
const BEACON: Vector3 = Vector3(220.0, 0.16, 0.12)
## The pink tint of an unprotected wizard's dim light, where they stand; a snuffed wizard's is a
## cold blue instead (MapInfo.flame_snuffed: their lantern still protects them).
const UNLIT_PINK: float = 0.06
const SNUFFED_BLUE: float = 0.2
## How high over its floor each glowing thing's light sits (px): an exit's doorway, a portal's
## middle, the ink well's beam; a rift (no floor) glows a little over where it hangs.
const EXIT_RISE: float = 56.0
const PORTAL_RISE: float = 70.0
const WELL_RISE: float = 60.0
const RIFT_RISE: float = 10.0
## The group the glowing things join (LevelExit, Portal, Inkwell, HexBolt, and the art of the small
## things that shine, RisoProp.shines).
const GLOWS: StringName = &"glows"
## How far above the wizard's middle their eyes are (px): sight is taken from there.
const EYE_RISE: float = 24.0
## How far past the view (px) sight and the darkness reach, so the camera's drift shows no edge.
const VIEW_MARGIN: float = 160.0
## The print layer (absolute z) of the shade and the deep dark: over the props, under the trail.
const SHADE_Z: int = 8

## A light that fades smoothly from its flame to nothing at its reach, cut to what the flame sees:
## where it is, how far it reaches, the outline it lights (and its bounds), and that outline as one
## mesh of rings fanning out from the flame, the falloff at each point (`falloff`), printed as it
## is however strong the light. The deep dark, which cuts lights against one another, wants it in
## small separate pieces with the falloff at their corners (`profile`): those are cut only then
## (RisoLight._fan).
class Fade:
	var at: Vector2
	var reach: float
	var outline: PackedVector2Array = PackedVector2Array()
	var box: Rect2
	var points: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var falloff: PackedFloat32Array = PackedFloat32Array()
	var pieces: Array[PackedVector2Array] = []
	var profile: Array[PackedFloat32Array] = []

	## How much of this light falls on `p`: none past its reach or outside what its flame sees.
	func light_at(p: Vector2) -> float:
		var d: float = p.distance_to(at)
		if d >= reach or not box.has_point(p) or not Geometry2D.is_point_in_polygon(p, outline):
			return 0.0
		return RisoLight.carried_falloff(d, reach)


## Whether light and sight stop at the rock (the F7 panel can turn it off to compare): off, the
## lights are plain circles and nothing is shaded out of sight (the deep dark stays).
static var by_sight: bool = true

var lanterns: Array[Node2D] = []
var ink: InkCanvas
## The canvas the carried light prints on, shifted from where it was worked out to its flame.
var carried_ink: InkCanvas
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
## Every fading light as last printed: the lanterns', the other things that shine, then the
## carried one.
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
	carried_ink = InkCanvas.new()
	add_child(carried_ink)
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
				if type in [LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE, LevelGen.Type.EXAM_DOOR]:
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
			LevelGen.Type.LIGHT_GATE:
				shut = not bool(info.light_gates.get(v, false))
			LevelGen.Type.EXAM_DOOR:
				shut = not bool(info.exam_doors.get(v, true))
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
	carried_ink.begin()
	dark_ink.begin()
	fades.clear()
	seen = PackedVector2Array()
	if info == null or info.world == null or cam == null or info.travelling:
		ink.finish()
		carried_ink.finish()
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
			var at_t: float = floorf(t * FLICKER_RATE) / FLICKER_RATE
			var flicker: float = 1.0 + RESPAWN_FLICKER * sin(at_t * 3.1) * sin(at_t * 1.7 + 0.6)
			_print_fade(_faded(at, RESPAWN_REACH, true), RESPAWN_LIFT * flicker)
		else:
			_print_fade(_faded(at, FAINT_REACH, true), FAINT_LIFT)
	for node: Node in get_tree().get_nodes_in_group(GLOWS):
		var glow: Array = _glow(node as Node2D, info)
		if not glow.is_empty() and near.has_point(glow[0]):
			var fade: Fade = _faded(glow[0], float(glow[1]), bool(glow[3]))
			# A tint in its own ink first (as the carried light's pink), then the night lifted.
			if glow.size() > 5 and int(glow[4]) >= 0 and float(glow[5]) > 0.0:
				ink.ink_mesh(int(glow[4]), fade.points, fade.indices, fade.falloff, float(glow[5]))
			_print_fade(fade, float(glow[2]))
	_carried_light(info)
	_darkness(info, view)
	ink.finish()
	carried_ink.finish()
	dark_ink.finish()


## Where a glowing thing's light is, how far it reaches, how much it lifts and whether it stays put,
## and for the small things that shine the plate that tints it and how much (RisoProp.light); or []
## if it is dark (an exit shut by a price, a lock or a boss; a dry ink well).
func _glow(node: Node2D, info: MapInfo) -> Array:
	if node == null or node.is_queued_for_deletion():
		return []
	if node is RisoProp:
		return (node as RisoProp).light()
	if node is HexBolt:
		return [node.global_position, BOLT_REACH, BOLT_LIFT, false]
	if node is LevelExit:
		var door: LevelExit = node as LevelExit
		if door.sealed() != &"" or door.lock() >= 0 or door.price() > 0:
			return []
		return [Vector2(node.global_position.x, _floor(node, info) - EXIT_RISE), GLOW_REACH, GLOW_LIFT, true]
	if node is Portal:
		if node.has_meta(&"rift"):
			return [node.global_position + Vector2(0, -RIFT_RISE), GLOW_REACH, GLOW_LIFT, true]
		return [Vector2(node.global_position.x, _floor(node, info) - PORTAL_RISE), GLOW_REACH, GLOW_LIFT, true]
	if node is Inkwell:
		if (node as Inkwell).used():
			return []
		return [Vector2(node.global_position.x, _floor(node, info) - WELL_RISE), GLOW_REACH, GLOW_LIFT, true]
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
	var lit: bool = info.flame_lit()
	var reach: float = CARRIED_REACH if lit else UNLIT_REACH
	var now: Array = [lit, by_sight, sight.version if sight != null else -1]
	var key: Array = [RisoLight.snap(at)] + now
	var due: bool = Engine.get_process_frames() % 2 == 0
	if _carried == null or _carried_key.size() != key.size() or _carried_key.slice(1) != now or (due and key != _carried_key):
		_carried_key = key
		_carried = _faded(at, reach, false)
	carried_ink.position = at - _carried.at
	if not lit:
		if info.flame_snuffed():
			carried_ink.ink_mesh(RisoPrint.BLUE, _carried.points, _carried.indices, _carried.falloff, SNUFFED_BLUE)
		else:
			carried_ink.ink_mesh(RisoPrint.PINK, _carried.points, _carried.indices, _carried.falloff, UNLIT_PINK)
	carried_ink.lift_ink_mesh([RisoPrint.NIGHT], _carried.points, _carried.indices, _carried.falloff, CARRIED_LIFT if lit else UNLIT_LIFT)
	fades.append(_carried)
	carried_seen = _carried.outline
	carried = Vector3(at.x, at.y, reach)


## Lift the night where `light` falls, `lift` at its flame, and keep it in `fades`.
func _print_fade(light: Fade, lift: float) -> void:
	ink.lift_ink_mesh([RisoPrint.NIGHT], light.points, light.indices, light.falloff, lift)
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
	RisoLight._mesh(light)
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


## Lay `light`'s outline (seen whole from its flame) out as one mesh fanning out from the flame:
## a spoke to each corner of the outline, each cut into the same number of rings (enough for the
## longest to step FADE_STEP), with the falloff at every point. Neighbouring spokes share their
## points, so it holds a quarter of the points the same rings would as separate pieces, and it is
## printed without being cut into triangles again.
static func _mesh(light: Fade) -> void:
	var at: Vector2 = light.at
	var outline: PackedVector2Array = light.outline
	var n: int = outline.size()
	if n < 3:
		return
	var longest: float = 0.0
	for p: Vector2 in outline:
		longest = maxf(longest, p.distance_to(at))
	var rings: int = clampi(ceili(longest / FADE_STEP), 1, 32)
	# The flame, then spoke by spoke its rings outward: ring k (1 to rings) of spoke i is point
	# 1 + i * rings + k - 1.
	var points: PackedVector2Array = PackedVector2Array()
	var falloff: PackedFloat32Array = PackedFloat32Array()
	points.resize(1 + n * rings)
	falloff.resize(1 + n * rings)
	points[0] = at
	falloff[0] = 1.0
	var inv_reach: float = 1.0 / maxf(light.reach, 0.001)
	for i: int in range(n):
		var a: Vector2 = outline[i] - at
		var length: float = a.length()
		for k: int in range(1, rings + 1):
			var s: float = float(k) / float(rings)
			var x: float = minf(length * s * inv_reach, 1.0)
			var idx: int = 1 + i * rings + k - 1
			points[idx] = at + a * s
			falloff[idx] = (1.0 - x * x) * (1.0 - x * x)
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(n * 3 + n * (rings - 1) * 6)
	var w: int = 0
	for i: int in range(n):
		var a0: int = 1 + i * rings
		var b0: int = 1 + ((i + 1) % n) * rings
		indices[w] = 0
		indices[w + 1] = a0
		indices[w + 2] = b0
		w += 3
		for k: int in range(rings - 1):
			indices[w] = a0 + k
			indices[w + 1] = b0 + k
			indices[w + 2] = b0 + k + 1
			indices[w + 3] = a0 + k
			indices[w + 4] = b0 + k + 1
			indices[w + 5] = a0 + k + 1
			w += 6
	light.points = points
	light.indices = indices
	light.falloff = falloff


## Cut `light`'s outline (seen whole from its flame) into small pieces fanning out from the flame in
## steps, each with the falloff at its corners (for the deep dark, which cuts them against other
## lights). Once for a light.
static func _fan(light: Fade) -> void:
	if not light.pieces.is_empty():
		return
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


## `p` snapped to the nearest LIGHT_SNAP step.
static func snap(p: Vector2) -> Vector2:
	return (p / LIGHT_SNAP).round() * LIGHT_SNAP


## The bounds of an outline.
static func _bounds(outline: PackedVector2Array) -> Rect2:
	if outline.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(outline[0], Vector2.ZERO)
	for p: Vector2 in outline:
		box = box.expand(p)
	return box


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


## The shade over what the wizard cannot see, and the deep dark over what no light falls on: all
## over in a place with gloom, and inside every crypt.
func _darkness(info: MapInfo, view: Rect2) -> void:
	var player: Player = Stage.player()
	var shade: float = info.here.shade()
	if by_sight and sight != null and shade > 0.0 and player != null and is_instance_valid(player):
		var from: Vector2 = RisoLight.eye(player)
		var key: Array = [RisoLight.snap(from), RisoLight.snap(view.position), view.size.round(), sight.version]
		# Its turn on odd frames, unless the rock changed or there is none yet.
		var due: bool = Engine.get_process_frames() % 2 == 1
		if key != _shade_key and (due or _shade_key.size() != key.size() or _shade_key[3] != key[3]):
			_shade_key = key
			_shade_seen = sight.polygon(from, view)
			_shade_pieces = RisoSight.outside(view, [_shade_seen])
		seen = _shade_seen
		dark_ink.ink(RisoPrint.NIGHT, shade, _shade_pieces, false)
	var gloom: float = info.here.gloom()
	if gloom > 0.0:
		_deep_dark(gloom, view, false)
	# Inside a crypt it is fully dark (Crypts), whatever the band.
	for room: Rect2 in crypt_rooms(info):
		var area: Rect2 = room.intersection(view)
		if area.has_area():
			_deep_dark(Crypts.DARK, area, true)


## The insides of the level's crypts (Crypts), in world pixels.
func crypt_rooms(info: MapInfo) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if info.world == null:
		return out
	for crypt: Dictionary in info.world.crypts:
		var room: Rect2i = (crypt["box"] as Rect2i).grow(-1)
		var top_left: Vector2 = info.cell_position(room.position) - Vector2(half, half)
		out.append(Rect2(top_left, Vector2(room.size) * half * 2.0))
	return out


## Night ink `gloom` deep over `area`, everywhere no light falls on it, lifting smoothly inside
## each light; `clip`: the lights are cut to `area` (a crypt's inside), else they lie within it.
func _deep_dark(gloom: float, area: Rect2, clip: bool) -> void:
	var lit: Array[PackedVector2Array] = []
	var near: Array[Fade] = []
	for light: Fade in fades:
		if not clip or light.box.intersects(area):
			lit.append(light.outline)
			near.append(light)
	dark_ink.ink(RisoPrint.NIGHT, gloom, RisoSight.outside(area, lit), false)
	var frame: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	# Inside the lights the deep dark lifts with them, smoothly: at each point, what is left of it
	# less each light's share there. Where lights overlap, the first prints it and the others leave
	# that part out.
	for i: int in range(near.size()):
		var light: Fade = near[i]
		var others: Array[Fade] = []
		var earlier: Array[Fade] = []
		for j: int in range(near.size()):
			if j != i and near[j].box.intersects(light.box):
				others.append(near[j])
				if j < i:
					earlier.append(near[j])
		RisoLight._fan(light)
		var pieces: Array[PackedVector2Array] = light.pieces
		var profile: Array[PackedFloat32Array] = light.profile
		if not earlier.is_empty():
			pieces = []
			profile = []
			_leave_out(light, earlier, pieces, profile)
		if clip and not area.encloses(light.box):
			var kept: Array[PackedVector2Array] = []
			var kept_profile: Array[PackedFloat32Array] = []
			for piece: PackedVector2Array in pieces:
				for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, frame):
					if Geometry2D.is_polygon_clockwise(part):
						continue
					var corners: PackedFloat32Array = PackedFloat32Array()
					for p: Vector2 in part:
						corners.append(RisoLight.carried_falloff(p.distance_to(light.at), light.reach))
					kept.append(part)
					kept_profile.append(corners)
			pieces = kept
			profile = kept_profile
		# Neighbouring pieces share their corners: each corner is worked out once.
		var left: Dictionary = {}
		var covers: Array[PackedFloat32Array] = []
		for k: int in range(pieces.size()):
			var cover: PackedFloat32Array = PackedFloat32Array()
			for c: int in range(pieces[k].size()):
				var p: Vector2 = pieces[k][c]
				if not left.has(p):
					left[p] = _dark_left(p, others)
				cover.append(gloom * float(left[p]) * (1.0 - profile[k][c]))
			covers.append(cover)
		dark_ink.ink_graded(RisoPrint.NIGHT, pieces, covers, false)


## How much of the deep dark is left at `p` by the `others` fading lights.
func _dark_left(p: Vector2, others: Array[Fade]) -> float:
	var dark: float = 1.0
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
