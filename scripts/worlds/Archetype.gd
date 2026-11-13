class_name Archetype
extends RefCounted
## What kind of level a band of depths holds (see Bands): the terrain it is
## collapsed from, how big it is, the realm it prints in, how it is gated, and what it adds to an
## ordinary level's dressing (LevelGen.populate_level calls the hooks below at fixed points, so an
## archetype never shifts what the others lay out). The base is plain caves with no extras.
##
## To add a band: extend this (GardenArchetype is the smallest example, SkyArchetype the fullest),
## set its look and feel in _init (the vars below), override the hooks it needs, then list it in
## Bands.LAYOUTS. Its art is chosen by name: its decor plan (`decor`, a RisoDecor.PLANS
## entry) and its realm (its colours in RisoPrint.REALMS, its backdrop in RisoBackground), each
## falling back to the garden's decor and the night backdrop, so a new band works before it has art
## of its own.

## Its name: how levels of it are told apart (NextWorldDef.archetype), and its print realm.
var name: StringName = &""
## What its title card says on the way in (RisoTransition.title).
var title: String = ""
## The decor its levels wear (RisoDecor.PLANS): the garden's unless it sets its own.
var decor: StringName = &"garden"
## The WFC sample its terrain is collapsed from.
var sample: String = ""
## The collapse's symmetry (see NextWorldDef.symmetry): 1 keeps up up.
var symmetry: int = 5
## Which of the eight turned and flipped versions of the sample's pieces the collapse uses instead,
## a bit each (see NextWorldDef.symmetry_mask); 0 (the usual) keeps to `symmetry`. A band's "tune"
## may set it (Bands.LAYOUTS), say to 33 for upright and mirrored.
var symmetry_mask: int = 0
## Whether its sample is a sheet of clusters, with open sky (LevelGen.SKY) between and round them,
## not one picture to collapse. Each cluster on the sheet is then a sample of its own, and each
## cluster of a level is collapsed afresh from one of them
## (WaveFunctionCollapse.collapse_clusters). The sky's.
var clustered: bool = false
## How much bigger than Rules.level_size its levels are, across and down (size_for).
var scale: Vector2 = Vector2.ONE
## Whether its levels are gated by chasms (see Chasms), crossed at `crossing`s.
var chasmed: bool = false
## Whether its lifts are rolling ladders (RollingLadder, LevelGen.make_moving): the institute's.
var ladders: bool = false
## What stands on each side of a chasm to cross it: a bell (bridges) or a vane (wind).
var crossing: LevelGen.Type = LevelGen.Type.BELL
## How far (cells) from its crossing a crossing's switch may be, or -1 for anywhere on its side.
var switch_reach: int = -1
## How far back from its gap (cells, from and to) one of each gap's two crossings stands, on a side
## dealt by the level seed (Chasms.place_bells); zero for both at the gap's edges.
var crossing_back: Vector2i = Vector2i.ZERO
## Whether its levels lie open to the sky: no rock round them, a drop below (Player.fall_back),
## and the camera goes past the edges (LevelLoader.SKY_MARGIN).
var open: bool = false
## How dark its levels are (RisoLight): how much night ink lies over everything the lanterns and
## glowing things do not light (`gloom`, a deep darkness all over; no band sets it now, the darkness
## lying in the cemetery's crypts instead, Crypts).
var gloom: float = 0.0
## How thickly an ordinary level of it is dressed (LevelGen.populate_level), before its own passes:
## the share of its open cells given a star (`star_share`), a wisp (`wisp_share`) and a watcher
## (`watcher_share`), the foes' times the difficulty's (Difficulty.foes), and hoppers per 1000 cells
## from depth 1 (`hoppers_per_k`). A band's line in Bands.LAYOUTS may set any of these ("tune").
var star_share: float = 0.2
var wisp_share: float = 0.2
var watcher_share: float = 0.1
var hoppers_per_k: float = LevelGen.HOPPERS_PER_K


## Small insides collapsed with each of its levels' terrain, from samples of their own, for its
## structures to be built round (the cemetery's crypts and their trials, Crypts): each {"sample":
## the WFC sample, "size": cells across and down, and optionally "slices": &"columns" or &"rows", to
## collapse it by its columns or rows, see WaveFunctionCollapse}. The level gets them as
## LevelGen.patches, in this order. None unless it sets them.
func patches(_def: NextWorldDef) -> Array[Dictionary]:
	return []


## The print realm (RisoPrint.REALMS) its levels print in.
func realm() -> StringName:
	return name


## Before the caves are joined: reshape the collapsed terrain (the sky keeps its islands only in
## clusters).
func shape(_w: LevelGen) -> void:
	pass


## Right after the caves are joined: cut the level's gates (chasms or gaps), before anything else
## is placed.
func cut_gates(_w: LevelGen) -> void:
	pass


## Whether a star (`grow` 3) or a ledge (`grow` 1) may go at `v`: everywhere, unless the archetype
## keeps open stretches clear (the sky, between its clusters).
func room(_w: LevelGen, _v: Vector2i, _grow: int) -> bool:
	return true


## Its own dressing, on top of an ordinary level's (after the hoppers, so the rest of the level
## lands as it would without it).
## How big its levels are at `depth` (cells across and down): Rules.level_size, `scale` times.
func size_for(depth: int) -> Vector2i:
	return Vector2i((Vector2(Rules.level_size(depth)) * scale).round())


func populate(_w: LevelGen, _def: NextWorldDef) -> void:
	pass


## Its last dressing, once everything else is laid (the secret rooms, vaults and crossings too), so
## nothing else in the level moves for it.
func finish(_w: LevelGen, _def: NextWorldDef) -> void:
	pass
