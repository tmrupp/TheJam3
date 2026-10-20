extends Node2D
class_name RisoLight
## Light and darkness, by line of sight. Every light is a hard-edged pool in two steps, printed as
## a riso print would: an outer pool to its reach and a brighter one round its flame (BAND_INNER of
## the reach), each lifting the night ink flat. Your respawn lantern throws a warm one that lifts
## the night off the rock and the sky around it, flickering softly, so the place you return to reads
## as a destination; every other lantern gives a faint one. Everything else that shines gives the
## same kind of light, from where it shines: open exits (doors once their way is open), portals and rifts, an
## ink well not yet dry, hex bolts in flight, and the small things that shine (stars, keys, moons,
## relics, shrines, a freed bell or vane, a thrown switch, an opened temple: RisoProp.light), each
## faintly tinted in its own ink. The lantern the wizard carries lights the way too, in the same
## way: while a lit lantern protects them it throws a warm light round its flame wherever they go;
## while they are unprotected only a short, dim one, faintly pink (danger). Rock stops every light:
## a light reaches only as far as its flame can see (RisoSight), so walls cast shadows.
##
## The wizard sees only past the rock too. What they cannot see from where they stand lies under
## more night ink (the place's `shade`), terrain, decor and props alike, still there to make out
## but dimmed; what they can see reaches to the edge of the view. In the deep dark (the place's
## `gloom`, which no band sets now) night ink lies over everything no light falls on, in sight or not,
## thinner in each light's outer pool and gone in its inner one, so most of what is seen is what a light lights. Inside a
## crypt (Crypts) it is darker still, in every band: the deep dark lies there alone, Crypts.DARK
## deep, so the moonlit terraces outside stay as they are.
##
## The lights print above the terrain and decor, under the props; the shade and the deep dark over
## the props, under the wizard's trail and the wizard.

## The lanterns' lights, each a pool in two steps (see BAND_INNER): how far it reaches (px) and how
## much night it lifts at the flame. The respawn lantern's, and how much its
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
## A light's two steps: the inner pool reaches BAND_INNER of the light's reach, and each pool
## lifts BAND_LIFT of the light's lift, so the inner one, under both, is the brighter. In the deep
## dark the outer pool leaves DARK_OUTER of the dark, the inner none.
const BAND_INNER: float = 0.5
const BAND_LIFT: float = 0.55
const DARK_OUTER: float = 0.45
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
## The lights of the other things that shine, each a pool round where it shines as a lantern's
## is: how far it reaches (px) and how much night it lifts there. Open exits, portals, rifts and
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
## The squares (px) the things that shine are indexed by, and how often (seconds) the index is laid
## out again even when nothing has come or gone (see _glows_near).
const GLOW_CELL: float = 512.0
const GLOW_REINDEX: float = 1.0
## How far above the wizard's middle their eyes are (px): sight is taken from there.
const EYE_RISE: float = 24.0
## How far past the view (px) sight and the darkness reach, so the camera's drift shows no edge.
const VIEW_MARGIN: float = 160.0
## How far past the view (px) the shade is worked out, in steps of the same: the camera drifts
## that far before it is worked out again.
const SHADE_SLACK: float = 192.0
## The print layer (absolute z) of the shade and the deep dark: over the props, under the trail.
const SHADE_Z: int = 8

## A light: a hard-edged pool in two steps round its flame, cut to what the flame sees. Where it
## is, how far it reaches, the outline it lights (and its bounds), and its two pools as the arrays
## it prints (`outer`, the whole outline; `inner`, the outline within BAND_INNER of its reach),
## kept from print to print, so a light that stays put prints the very same arrays again and its
## ink is kept without comparing them (InkCanvas.keeps_shapes).
class Fade:
	var at: Vector2
	var reach: float
	var outline: PackedVector2Array = PackedVector2Array()
	var box: Rect2
	var outer: Array[PackedVector2Array] = []
	var inner: Array[PackedVector2Array] = []


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
## Every light as last printed: the lanterns', the other things that shine, then the
## carried one.
var fades: Array[Fade] = []
## The lanterns' lights, which stay put, by where they are and how far they reach, until the rock
## changes (`_cache_version`).
var _fade_cache: Dictionary = {}
## The still lights as last printed, by how they print (Vector3: lift, tint plate, tint): each
## [the lights, their outer pools, their inner pools], kept while the same lights are in it so the
## very same arrays print again (see keeps_shapes).
var _batches: Dictionary = {}
## Where the things that shine are (_glows_near): by GLOW_CELL square, laid out from the group as it
## was (`_glow_group`), at `_glow_indexed`; the hex bolts apart.
var _glow_index: Dictionary = {}
var _glow_flying: Array[Node2D] = []
var _glow_group: Array[Node] = []
var _glow_indexed: float = -INF
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
	# Each light hands over the very same arrays while it stays put (Fade), and the shade its pieces
	# until they are worked out again, never changing one: their ink is kept without a comparison.
	ink = InkCanvas.new()
	ink.keeps_shapes = true
	add_child(ink)
	carried_ink = InkCanvas.new()
	carried_ink.keeps_shapes = true
	add_child(carried_ink)
	dark_ink = InkCanvas.new()
	dark_ink.keeps_shapes = true
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
				if type in [LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE, LevelGen.Type.EXAM_DOOR, LevelGen.Type.OSSUARY_DOOR]:
					_changing[Vector2i(x, y)] = type
	_cache.clear()
	_fade_cache.clear()
	_batches.clear()
	_glow_group = []
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
			LevelGen.Type.OSSUARY_DOOR:
				shut = not info.ossuary_open(v)
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
	# The lights that stay put, gathered by how they print (see _batches); the rest printed apart.
	var still: Dictionary = {}
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
			_gather(still, _faded(at, RESPAWN_REACH, true), RESPAWN_LIFT * flicker, -1, 0.0)
		else:
			_gather(still, _faded(at, FAINT_REACH, true), FAINT_LIFT, -1, 0.0)
	for node: Node2D in _glows_near(near):
		var glow: Array = _glow(node, info)
		if glow.is_empty() or not near.has_point(glow[0]):
			continue
		var fade: Fade = _faded(glow[0], float(glow[1]), bool(glow[3]))
		var plate: int = int(glow[4]) if glow.size() > 5 and float(glow[5]) > 0.0 else -1
		var tint: float = float(glow[5]) if plate >= 0 else 0.0
		if bool(glow[3]):
			_gather(still, fade, float(glow[2]), plate, tint)
			continue
		# A tint in its own ink first (as the carried light's pink), then the night lifted.
		if plate >= 0:
			ink.ink(plate, tint * BAND_LIFT, fade.inner, false)
		_print_fade(fade, float(glow[2]))
	_print_still(still)
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


