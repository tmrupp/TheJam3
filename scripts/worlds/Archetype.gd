class_name Archetype
extends RefCounted
## What kind of level a band of depths holds (see NextWorldDef.ARCHETYPES): the terrain it is
## collapsed from, how big it is, the realm it prints in, how it is gated, and what it adds to an
## ordinary level's dressing (LevelGen.populate_level calls the hooks below at fixed points, so an
## archetype never shifts what the others lay out). The base is plain caves with no extras.
##
## To add a band: extend this (GardenArchetype is the smallest example, SkyArchetype the fullest),
## set its look and feel in _init (the vars below), override the hooks it needs, then list it in
## NextWorldDef.ARCHETYPES. Its art is chosen by name: its decor plan (`decor`, a RisoDecor.PLANS
## entry) and its realm (its colours in RisoPrint.REALMS, its backdrop in RisoBackground), each
## falling back to the garden's decor and the night backdrop, so a new band works before it has art
## of its own.

## Its name: how levels of it are told apart (NextWorldDef.archetype), and its print realm.
var name: StringName = &""
## The decor its levels wear (RisoDecor.PLANS): the garden's unless it sets its own.
var decor: StringName = &"garden"
## The WFC sample its terrain is collapsed from.
var sample: String = ""
## The collapse's symmetry (see NextWorldDef.symmetry): 1 keeps up up.
var symmetry: int = 5
## How much bigger than Rules.level_size its levels are, across and down.
var scale: Vector2 = Vector2.ONE
## Whether its levels are gated by chasms (see Chasms), crossed at `crossing`s.
var chasmed: bool = false
## What stands on each side of a chasm to cross it: a bell (bridges) or a vane (wind).
var crossing: LevelGen.Type = LevelGen.Type.BELL
## How far (cells) from its crossing a crossing's switch may be, or -1 for anywhere on its side.
var switch_reach: int = -1
## Whether its levels lie open to the sky: no rock round them, a drop below (Player.fall_back),
## and the camera goes past the edges (LevelLoader.SKY_MARGIN).
var open: bool = false


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
func populate(_w: LevelGen, _def: NextWorldDef) -> void:
	pass
