extends Node2D
class_name RisoDecor
## Decor for the surface grotto: small printed props that make the rock feel lived in, never
## part of the gameplay.
## - Floors: grass tufts, broad-leaved plants, moon-flowers, mushrooms, stones; and hedges (shrub_runs): low runs of
##   rounded leafage along stretches of floor, as long as the stretch allows, behind the fences.
## - Ceilings: hanging roots, stalactites, ink drips (RisoAmbient drops ink from them).
## - Walls: vines down the rock face.
## A cemetery has its own plan (PLANS, by Archetype.decor): headstones (rounded, gothic, cross-topped,
## broken, flat ledgers), crosses, obelisks, urns, angels, grave flowers, bare trees and dry grass
## on its floors, cobwebs and roots under its ceilings, ivy on its walls.
## The sky has its own too: grass, flowers and stones on its islands, standing stones, stone piles
## and windsocks where there is headroom, scattered roots and wisps under them, vines down
## their sides.
## The institute has its own: veined marble slabs on its halls, and inside them great columns from
## floor to ceiling with tall bookcases between (books in many colours, a departure from the decor's
## inks asked for by the owner), reading desks on the lecture halls' tiers and now and then a statue;
## bookcases out in its rooms too, with desks in its studies, alchemy equipment in its laboratories
## and ritual equipment in its sanctums.
## The whale's belly has its own: bones on its floors (a fish's skeleton, loose ribs), lumps of
## flesh, tendrils of flesh and drips hanging from its ceilings, and dark veins through the flesh
## along its walls.
## The crags have theirs: on the castle's masonry (LevelGen.masonry), dressed stone in courses,
## arrow slits through its walls, banners and rubble on its floors and battlements along them; on
## the bare cliff, crag grass, stones, fallen blocks and broken columns, cobwebs and roots under
## its ledges and ivy down its faces.
## Behind them, in a lighter ink on a layer of their own, fences run along stretches of floor
## (fence_runs): white wooden pickets in the garden, iron railings between stone posts in a cemetery,
## lines of peace flags strung between two stone piles in the sky.
## Plants (tufts, flowers, roots, vines) are drawn live, only on screen, so they can sway: a slow
## idle breeze, and a springy push away from the wizard as they pass.
## Every choice is a hash of the level seed and the cell, so a level always wears the same
## decor for everyone; the world's RNG is never touched. Decor keeps clear of any cell holding
## an object, and prints only in blue, night, moss (accent over blue) and bare paper: pink is
## danger, yellow is reward, glow is the wizard's.

const CHUNK: int = 16

## Draw order and ink for each kind of mark. [plate, cover, knock, punch]
const SLOTS: Array[Array] = [
	[RisoPrint.NIGHT, 0.0, false, false],   # 0-3 unused (the rock stays plain)
	[RisoPrint.NIGHT, 0.0, false, false],
	[RisoPrint.BLUE, 0.0, false, false],
	[RisoPrint.BLUE, 0.0, false, false],
	[RisoPrint.BLUE, 1.0, false, true],     # 4 roots, stalactites, drips, vines, stems
	[RisoPrint.NIGHT, 0.3, false, false],   # 5 their shade
	[RisoPrint.ACCENT, 0.85, false, false], # 6 moss over blue: tufts, leaves, vine leaves
	[RisoPrint.BLUE, 1.0, false, true],     # 7 moss bases (blue under the accent)
	[RisoPrint.NIGHT, 1.0, true, false],    # 8 paper: petals, mushroom stems and spots
	[RisoPrint.BLUE, 0.2, false, false],    # 9 petal tint
	[RisoPrint.NIGHT, 0.7, false, false],   # 10 flower hearts
	[RisoPrint.BLUE, 1.0, false, true],     # 11 mushroom caps
	[RisoPrint.BLUE, 0.85, false, true],    # 12 stones
	[RisoPrint.NIGHT, 0.35, false, false],  # 13 stone shade
	[RisoPrint.NIGHT, 1.0, true, false],    # 14 paper spots on the caps
	[RisoPrint.NIGHT, 1.0, true, false],    # 15 background fences: the garden's white pickets
	[RisoPrint.BLUE, 0.8, false, false],    # 16 the cemetery's iron railings
	[RisoPrint.NIGHT, 0.18, false, false],  # 17 their shade
	[RisoPrint.ACCENT, 0.9, false, true],   # 18 the sky's peace flags: sun (and moss over blue)
	[RisoPrint.PINK, 0.55, false, true],    # 19 the sky's peace flags: plum (over blue)
	[RisoPrint.BLUE, 0.9, false, true],     # 20 the sky's flags' blue, their poles and stone piles
	[RisoPrint.BLUE, 1.0, false, true],     # 21 hedges: moss base (blue under the accent)
	[RisoPrint.ACCENT, 0.85, false, false], # 22 hedges: moss
	[RisoPrint.NIGHT, 0.3, false, false],   # 23 hedges: shade at their foot
	[RisoPrint.BLUE, 0.55, false, true],    # 24 the crags' battlements: pale stone
	[RisoPrint.NIGHT, 0.25, false, false],  # 25 their shade
	[RisoPrint.NIGHT, 0.06, false, false],  # 26 dressed stone on masonry: the lighter blocks
	[RisoPrint.NIGHT, 0.14, false, false],  # 27 the darker blocks
	[RisoPrint.NIGHT, 0.85, false, false],  # 28 arrow slits
	[RisoPrint.NIGHT, 0.6, true, false],    # 29 mortar between the blocks: the stone's inks lifted
	[RisoPrint.BLUE, 1.0, false, true],     # 30 the institute's books: brown (the base of the rest)
	[RisoPrint.ACCENT, 0.9, false, false],  # 31 moss books (over brown)
	[RisoPrint.PINK, 0.65, false, false],   # 32 maroon books (over brown)
	[RisoPrint.NIGHT, 0.95, false, false],  # 33 night books
	[RisoPrint.BLUE, 0.45, false, true],    # 34 tan books
	[RisoPrint.PINK, 0.45, false, false],   # 35 plum books (over tan)
	[RisoPrint.NIGHT, 0.3, false, false],   # 36 the books' shade (tops, spine bands)
	[RisoPrint.NIGHT, 1.0, true, false],    # 37 paper books and gilt bands (every ink knocked)
	[RisoPrint.BLUE, 0.1, false, false],    # 38 marble's veins, faint
	[RisoPrint.NIGHT, 1.0, true, false],    # 39 great columns: paper marble (behind the rest)
	[RisoPrint.NIGHT, 0.12, false, false],  # 40 their shade and fluting
	[RisoPrint.NIGHT, 0.22, false, false],  # 41 the joints between marble's slabs, a wooden panel's shadow
]
## What mortar lifts (slot 29): every ink built stone can print in (RisoTerrain.MASONRY_LOOKS).
const MORTAR_LIFT: Array[int] = [RisoPrint.BLUE, RisoPrint.ACCENT, RisoPrint.CLOTH, RisoPrint.NIGHT]
## Fence slots, between the hedges and the rest of the decor.
const BACK_SLOTS: Array[int] = [15, 16, 17, 18, 19, 20, 24, 25, 39, 40]
## Hedge slots, behind everything else (the fences in front of them).
const HEDGE_SLOTS: Array[int] = [21, 22, 23]
const KNOCK_ALL: Array[int] = [RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE, RisoPrint.GLOW, RisoPrint.ROBE]
const KNOCK_ROCK: Array[int] = [RisoPrint.BLUE, RisoPrint.NIGHT]
## How a cobweb is spun (in the sketch measures props are drawn at, see PROP_SCALE): a spoke every
## WEB_TURN radians about its hub, WEB_REACH long on the whole (14 to 24), and rings strung straight
## across them WEB_RINGS of the way out. The spider's webs are spun to the same density of lines on
## screen (WEB_RING_GAP and the rest, below; Spider.plain_web).
const WEB_TURN: float = PI * 0.2
## An arrow slit, as a crossbow's is cut (CrossbowArt) and an empty one in the crags' walls: its
## niche in the face toward the room, how deep into the stone and how high; the bore on from it
## through to the outer face, how high; all drawn SLIT_SIZE times as big (pixels).
const SLIT_NICHE: Vector2 = Vector2(50.0, 76.0)
const SLIT_BORE: float = 12.0
const SLIT_SIZE: float = 1.4
const WEB_REACH: float = 19.0
const WEB_RINGS: Array[float] = [0.45, 0.8]
const STRUCTURES: Array[String] = ["level_exit.tscn", "shrine.tscn", "door.tscn", "checkpoint.tscn", "spikes.tscn",
	"portal.tscn", "inkwell.tscn", "moving_platform.tscn", "rolling_ladder.tscn", "bell.tscn", "switch.tscn", "switch_gate.tscn", "key.tscn",
	"relic.tscn", "gondola.tscn", "stalactite.tscn", "department.tscn", "way_back.tscn", "study_desk.tscn",
	"timetable_board.tscn"]
## Structures that stand tall, keeping a wider stretch of floor clear (see rebuild). A department's
## portal is one: an institute column or bookcase stood on its cell once rose out of its arch.
const TALL: Array[String] = ["level_exit.tscn", "shrine.tscn", "checkpoint.tscn", "door.tscn", "bell.tscn", "gondola.tscn",
	"department.tscn", "way_back.tscn"]

## The plan: one entry per prop, {kind, cell, at (world), seed}.
var items: Array[Dictionary] = []
## Where RisoAmbient hangs its life: fireflies over plants, ink drops under drips.
var firefly_spots: PackedVector2Array = PackedVector2Array()
var drip_spots: PackedVector2Array = PackedVector2Array()
## Where each drip's drop lands (the floor below it, or a few cells down).
var drip_ends: PackedFloat32Array = PackedFloat32Array()
var _solid: Dictionary = {}
var canvases: Array[InkCanvas] = []
## Plants that sway: indexes into `items`, each item holding its polygons ("parts"), the point it
## grows from ("anchor"), whether it hangs ("hang") and its spring ("a", "v").
const SWAY_KINDS: Array[StringName] = [&"tuft", &"leafy", &"roots", &"vine"]
## How many times a second the idle breeze moves the plants: it sways them so little (0.03) that its
## steps are not seen, and a plant is bent again only when its bend has moved BEND_STEP, so on most
## frames nothing is reprinted.
const BREEZE_RATE: float = 10.0
const BEND_STEP: float = 0.002
var swaying: Array[int] = []
var live: InkCanvas
var t: float = 0.0
var half: float = 64.0


func _ready() -> void:
	z_index = -15
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	live = InkCanvas.new()
	add_child(live)


## A stable 0..1 hash of the level seed, a cell and a salt.
static func h(level_seed: int, v: Vector2i, salt: int) -> float:
	# Rules.level_seed's mix, written out here: decor asks for it hundreds of thousands of times a
	# level (the institute's books), and a call less each time is felt.
	var x: int = ((level_seed ^ (salt * 2654435)) * 73856093) ^ ((v.x * 7919 + v.y * 104729 + salt) * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 15)) * 0x2c1b3c6d
	x = (x ^ (x >> 12)) * 0x297a2d39
	x = (x ^ (x >> 15)) & 0x7fffffff
	return float(x % 100000) / 100000.0


## The decor plans, by name (Archetype.decor, NextWorldDef.decor): each works out every prop for a
## level from (solid, occupied, level seed, bounds, the sky's bottom style, the masonry). A band with
## a look of its own adds its plan here; any other name gets the garden's.
static var PLANS: Dictionary = {
	&"garden": plan_garden,
	&"cemetery": plan_graveyard,
	&"sky": plan_isles,
	&"crags": plan_crags,
	&"institute": plan_institute,
	&"belly": plan_belly,
}


## Work out every prop for a level (pure: the same inputs always give the same plan), by the plan
## named `decor` (see PLANS). `masonry` is the rock laid as built stone (LevelGen.masonry), and
## `interiors` the open cells inside built rooms (LevelGen.interiors).
static func plan(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, decor: StringName = &"garden", sky_bottom_style: StringName = &"roots", masonry: Dictionary = {}, interiors: Dictionary = {}) -> Array[Dictionary]:
	var by: Callable = PLANS.get(decor, PLANS[&"garden"])
	return by.call(solid, occupied, level_seed, bounds, sky_bottom_style, masonry, interiors)


## A cemetery's plan: its graves and props (plan_cemetery), and iron railings along its floors
## (none inside its crypts).
static func plan_graveyard(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, _bottom_style: StringName = &"roots", masonry: Dictionary = {}, interiors: Dictionary = {}) -> Array[Dictionary]:
	var graves: Array[Dictionary] = plan_cemetery(solid, occupied, level_seed, bounds, masonry, interiors)
	for run: Dictionary in fence_runs(solid, occupied, level_seed, bounds):
		if (run["cells"] as Array).any(func(c: Vector2i) -> bool: return interiors.has(c)):
			continue
		run["iron"] = true
		graves.append(run)
	return graves


## The sky's plan: its islands' props (plan_sky), and peace flags strung along their floors.
static func plan_isles(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, bottom_style: StringName = &"roots", _masonry: Dictionary = {}, _interiors: Dictionary = {}) -> Array[Dictionary]:
	var isles: Array[Dictionary] = plan_sky(solid, occupied, level_seed, bounds, bottom_style)
	for run: Dictionary in fence_runs(solid, occupied, level_seed, bounds):
		run["bunting"] = true
		isles.append(run)
	return isles