## The light of the lantern the wizard carries (see the class note), thrown from its flame.
func _carried_light(info: MapInfo) -> void:
	carried = Vector3.ZERO
	carried_seen = PackedVector2Array()
	var player: Player = Stage.player()
	if player == null or not is_instance_valid(player) or player.phasing or info.run == null:
		return
	var at: Vector2 = _flame(player)
	var lit: bool = info.flame_lit()
	# A flare (Lamplight.flare_scale) in steps, so its light is worked out again only as it grows.
	var reach: float = snappedf(Lamplight.carried_reach(info), 16.0) if lit else UNLIT_REACH
	var now: Array = [lit, reach, by_sight, sight.version if sight != null else -1]
	var key: Array = [RisoLight.snap(at)] + now
	var due: bool = Engine.get_process_frames() % 2 == 0
	if _carried == null or _carried_key.size() != key.size() or _carried_key.slice(1) != now or (due and key != _carried_key):
		_carried_key = key
		_carried = _faded(at, reach, false)
	carried_ink.position = at - _carried.at
	if not lit:
		if info.flame_snuffed():
			carried_ink.ink(RisoPrint.BLUE, SNUFFED_BLUE, _carried.inner, false)
		else:
			carried_ink.ink(RisoPrint.PINK, UNLIT_PINK, _carried.inner, false)
	var lift: float = (CARRIED_LIFT if lit else UNLIT_LIFT) * BAND_LIFT
	carried_ink.lift_ink([RisoPrint.NIGHT], lift, _carried.outer)
	carried_ink.lift_ink([RisoPrint.NIGHT], lift, _carried.inner)
	fades.append(_carried)
	carried_seen = _carried.outline
	carried = Vector3(at.x, at.y, reach)


## Put still light `light`, lifting `lift` and tinted `tint` in `plate` (-1 for none), with the
## others that print as it does, in `still` (see _batches).
func _gather(still: Dictionary, light: Fade, lift: float, plate: int, tint: float) -> void:
	var key: Vector3 = Vector3(snappedf(lift, 0.001), float(plate), snappedf(tint, 0.001))
	if not still.has(key):
		still[key] = [] as Array[Fade]
	(still[key] as Array[Fade]).append(light)
	fades.append(light)


## Print the still lights gathered in `still`: each group's pools in one op apiece (a tint, then
## the outer pools lifted, then the inner ones), the very arrays it printed last time while the
## same lights are in it (_batches).
func _print_still(still: Dictionary) -> void:
	var now: Dictionary = {}
	for key: Vector3 in still:
		var lights: Array[Fade] = still[key]
		var batch: Array = _batches.get(key, [])
		if batch.is_empty() or batch[0] != lights:
			var outers: Array[PackedVector2Array] = []
			var inners: Array[PackedVector2Array] = []
			for light: Fade in lights:
				outers.append_array(light.outer)
				inners.append_array(light.inner)
			batch = [lights, outers, inners]
		now[key] = batch
		if int(key.y) >= 0:
			ink.ink(int(key.y), key.z * BAND_LIFT, batch[2], false)
		ink.lift_ink([RisoPrint.NIGHT], key.x * BAND_LIFT, batch[1])
		ink.lift_ink([RisoPrint.NIGHT], key.x * BAND_LIFT, batch[2])
	_batches = now