## The garden's plan (and any level's without one of its own): fences, hedges, and plants, roots
## and vines on the rock.
static func plan_garden(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, _bottom_style: StringName = &"roots", _masonry: Dictionary = {}, _interiors: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = fence_runs(solid, occupied, level_seed, bounds)
	out.append_array(shrub_runs(solid, occupied, level_seed, bounds))
	var cells: Array = solid.keys()
	cells.sort()
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			continue
		var above: Vector2i = v + Vector2i.UP
		var below: Vector2i = v + Vector2i.DOWN
		if not solid.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			var kind: StringName = &""
			if r < 0.36:
				kind = &"tuft"
			elif r < 0.47:
				kind = &"leafy"
			elif r < 0.6:
				kind = &"mushroom"
			elif r < 0.65:
				kind = &"stones"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		if not solid.has(below) and not occupied.has(below):
			var r: float = h(level_seed, v, 2)
			var kind: StringName = &""
			if r < 0.24:
				kind = &"roots"
			elif r < 0.34:
				kind = &"stalactite"
			elif r < 0.4:
				kind = &"drip"
			if kind != &"":
				out.append({"kind": kind, "cell": below, "base": v})
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var open: Vector2i = v + side
			if solid.has(open) or occupied.has(open) or not solid.has(above):
				continue
			if h(level_seed, v, 3 + side.x) < 0.12:
				out.append({"kind": &"vine", "cell": open, "base": v, "side": side.x})
	return out


## The whale's belly (Belly): on its floors, now and then bones (BELLY_BONES) or lumps of flesh
## (BELLY_LUMPS); from its ceilings, tendrils of flesh (BELLY_TENDRILS) and drips (BELLY_DRIPS);
## and through the flesh along its open faces, veins (BELLY_VEINS of them).
static func plan_belly(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, _bottom_style: StringName = &"roots", _masonry: Dictionary = {}, _interiors: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array = solid.keys()
	cells.sort()
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			continue
		var above: Vector2i = v + Vector2i.UP
		var below: Vector2i = v + Vector2i.DOWN
		if not solid.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			if r < BELLY_BONES:
				out.append({"kind": &"bones", "cell": above, "base": v})
			elif r < BELLY_BONES + BELLY_LUMPS:
				out.append({"kind": &"stones", "cell": above, "base": v})
		if not solid.has(below) and not occupied.has(below) and bounds.has_point(below):
			var r: float = h(level_seed, v, 2)
			if r < BELLY_TENDRILS:
				out.append({"kind": &"roots", "cell": below, "base": v})
			elif r < BELLY_TENDRILS + BELLY_DRIPS:
				out.append({"kind": &"drip", "cell": below, "base": v})
		# A vein runs through the flesh along an open face.
		var open: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not solid.has(v + d) and bounds.has_point(v + d):
				open.append(d)
		if not open.is_empty() and h(level_seed, v, 5) < BELLY_VEINS:
			out.append({"kind": &"vein", "cell": v, "base": v, "face": open[int(h(level_seed, v, 6) * float(open.size()))]})
	return out


## The belly's decor (plan_belly): the share of floors with bones on them, with lumps of flesh, of
## ceilings with tendrils hanging from them, with drips, and of the flesh along open faces with a
## vein through it.
const BELLY_BONES: float = 0.14
const BELLY_LUMPS: float = 0.1
const BELLY_TENDRILS: float = 0.3
const BELLY_DRIPS: float = 0.12
const BELLY_VEINS: float = 0.35


## Hedges, in the garden: along stretches of floor (as fences are, but dealt on their own) at least
## SHRUB_MIN long, about half of them, in lengths of up to SHRUB_MAX cells with a gap between. Each
## is {kind: shrub_run, cell: its first cell, cells: its cells, base: the rock under the first}.
const SHRUB_MIN: int = 2
const SHRUB_MAX: int = 5


static func shrub_runs(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var floor_at: Callable = func(v: Vector2i) -> bool: return bounds.has_point(v + Vector2i.DOWN) and not solid.has(v) and not occupied.has(v) and solid.has(v + Vector2i.DOWN)
	for y: int in range(bounds.position.y, bounds.end.y):
		var x: int = bounds.position.x
		while x < bounds.end.x:
			if not floor_at.call(Vector2i(x, y)):
				x += 1
				continue
			var from: int = x
			while x < bounds.end.x and floor_at.call(Vector2i(x, y)):
				x += 1
			if x - from < SHRUB_MIN or h(level_seed, Vector2i(from, y), 60) >= 0.5:
				continue
			var at: int = from + int(h(level_seed, Vector2i(from, y), 61) * 2.0)
			while x - at >= SHRUB_MIN:
				var long: int = mini(x - at, SHRUB_MIN + int(h(level_seed, Vector2i(at, y), 62) * float(SHRUB_MAX - SHRUB_MIN + 1)))
				var cells: Array[Vector2i] = []
				for k: int in range(long):
					cells.append(Vector2i(at + k, y))
				out.append({"kind": &"shrub_run", "cell": cells[0], "cells": cells, "base": cells[0] + Vector2i.DOWN})
				at += long + 1
	return out


## Background fences: along stretches of floor (open cells over rock, side by side on one row, none
## holding a structure) at least FENCE_MIN long, about half of them fenced, in lengths of up to
## FENCE_MAX cells with a gap between. Each is {kind: fence_run, cell: its first cell, cells: its
## cells, base: the rock under the first}.
const FENCE_MIN: int = 3
const FENCE_MAX: int = 6


static func fence_runs(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# On rock inside the level (not its outer walls).
	var floor_at: Callable = func(v: Vector2i) -> bool: return bounds.has_point(v + Vector2i.DOWN) and not solid.has(v) and not occupied.has(v) and solid.has(v + Vector2i.DOWN)
	for y: int in range(bounds.position.y, bounds.end.y):
		var x: int = bounds.position.x
		while x < bounds.end.x:
			if not floor_at.call(Vector2i(x, y)):
				x += 1
				continue
			var from: int = x
			while x < bounds.end.x and floor_at.call(Vector2i(x, y)):
				x += 1
			if x - from < FENCE_MIN or h(level_seed, Vector2i(from, y), 50) >= 0.5:
				continue
			# Cut into lengths, leaving a cell's gap between them.
			var at: int = from + int(h(level_seed, Vector2i(from, y), 51) * 2.0)
			while x - at >= FENCE_MIN - 1:
				var long: int = mini(x - at, FENCE_MIN + int(h(level_seed, Vector2i(at, y), 52) * float(FENCE_MAX - FENCE_MIN + 1)))
				var cells: Array[Vector2i] = []
				for k: int in range(long):
					cells.append(Vector2i(at + k, y))
				out.append({"kind": &"fence_run", "cell": cells[0], "cells": cells, "base": cells[0] + Vector2i.DOWN})
				at += long + 1
	return out


## A cemetery's props (see plan). Its crypts (Crypts) are built of dressed stone (`masonry`, as the
## crags' castle is), and inside them (`interiors`) lie only urns, rubble and broken columns on the
## floors and cobwebs under the ceilings: no graves, plants or ivy.
static func plan_cemetery(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, masonry: Dictionary = {}, interiors: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array = solid.keys()
	cells.sort()
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			continue
		var above: Vector2i = v + Vector2i.UP
		var below: Vector2i = v + Vector2i.DOWN
		if masonry.has(v):
			out.append({"kind": &"ashlar", "cell": v, "base": v})
		if interiors.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			var kind: StringName = &""
			if r < 0.14:
				kind = &"urn"
			elif r < 0.3:
				kind = &"rubble"
			elif r < 0.36 and not solid.has(above + Vector2i.UP):
				kind = &"column"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		elif not solid.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			var tall_room: bool = not solid.has(above + Vector2i.UP)
			var kind: StringName = &""
			if r < 0.2:
				kind = &"headstone"
			elif r < 0.26:
				kind = &"cross"
			elif r < 0.29 and tall_room:
				kind = &"obelisk"
			elif r < 0.32:
				kind = &"urn"
			elif r < 0.335 and tall_room:
				kind = &"angel"
			elif r < 0.36 and tall_room:
				kind = &"dead_tree"
			elif r < 0.41:
				kind = &"flowers"
			elif r < 0.6:
				kind = &"tuft"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		if not solid.has(below) and not occupied.has(below):
			var r: float = h(level_seed, v, 2)
			var kind: StringName = &""
			if r < (0.3 if interiors.has(below) else 0.14):
				kind = &"cobweb"
			elif r < 0.3 and not interiors.has(below):
				kind = &"roots"
			if kind != &"":
				out.append({"kind": kind, "cell": below, "base": v})
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var open: Vector2i = v + side
			if solid.has(open) or occupied.has(open) or not solid.has(above) or interiors.has(open):
				continue
			if h(level_seed, v, 3 + side.x) < 0.08:
				out.append({"kind": &"vine", "cell": open, "base": v, "side": side.x})
	return out


## The sky's props (see plan).
static func plan_sky(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, bottom_style: StringName = &"roots") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array = solid.keys()
	cells.sort()
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			continue
		var above: Vector2i = v + Vector2i.UP
		var below: Vector2i = v + Vector2i.DOWN
		if not solid.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			var kind: StringName = &""
			if r < 0.3:
				kind = &"tuft"
			elif r < 0.36:
				kind = &"flowers"
			elif r < 0.41:
				kind = &"stones"
			elif r < 0.47:
				kind = &"cairn"
			elif r < 0.52 and not solid.has(above + Vector2i.UP):
				kind = &"menhir"
			elif r < 0.55 and not solid.has(above + Vector2i.UP):
				kind = &"windsock"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		# Short, scattered roots leave breathing room. Cloud-only bottoms have no hanging props;
		# the mixed version is sparser still. None of this decor has collision.
		if bottom_style != &"clouds" and not solid.has(below) and not occupied.has(below) and bounds.has_point(below):
			var r: float = h(level_seed, v, 2)
			var clearance: int = 0
			for d: int in range(4):
				var at: Vector2i = below + Vector2i(0, d)
				if solid.has(at) or occupied.has(at) or not bounds.has_point(at):
					break
				clearance += 1
			var root_share: float = 0.38 if bottom_style == &"roots" else 0.18
			if r < root_share + 0.08:
				out.append({"kind": &"sky_roots" if r < root_share else &"tendril", "cell": below, "base": v, "clearance": clearance})
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var open: Vector2i = v + side
			if solid.has(open) or occupied.has(open) or not solid.has(above):
				continue
			if h(level_seed, v, 3 + side.x) < 0.06:
				out.append({"kind": &"vine", "cell": open, "base": v, "side": side.x})
	return out


## The institute's plan (see the class description): its halls' marble in slabs (MARBLE_SLAB cells
## square, veined); inside the halls (interiors), great columns from floor to ceiling every
## COLUMN_EVERY cells and between them bookcases as tall as the room (up to BOOKCASE_ROWS cells, up
## through the library's galleries),
## two cells wide where there is room, desks on the steps of the lecture halls' tiers, now and then
## a statue. It is all indoors: the rest of its walls are panelled in wood (PANEL_ROWS cells to a
## panel), and
## in its rooms stand bookcases (BOOKCASE_OUT of the floors), desks (DESK_OUT) and now and then a
## statue; nothing grows and nothing hangs from its ceilings. Its rooms are given over to uses by
## patches (ROOM_USE cells across and down, dealt by the seed, room_use): most are studies, as
## above; a laboratory (LAB_SHARE of the patches) holds alchemy equipment where a study holds desks
## (EQUIPMENT_OUT of the floors) and half the bookcases; a sanctum (SANCTUM_SHARE) holds ritual
## equipment the same way.
const MARBLE_SLAB: int = 2
const COLUMN_EVERY: int = 4
const BOOKCASE_ROWS: int = 8
const BOOKCASE_OUT: float = 0.3
const DESK_OUT: float = 0.14
## How many kinds of desk there are (see the "desk" sketch).
const DESKS: int = 6
## The patches the institute's rooms are given over to a use by (cells across and down), the share
## that are laboratories and sanctums (the rest are studies), how many of their floors hold
## equipment, and how many kinds of ritual equipment there are (the "ritual" sketch).
const ROOM_USE: Vector2i = Vector2i(8, 6)
const LAB_SHARE: float = 0.22
const SANCTUM_SHARE: float = 0.18
const EQUIPMENT_OUT: float = 0.26
const RITUAL: int = 4
## Alchemy equipment is made up from parts, dealt by the cell (_alchemy): what it stands on (a bench
## by ALCHEMY_BENCH, the floor by ALCHEMY_FLOOR, a cabinet by ALCHEMY_CABINET, else a cauldron), and
## on it a row of glass vessels (_glassware), each of one of VESSEL_SHAPES shapes at its own size
## (VESSEL_SIZE, from, to) and filled its own way, some over a burner (BURNER_SHARE) and some joined
## to the next by a glass tube (TUBE_SHARE), at most VESSELS_MOST in a row.
const ALCHEMY_BENCH: float = 0.45
const ALCHEMY_FLOOR: float = 0.2
const ALCHEMY_CABINET: float = 0.2
const VESSEL_SHAPES: int = 6
const VESSEL_SIZE: Vector2 = Vector2(0.7, 1.3)
const BURNER_SHARE: float = 0.35
const TUBE_SHARE: float = 0.4
const VESSELS_MOST: int = 6
## The institute's wooden walls (the "panel" sketch): tall sunk panels a cell wide and PANEL_ROWS
## cells high, in a frame of stiles PANEL_STILE wide and rails PANEL_RAIL high (px, at full size),
## the frame's shadow falling PANEL_SHADOW into each panel.
const PANEL_ROWS: int = 2
const PANEL_STILE: float = 24.0
const PANEL_RAIL: float = 26.0
const PANEL_SHADOW: float = 9.0
## The other wall styles (RisoPrint.wall_style): light planks laid level, PLANKS_TO_A_CELL rows to a
## cell with a seam PLANK_SEAM high under each and an end joint now and then (PLANK_JOINTS of the
## cells in a row), a few lengths a shade darker (PLANK_DARK) and some with a fine grain line; or
## pale stone in courses STONE_COURSES to a cell, blocks a cell long staggered half a block a course,
## joints STONE_JOINT wide, some blocks a shade darker (STONE_DARK). Seams and joints print in the
## stones' shade (slot 13), dark enough to show through the screen of the paler inks.
const PLANKS_TO_A_CELL: int = 4
const PLANK_SEAM: float = 4.0
const PLANK_JOINTS: float = 0.45
const PLANK_DARK: float = 0.3
const STONE_COURSES: int = 2
const STONE_JOINT: float = 4.0
const STONE_DARK: float = 0.35

static func plan_institute(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, _bottom_style: StringName = &"roots", masonry: Dictionary = {}, interiors: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cells: Array = solid.keys()
	cells.sort()
	var taken: Dictionary = {}
	# How many open cells rise over floor cell `v` before the ceiling (at most `most`), none of them
	# holding a structure.
	var room_over: Callable = func(v: Vector2i, most: int) -> int:
		var n: int = 0
		while n < most and not solid.has(v + Vector2i(0, -n)) and not occupied.has(v + Vector2i(0, -n)) and bounds.has_point(v + Vector2i(0, -n)):
			n += 1
		return n
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			# The rock round the level is panelled too, as far as the view goes past the edge.
			if bounds.grow(1).has_point(v):
				out.append({"kind": &"panel", "cell": v, "base": v})
			continue
		var built: bool = masonry.has(v)
		var above: Vector2i = v + Vector2i.UP
		if built:
			out.append({"kind": &"marble", "cell": v, "base": v, "slab": masonry.has(v + Vector2i.RIGHT) and masonry.has(v + Vector2i.DOWN) and masonry.has(v + Vector2i(1, 1)) and posmod(v.x, MARBLE_SLAB) == 0 and posmod(v.y, MARBLE_SLAB) == 0})
		else:
			out.append({"kind": &"panel", "cell": v, "base": v})
		if not solid.has(above) and not occupied.has(above) and not taken.has(above):
			var r: float = h(level_seed, v, 1)
			if built and interiors.has(above):
				var step: bool = (not solid.has(v + Vector2i.LEFT) and interiors.has(v + Vector2i.LEFT)) or (not solid.has(v + Vector2i.RIGHT) and interiors.has(v + Vector2i.RIGHT))
				var high: int = room_over.call(above, 12)
				if step:
					out.append({"kind": &"desk", "cell": above, "base": v})
				elif posmod(v.x + int(h(level_seed, Vector2i(0, v.y), 7) * 4.0), COLUMN_EVERY) == 0 and high >= 2:
					out.append({"kind": &"great_column", "cell": above, "base": v, "rise": high})
				elif r < 0.08 and high >= 2:
					out.append({"kind": &"statue", "cell": above, "base": v})
				else:
					var wide: int = 2 if solid.has(v + Vector2i.RIGHT) and not occupied.has(above + Vector2i.RIGHT) and not solid.has(above + Vector2i.RIGHT) \
							and posmod(v.x + 1 + int(h(level_seed, Vector2i(0, v.y), 7) * 4.0), COLUMN_EVERY) != 0 and h(level_seed, v, 8) < 0.6 else 1
					out.append({"kind": &"bookcase", "cell": above, "base": v, "rise": mini(high, BOOKCASE_ROWS), "wide": wide})
					if wide == 2:
						taken[above + Vector2i.RIGHT] = true
			elif built:
				if r < 0.1 and room_over.call(above, 2) >= 2:
					out.append({"kind": &"statue", "cell": above, "base": v})
			else:
				var high: int = room_over.call(above, 2)
				var use: StringName = room_use(level_seed, above)
				var shelves: float = BOOKCASE_OUT if use == &"desk" else BOOKCASE_OUT * 0.5
				var tables: float = DESK_OUT if use == &"desk" else EQUIPMENT_OUT
				if r < shelves and high >= 1:
					out.append({"kind": &"bookcase", "cell": above, "base": v, "rise": high, "wide": 1})
				elif r < shelves + tables:
					out.append({"kind": use, "cell": above, "base": v})
				elif r < shelves + tables + 0.03 and high >= 2:
					out.append({"kind": &"statue", "cell": above, "base": v})
	return out


## Bookcases standing on the library's gallery over its timetable board (TimetableBoard), up to its
## ceiling, one to a cell, where the board keeps the floor's own bookcases away (see rebuild).
func _over_board(info: MapInfo, solid: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node: Node in info.map_elements.get_children():
		var board: TimetableBoard = node as TimetableBoard
		if board == null or board.is_queued_for_deletion():
			continue
		@warning_ignore("integer_division")
		var reach: int = int(BoardArt.BOARD_W) / 2
		var ledge: int = board.cell.y - Institute.LIBRARY_GROUND
		for dx: int in range(-reach, reach + 1):
			var stand: Vector2i = Vector2i(board.cell.x + dx, ledge - 1)
			var rise: int = 0
			while rise < BOOKCASE_ROWS and not solid.has(stand + Vector2i(0, -rise)):
				rise += 1
			if rise > 0:
				out.append({"kind": &"bookcase", "cell": stand, "base": Vector2i(stand.x, ledge), "rise": rise, "wide": 1})
	return out


## What the institute's room at cell `v` of level `level_seed` is given over to (see ROOM_USE), as
## the kind of thing on its floors: &"alchemy" in a laboratory, &"ritual" in a sanctum, &"desk" in a
## study.
static func room_use(level_seed: int, v: Vector2i) -> StringName:
	var patch: Vector2i = Vector2i(floori(float(v.x) / float(ROOM_USE.x)), floori(float(v.y) / float(ROOM_USE.y)))
	var roll: float = h(level_seed, patch, 120)
	if roll < LAB_SHARE:
		return &"alchemy"
	if roll < LAB_SHARE + SANCTUM_SHARE:
		return &"ritual"
	return &"desk"


## The crags' plan: battlements along the floors of the castle's masonry (fence runs whose rock is
## built), and the props of its stone and its cliffs (see the class description).
static func plan_crags(solid: Dictionary, occupied: Dictionary, level_seed: int, bounds: Rect2i, _bottom_style: StringName = &"roots", masonry: Dictionary = {}, interiors: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: Dictionary in fence_runs(solid, occupied, level_seed, bounds):
		if masonry.has(run["base"]):
			run["battlement"] = true
			out.append(run)
	var cells: Array = solid.keys()
	cells.sort()
	for v: Vector2i in cells:
		if not bounds.has_point(v):
			continue
		var built: bool = masonry.has(v)
		var above: Vector2i = v + Vector2i.UP
		var below: Vector2i = v + Vector2i.DOWN
		if built:
			out.append({"kind": &"ashlar", "cell": v, "base": v})
			# An arrow slit through a wall: masonry over and under, open air to one side, and nothing
			# set beside it (a crossbow's own slit is its art's). "inner" is the side its room is on
			# (-1 left, +1 right, 0 none), "outer" the side open air is on outside it (0 none).
			var left_open: bool = not solid.has(v + Vector2i.LEFT)
			var right_open: bool = not solid.has(v + Vector2i.RIGHT)
			if masonry.has(above) and masonry.has(below) and (left_open or right_open) and not occupied.has(v + Vector2i.LEFT) and not occupied.has(v + Vector2i.RIGHT) and h(level_seed, v, 5) < 0.35:
				var inner: int = 0
				if left_open and interiors.has(v + Vector2i.LEFT):
					inner = -1
				elif right_open and interiors.has(v + Vector2i.RIGHT):
					inner = 1
				var outer: int = 0
				if right_open and inner != 1:
					outer = 1
				elif left_open and inner != -1:
					outer = -1
				out.append({"kind": &"slit", "cell": v, "base": v, "inner": inner, "outer": outer})
		if not solid.has(above) and not occupied.has(above):
			var r: float = h(level_seed, v, 1)
			var tall_room: bool = not solid.has(above + Vector2i.UP)
			var kind: StringName = &""
			if built:
				if r < 0.14 and tall_room:
					kind = &"banner"
				elif r < 0.3:
					kind = &"rubble"
			elif r < 0.28:
				kind = &"tuft"
			elif r < 0.36:
				kind = &"stones"
			elif r < 0.42:
				kind = &"rubble"
			elif r < 0.46 and tall_room:
				kind = &"column"
			if kind != &"":
				out.append({"kind": kind, "cell": above, "base": v})
		if not solid.has(below) and not occupied.has(below):
			var r: float = h(level_seed, v, 2)
			var kind: StringName = &""
			if r < 0.12:
				kind = &"cobweb"
			elif r < 0.2 and not built:
				kind = &"roots"
			elif r < 0.28 and not built:
				kind = &"stalactite"
			if kind != &"":
				out.append({"kind": kind, "cell": below, "base": v})
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var open: Vector2i = v + side
			if built or solid.has(open) or occupied.has(open) or not solid.has(above):
				continue
			if h(level_seed, v, 3 + side.x) < 0.1:
				out.append({"kind": &"vine", "cell": open, "base": v, "side": side.x})
	return out


## Rebuild for the level MapInfo has just laid out.
func rebuild(info: MapInfo, cracked_positions: Array[Vector2] = []) -> void:
	var tm: TileMap = info.tile_map
	half = float(tm.tile_set.tile_size.x) * tm.global_scale.x * 0.5
	var solid: Dictionary = {}
	for v: Vector2i in tm.get_used_cells(0):
		solid[v] = true
	for p: Vector2 in cracked_positions:
		solid[info.cell_at(p)] = true
	var occupied: Dictionary = {}
	for node: Node in info.map_elements.get_children():
		if not (node is Node2D) or node.is_queued_for_deletion():
			continue
		# Only structures keep decor away; plants can grow under a floating star or beside a wisp.
		# Decor is background: it never stands on or beside one, so nothing of it shows through
		# or over a structure.
		var file: String = node.scene_file_path.get_file()
		if not file in STRUCTURES:
			continue
		var c: Vector2i = node.get_meta(&"cell", info.cell_at((node as Node2D).global_position))
		occupied[c] = true
		occupied[c + Vector2i.LEFT] = true
		occupied[c + Vector2i.RIGHT] = true
		# Tall things (exits, shrines, lanterns, doors, bells) keep a wider stretch clear.
		if file in TALL:
			for d: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(3, 0)]:
				occupied[c + d] = true
		# The library's timetable board keeps its own stretch of wall clear, floor to gallery (BoardArt).
		if file == "timetable_board.tscn":
			@warning_ignore("integer_division")
			var reach: int = int(BoardArt.BOARD_W) / 2
			for dx: int in range(-reach, reach + 1):
				for dy: int in range(0, Institute.LIBRARY_GROUND + 1):
					occupied[c + Vector2i(dx, -dy)] = true
	# A sky temple is dressed by its own art (TempleArt): no decor on it, in it or over it.
	for temple: Dictionary in info.world.temples:
		var box: Rect2i = (temple["box"] as Rect2i).grow(1)
		for x: int in range(box.position.x, box.end.x):
			for y: int in range(box.position.y - SkyArchetype.TEMPLE_AIR, box.end.y + 1):
				occupied[Vector2i(x, y)] = true
	var level_seed: int = Rules.level_seed(info.coord.x, info.coord.y)
	var bottoms: StringName = RisoPrint.instance.sky_bottom_style if RisoPrint.instance != null else &"roots"
	items = RisoDecor.plan(solid, occupied, level_seed, Rect2i(Vector2i.ZERO, info.world.size), info.here.decor(), bottoms, info.world.masonry, info.world.interiors)
	items.append_array(_over_board(info, solid))
	# Nothing grows in some side worlds (NextWorldDef.grows).
	if not info.here.grows():
		items.clear()
	_solid = solid
	firefly_spots = PackedVector2Array()
	drip_spots = PackedVector2Array()
	drip_ends = PackedFloat32Array()
	var chunks: Dictionary = {}
	swaying.clear()
	for index: int in range(items.size()):
		var item: Dictionary = items[index]
		var v: Vector2i = item["cell"]
		if item["kind"] in SWAY_KINDS:
			var own: Array = _empty_slots()
			var at: Vector2 = tm.to_global(tm.map_to_local(v))
			_draw_item(item, at, own, level_seed)
			var parts: Array = []
			for i: int in range(own.size()):
				for poly: PackedVector2Array in own[i]:
					parts.append([i, poly])
			var hang: bool = item["kind"] in [&"roots", &"vine"]
			item["parts"] = parts
			item["hang"] = hang
			var tall: float = 1.0
			for part: Array in parts:
				for q: Vector2 in part[1]:
					tall = maxf(tall, absf(q.y - (at.y + (-half if hang else half))))
			item["tall"] = tall
			item["anchor"] = Vector2(at.x - float(item.get("side", 0)) * half, at.y + (-half if hang else half))
			item["a"] = 0.0
			item["v"] = 0.0
			swaying.append(index)
			continue
		var key: Vector2i = Vector2i(floori(float(v.x) / CHUNK), floori(float(v.y) / CHUNK))
		if not chunks.has(key):
			chunks[key] = _empty_slots()
		var c: Vector2 = tm.to_global(tm.map_to_local(v))
		_draw_item(item, c, chunks[key], level_seed)
	for canvas: InkCanvas in canvases:
		canvas.queue_free()
	canvases.clear()
	for key: Vector2i in chunks:
		# Hedges at the back, fences in front of them, then the rest of the decor.
		for layer: int in [LAYER_HEDGE, LAYER_BACK, LAYER_FRONT]:
			var canvas: InkCanvas = InkCanvas.new()
			add_child(canvas)
			canvas.z_index = layer - LAYER_FRONT
			canvases.append(canvas)
			canvas.begin()
			_print_slots(canvas, chunks[key], layer)
			canvas.finish()


func _empty_slots() -> Array:
	var slots: Array = []
	for i: int in range(SLOTS.size()):
		var polys: Array[PackedVector2Array] = []
		slots.append(polys)
	return slots


## The decor's layers, back to front: hedges (HEDGE_SLOTS), fences (BACK_SLOTS), the rest.
const LAYER_HEDGE: int = 0
const LAYER_BACK: int = 1
const LAYER_FRONT: int = 2


## The layer slot `i` prints on.
static func layer_of(i: int) -> int:
	if i in HEDGE_SLOTS:
		return LAYER_HEDGE
	return LAYER_BACK if i in BACK_SLOTS else LAYER_FRONT


## Print the slots of `layer` into `canvas`.
func _print_slots(canvas: InkCanvas, slots: Array, layer: int = LAYER_FRONT) -> void:
	for i: int in range(SLOTS.size()):
		var polys: Array[PackedVector2Array] = slots[i]
		if polys.is_empty() or layer_of(i) != layer:
			continue
		var slot: Array = SLOTS[i]
		if bool(slot[2]) and float(slot[1]) < 1.0:
			# Lifted, not cleared: lighter, the paper showing through a little.
			canvas.lift_ink(MORTAR_LIFT, float(slot[1]), polys)
		elif bool(slot[2]):
			canvas.knock(KNOCK_ALL if i in [8, 14, 15, 37] else KNOCK_ROCK, polys)
		else:
			canvas.ink(int(slot[0]), float(slot[1]), polys, bool(slot[3]))


## A pile of flat stones on the floor at `x`, `k` its scale: three to five, each smaller than the
## one under it, shaded down one side. Its top (the y of its highest stone) comes back, where a line
## of flags ties on. `back` prints it on the background layer with its flags.
func _cairn(slots: Array, x: float, floor_y: float, k: float, s: int, v: Vector2i, back: bool) -> float:
	var y: float = floor_y + 1.0
	var w: float = (15.0 + _r(s, v, 40) * 5.0) * k
	for i: int in range(4 + int(_r(s, v, 41) * 3.0)):
		var h: float = w * (0.38 + 0.1 * _r(s, v, 50 + i))
		var at: Vector2 = Vector2(x + (_r(s, v, 60 + i) - 0.5) * 2.0 * k, y - h * 0.5)
		var stone: PackedVector2Array = RisoShapes.ellipse(at, w * 0.5, h * 0.5, 14)
		slots[20 if back else 12].append(stone)
		slots[17 if back else 13].append(RisoShapes.ellipse(at + Vector2(w * 0.18, h * 0.1), w * 0.3, h * 0.36, 10))
		y -= h * 0.85
		w *= 0.78
	return y


## How far a plant leans at `anchor` (radians-ish shear), for tests and drawing.
func lean(index: int) -> float:
	return float(items[index].get("a", 0.0))


func _process(delta: float) -> void:
	t += delta
	live.begin()
	var cam: Camera2D = get_viewport().get_camera_2d()
	var player: Player = Stage.player()
	if cam == null or swaying.is_empty():
		live.finish()
		return
	var view: Rect2 = RisoLight.view_rect(self, cam).grow(200.0)
	var slots: Array = _empty_slots()
	var dt: float = minf(delta, 0.05)
	var breeze_t: float = floorf(t * BREEZE_RATE) / BREEZE_RATE
	for index: int in swaying:
		var item: Dictionary = items[index]
		var anchor: Vector2 = item["anchor"]
		if not view.has_point(anchor):
			continue
		var hang: bool = item["hang"]
		# The push: away from the wizard, and along with them, while they brush past.
		var target: float = 0.0
		if player != null:
			var reach_y: float = anchor.y + (90.0 if hang else -70.0)
			var dx: float = anchor.x - player.global_position.x
			var close: float = clampf(1.0 - absf(dx) / 130.0, 0.0, 1.0) * clampf(1.0 - absf(player.global_position.y - reach_y) / 130.0, 0.0, 1.0)
			if close > 0.0:
				# Leans away from the wizard, and is swept along the way they are going.
				var away: float = signf(dx) * (1.0 if not hang else -1.0)
				var sweep: float = clampf(player.velocity.x / 300.0, -1.0, 1.0) * (1.0 if not hang else -1.0)
				target = clampf(away * 0.16 + sweep * 0.2, -0.3, 0.3) * sqrt(close)
		var a: float = item["a"]
		var v: float = item["v"]
		# A light spring: brushed aside, it eases back with a small wobble.
		v += ((target - a) * 30.0 - v * 6.5) * dt
		a += v * dt
		item["a"] = a
		item["v"] = v
		var bend: float = a + sin(breeze_t * 1.3 + anchor.x * 0.013) * 0.03
		if not item.has("bent") or absf(bend - float(item["bent_at"])) >= BEND_STEP:
			item["bent_at"] = bend
			item["bent"] = _bent(item, anchor, -bend if hang else bend)
		for part: Array in item["bent"]:
			(slots[int(part[0])] as Array[PackedVector2Array]).append(part[1])
	_print_slots(live, slots)
	live.finish()


## A swaying plant's parts ([slot, outline]) bent `turn` about its root. Bend, don't skew: each point
## turns about the root by an angle that grows along the plant, so stems curve and keep their
## length, and heads tilt with their tips.
func _bent(item: Dictionary, anchor: Vector2, turn: float) -> Array:
	var tall: float = item["tall"]
	var out: Array = []
	for part: Array in item["parts"]:
		var poly: PackedVector2Array = part[1]
		var bent: PackedVector2Array = PackedVector2Array()
		bent.resize(poly.size())
		for k: int in range(poly.size()):
			var p: Vector2 = poly[k]
			var f: float = clampf(absf(p.y - anchor.y) / tall, 0.0, 1.0)
			bent[k] = anchor + (p - anchor).rotated(turn * f * (2.0 - f))
		out.append([part[0], bent])
	return out


# ------------------------------------------------------------------ the props

## A book `poly` inked in one of the institute's book colours, picked by `roll` (0 to 1), on bare
## paper: brown, moss, maroon, night, tan, plum or paper.
func _book_ink(slots: Array, poly: PackedVector2Array, roll: float) -> void:
	# On bare paper, so its colour prints true over the case.
	slots[14].append(poly)
	if roll < 0.2:
		slots[30].append(poly)
	elif roll < 0.36:
		slots[30].append(poly)
		slots[31].append(poly)
	elif roll < 0.54:
		slots[30].append(poly)
		slots[32].append(poly)
	elif roll < 0.66:
		slots[33].append(poly)
	elif roll < 0.8:
		slots[34].append(poly)
	elif roll < 0.9:
		slots[34].append(poly)
		slots[35].append(poly)
	else:
		slots[37].append(poly)


## A book lying open on a desk at `at` (the middle of its spine), each page `w` long, the whole
## turned `tilt` radians: two paper pages, a night line or two on each.
func _open_book(slots: Array, at: Vector2, w: float, tilt: float) -> void:
	var xf: Transform2D = Transform2D(tilt, at)
	slots[33].append(xf * PackedVector2Array([Vector2(-w - 0.8, 0.8), Vector2(w + 0.8, 0.8), Vector2(w + 0.8, -1.2), Vector2(-w - 0.8, -1.2)]))
	slots[37].append(xf * PackedVector2Array([Vector2(-w, 0.0), Vector2(0, 0.0), Vector2(0, -2.6), Vector2(-w, -2.0)]))
	slots[37].append(xf * PackedVector2Array([Vector2(0, 0.0), Vector2(w, 0.0), Vector2(w, -2.0), Vector2(0, -2.6)]))
	for side: float in [-1.0, 1.0]:
		slots[36].append(xf * RisoShapes.rrect(side * w * 0.55 - w * 0.3, -1.6, w * 0.6, 0.35, 0.1))


## A stack of `n` books lying flat, its bottom middle at `at`, each its own size and colour (dealt by
## the cell `v` of level `s`), a little askew.
func _book_stack(slots: Array, at: Vector2, n: int, s: int, v: Vector2i) -> void:
	var y: float = at.y
	for k: int in range(n):
		var w: float = 8.0 + _r(s, v, 120 + k) * 4.0
		var h: float = 1.8 + _r(s, v, 125 + k) * 0.8
		var shift: float = (_r(s, v, 130 + k) - 0.5) * 3.0
		_book_ink(slots, Transform2D((_r(s, v, 135 + k) - 0.5) * 0.08, Vector2(at.x + shift, y - h * 0.5)) * RisoShapes.rrect(-w * 0.5, -h * 0.5, w, h, 0.0), _r(s, v, 140 + k))
		y -= h + 0.2


## Alchemy equipment standing at `x` on the floor at `floor_y`, made up from parts dealt by the cell
## `v` of level `s` (see ALCHEMY_BENCH): a bench (its width and height dealt, a low shelf under it
## now and then) with a row of glassware on it (_glassware) and sometimes more on the shelf; a row
## of glassware standing on the floor; a small open cabinet of two or three shelves of jars and
## vials; or an iron cauldron on three legs, its size dealt, bubbling, a ladle in it, now and then a
## stool beside it with a vessel or two. Wood and iron are in the decor's inks, glass bare paper.
func _alchemy(x: float, floor_y: float, slots: Array, s: int, v: Vector2i) -> void:
	var wood: Array = slots[12]
	var shade: Array = slots[13]
	var roll: float = _r(s, v, 13)
	if roll < ALCHEMY_BENCH:
		var w: float = 28.0 + _r(s, v, 14) * 18.0
		var tall: float = 14.0 + _r(s, v, 15) * 6.0
		var top: float = floor_y - tall
		wood.append(RisoShapes.rrect(x - w * 0.5, top, w, 3.0, 0.8))
		for side: float in [-1.0, 1.0]:
			wood.append(RisoShapes.rrect(x + side * (w * 0.5 - 2.5) - 1.2, top + 2.0, 2.4, tall - 1.0, 0.6))
		shade.append(RisoShapes.rrect(x - w * 0.5, top + 2.5, w, 1.5, 0.5))
		if _r(s, v, 16) < 0.5:
			var low: float = floor_y - tall * 0.35
			wood.append(RisoShapes.rrect(x - w * 0.5 + 2.5, low, w - 5.0, 1.5, 0.4))
			_glassware(slots, x - w * 0.5 + 4.0, x + w * 0.5 - 4.0, low, top + 2.0 - low, s, v, 300, false)
		_glassware(slots, x - w * 0.5 + 2.0, x + w * 0.5 - 2.0, top, 26.0, s, v, 100, true)
	elif roll < ALCHEMY_BENCH + ALCHEMY_FLOOR:
		_glassware(slots, x - 16.0, x + 16.0, floor_y, 30.0, s, v, 100, true)
	elif roll < ALCHEMY_BENCH + ALCHEMY_FLOOR + ALCHEMY_CABINET:
		var w: float = 20.0 + _r(s, v, 14) * 8.0
		var shelves: int = 2 + int(_r(s, v, 15) * 2.0)
		var tall: float = float(shelves) * 12.0 + 4.0
		wood.append(RisoShapes.rrect(x - w * 0.5, floor_y - tall, w, tall, 1.0))
		shade.append(RisoShapes.rrect(x - w * 0.5 + 2.0, floor_y - tall + 2.0, w - 4.0, tall - 4.0, 0.6))
		for k: int in range(shelves):
			var shelf: float = floor_y - 2.0 - float(k) * 12.0
			wood.append(RisoShapes.rrect(x - w * 0.5 + 2.0, shelf - 1.5, w - 4.0, 1.5, 0.3))
			_glassware(slots, x - w * 0.5 + 3.0, x + w * 0.5 - 3.0, shelf - 1.5, 9.5, s, v, 100 + k * 60, false)
	else:
		var k: float = 0.8 + _r(s, v, 14) * 0.4
		for lx: float in [-10.0, 0.0, 10.0]:
			slots[33].append(RisoShapes.rrect(x + lx * k - 1.2, floor_y - 5.0, 2.4, 5.0, 0.6))
		slots[33].append(RisoShapes.smooth(PackedVector2Array([Vector2(x - 15.0 * k, floor_y - 4.0 - 18.0 * k), Vector2(x + 15.0 * k, floor_y - 4.0 - 18.0 * k), Vector2(x + 14.0 * k, floor_y - 4.0 - 7.0 * k), Vector2(x + 8.0 * k, floor_y - 4.0), Vector2(x - 8.0 * k, floor_y - 4.0), Vector2(x - 14.0 * k, floor_y - 4.0 - 7.0 * k)]), 2))
		var rim: float = floor_y - 4.0 - 18.0 * k
		_brew(slots, [RisoShapes.ellipse(Vector2(x, rim), 13.5 * k, 2.4, 18)], _r(s, v, 15) * 0.75)
		for i: int in range(2 + int(_r(s, v, 16) * 3.0)):
			var b: Vector2 = Vector2(x + (_r(s, v, 20 + i) - 0.5) * 20.0 * k, rim - 2.0 - _r(s, v, 25 + i) * 7.0)
			slots[37].append(RisoShapes.circle(b, 0.8 + _r(s, v, 30 + i) * 1.4, 8))
		wood.append(Transform2D(0.3 + _r(s, v, 17) * 0.5, Vector2(x + 8.0 * k, rim)) * RisoShapes.rrect(-0.9, -14.0, 1.8, 16.0, 0.6))
		if _r(s, v, 18) < 0.5:
			var side: float = 1.0 if _r(s, v, 19) < 0.5 else -1.0
			var sx: float = x + side * (15.0 * k + 9.0)
			wood.append(RisoShapes.rrect(sx - 5.0, floor_y - 9.0, 10.0, 2.0, 0.6))
			for lx: float in [-4.0, 3.0]:
				wood.append(RisoShapes.rrect(sx + lx, floor_y - 7.5, 1.4, 7.5, 0.4))
			_glassware(slots, sx - 4.5, sx + 4.5, floor_y - 9.0, 14.0, s, v, 200, false)


## A row of glass vessels standing on the line at `base_y` from `x0` to `x1`, none taller than
## `room`, dealt by the cell `v` of level `s` from salt `salt` on: each of one of VESSEL_SHAPES
## shapes (_vessel) at its own size and fill, set a little apart. Where `rich` (a bench or the floor,
## not a shelf), some stand over a burner, a little tripod over a candle (BURNER_SHARE), some are
## joined to the next by a glass tube arching between their mouths (TUBE_SHARE), and a full one
## now and then bubbles.
func _glassware(slots: Array, x0: float, x1: float, base_y: float, room: float, s: int, v: Vector2i, salt: int, rich: bool) -> void:
	var at: float = x0 + _r(s, v, salt) * 2.0
	var mouths: Array[Vector2] = []
	var tubed: Array[bool] = []
	for k: int in range(VESSELS_MOST):
		var q: int = salt + 1 + k * 9
		var shape: int = int(_r(s, v, q) * float(VESSEL_SHAPES)) % VESSEL_SHAPES
		var size: float = lerpf(VESSEL_SIZE.x, VESSEL_SIZE.y, _r(s, v, q + 1))
		var burner: bool = rich and shape != 4 and _r(s, v, q + 2) < BURNER_SHARE
		var lift: float = 7.0 if burner else 0.0
		size = minf(size, (room - lift) / _vessel_tall(shape))
		if size < 0.45:
			continue
		var wide: float = _vessel_wide(shape) * size
		if burner:
			wide = maxf(wide, 12.0)
		if at + wide > x1:
			break
		var base: Vector2 = Vector2(at + wide * 0.5, base_y)
		if burner:
			for lx: float in [-1.0, 1.0]:
				slots[33].append_array(strip(PackedVector2Array([base + Vector2(lx * 2.5, -lift), base + Vector2(lx * 5.5, 0.0)]), 1.0, 1.0))
			slots[33].append(RisoShapes.rrect(base.x - 5.0, base.y - lift - 1.0, 10.0, 1.2, 0.4))
			_candle(slots, base, 2.5)
		var fill: float = 0.2 + _r(s, v, q + 3) * 0.7
		var mouth: Vector2 = _vessel(slots, shape, base + Vector2(0, -lift), size, fill, _r(s, v, q + 4))
		mouths.append(mouth)
		tubed.append(rich and shape != 4 and _r(s, v, q + 5) < TUBE_SHARE)
		if fill > 0.75 and _r(s, v, q + 6) < 0.5:
			for i: int in range(2):
				slots[37].append(RisoShapes.circle(mouth + Vector2((_r(s, v, q + 7 + i) - 0.5) * 3.0, -2.5 - float(i) * 3.0), 0.7 + float(i) * 0.3, 8))
		at += wide + 1.0 + _r(s, v, q + 8) * 2.5
	for i: int in range(mouths.size() - 1):
		if not tubed[i]:
			continue
		var a: Vector2 = mouths[i]
		var b: Vector2 = mouths[i + 1]
		var up: float = minf(a.y, b.y) - 4.0 - absf(b.x - a.x) * 0.2
		slots[14].append_array(strip(RisoShapes.smooth_open(PackedVector2Array([a, Vector2(lerpf(a.x, b.x, 0.25), up), Vector2(lerpf(a.x, b.x, 0.75), up), b]), 3), 1.5, 1.2))


## How wide a vessel of shape `shape` is at size 1 (see _vessel).
func _vessel_wide(shape: int) -> float:
	return [10.0, 10.0, 6.6, 9.0, 2.6, 7.2][shape]


## How tall a vessel of shape `shape` is at size 1, to its mouth (see _vessel).
func _vessel_tall(shape: int) -> float:
	return [14.5, 14.0, 10.0, 17.0, 11.5, 18.5][shape]


## A glass vessel of shape `shape` standing at `base`, `size` times its usual size, filled `fill` of
## the way up its body with a brew of a colour picked by `roll` (_brew): a round flask with a neck, a
## conical flask, a beaker with a lip, a gourd of two bulbs, a stoppered vial, or a small flask with
## a long neck. Glass is bare paper; the brew is cut to the glass's inside. Returns its mouth.
func _vessel(slots: Array, shape: int, base: Vector2, size: float, fill: float, roll: float) -> Vector2:
	var body: Array[PackedVector2Array] = []
	var glass: Array[PackedVector2Array] = []
	var mouth: Vector2 = base
	var body_tall: float = 0.0
	match shape:
		0:
			var r: float = 5.0 * size
			var c: Vector2 = base + Vector2(0, -r)
			body.append(RisoShapes.circle(c, r, 18))
			glass.append(RisoShapes.rrect(c.x - r * 0.3, c.y - r * 1.9, r * 0.6, r * 1.1, 0.4))
			mouth = Vector2(c.x, c.y - r * 1.9)
			body_tall = r * 2.0
		1:
			var b: float = 5.0 * size
			var h: float = 9.0 * size
			var n: float = 1.4 * size
			body.append(PackedVector2Array([base + Vector2(-b, 0), base + Vector2(b, 0), base + Vector2(n, -h), base + Vector2(-n, -h)]))
			glass.append(RisoShapes.rrect(base.x - n, base.y - h - 5.0 * size, n * 2.0, 5.0 * size + 0.5, 0.3))
			mouth = base + Vector2(0, -h - 5.0 * size)
			body_tall = h
		2:
			var w: float = 3.0 * size
			var h: float = 9.5 * size
			body.append(RisoShapes.rrect(base.x - w, base.y - h, w * 2.0, h, 0.8))
			glass.append(RisoShapes.rrect(base.x - w - 0.6, base.y - h, w * 2.0 + 1.2, 1.0, 0.3))
			mouth = base + Vector2(0, -h)
			body_tall = h
		3:
			var r1: float = 4.5 * size
			var r2: float = 2.8 * size
			var c1: Vector2 = base + Vector2(0, -r1)
			var c2: Vector2 = c1 + Vector2(0, -r1 - r2 * 0.6)
			body.append(RisoShapes.circle(c1, r1, 18))
			glass.append(RisoShapes.circle(c2, r2, 14))
			glass.append(RisoShapes.rrect(c2.x - r2 * 0.35, c2.y - r2 * 1.9, r2 * 0.7, r2 * 1.1, 0.3))
			mouth = Vector2(c2.x, c2.y - r2 * 1.9)
			body_tall = r1 * 2.0
		4:
			var w: float = 1.3 * size
			var h: float = 10.0 * size
			body.append(RisoShapes.rrect(base.x - w, base.y - h, w * 2.0, h, w))
			slots[33].append(RisoShapes.rrect(base.x - w * 0.8, base.y - h - 1.5 * size, w * 1.6, 2.0 * size, 0.4))
			mouth = base + Vector2(0, -h - 1.5 * size)
			body_tall = h
		_:
			var r: float = 3.6 * size
			var c: Vector2 = base + Vector2(0, -r)
			body.append(RisoShapes.circle(c, r, 16))
			glass.append(RisoShapes.rrect(c.x - r * 0.22, c.y - r - 11.0 * size, r * 0.44, 11.0 * size + 0.5, 0.3))
			mouth = Vector2(c.x, c.y - r - 11.0 * size)
			body_tall = r * 2.0
	slots[14].append_array(body)
	slots[14].append_array(glass)
	var level: float = base.y - body_tall * fill
	var below: PackedVector2Array = RisoShapes.rrect(base.x - 40.0, level, 80.0, base.y - level + 2.0, 0.0)
	var brew: Array = []
	for poly: PackedVector2Array in body:
		for inside: PackedVector2Array in Geometry2D.offset_polygon(poly, -0.7):
			brew.append_array(Geometry2D.intersect_polygons(inside, below))
	_brew(slots, brew, roll)
	return mouth


## Ritual equipment of kind `kind` (one of RITUAL), standing at `x` on the floor at `floor_y`, dealt
## by the cell `v` of level `s`: a tall candelabra of three or five candles; an altar under a cloth with a skull and two
## candles; a brazier on a tripod, its smoke curling up; or a standing tablet carved with a star in a
## circle. Candles and bone are bare paper, stone, wood and iron in the decor's inks; no flame
## is lit in gold, as gold is for rewards.
func _ritual(kind: int, x: float, floor_y: float, slots: Array, s: int, v: Vector2i) -> void:
	var wood: Array = slots[12]
	var shade: Array = slots[13]
	match kind:
		0:
			@warning_ignore("integer_division")
			var side: int = (3 if _r(s, v, 13) < 0.5 else 5) / 2
			slots[33].append(RisoShapes.rrect(x - 6.0, floor_y - 2.0, 12.0, 2.0, 0.8))
			slots[33].append(RisoShapes.rrect(x - 1.0, floor_y - 30.0, 2.0, 29.0, 0.6))
			slots[33].append(RisoShapes.ellipse(Vector2(x, floor_y - 14.0), 2.4, 2.0, 10))
			for k: int in range(-side, side + 1):
				var tip: Vector2 = Vector2(x + float(k) * 6.0, floor_y - 31.0 + absf(float(k)) * 1.5)
				if k != 0:
					slots[33].append_array(strip(PackedVector2Array([Vector2(x, floor_y - 25.0), Vector2(x + float(k) * 4.0, floor_y - 25.0), tip]), 1.4, 1.2))
				slots[33].append(RisoShapes.rrect(tip.x - 2.0, tip.y - 1.0, 4.0, 1.4, 0.5))
				_candle(slots, tip + Vector2(0, -1.0), 5.0 + _r(s, v, 20 + k + side) * 3.0)
		1:
			wood.append(RisoShapes.rrect(x - 13.0, floor_y - 16.0, 26.0, 16.0, 0.8))
			shade.append(RisoShapes.rrect(x + 5.0, floor_y - 16.0, 8.0, 16.0, 0.8))
			# A cloth over it, hanging down at its ends.
			slots[37].append(PackedVector2Array([Vector2(x - 14.0, floor_y - 16.5), Vector2(x + 14.0, floor_y - 16.5), Vector2(x + 14.0, floor_y - 9.0), Vector2(x + 11.0, floor_y - 7.0), Vector2(x + 10.0, floor_y - 15.0), Vector2(x - 10.0, floor_y - 15.0), Vector2(x - 11.0, floor_y - 7.0), Vector2(x - 14.0, floor_y - 9.0)]))
			var skull: Vector2 = Vector2(x, floor_y - 22.0)
			slots[37].append(RisoShapes.circle(skull, 4.6, 14))
			slots[37].append(RisoShapes.rrect(skull.x - 2.6, skull.y + 2.0, 5.2, 3.6, 1.0))
			for ex: float in [-1.8, 1.8]:
				slots[33].append(RisoShapes.circle(skull + Vector2(ex, 0.2), 1.2, 8))
			slots[33].append(RisoShapes.rrect(skull.x - 0.4, skull.y + 1.8, 0.8, 1.4, 0.3))
			for k: int in range(2):
				_candle(slots, Vector2(x - 10.0 + float(k) * 20.0, floor_y - 16.5), 6.0 + _r(s, v, 20 + k) * 3.0)
		2:
			for lx: float in [-1.0, 1.0]:
				slots[33].append(PackedVector2Array([Vector2(x + lx * 2.0, floor_y - 13.0), Vector2(x + lx * 3.4, floor_y - 13.0), Vector2(x + lx * 9.0, floor_y), Vector2(x + lx * 7.6, floor_y)]))
			slots[33].append(RisoShapes.rrect(x - 0.8, floor_y - 13.0, 1.6, 13.0, 0.4))
			slots[33].append(PackedVector2Array([Vector2(x - 11.0, floor_y - 19.0), Vector2(x + 11.0, floor_y - 19.0), Vector2(x + 7.0, floor_y - 13.0), Vector2(x - 7.0, floor_y - 13.0)]))
			shade.append(RisoShapes.rrect(x - 10.0, floor_y - 19.0, 20.0, 1.4, 0.5))
			for k: int in range(2):
				var sx: float = x - 3.0 + float(k) * 6.0
				var smoke: PackedVector2Array = PackedVector2Array()
				for j: int in range(6):
					smoke.append(Vector2(sx + sin(float(j) * 1.3 + _r(s, v, 13 + k) * 6.0) * 3.0, floor_y - 20.0 - float(j) * 5.0))
				slots[5].append_array(strip(smoke, 3.0, 0.6))
		_:
			wood.append(RisoShapes.rrect(x - 8.0, floor_y - 3.0, 16.0, 3.0, 0.8))
			wood.append(RisoShapes.smooth(PackedVector2Array([Vector2(x - 9.0, floor_y - 3.0), Vector2(x - 9.0, floor_y - 26.0), Vector2(x - 5.0, floor_y - 31.0), Vector2(x + 5.0, floor_y - 31.0), Vector2(x + 9.0, floor_y - 26.0), Vector2(x + 9.0, floor_y - 3.0)]), 2))
			shade.append(RisoShapes.rrect(x + 4.0, floor_y - 27.0, 5.0, 24.0, 1.0))
			# Carved in it, a star in a circle.
			var at: Vector2 = Vector2(x, floor_y - 17.0)
			for half_ring: PackedVector2Array in RisoShapes.ring(at, 6.2, 7.0, 24):
				slots[37].append(half_ring)
			var points: Array[Vector2] = []
			for k: int in range(5):
				points.append(at + Vector2.from_angle(-PI * 0.5 + TAU * float(k) / 5.0) * 6.2)
			for k: int in range(5):
				slots[37].append_array(strip(PackedVector2Array([points[k], points[(k + 2) % 5]]), 0.7, 0.7))


## A brew (`polys`) in one of the alchemists' colours, picked by `roll` (0 to 1): brown, tan or
## night (never the accent, which the institute prints in gold, kept for rewards); over the glass's
## bare paper, so it prints true.
func _brew(slots: Array, polys: Array, roll: float) -> void:
	for poly: PackedVector2Array in polys:
		if roll < 0.4:
			slots[30].append(poly)
		elif roll < 0.72:
			slots[34].append(poly)
		else:
			slots[33].append(poly)


## A candle standing at `base`, `tall` high: bare paper, a night wick and a small paper flame (no
## gold: the institute's candles are not rewards).
func _candle(slots: Array, base: Vector2, tall: float) -> void:
	slots[37].append(RisoShapes.rrect(base.x - 1.4, base.y - tall, 2.8, tall, 0.6))
	slots[33].append(RisoShapes.rrect(base.x - 0.3, base.y - tall - 1.4, 0.6, 1.6, 0.2))
	slots[37].append(Transform2D(PI * 0.5, base + Vector2(0, -tall - 3.6)) * RisoShapes.almond(Vector2.ZERO, 2.2, 1.1))


func _r(level_seed: int, v: Vector2i, salt: int) -> float:
	var x: int = ((level_seed ^ (salt * 2654435)) * 73856093) ^ ((v.x * 7919 + v.y * 104729 + salt) * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 15)) * 0x2c1b3c6d
	x = (x ^ (x >> 12)) * 0x297a2d39
	x = (x ^ (x >> 15)) & 0x7fffffff
	return float(x % 100000) / 100000.0


## A bent strip from `a` along `pts`, `w0` wide at the start tapering to `w1`.
static func strip(pts: PackedVector2Array, w0: float, w1: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) < 0.5:
			continue
		var n: Vector2 = (b - a).normalized().orthogonal()
		var wa: float = lerpf(w0, w1, float(i) / float(pts.size() - 1)) * 0.5
		var wb: float = lerpf(w0, w1, float(i + 1) / float(pts.size() - 1)) * 0.5
		out.append(PackedVector2Array([a - n * wa, b - n * wb, b + n * wb, a + n * wa]))
	return out


## Props on floors, ceilings and walls are drawn at a sketch size, then grown by PROP_SCALE
## around where they grow from, so they read next to the wizard.
const PROP_SCALE: float = 2.0
## A cobweb's lines as they come out on screen, grown by PROP_SCALE, which the spider's webs share
## whatever their size (Spider.plain_web): its rings this far apart (px), its spokes this far apart
## at its outer ring, its spokes this wide where they are tied (thinning to WEB_TIP of that) and its
## rings this wide.
const WEB_RING_GAP: float = 0.35 * WEB_REACH * PROP_SCALE
const WEB_SPOKE_GAP: float = 0.8 * WEB_REACH * WEB_TURN * PROP_SCALE
const WEB_W: float = 1.0 * PROP_SCALE
const WEB_TIP: float = 0.6
const WEB_RING_W: float = 0.8 * PROP_SCALE


func _draw_item(item: Dictionary, c: Vector2, slots: Array, s: int) -> void:
	var before: Array[int] = []
	for slot: Array in slots:
		before.append(slot.size())
	_sketch_item(item, c, slots, s)
	var anchor: Variant = null
	match item["kind"]:
		&"tuft", &"leafy", &"mushroom", &"stones", &"bones", &"headstone", &"cross", &"fence", &"dead_tree", &"obelisk", &"urn", &"angel", &"flowers", &"windsock", &"cairn", &"menhir", &"banner", &"rubble", &"column", &"bookcase", &"desk", &"statue", &"great_column", &"alchemy", &"ritual":
			anchor = Vector2(c.x, c.y + half)
		&"roots", &"sky_roots", &"stalactite", &"drip", &"cobweb", &"tendril":
			anchor = Vector2(c.x, c.y - half)
		&"vine":
			anchor = Vector2(c.x - float(item["side"]) * half, c.y - half)
	if anchor == null:
		return
	var grow: Transform2D = Transform2D(0.0, Vector2(PROP_SCALE, PROP_SCALE), 0.0, anchor) * Transform2D(0.0, -(anchor as Vector2))
	for i: int in range(slots.size()):
		var slot: Array = slots[i]
		for j: int in range(before[i], slot.size()):
			slot[j] = grow * (slot[j] as PackedVector2Array)
	# Spots for ambient life move with their props.
	if item["kind"] == &"drip" and not drip_spots.is_empty():
		drip_spots[drip_spots.size() - 1] = grow * drip_spots[drip_spots.size() - 1]
	if item["kind"] == &"tuft" and not firefly_spots.is_empty():
		firefly_spots[firefly_spots.size() - 1] = grow * firefly_spots[firefly_spots.size() - 1]


## A cell of the institute's walls as light planks laid level (see PLANKS_TO_A_CELL): a seam under
## each row, an end joint where the seed puts one, a few lengths a faint shade darker, some with a
## fine grain line along them.
func _planks(v: Vector2i, c: Vector2, slots: Array, s: int) -> void:
	var tall: float = half * 2.0 / float(PLANKS_TO_A_CELL)
	for row: int in range(PLANKS_TO_A_CELL):
		var y0: float = c.y - half + float(row) * tall
		var course: Vector2i = Vector2i(v.x, v.y * PLANKS_TO_A_CELL + row)
		var cuts: Array[float] = [c.x - half]
		if _r(s, course, 93) < PLANK_JOINTS:
			cuts.append(c.x - half + (0.15 + 0.7 * _r(s, course, 94)) * half * 2.0)
		cuts.append(c.x + half)
		for k: int in range(cuts.size() - 1):
			var piece: Vector2i = Vector2i(course.x * 2 + k, course.y)
			if _r(s, piece, 95) < PLANK_DARK:
				slots[27].append(RisoShapes.rrect(cuts[k], y0, cuts[k + 1] - cuts[k], tall, 0.0))
			if _r(s, piece, 96) < 0.4:
				var gy: float = y0 + tall * (0.3 + 0.35 * _r(s, piece, 97))
				var gx: float = cuts[k] + (cuts[k + 1] - cuts[k]) * 0.2 * _r(s, piece, 98)
				slots[41].append(RisoShapes.rrect(gx, gy, (cuts[k + 1] - gx) * (0.5 + 0.4 * _r(s, piece, 99)), 1.5, 0.0))
			if k > 0:
				slots[13].append(RisoShapes.rrect(cuts[k] - PLANK_SEAM * 0.5, y0, PLANK_SEAM, tall, 0.0))
		slots[13].append(RisoShapes.rrect(c.x - half, y0 + tall - PLANK_SEAM, half * 2.0, PLANK_SEAM, 0.0))


## A cell of the institute's walls as pale stone in courses (see STONE_COURSES): blocks a cell long,
## every other course shifted half a block, fine joints between, some blocks a faint shade darker.
func _stone(v: Vector2i, c: Vector2, slots: Array, s: int) -> void:
	var tall: float = half * 2.0 / float(STONE_COURSES)
	var j: float = STONE_JOINT
	for row: int in range(STONE_COURSES):
		var y0: float = c.y - half + float(row) * tall
		var course: int = v.y * STONE_COURSES + row
		var shifted: bool = posmod(course, 2) == 1
		# The blocks this cell's stretch of the course crosses (a shifted course's straddle the
		# cell's middle), each toned by its own place in the course, and the joints between them.
		for k: int in range(2 if shifted else 1):
			var a: float = c.x - half if k == 0 else c.x
			var b: float = c.x if shifted and k == 0 else c.x + half
			var block: Vector2i = Vector2i(v.x - 1 + k if shifted else v.x, course)
			if _r(s, block, 85) < STONE_DARK:
				slots[27].append(RisoShapes.rrect(a, y0, b - a, tall, 0.0))
		if shifted:
			slots[13].append(RisoShapes.rrect(c.x - j * 0.5, y0, j, tall, 0.0))
		else:
			# Its joints on the cell's edges, half in each cell (none reaching out into the open).
			slots[13].append(RisoShapes.rrect(c.x - half, y0, j * 0.5, tall, 0.0))
			slots[13].append(RisoShapes.rrect(c.x + half - j * 0.5, y0, j * 0.5, tall, 0.0))
	# The beds between courses: half a joint on the cell's top and bottom edges, a whole one inside.
	slots[13].append(RisoShapes.rrect(c.x - half, c.y - half, half * 2.0, j * 0.5, 0.0))
	slots[13].append(RisoShapes.rrect(c.x - half, c.y + half - j * 0.5, half * 2.0, j * 0.5, 0.0))
	for row: int in range(1, STONE_COURSES):
		slots[13].append(RisoShapes.rrect(c.x - half, c.y - half + float(row) * tall - j * 0.5, half * 2.0, j, 0.0))


func _sketch_item(item: Dictionary, c: Vector2, slots: Array, s: int) -> void:
	var v: Vector2i = item["cell"]
	var floor_y: float = c.y + half
	var ceil_y: float = c.y - half
	match item["kind"]:
		&"leafy":
			# A broad-leaved plant: two to four long stalks fanning out from one root, each holding
			# a big leaf (a pointed oval with a darker midrib), their count, height, lean, size and
			# angle dealt per cell.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var n: int = 2 + int(_r(s, v, 11) * 3.0)
			var fan: float = 18.0 + _r(s, v, 12) * 14.0
			for i: int in range(n):
				var f: float = float(i) / float(n - 1) - 0.5
				var tall: float = 14.0 + _r(s, v, 20 + i) * 16.0
				var tip: Vector2 = Vector2(x + f * fan, floor_y - tall)
				var stalk: PackedVector2Array = PackedVector2Array([Vector2(x, floor_y + 1.0), Vector2(x + f * fan * 0.3, floor_y - tall * 0.55), tip])
				slots[4].append_array(strip(stalk, 1.8, 1.0))
				var size: float = 7.5 + _r(s, v, 30 + i) * 5.5
				# Mostly upright, tipped out a little to the side its stalk leans.
				var turn: float = f * 0.9 + (_r(s, v, 40 + i) - 0.5) * 0.4
				var xf: Transform2D = Transform2D(turn, tip)
				var length: float = size * 2.3
				var leaf: PackedVector2Array = xf * RisoShapes.smooth(PackedVector2Array([Vector2(0, 1), Vector2(size * 0.55, -length * 0.25), Vector2(size * 0.45, -length * 0.62), Vector2(0, -length), Vector2(-size * 0.45, -length * 0.62), Vector2(-size * 0.55, -length * 0.25)]), 3)
				slots[7].append(leaf)
				slots[6].append(leaf)
				slots[5].append_array(strip(xf * PackedVector2Array([Vector2(0, 0), Vector2(0, -length * 0.82)]), 1.1, 0.4))
		&"tuft":
			# Three kinds of grass, picked per cell: a clump, tall reeds with seed heads, or a low
			# fuzz of many short blades.
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var style: int = int(_r(s, v, 12) * 3.0)
			var blades: int = [3 + int(_r(s, v, 11) * 4.0), 2 + int(_r(s, v, 11) * 3.0), 6 + int(_r(s, v, 11) * 4.0)][style]
			var spread: float = [5.0, 6.5, 3.2][style]
			for i: int in range(blades):
				var x: float = x0 + (float(i) - float(blades) * 0.5) * spread
				var tall: float = [12.0 + _r(s, v, 20 + i) * 16.0, 26.0 + _r(s, v, 20 + i) * 18.0, 5.0 + _r(s, v, 20 + i) * 6.0][style]
				var lean: float = (_r(s, v, 30 + i) - 0.5) * [12.0, 8.0, 7.0][style]
				var base: float = [2.4, 1.5, 1.8][style]
				var blade: PackedVector2Array = PackedVector2Array([Vector2(x - base, floor_y + 2), Vector2(x + base, floor_y + 2), Vector2(x + lean, floor_y - tall)])
				slots[7].append(blade)
				slots[6].append(blade)
				if style == 1 and _r(s, v, 40 + i) < 0.6:
					var head: PackedVector2Array = RisoShapes.almond(Vector2(x + lean, floor_y - tall - 3.0), 1.8, 4.0, 8)
					slots[4].append(head)
			firefly_spots.append(Vector2(x0, floor_y - 30.0))
		&"mushroom":
			# Clusters of one to four, each a dome, a cone or a flat parasol, sized and tilted
			# per mushroom; domes and parasols are spotted.
			var n: int = 1 + int(_r(s, v, 10) * 4.0)
			var x0: float = c.x + (_r(s, v, 11) - 0.5) * half * 0.5
			for i: int in range(n):
				var x: float = x0 + float(i) * 14.0 - float(n - 1) * 7.0
				var style: int = int(_r(s, v, 50 + i) * 3.0)
				var tall: float = [5.0 + _r(s, v, 20 + i) * 7.0, 6.0 + _r(s, v, 20 + i) * 8.0, 11.0 + _r(s, v, 20 + i) * 9.0][style]
				var w: float = [16.0 + _r(s, v, 30 + i) * 10.0, 11.0 + _r(s, v, 30 + i) * 6.0, 20.0 + _r(s, v, 30 + i) * 10.0][style]
				var tilt: Transform2D = Transform2D((_r(s, v, 60 + i) - 0.5) * 0.4, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
				slots[8].append(tilt * RisoShapes.rrect(x - 2.6, floor_y - tall, 5.2, tall + 2.0, 2.2))
				var top: Vector2 = Vector2(x, floor_y - tall)
				var cap: PackedVector2Array = PackedVector2Array()
				match style:
					0:
						for k: int in range(9):
							var a: float = PI + PI * float(k) / 8.0
							cap.append(top + Vector2(cos(a) * w * 0.5, sin(a) * w * 0.42))
					1:
						cap = RisoShapes.smooth(PackedVector2Array([top + Vector2(-w * 0.5, 1), top + Vector2(-w * 0.18, -w * 0.45), top + Vector2(0, -w * 0.85), top + Vector2(w * 0.18, -w * 0.45), top + Vector2(w * 0.5, 1)]))
					2:
						cap = RisoShapes.smooth(PackedVector2Array([top + Vector2(-w * 0.5, 1.5), top + Vector2(-w * 0.32, -w * 0.16), top + Vector2(w * 0.32, -w * 0.16), top + Vector2(w * 0.5, 1.5)]))
				slots[11].append(tilt * cap)
				if style != 1:
					var high: float = 0.16 if style == 0 else 0.07
					for k: int in range(2 + (1 if style == 2 else 0)):
						slots[14].append(tilt * RisoShapes.circle(top + Vector2((float(k) - 0.6) * w * 0.28, -w * (high + 0.05 * float(k % 2))), 1.6, 6))
		&"stones":
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			for i: int in range(2 + int(_r(s, v, 11) * 2.0)):
				var w: float = 9.0 + _r(s, v, 20 + i) * 8.0
				var stone: PackedVector2Array = RisoShapes.ellipse(Vector2(x0 + float(i) * 10.0 - 8.0, floor_y - w * 0.3 - float(i % 2) * 5.0), w * 0.6, w * 0.38, 12)
				slots[12].append(stone)
				slots[13].append(stone)
		&"roots":
			for i: int in range(2 + int(_r(s, v, 10) * 3.0)):
				var x: float = c.x + (_r(s, v, 20 + i) - 0.5) * half * 0.8
				var long: float = 18.0 + _r(s, v, 30 + i) * 52.0
				var pts: PackedVector2Array = PackedVector2Array()
				for k: int in range(6):
					var f: float = float(k) / 5.0
					pts.append(Vector2(x + sin(f * 5.0 + float(i) * 2.0) * 4.0 * f, ceil_y - 2.0 + long * f))
				var root: Array[PackedVector2Array] = RisoDecor.strip(pts, 4.5, 1.2)
				slots[4].append_array(root)
				slots[5].append_array(root)
		&"bones":
			# Bones on the floor, in bare paper: a fish's skeleton lying on its side (a spine, ribs
			# along it, a head and a forked tail), or a few loose ribs and a knuckle of spine.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var flip: float = 1.0 if _r(s, v, 11) < 0.5 else -1.0
			if _r(s, v, 12) < 0.55:
				var long: float = 32.0 + _r(s, v, 13) * 14.0
				var y: float = floor_y - 7.0
				var x0: float = x - long * 0.5 * flip
				var x1: float = x + long * 0.5 * flip
				slots[8].append_array(strip(PackedVector2Array([Vector2(x0, y), Vector2(x1, y)]), 2.0, 2.0))
				var ribs: int = 4 + int(_r(s, v, 14) * 3.0)
				for k: int in range(ribs):
					var rx: float = lerpf(x0, x1, 0.25 + 0.55 * float(k) / float(ribs - 1))
					var tall: float = 7.0 - 2.5 * absf(float(k) / float(ribs - 1) - 0.4)
					slots[8].append_array(strip(PackedVector2Array([Vector2(rx, y - tall), Vector2(rx + flip * 2.0, y), Vector2(rx, y + tall * 0.75)]), 1.5, 0.8))
				slots[8].append(PackedVector2Array([Vector2(x1, y - 7.0), Vector2(x1 + flip * 10.0, y), Vector2(x1, y + 5.0)]))
				slots[13].append(RisoShapes.circle(Vector2(x1 + flip * 2.5, y - 1.8), 1.6, 6))
				slots[8].append(PackedVector2Array([Vector2(x0, y), Vector2(x0 - flip * 8.0, y - 7.0), Vector2(x0 - flip * 4.5, y), Vector2(x0 - flip * 8.0, y + 6.0)]))
			else:
				for k: int in range(2 + int(_r(s, v, 13) * 2.0)):
					var bx: float = x + (float(k) - 1.0) * 7.0
					var lean: float = (_r(s, v, 20 + k) - 0.5) * 0.8
					var rib: PackedVector2Array = PackedVector2Array()
					for j: int in range(5):
						var f: float = float(j) / 4.0
						rib.append(Vector2(bx + sin(f * PI) * 4.0 * flip + lean * 10.0 * f, floor_y - 1.0 - f * (9.0 + _r(s, v, 30 + k) * 5.0) * cos(lean)))
					slots[8].append_array(strip(rib, 1.6, 0.8))
				slots[8].append(RisoShapes.ellipse(Vector2(x - flip * 9.0, floor_y - 2.5), 3.5, 2.5, 10))
		&"vein":
			# A vein through the flesh along an open face: a dark line wandering a little way in
			# from the face, branching once or twice, drawn at the rock's own size (not grown).
			var face: Vector2i = item["face"]
			var along: Vector2 = Vector2(absf(float(face.y)), absf(float(face.x)))
			var inward: Vector2 = -Vector2(face)
			var start: Vector2 = c - along * half * (0.6 + _r(s, v, 10) * 0.4) + Vector2(face) * half * 0.55
			var long: float = half * (1.2 + _r(s, v, 11) * 0.8)
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in range(9):
				var f: float = float(k) / 8.0
				pts.append(start + along * long * f + inward * (10.0 + sin(f * 5.0 + _r(s, v, 12) * 6.0) * 8.0 + f * 12.0))
			slots[5].append_array(strip(pts, 9.0, 3.5))
			for b: int in range(1 + int(_r(s, v, 13) * 2.0)):
				var from: Vector2 = pts[2 + b * 3]
				var tip: Vector2 = from + along * (24.0 + _r(s, v, 14 + b) * 16.0) + inward * (22.0 + _r(s, v, 16 + b) * 18.0)
				slots[5].append_array(strip(PackedVector2Array([from, from.lerp(tip, 0.5) + along * 6.0, tip]), 6.0, 2.0))
		&"stalactite":
			for i: int in range(1 + int(_r(s, v, 10) * 2.0)):
				var x: float = c.x + (_r(s, v, 20 + i) - 0.5) * half * 0.6
				var w: float = 10.0 + _r(s, v, 30 + i) * 10.0
				var long: float = 18.0 + _r(s, v, 40 + i) * 28.0
				var spike: PackedVector2Array = PackedVector2Array([Vector2(x - w * 0.5, ceil_y - 2), Vector2(x + w * 0.5, ceil_y - 2), Vector2(x + w * 0.1, ceil_y + long)])
				slots[4].append(spike)
				slots[5].append(PackedVector2Array([Vector2(x, ceil_y - 2), Vector2(x + w * 0.5, ceil_y - 2), Vector2(x + w * 0.1, ceil_y + long)]))
		&"drip":
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			slots[4].append(RisoShapes.smooth(PackedVector2Array([Vector2(x - 6, ceil_y - 2), Vector2(x + 6, ceil_y - 2), Vector2(x + 2, ceil_y + 8), Vector2(x, ceil_y + 12), Vector2(x - 2, ceil_y + 8)])))
			drip_spots.append(Vector2(x, ceil_y + 12))
			var fall: int = 0
			while fall < 6 and not _solid.has(v + Vector2i(0, fall + 1)):
				fall += 1
			drip_ends.append(c.y + half + float(fall) * half * 2.0 - 2.0)
		&"headstone":
			# Pale stone (bare paper, shaded down one side), leaning a little, in one of five shapes:
			# rounded, gothic (pointed), cross-topped, broken (its top snapped off at a slant), or a
			# flat ledger lying on the grave with a low stone at its head. Marks cut in blue.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			var w: float = 18.0 + _r(s, v, 11) * 8.0
			var tall: float = 26.0 + _r(s, v, 12) * 14.0
			var tilt: Transform2D = Transform2D((_r(s, v, 13) - 0.5) * 0.3, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
			var style: int = int(_r(s, v, 14) * 5.0)
			var stone: PackedVector2Array
			match style:
				1:
					stone = PackedVector2Array([Vector2(x - w * 0.5, floor_y + 2.0), Vector2(x - w * 0.5, floor_y - tall * 0.65), Vector2(x, floor_y - tall), Vector2(x + w * 0.5, floor_y - tall * 0.65), Vector2(x + w * 0.5, floor_y + 2.0)])
				2:
					stone = RisoShapes.rrect(x - w * 0.5, floor_y - tall * 0.7, w, tall * 0.7 + 2.0, 2.0)
					slots[8].append(tilt * RisoShapes.rrect(x - 2.6, floor_y - tall - 4.0, 5.2, tall * 0.4, 1.0))
					slots[8].append(tilt * RisoShapes.rrect(x - 7.0, floor_y - tall + 2.0, 14.0, 4.4, 1.0))
				3:
					var cut: float = (_r(s, v, 15) - 0.5) * 10.0
					stone = PackedVector2Array([Vector2(x - w * 0.5, floor_y + 2.0), Vector2(x - w * 0.5, floor_y - tall * 0.6 - cut), Vector2(x - w * 0.1, floor_y - tall * 0.5), Vector2(x + w * 0.15, floor_y - tall * 0.66), Vector2(x + w * 0.5, floor_y - tall * 0.55 + cut), Vector2(x + w * 0.5, floor_y + 2.0)])
				4:
					stone = RisoShapes.rrect(x - w * 0.7, floor_y - 6.0, w * 1.4, 8.0, 2.0)
					slots[8].append(tilt * RisoShapes.arch(x - w * 0.85, floor_y - tall * 0.55, w * 0.45, tall * 0.55 + 2.0, 8))
				_:
					stone = RisoShapes.arch(x - w * 0.5, floor_y - tall, w, tall + 2.0, 10)
			slots[8].append(tilt * stone)
			slots[13].append(tilt * Transform2D(0.0, Vector2(0.5, 1.0), 0.0, Vector2(x * 0.5 + w * 0.25, 0.0)) * stone)
			if style != 4 and style != 2:
				slots[4].append(tilt * RisoShapes.rrect(x - 1.1, floor_y - tall * 0.62, 2.2, w * 0.6, 0.6))
				slots[4].append(tilt * RisoShapes.rrect(x - w * 0.2, floor_y - tall * 0.62 + w * 0.15, w * 0.4, 2.2, 0.6))
		&"obelisk":
			# A tall tapering needle of stone on a base, its tip a little pyramid.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var tall: float = 58.0 + _r(s, v, 11) * 22.0
			slots[8].append(RisoShapes.rrect(x - 11.0, floor_y - 9.0, 22.0, 11.0, 2.0))
			var shaft: PackedVector2Array = PackedVector2Array([Vector2(x - 7.0, floor_y - 8.0), Vector2(x - 4.5, floor_y - tall), Vector2(x, floor_y - tall - 8.0), Vector2(x + 4.5, floor_y - tall), Vector2(x + 7.0, floor_y - 8.0)])
			slots[8].append(shaft)
			slots[13].append(PackedVector2Array([Vector2(x, floor_y - 8.0), Vector2(x, floor_y - tall - 8.0), Vector2(x + 4.5, floor_y - tall), Vector2(x + 7.0, floor_y - 8.0)]))
		&"urn":
			# An urn on a stone plinth.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			slots[8].append(RisoShapes.rrect(x - 9.0, floor_y - 18.0, 18.0, 20.0, 1.5))
			slots[13].append(RisoShapes.rrect(x, floor_y - 18.0, 9.0, 20.0, 1.5))
			var urn: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(x - 4.0, floor_y - 18.0), Vector2(x - 9.0, floor_y - 24.0), Vector2(x - 8.0, floor_y - 33.0), Vector2(x - 5.0, floor_y - 37.0), Vector2(x + 5.0, floor_y - 37.0), Vector2(x + 8.0, floor_y - 33.0), Vector2(x + 9.0, floor_y - 24.0), Vector2(x + 4.0, floor_y - 18.0)]), 3)
			slots[8].append(urn)
			slots[13].append(RisoShapes.rrect(x - 7.0, floor_y - 39.0, 14.0, 2.6, 1.0))
		&"angel":
			# A stone angel on a plinth, head bowed, wings folded up behind.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.3
			var face: float = 1.0 if _r(s, v, 11) < 0.5 else -1.0
			slots[8].append(RisoShapes.rrect(x - 12.0, floor_y - 12.0, 24.0, 14.0, 2.0))
			var robe: PackedVector2Array = PackedVector2Array([Vector2(x - 9.0, floor_y - 12.0), Vector2(x - 5.0, floor_y - 44.0), Vector2(x + 5.0, floor_y - 44.0), Vector2(x + 9.0, floor_y - 12.0)])
			var wing: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([Vector2(x - face * 2.0, floor_y - 42.0), Vector2(x - face * 16.0, floor_y - 58.0), Vector2(x - face * 13.0, floor_y - 38.0), Vector2(x - face * 8.0, floor_y - 26.0)]), 3)
			slots[8].append(wing)
			slots[13].append(wing)
			slots[8].append(robe)
			slots[8].append(RisoShapes.circle(Vector2(x + face * 2.0, floor_y - 49.0), 5.0, 14))
			slots[13].append(PackedVector2Array([Vector2(x, floor_y - 12.0), Vector2(x, floor_y - 44.0), Vector2(x + 5.0, floor_y - 44.0), Vector2(x + 9.0, floor_y - 12.0)]))
		&"flowers":
			# Grave flowers: a few stems, their heads drooping, pale petals.
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			for i: int in range(3 + int(_r(s, v, 11) * 3.0)):
				var x: float = x0 + (float(i) - 2.0) * 4.5
				var tall: float = 10.0 + _r(s, v, 20 + i) * 9.0
				var droop: float = (2.0 + _r(s, v, 30 + i) * 4.0) * (1.0 if i % 2 == 0 else -1.0)
				var stem: PackedVector2Array = PackedVector2Array([Vector2(x, floor_y + 1.0), Vector2(x + droop * 0.3, floor_y - tall), Vector2(x + droop, floor_y - tall + 3.0)])
				slots[4].append_array(RisoDecor.strip(stem, 1.6, 1.0))
				slots[8].append(RisoShapes.almond(Vector2(x + droop, floor_y - tall + 5.0), 2.6, 3.4, 8))
		&"shrub_run":
			# A hedge the length of the run (HEDGE_SLOTS, behind the fences), drawn at full size: a
			# low band of leafage with a row of rounded tops along it, shaded at its foot.
			var k: float = PROP_SCALE
			var cells: Array = item["cells"]
			var x0: float = c.x - half + 3.0 * k
			var x1: float = c.x - half + float(cells.size()) * half * 2.0 - 3.0 * k
			var tall: float = (19.0 + _r(s, v, 70) * 5.0) * k
			slots[21].append(RisoShapes.rrect(x0, floor_y - tall * 0.5, x1 - x0, tall * 0.5 + 2.0, 4.0 * k))
			var n: int = maxi(2, int((x1 - x0) / (15.0 * k)) + 1)
			for i: int in range(n):
				var x: float = lerpf(x0 + 7.0 * k, x1 - 7.0 * k, float(i) / float(n - 1))
				var r: float = (8.0 + _r(s, v, 80 + i) * 2.0) * k
				slots[21].append(RisoShapes.circle(Vector2(x, floor_y - tall + r + _r(s, v, 120 + i) * 2.0 * k), r, 16))
			slots[22].append_array(slots[21].slice(slots[21].size() - n - 1))
			slots[23].append(RisoShapes.rrect(x0, floor_y - tall * 0.22, x1 - x0, tall * 0.22 + 2.0, 3.0 * k))
			firefly_spots.append(Vector2((x0 + x1) * 0.5, floor_y - tall - 20.0))
		&"fence_run":
			# Behind the rest: a fence the length of the run (BACK_SLOTS), drawn at full size (it is
			# not grown about one end like the other props).
			var k: float = PROP_SCALE
			var cells: Array = item["cells"]
			var x0: float = c.x - half
			var x1: float = c.x - half + float(cells.size()) * half * 2.0
			if item.has("battlement"):
				# A parapet of pale stone along the edge of a built floor, its top cut into merlons
				# with gaps between, shaded at its foot and down one side of each merlon.
				var wall: float = 15.0 * k
				var merlon: float = 9.0 * k
				slots[24].append(RisoShapes.rrect(x0 + 1.0, floor_y - wall, x1 - x0 - 2.0, wall + 2.0, 1.5 * k))
				slots[25].append(RisoShapes.rrect(x0 + 1.0, floor_y - wall * 0.3, x1 - x0 - 2.0, wall * 0.3 + 2.0, 1.0 * k))
				var n: int = maxi(2, int((x1 - x0) / (16.0 * k)))
				var pitch: float = (x1 - x0 - 2.0) / float(n)
				for i: int in range(n):
					var mx: float = x0 + 1.0 + float(i) * pitch + pitch * 0.18
					var mw: float = pitch * 0.64
					slots[24].append(RisoShapes.rrect(mx, floor_y - wall - merlon, mw, merlon + 3.0, 1.2 * k))
					slots[25].append(RisoShapes.rrect(mx + mw * 0.62, floor_y - wall - merlon, mw * 0.38, merlon + 3.0, 1.0 * k))
				return
			if item.has("bunting"):
				# Peace flags: a line strung between two poles, each standing in a pile of stones,
				# sagging, hung with triangles in turn of blue, paper, sun, moss (sun over blue) and
				# plum (pink over blue).
				var ends: Array[float] = [x0 + 9.0 * k, x1 - 9.0 * k]
				var tops: Array[float] = []
				for px: float in ends:
					var pile: float = _cairn(slots, px, floor_y, k, s, Vector2i(int(px), v.y), true)
					var top: float = floor_y - (40.0 + _r(s, Vector2i(int(px), v.y), 70) * 8.0) * k
					slots[20].append(RisoShapes.rrect(px - 1.2 * k, top, 2.4 * k, pile - top + 2.0, 1.0 * k))
					tops.append(top + 2.0 * k)
				var line: PackedVector2Array = PackedVector2Array()
				for j: int in range(13):
					var u: float = float(j) / 12.0
					line.append(Vector2(lerpf(ends[0], ends[1], u), lerpf(tops[0], tops[1], u) + sin(u * PI) * 10.0 * k))
				slots[17].append_array(RisoDecor.strip(line, 0.8 * k, 0.8 * k))
				slots[16].append_array(RisoDecor.strip(line, 0.5 * k, 0.5 * k))
				var n: int = int((ends[1] - ends[0] - 8.0 * k) / (11.0 * k))
				for i: int in range(n):
					var u: float = (float(i) + 0.5) / float(n)
					var top: Vector2 = Vector2(lerpf(ends[0], ends[1], u), lerpf(tops[0], tops[1], u) + sin(u * PI) * 10.0 * k)
					var flag: PackedVector2Array = RisoShapes.tri(top + Vector2(-4.5 * k, 0.0), top + Vector2(4.5 * k, 0.0), top + Vector2(0.8 * k, 11.0 * k))
					match i % 5:
						0:
							slots[20].append(flag)
						1:
							slots[15].append(flag)
						2:
							slots[18].append(flag)
						3:
							slots[20].append(flag)
							slots[18].append(flag)
						4:
							slots[20].append(flag)
							slots[19].append(flag)
				return
			if not item.has("iron"):
				# Wooden pickets, rounded, over two rails; now and then one lost or leaning.
				var n: int = int((x1 - x0) / (10.0 * k))
				for i: int in range(n):
					if _r(s, v, 60 + i) < 0.07:
						continue
					var x: float = x0 + (5.0 + float(i) * 10.0) * k
					var tall: float = (26.0 + (_r(s, v, 100 + i) - 0.5) * 4.0) * k
					var lean: Transform2D = Transform2D((_r(s, v, 140 + i) - 0.5) * 0.25 if _r(s, v, 180 + i) < 0.15 else 0.0, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
					slots[15].append(lean * RisoShapes.arch(x - 3.2 * k, floor_y - tall, 6.4 * k, tall + 2.0, 6))
				for rail: float in [21.0, 9.0]:
					slots[15].append(RisoShapes.rrect(x0 + 2.0, floor_y - rail * k, x1 - x0 - 4.0, 3.4 * k, 1.2 * k))
				slots[17].append(RisoShapes.rrect(x0 + 2.0, floor_y - 9.0 * k, x1 - x0 - 4.0, 3.4 * k, 1.2 * k))
			else:
				# Iron railings, spear-tipped, between stone posts at each end and every few cells.
				var n: int = int((x1 - x0) / (8.0 * k))
				for i: int in range(n):
					var x: float = x0 + (4.0 + float(i) * 8.0) * k
					var tall: float = 30.0 * k
					slots[16].append(RisoShapes.rrect(x - 1.0 * k, floor_y - tall, 2.0 * k, tall + 2.0, 0.8 * k))
					slots[16].append(RisoShapes.tri(Vector2(x - 2.2 * k, floor_y - tall + 2.0), Vector2(x + 2.2 * k, floor_y - tall + 2.0), Vector2(x, floor_y - tall - 5.0 * k)))
				for rail: float in [7.0, 24.0]:
					slots[16].append(RisoShapes.rrect(x0, floor_y - rail * k, x1 - x0, 2.2 * k, 0.8 * k))
				var posts: Array[float] = [x0 + 3.0 * k, x1 - 3.0 * k]
				for j: int in range(1, cells.size()):
					if j % 3 == 0:
						posts.append(x0 + float(j) * half * 2.0)
				for px: float in posts:
					slots[16].append(RisoShapes.rrect(px - 4.5 * k, floor_y - 36.0 * k, 9.0 * k, 36.0 * k + 2.0, 1.5 * k))
					slots[16].append(RisoShapes.rrect(px - 6.0 * k, floor_y - 40.0 * k, 12.0 * k, 5.0 * k, 1.5 * k))
					slots[17].append(RisoShapes.rrect(px, floor_y - 36.0 * k, 4.5 * k, 36.0 * k + 2.0, 1.5 * k))
		&"banner":
			# A castle banner: a pole with a crossbar, a long swallowtailed cloth hanging from it in
			# paper with a blue band down its middle, stirring a little.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var tall: float = 46.0 + _r(s, v, 11) * 12.0
			slots[12].append(RisoShapes.rrect(x - 1.3, floor_y - tall, 2.6, tall + 2.0, 1.0))
			slots[12].append(RisoShapes.rrect(x - 9.0, floor_y - tall + 3.0, 18.0, 2.4, 1.0))
			slots[12].append(RisoShapes.circle(Vector2(x, floor_y - tall - 1.5), 2.4, 10))
			var drop: float = 22.0 + _r(s, v, 12) * 8.0
			var lean: float = (_r(s, v, 13) - 0.5) * 4.0
			var top: float = floor_y - tall + 5.0
			var cloth: PackedVector2Array = PackedVector2Array([Vector2(x - 8.0, top), Vector2(x + 8.0, top), Vector2(x + 8.0 + lean, top + drop), Vector2(x + lean, top + drop - 6.0), Vector2(x - 8.0 + lean, top + drop)])
			slots[8].append(cloth)
			slots[12].append(PackedVector2Array([Vector2(x - 2.5, top), Vector2(x + 2.5, top), Vector2(x + 2.5 + lean * 0.8, top + drop - 4.6), Vector2(x + lean * 0.8, top + drop - 6.0), Vector2(x - 2.5 + lean * 0.8, top + drop - 4.6)]))
			slots[13].append(PackedVector2Array([Vector2(x + 3.0, top), Vector2(x + 8.0, top), Vector2(x + 8.0 + lean, top + drop), Vector2(x + 3.0 + lean, top + drop - 3.5)]))
		&"rubble":
			# Fallen blocks of dressed stone: two to four, squarish, tumbled, shaded down one side.
			var x0: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			for i: int in range(2 + int(_r(s, v, 11) * 3.0)):
				var w: float = 7.0 + _r(s, v, 20 + i) * 6.0
				var hgt: float = w * (0.6 + 0.3 * _r(s, v, 30 + i))
				var at: Vector2 = Vector2(x0 + (float(i) - 1.0) * 8.0, floor_y - hgt * 0.5 + 1.0 - (5.0 if i == 3 else 0.0))
				var block: PackedVector2Array = Transform2D((_r(s, v, 40 + i) - 0.5) * 0.5, at) * RisoShapes.rrect(-w * 0.5, -hgt * 0.5, w, hgt, 1.5)
				slots[12].append(block)
				slots[13].append(Transform2D(0.0, Vector2(0.5, 1.0), 0.0, Vector2(at.x * 0.5 + w * 0.25, 0.0)) * block)
		&"bookcase":
			# A bookcase as tall as the room (`rise` cells, its top a little short of the ceiling)
			# and a cell or two wide: a dark wooden case, a cornice over it, a shelf every half cell,
			# and on each shelf a row of books dealt one by one by the cell: how wide and tall, which
			# colour (brown, moss, maroon, night, tan, plum or paper), a gilt band or two on some,
			# now and then one leaning on its neighbour, a gap, or a short stack lying flat. The books,
			# their bands and the shelves are square-cornered: a few hundred to a case, rounding under
			# a pixel would only multiply their points.
			var rise: int = int(item.get("rise", 1))
			var wide: float = float(int(item.get("wide", 1))) * half - 6.0
			var x0: float = c.x - half * 0.5 + 3.0
			var tall: float = float(rise) * half - 8.0
			slots[12].append(RisoShapes.rrect(x0, floor_y - tall, wide, tall + 1.0, 1.0))
			slots[13].append(RisoShapes.rrect(x0 - 2.0, floor_y - tall - 3.0, wide + 4.0, 4.0, 1.0))
			slots[13].append(RisoShapes.rrect(x0 + wide - 3.0, floor_y - tall, 3.0, tall + 1.0, 1.0))
			var shelves: int = maxi(1, int(tall / 16.0))
			var gap: float = tall / float(shelves)
			for shelf: int in range(shelves):
				var y1: float = floor_y - 2.0 - float(shelf) * gap
				slots[13].append(RisoShapes.rrect(x0 + 1.5, y1, wide - 3.0, 1.6, 0.0))
				var x: float = x0 + 2.5
				var n: int = 0
				while x < x0 + wide - 5.0:
					var salt: int = 300 + shelf * 61 + n * 7
					var roll: float = _r(s, v, salt)
					var bw: float = 2.4 + _r(s, v, salt + 1) * 2.4
					var bh: float = gap * (0.55 + _r(s, v, salt + 2) * 0.3)
					if roll < 0.06:
						x += bw + 1.5
						n += 1
						continue
					var book: PackedVector2Array
					if roll < 0.12 and x + 9.0 < x0 + wide - 4.0:
						# A short stack lying flat.
						for k: int in range(2 + int(_r(s, v, salt + 3) * 2.0)):
							var lie: PackedVector2Array = RisoShapes.rrect(x, y1 - 2.2 * float(k + 1), 8.0 + _r(s, v, salt + 4 + k) * 2.0, 2.0, 0.0)
							_book_ink(slots, lie, _r(s, v, salt + 9 + k))
						x += 11.0
						n += 1
						continue
					book = PackedVector2Array([Vector2(x + bw, y1 - bh), Vector2(x + bw, y1), Vector2(x, y1), Vector2(x, y1 - bh)])
					if roll > 0.94:
						book = Transform2D(0.22, Vector2(x, y1)) * RisoShapes.rrect(0.0, -bh, bw, bh, 0.0)
					_book_ink(slots, book, _r(s, v, salt + 5))
					if _r(s, v, salt + 6) < 0.35:
						slots[37].append(RisoShapes.rrect(x + 0.3, y1 - bh * 0.78, bw - 0.6, 0.7, 0.0))
						if _r(s, v, salt + 7) < 0.5:
							slots[37].append(RisoShapes.rrect(x + 0.3, y1 - bh * 0.2, bw - 0.6, 0.7, 0.0))
					x += bw + 0.4
					n += 1
		&"desk":
			# One of DESKS kinds of desk, dealt by the cell, each with books on it (dealt one by one
			# as a bookcase's are): a sloping reading desk with an open book and a stack beside it;
			# a writing table with a stack of books, an ink pot and a quill and a sheet of paper; a
			# long library table with a row of books standing between bookends and one lying open;
			# a lectern on its post with a great book open on it; a small table with a globe on a
			# stand and books under it; or a desk of drawers with papers and a leaning pile.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.3
			var kind: int = int(_r(s, v, 12) * float(DESKS)) % DESKS
			var wood: Array = slots[12]
			var shade: Array = slots[13]
			match kind:
				0:
					wood.append(PackedVector2Array([Vector2(x - 15.0, floor_y - 20.0), Vector2(x + 15.0, floor_y - 25.0), Vector2(x + 15.0, floor_y - 21.0), Vector2(x - 15.0, floor_y - 17.0)]))
					for lx: float in [x - 11.0, x + 11.0]:
						wood.append(RisoShapes.rrect(lx - 1.3, floor_y - 21.0, 2.6, 22.0, 0.8))
					shade.append(RisoShapes.rrect(x + 9.7, floor_y - 21.0, 2.6, 22.0, 0.8))
					_open_book(slots, Vector2(x, floor_y - 25.0), 11.0, -0.17)
					_book_stack(slots, Vector2(x + 18.0, floor_y), 3, s, v)
				1:
					wood.append(RisoShapes.rrect(x - 17.0, floor_y - 20.0, 34.0, 3.0, 0.8))
					for lx: float in [x - 15.0, x + 13.0]:
						wood.append(RisoShapes.rrect(lx, floor_y - 18.0, 2.4, 19.0, 0.6))
					shade.append(RisoShapes.rrect(x - 17.0, floor_y - 17.5, 34.0, 1.5, 0.5))
					_book_stack(slots, Vector2(x - 9.0, floor_y - 20.0), 2 + int(_r(s, v, 13) * 3.0), s, v)
					slots[33].append(RisoShapes.rrect(x + 4.0, floor_y - 24.0, 4.0, 4.0, 1.2))
					slots[37].append(Transform2D(0.5, Vector2(x + 6.5, floor_y - 24.0)) * PackedVector2Array([Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0.3, -10.0), Vector2(-0.5, -9.0)]))
					slots[37].append(Transform2D(-0.08, Vector2(x + 12.0, floor_y - 20.5)) * RisoShapes.rrect(-4.0, -0.8, 8.0, 0.8, 0.2))
				2:
					wood.append(RisoShapes.rrect(x - 26.0, floor_y - 18.0, 52.0, 3.0, 0.8))
					for lx: float in [x - 23.0, x + 21.0]:
						wood.append(RisoShapes.rrect(lx, floor_y - 16.0, 2.4, 17.0, 0.6))
					shade.append(RisoShapes.rrect(x - 26.0, floor_y - 15.5, 52.0, 1.5, 0.5))
					var bx: float = x - 22.0
					wood.append(RisoShapes.rrect(bx - 1.5, floor_y - 27.0, 1.5, 9.0, 0.4))
					for k: int in range(5 + int(_r(s, v, 13) * 3.0)):
						var bw: float = 2.2 + _r(s, v, 140 + k) * 1.8
						var bh: float = 6.0 + _r(s, v, 150 + k) * 4.0
						_book_ink(slots, RisoShapes.rrect(bx, floor_y - 18.0 - bh, bw, bh, 0.3), _r(s, v, 160 + k))
						bx += bw + 0.3
					wood.append(RisoShapes.rrect(bx + 0.3, floor_y - 27.0, 1.5, 9.0, 0.4))
					_open_book(slots, Vector2(x + 12.0, floor_y - 18.5), 8.0, 0.0)
				3:
					wood.append(RisoShapes.rrect(x - 7.0, floor_y - 3.0, 14.0, 3.0, 0.8))
					wood.append(RisoShapes.rrect(x - 1.6, floor_y - 26.0, 3.2, 24.0, 0.8))
					wood.append(PackedVector2Array([Vector2(x - 11.0, floor_y - 27.0), Vector2(x + 11.0, floor_y - 31.0), Vector2(x + 11.0, floor_y - 28.0), Vector2(x - 11.0, floor_y - 24.0)]))
					shade.append(RisoShapes.rrect(x + 0.4, floor_y - 26.0, 1.2, 24.0, 0.4))
					_open_book(slots, Vector2(x, floor_y - 29.5), 10.0, -0.18)
					slots[32].append(Transform2D(-0.18, Vector2(x + 1.0, floor_y - 29.0)) * RisoShapes.rrect(-0.6, 0.0, 1.2, 7.0, 0.3))
				4:
					wood.append(RisoShapes.rrect(x - 10.0, floor_y - 14.0, 20.0, 2.5, 0.8))
					for lx: float in [x - 9.0, x + 7.0]:
						wood.append(RisoShapes.rrect(lx, floor_y - 12.0, 2.0, 13.0, 0.6))
					_book_stack(slots, Vector2(x - 1.0, floor_y), 2, s, v)
					wood.append(RisoShapes.rrect(x - 1.0, floor_y - 19.0, 2.0, 5.0, 0.5))
					var globe: Vector2 = Vector2(x, floor_y - 27.0)
					slots[30].append(RisoShapes.circle(globe, 8.0, 18))
					slots[31].append(RisoShapes.ellipse(globe + Vector2(-2.0, -1.5), 3.5, 4.5, 10, 0.4))
					slots[31].append(RisoShapes.ellipse(globe + Vector2(3.5, 3.0), 2.5, 2.0, 8))
					slots[37].append_array(RisoShapes.ring(globe, 8.6, 9.8, 20).slice(0, 1))
				_:
					wood.append(RisoShapes.rrect(x - 15.0, floor_y - 20.0, 30.0, 20.0, 1.0))
					for row: int in range(3):
						shade.append(RisoShapes.rrect(x - 13.0, floor_y - 18.0 + float(row) * 6.0, 26.0, 0.8, 0.3))
						slots[37].append(RisoShapes.circle(Vector2(x, floor_y - 15.5 + float(row) * 6.0), 0.9, 6))
					slots[37].append(Transform2D(0.1, Vector2(x - 8.0, floor_y - 20.5)) * RisoShapes.rrect(-5.0, -0.7, 10.0, 0.7, 0.2))
					slots[37].append(Transform2D(-0.15, Vector2(x - 6.0, floor_y - 21.0)) * RisoShapes.rrect(-4.5, -0.7, 9.0, 0.7, 0.2))
					var lean: Transform2D = Transform2D(0.12, Vector2(x + 7.0, floor_y - 20.0))
					for k: int in range(3):
						_book_ink(slots, lean * RisoShapes.rrect(-4.5, -2.2 * float(k + 1), 9.0, 2.0, 0.4), _r(s, v, 170 + k))
		&"alchemy":
			_alchemy(c.x + (_r(s, v, 10) - 0.5) * half * 0.3, floor_y, slots, s, v)
		&"ritual":
			_ritual(int(_r(s, v, 12) * float(RITUAL)) % RITUAL, c.x + (_r(s, v, 10) - 0.5) * half * 0.3, floor_y, slots, s, v)
		&"statue":
			# A statue on a plinth: a draped figure in bare paper (head, shoulders, a gown to the
			# plinth), shaded down one side, its arm raised or at its side by the cell.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.3
			slots[12].append(RisoShapes.rrect(x - 9.0, floor_y - 10.0, 18.0, 11.0, 1.0))
			slots[13].append(RisoShapes.rrect(x + 3.0, floor_y - 10.0, 6.0, 11.0, 1.0))
			var figure: Array[PackedVector2Array] = [
				RisoShapes.smooth(PackedVector2Array([Vector2(x - 5.0, floor_y - 10.0), Vector2(x - 6.0, floor_y - 28.0), Vector2(x - 3.5, floor_y - 36.0),
					Vector2(x + 3.5, floor_y - 36.0), Vector2(x + 6.0, floor_y - 28.0), Vector2(x + 5.0, floor_y - 10.0)]), 2),
				RisoShapes.circle(Vector2(x, floor_y - 40.0), 4.0, 14),
			]
			if _r(s, v, 11) < 0.5:
				figure.append(Transform2D(-0.5, Vector2(x + 4.5, floor_y - 33.0)) * RisoShapes.rrect(-1.2, -11.0, 2.4, 12.0, 1.0))
			slots[8].append_array(figure)
			slots[13].append(PackedVector2Array([Vector2(x + 1.5, floor_y - 10.0), Vector2(x + 2.0, floor_y - 35.0), Vector2(x + 3.5, floor_y - 36.0), Vector2(x + 6.0, floor_y - 28.0), Vector2(x + 5.0, floor_y - 10.0)]))
		&"great_column":
			# A great column of pale marble from the floor to the ceiling (`rise` cells): a square base
			# on a plinth, a fluted shaft tapering a little, a capital with a scroll each side.
			var rise: float = float(int(item.get("rise", 2)))
			var x: float = c.x
			var tall: float = rise * half
			var w: float = 9.0
			slots[39].append(RisoShapes.rrect(x - w * 1.5, floor_y - 5.0, w * 3.0, 6.0, 0.5))
			slots[39].append(RisoShapes.rrect(x - w * 1.2, floor_y - 9.0, w * 2.4, 5.0, 1.5))
			slots[39].append(PackedVector2Array([Vector2(x - w, floor_y - 9.0), Vector2(x - w * 0.85, floor_y - tall + 9.0), Vector2(x + w * 0.85, floor_y - tall + 9.0), Vector2(x + w, floor_y - 9.0)]))
			slots[39].append(RisoShapes.rrect(x - w * 1.4, floor_y - tall + 4.0, w * 2.8, 5.0, 1.0))
			slots[39].append(RisoShapes.rrect(x - w * 1.7, floor_y - tall, w * 3.4, 4.0, 0.5))
			for side: float in [-1.0, 1.0]:
				slots[39].append(RisoShapes.circle(Vector2(x + side * w * 1.25, floor_y - tall + 7.0), 2.6, 10))
			for fx: float in [-0.5, 0.0, 0.5]:
				slots[40].append(RisoShapes.rrect(x + fx * w - 0.5, floor_y - tall + 11.0, 1.0, tall - 22.0, 0.5))
			slots[40].append(PackedVector2Array([Vector2(x + w * 0.45, floor_y - 9.0), Vector2(x + w * 0.4, floor_y - tall + 9.0), Vector2(x + w * 0.85, floor_y - tall + 9.0), Vector2(x + w, floor_y - 9.0)]))
		&"panel":
			# The institute's walls, at full size, by the wall style (RisoPrint.wall_style): planks
			# or stone (_planks, _stone), else panelling, the same everywhere, so it stays quiet
			# behind what happens in front of it. A frame of stiles and rails round tall sunk
			# panels, each a cell wide and PANEL_ROWS cells high (so a cell holds the top or the
			# bottom of one), a shade darker than the frame, with the frame's shadow along the
			# panel's top and down its left side.
			var style: StringName = RisoPrint.instance.wall_style if RisoPrint.instance != null else &"planks"
			if style == &"planks":
				_planks(v, c, slots, s)
				return
			if style == &"stone":
				_stone(v, c, slots, s)
				return
			var x0: float = c.x - half + PANEL_STILE * 0.5
			var x1: float = c.x + half - PANEL_STILE * 0.5
			var top: bool = posmod(v.y, PANEL_ROWS) == 0
			var bottom: bool = posmod(v.y, PANEL_ROWS) == PANEL_ROWS - 1
			var y0: float = c.y - half + (PANEL_RAIL * 0.5 if top else 0.0)
			var y1: float = c.y + half - (PANEL_RAIL * 0.5 if bottom else 0.0)
			var b: float = PANEL_SHADOW
			slots[27].append(RisoShapes.rrect(x0, y0, x1 - x0, y1 - y0, 0.0))
			slots[41].append(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + b, y0 + (b if top else 0.0)), Vector2(x0 + b, y1), Vector2(x0, y1)]))
			if top:
				slots[41].append(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y0 + b), Vector2(x0 + b, y0 + b)]))
		&"marble":
			# Pale marble on the institute's halls, at full size: big slabs MARBLE_SLAB cells square,
			# each its own faint tone, with fine joints only between slabs and soft blue veins
			# wandering across each whole slab.
			var slab: Vector2i = Vector2i(floori(float(v.x) / MARBLE_SLAB), floori(float(v.y) / MARBLE_SLAB))
			var tone: float = _r(s, slab, 70)
			if tone < 0.35:
				slots[26].append(RisoShapes.rrect(c.x - half, c.y - half, half * 2.0, half * 2.0, 0.0))
			elif tone < 0.55:
				slots[27].append(RisoShapes.rrect(c.x - half, c.y - half, half * 2.0, half * 2.0, 0.0))
			var joint: float = 2.5
			if posmod(v.x, MARBLE_SLAB) == 0:
				slots[41].append(RisoShapes.rrect(c.x - half - joint * 0.5, c.y - half, joint, half * 2.0, 1.0))
			if posmod(v.y, MARBLE_SLAB) == 0:
				slots[41].append(RisoShapes.rrect(c.x - half, c.y - half - joint * 0.5, half * 2.0, joint, 1.0))
			if bool(item.get("slab", false)):
				var span: float = half * 2.0 * float(MARBLE_SLAB)
				var top_left: Vector2 = Vector2(c.x - half, c.y - half)
				# One soft vein wandering across the slab (now and then a fainter second), never
				# straight: a lazy wave, thick and thin by turns, the same slant all the way.
				for k: int in range(1 if _r(s, slab, 71) < 0.6 else 2):
					var pts: PackedVector2Array = PackedVector2Array()
					var lean: float = _r(s, slab, 75 + k)
					var drift: float = (0.25 + 0.35 * lean) * span * (1.0 if _r(s, slab, 78 + k) < 0.5 else -1.0)
					var y: float = span * 0.5 - drift * 0.5 + (_r(s, slab, 72 + k) - 0.5) * span * 0.3
					var wave: float = 2.0 + _r(s, slab, 80 + k) * 2.5
					for i: int in range(17):
						var u: float = float(i) / 16.0
						pts.append(top_left + Vector2(u * span, clampf(y + drift * u + sin(u * wave * PI + float(k) * 2.0) * 22.0, 12.0, span - 12.0)))
					var pieces: Array[PackedVector2Array] = strip(pts, (6.0 if k == 0 else 3.5) + 2.5 * lean, 2.0)
					for i: int in range(pieces.size()):
						if k == 0 or i % 3 != 2:
							slots[38].append(pieces[i])
		&"column":
			# A broken column: a square base, a shaft shaded down one side, snapped off at a slant.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var tall: float = 26.0 + _r(s, v, 11) * 22.0
			var wide: float = 9.0
			var cut: float = (_r(s, v, 12) - 0.5) * 10.0
			slots[8].append(RisoShapes.rrect(x - wide * 0.9, floor_y - 5.0, wide * 1.8, 7.0, 1.0))
			var shaft: PackedVector2Array = PackedVector2Array([Vector2(x - wide * 0.5, floor_y - 4.0), Vector2(x - wide * 0.5, floor_y - tall - cut), Vector2(x - wide * 0.1, floor_y - tall + 3.0), Vector2(x + wide * 0.2, floor_y - tall - 2.0), Vector2(x + wide * 0.5, floor_y - tall + cut), Vector2(x + wide * 0.5, floor_y - 4.0)])
			slots[8].append(shaft)
			slots[13].append(PackedVector2Array([Vector2(x + wide * 0.15, floor_y - 4.0), Vector2(x + wide * 0.15, floor_y - tall - 1.0), Vector2(x + wide * 0.5, floor_y - tall + cut), Vector2(x + wide * 0.5, floor_y - 4.0)]))
		&"ashlar":
			# Dressed stone on the castle's masonry, at full size: two courses to a cell, each of two
			# blocks (the courses' joints staggered), in two faint tones dealt per block, with pale
			# mortar in the joints between them (the stone's inks lifted).
			var gap: float = 3.0
			for course: int in range(2):
				var y0: float = ceil_y + float(course) * half
				var shift: float = half * 0.5 if (v.y * 2 + course) % 2 == 1 else 0.0
				# The bed joint along the top of the course.
				slots[29].append(RisoShapes.rrect(c.x - half, y0 - gap * 0.5, half * 2.0, gap, 1.0))
				for b: int in range(-1, 2):
					var bx0: float = maxf(c.x - half, c.x - half + shift + float(b) * half)
					var bx1: float = minf(c.x + half, c.x - half + shift + float(b + 1) * half)
					if bx1 - bx0 < gap * 2.0:
						continue
					var tone: int = 27 if _r(s, v, 70 + course * 3 + b) < 0.4 else 26
					slots[tone].append(RisoShapes.rrect(bx0 + gap * 0.5, y0 + gap * 0.5, bx1 - bx0 - gap, half - gap, 2.0))
					# The head joint at the block's left end, inside the cell.
					if bx0 > c.x - half + 0.5:
						slots[29].append(RisoShapes.rrect(bx0 - gap * 0.5, y0, gap, half, 1.0))
		&"slit":
			# An arrow slit through a castle wall, cut as a crossbow's is (SLIT_NICHE) but empty: a
			# dark niche in the face toward its room, and a narrow bore on from it through the stone
			# to the open air outside. Facing only the outside, the bore alone, running in from there.
			var inner: int = int(item.get("inner", 0))
			var outer: int = int(item.get("outer", 0))
			var deep: float = SLIT_NICHE.x * SLIT_SIZE
			var high: float = SLIT_NICHE.y * SLIT_SIZE
			var bore: float = SLIT_BORE * SLIT_SIZE
			var from: float = c.x - float(outer) * half
			if inner != 0:
				var face: float = c.x + float(inner) * half
				slots[28].append(RisoShapes.rrect(minf(face, face - float(inner) * deep), c.y - high * 0.5, deep, high, 6.0))
				from = face - float(inner) * (deep - 4.0 * SLIT_SIZE)
			var to: float = c.x + float(outer) * half if outer != 0 else c.x - float(inner) * half
			slots[28].append(RisoShapes.rrect(minf(from, to), c.y - bore * 0.5, absf(to - from), bore, 3.0))
		&"cross":
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var tall: float = 26.0 + _r(s, v, 11) * 12.0
			var tilt: Transform2D = Transform2D((_r(s, v, 13) - 0.5) * 0.35, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
			var cross: Array[PackedVector2Array] = [tilt * RisoShapes.rrect(x - 2.0, floor_y - tall, 4.0, tall + 2.0, 1.0), tilt * RisoShapes.rrect(x - 7.0, floor_y - tall * 0.78, 14.0, 4.0, 1.0)]
			slots[8].append_array(cross)
			slots[13].append(cross[0])
		&"fence":
			# Iron railings: bars with spear tips over two rails, a cell wide.
			var x0: float = c.x - half * 0.8
			for i: int in range(5):
				var x: float = x0 + float(i) * half * 0.4
				var tall: float = 22.0 + (3.0 if i % 2 == 0 else 0.0)
				slots[4].append(RisoShapes.rrect(x - 1.1, floor_y - tall, 2.2, tall + 2.0, 0.8))
				slots[4].append(RisoShapes.tri(Vector2(x - 2.4, floor_y - tall + 1.0), Vector2(x + 2.4, floor_y - tall + 1.0), Vector2(x, floor_y - tall - 5.0)))
			for rail_y: float in [floor_y - 6.0, floor_y - 17.0]:
				slots[4].append(RisoShapes.rrect(x0 - 2.0, rail_y, half * 1.6 + 4.0, 2.0, 0.8))
			slots[5].append(RisoShapes.rrect(x0 - 2.0, floor_y - 6.0, half * 1.6 + 4.0, 2.0, 0.8))
		&"dead_tree":
			# A bare tree: a crooked trunk forking into thin branches.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.4
			var tall: float = 50.0 + _r(s, v, 11) * 26.0
			var bend: float = (_r(s, v, 12) - 0.5) * 16.0
			var trunk: PackedVector2Array = PackedVector2Array()
			for k: int in range(6):
				var f: float = float(k) / 5.0
				trunk.append(Vector2(x + bend * f * f + sin(f * 4.0) * 2.0, floor_y + 2.0 - tall * f))
			slots[4].append_array(RisoDecor.strip(trunk, 7.0, 2.2))
			slots[5].append_array(RisoDecor.strip(trunk, 3.5, 1.0))
			for b: int in range(3 + int(_r(s, v, 13) * 3.0)):
				var f: float = 0.45 + 0.5 * _r(s, v, 20 + b)
				var from: Vector2 = Vector2(x + bend * f * f, floor_y - tall * f)
				var side: float = 1.0 if b % 2 == 0 else -1.0
				var long: float = 10.0 + _r(s, v, 30 + b) * 16.0
				var branch: PackedVector2Array = PackedVector2Array([from, from + Vector2(side * long * 0.6, -long * 0.5), from + Vector2(side * long, -long * 0.9)])
				slots[4].append_array(RisoDecor.strip(branch, 2.4, 0.8))
		&"windsock":
			# A windsock on a pole, its sock blowing out one way in bands of paper and blue.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			var tall: float = 34.0 + _r(s, v, 11) * 10.0
			var way: float = 1.0 if _r(s, v, 12) < 0.5 else -1.0
			slots[12].append(RisoShapes.rrect(x - 1.3, floor_y - tall, 2.6, tall + 2.0, 1.0))
			slots[13].append(RisoShapes.rrect(x, floor_y - tall, 1.3, tall + 2.0, 0.6))
			var droop: float = 2.0 + _r(s, v, 13) * 4.0
			for b: int in range(3):
				var a0: float = float(b) * 6.0
				var a1: float = a0 + 6.0
				var h0: float = 4.6 - float(b) * 1.0
				var h1: float = h0 - 1.0
				var y0: float = floor_y - tall + 4.0 + droop * a0 / 18.0
				var y1: float = floor_y - tall + 4.0 + droop * a1 / 18.0
				var band: PackedVector2Array = PackedVector2Array([Vector2(x + way * a0, y0 - h0), Vector2(x + way * a1, y1 - h1), Vector2(x + way * a1, y1 + h1), Vector2(x + way * a0, y0 + h0)])
				slots[8 if b % 2 == 0 else 12].append(band)
		&"cairn":
			# A pile of flat stones, largest at the bottom.
			_cairn(slots, c.x + (_r(s, v, 10) - 0.5) * half * 0.5, floor_y, 1.0, s, v, false)
		&"menhir":
			# A standing stone: a tall slab, rounded at the top, leaning a little, shaded down one side.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.5
			var tall: float = 30.0 + _r(s, v, 11) * 16.0
			var wide: float = 9.0 + _r(s, v, 12) * 5.0
			var tilt: Transform2D = Transform2D((_r(s, v, 13) - 0.5) * 0.2, Vector2(x, floor_y)) * Transform2D(0.0, Vector2(-x, -floor_y))
			var slab: PackedVector2Array = tilt * RisoShapes.smooth(PackedVector2Array([Vector2(x - wide * 0.5, floor_y + 1.0), Vector2(x - wide * 0.55, floor_y - tall * 0.6), Vector2(x - wide * 0.3, floor_y - tall), Vector2(x + wide * 0.35, floor_y - tall * 0.95), Vector2(x + wide * 0.5, floor_y - tall * 0.5), Vector2(x + wide * 0.45, floor_y + 1.0)]), 3)
			slots[12].append(slab)
			slots[13].append(tilt * PackedVector2Array([Vector2(x + wide * 0.1, floor_y + 1.0), Vector2(x + wide * 0.1, floor_y - tall * 0.9), Vector2(x + wide * 0.35, floor_y - tall * 0.95), Vector2(x + wide * 0.5, floor_y - tall * 0.5), Vector2(x + wide * 0.45, floor_y + 1.0)]))
		&"sky_roots":
			# Seeded, uneven bundles: long curling roots, fine forks and occasional hanging leaves.
			# Static chunk geometry keeps the abundant curtains inexpensive to print.
			var reach: float = half * (float(item["clearance"]) - 0.15)
			var strands: int = 2 + int(_r(s, v, 10) * 3.0)
			for i: int in range(strands):
				var salt: int = 30 + i * 9
				var x: float = c.x + (_r(s, v, salt) - 0.5) * half * 0.7
				var long: float = minf(reach, 25.0 + _r(s, v, salt + 1) * 65.0)
				var curl: float = 3.0 + _r(s, v, salt + 2) * 7.0
				var phase: float = _r(s, v, salt + 3) * TAU
				var pts: PackedVector2Array = PackedVector2Array()
				for k: int in range(10):
					var f: float = float(k) / 9.0
					pts.append(Vector2(x + sin(f * 5.0 + phase) * curl * f, ceil_y - 1.0 + long * f))
				slots[4].append_array(strip(pts, 1.5 + _r(s, v, salt + 4) * 1.4, 0.45))
				for k: int in [4, 7]:
					var side: float = 1.0 if (i + k) % 2 == 0 else -1.0
					var tip: Vector2 = pts[k] + Vector2(side * (4.0 + _r(s, v, salt + 5) * 5.0), long * 0.06)
					slots[4].append_array(strip(PackedVector2Array([pts[k], tip]), 1.2, 0.45))
					if _r(s, v, salt + k) < 0.2:
						var leaf: PackedVector2Array = Transform2D(side * 0.6, tip) * RisoShapes.almond(Vector2.ZERO, 3.8, 1.8, 8)
						slots[7].append(leaf)
						slots[6].append(leaf)
		&"tendril":
			# A wisp of cloud trailing from under an island: puffs dwindling as they hang.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var r: float = 7.0 + _r(s, v, 11) * 4.0
			var y: float = ceil_y + r * 0.4
			for i: int in range(3 + int(_r(s, v, 12) * 2.0)):
				slots[12].append(RisoShapes.circle(Vector2(x + sin(float(i) * 1.7 + _r(s, v, 13) * 6.0) * 3.0, y), r, 12))
				y += r * 1.3
				r *= 0.72
		&"cobweb":
			# A web strung under the rock: paper threads, five spokes (WEB_TURN apart) and the rings.
			var x: float = c.x + (_r(s, v, 10) - 0.5) * half * 0.6
			var top: Vector2 = Vector2(x, ceil_y - 1.0)
			var reach: float = 14.0 + _r(s, v, 11) * 10.0
			var ends: Array[Vector2] = []
			for k: int in range(5):
				var a: float = PI * 0.1 + WEB_TURN * float(k)
				ends.append(top + Vector2(cos(a), sin(a)) * reach)
			for e: Vector2 in ends:
				slots[8].append_array(RisoDecor.strip(PackedVector2Array([top, e]), WEB_W / PROP_SCALE, WEB_W / PROP_SCALE * WEB_TIP))
			for ring: float in WEB_RINGS:
				for k: int in range(4):
					slots[8].append_array(RisoDecor.strip(PackedVector2Array([top.lerp(ends[k], ring), top.lerp(ends[k + 1], ring)]), 0.8, 0.8))
		&"vine":
			var side: float = float(item["side"])
			var wall_x: float = c.x - side * half
			var long: float = 32.0 + _r(s, v, 10) * 44.0
			var pts: PackedVector2Array = PackedVector2Array()
			for k: int in range(8):
				var f: float = float(k) / 7.0
				pts.append(Vector2(wall_x + side * (3.0 + sin(f * 6.0) * 3.0), ceil_y + 4.0 + long * f))
			slots[4].append_array(RisoDecor.strip(pts, 3.2, 1.6))
			for k: int in range(1, 8):
				var flip: float = side * (1.0 if k % 2 == 0 else -0.5)
				var leaf: PackedVector2Array = Transform2D(flip * 0.9, pts[k]) * RisoShapes.almond(Vector2(flip * 5.0, 0), 5.5, 2.4, 8)
				slots[7].append(leaf)
				slots[6].append(leaf)