## The things that shine (GLOWS) whose place lies in `near`, from an index of where they are
## (_glow_index), so the hundreds of stars in a level are not each asked for their light every frame.
## The index is laid out again when anything joins or leaves the group (the group's array compared
## with the last, natively), or every GLOW_REINDEX seconds (a key carried off, say); hex bolts,
## which fly, are looked at every frame.
func _glows_near(near: Rect2) -> Array[Node2D]:
	var group: Array[Node] = get_tree().get_nodes_in_group(GLOWS)
	if group != _glow_group or t - _glow_indexed > GLOW_REINDEX:
		_glow_group = group
		_glow_indexed = t
		_glow_index.clear()
		_glow_flying.clear()
		for node: Node in group:
			var n: Node2D = node as Node2D
			if n == null:
				continue
			if n is HexBolt:
				_glow_flying.append(n)
				continue
			var cell: Vector2i = Vector2i((n.global_position / GLOW_CELL).floor())
			if not _glow_index.has(cell):
				_glow_index[cell] = [] as Array[Node2D]
			(_glow_index[cell] as Array[Node2D]).append(n)
	var out: Array[Node2D] = []
	var grown: Rect2 = near.grow(GLOW_CELL * 0.5)
	var lo: Vector2i = Vector2i((grown.position / GLOW_CELL).floor())
	var hi: Vector2i = Vector2i((grown.end / GLOW_CELL).floor())
	for x: int in range(lo.x, hi.x + 1):
		for y: int in range(lo.y, hi.y + 1):
			var here: Variant = _glow_index.get(Vector2i(x, y))
			if here != null:
				for n: Variant in here:
					if is_instance_valid(n):
						out.append(n as Node2D)
	for n: Variant in _glow_flying:
		if is_instance_valid(n):
			out.append(n as Node2D)
	return out


## Lift the night where `light` falls (`lift` at its flame, in its two pools), and keep it in
## `fades`.
func _print_fade(light: Fade, lift: float) -> void:
	ink.lift_ink([RisoPrint.NIGHT], lift * BAND_LIFT, light.outer)
	ink.lift_ink([RisoPrint.NIGHT], lift * BAND_LIFT, light.inner)
	fades.append(light)


## A light at `at` reaching `reach`, cut to what its flame sees, with its two pools; `still` lights
## keep what they light until the rock changes.
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
	if light.outline.size() >= 3:
		light.outer = [light.outline]
		# The inner pool: what the flame sees within BAND_INNER of its reach. Both are seen whole
		# from the flame, so they meet in one outline.
		for piece: PackedVector2Array in RisoSight.lit(RisoShapes.circle(at, reach * BAND_INNER, 32), light.outline):
			if light.inner.is_empty() or piece.size() > light.inner[0].size():
				light.inner = [piece]
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
		# Worked out over the view grown SHADE_SLACK and snapped to steps of it, so the camera's
		# drift with the wizard standing still does not have it worked out again.
		var corner: Vector2 = ((view.position - Vector2(SHADE_SLACK, SHADE_SLACK)) / SHADE_SLACK).floor() * SHADE_SLACK
		var box: Rect2 = Rect2(corner, ((view.end + Vector2(SHADE_SLACK, SHADE_SLACK) - corner) / SHADE_SLACK).ceil() * SHADE_SLACK)
		var key: Array = [RisoLight.snap(from), box, sight.version]
		# Its turn on odd frames, unless the rock changed or there is none yet.
		var due: bool = Engine.get_process_frames() % 2 == 1
		if key != _shade_key and (due or _shade_key.size() != key.size() or _shade_key[2] != key[2]):
			_shade_key = key
			_shade_seen = sight.polygon(from, box)
			_shade_pieces = RisoSight.outside(box, [_shade_seen])
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


## Night ink `gloom` deep over `area`, everywhere no light falls on it, in two steps inside each
## light: DARK_OUTER of it in a light's outer pool, none in its inner one. `clip`: the lights are cut
## to `area` (a crypt's inside), else they lie within it. Printed as two coats, the dark outside the
## inner pools and then more of it outside the outer ones, which together come to `gloom` where no
## light falls.
func _deep_dark(gloom: float, area: Rect2, clip: bool) -> void:
	var outers: Array[PackedVector2Array] = []
	var inners: Array[PackedVector2Array] = []
	for light: Fade in fades:
		if (not clip or light.box.intersects(area)) and not light.outer.is_empty():
			outers.append(light.outline)
			if not light.inner.is_empty():
				inners.append(light.inner[0])
	var first: float = gloom * DARK_OUTER
	# The second coat over the first comes to `gloom` where both lie (the inks multiply).
	var second: float = 1.0 - (1.0 - gloom) / maxf(1.0 - first, 0.001)
	dark_ink.ink(RisoPrint.NIGHT, first, RisoSight.outside(area, inners), false)
	dark_ink.ink(RisoPrint.NIGHT, second, RisoSight.outside(area, outers), false)


## The camera's view in world space.
static func view_rect(node: CanvasItem, cam: Camera2D) -> Rect2:
	var base: Vector2 = Vector2(node.get_window().content_scale_size)
	if base.x < 1.0:
		base = Vector2(320, 180)
	var size: Vector2 = base / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)
