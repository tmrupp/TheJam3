class_name LevelRecord
extends RefCounted
## What changed in one visited place. Levels regenerate identically from their seed (LevelGen),
## then their record is applied as they load: pickups taken, doors opened, enemies slain, rock
## broken, exits paid for, bells rung, what has been seen. Kept by the run (RunState.records) and
## saved with it (to_dict, from_dict). Cells are level cells; most sets are {cell: true}.

## Pickups taken (stars, keys, relics, clusters), by cell.
var taken: Dictionary = {}
## Doors and switch gates opened, by cell.
var opened: Dictionary = {}
## Enemies slain, by cell: they stay gone until the wizard dies (RunState.revive_slain).
var slain: Dictionary = {}
## Cracked rock broken (and a secret room's rock once it opens), by cell.
var broken: Dictionary = {}
## Keys left lying in the level (swapped off a full ring, or sold by a shrine): id -> [position,
## colour]; the next one gets `next_drop`.
var dropped: Dictionary = {}
var next_drop: int = 0
## Whether the way on has been paid for (and, at the start, its way up), and the side-world
## doors paid for (by exit).
var deeper_paid: bool = false
var up_paid: bool = false
var doors_paid: Dictionary = {}
## Side doors left open behind the wizard (by exit), and every exit taken (for the worlds map).
var lateral_open: Dictionary = {}
var ways_taken: Dictionary = {}
## Whether the shrine has been used.
var shrine_used: bool = false
## Whether the ink well has been paid (the whole map inked), and what has been seen: a byte per
## cell, 1 once seen (see MapInfo.reveal).
var mapped: bool = false
var seen: PackedByteArray = PackedByteArray()
## Chasms bridged, by chasm; bells and vanes unchained, by cell; secret rooms opened, by number;
## lanterns burned out, by cell; switches thrown, by cell.
var bridges: Dictionary = {}
var bells_free: Dictionary = {}
var secrets: Dictionary = {}
var spent_lanterns: Dictionary = {}
var switched: Dictionary = {}
## Sky levels: the vanes switched on, by cell (each to the way it points, +1 right or -1 left), and
## the way the level's wind turned last (the way of the vane last switched on; 0 before any was).
## The wind itself is Rules.wind_of.
var vanes_on: Dictionary = {}
var wind_way: int = 0
## Whether its temple has been opened, and how many steps of its lock are lit (Temple).
var temple_open: bool = false
var temple_progress: int = 0
## Mending bowls standing on their own used (MendWell), by cell.
var mended: Dictionary = {}
## The wizard's own teleporters standing here (Rift): their positions.
var rifts: Array = []
## The institute: its masters' lessons (Lesson), by the master's cell: {"at": where it fell,
## "ability", "taken"}.
var lessons: Dictionary = {}
## The institute's timetable (Timetable): how many times its great bell has rung (the period is this
## counted round Timetable.PERIODS), whether it is passing time, the lecterns' papers lifted (by
## hall and rings, MapInfo.lectern_swap), and the paper left on each classroom's lectern (hall ->
## code, the pigeonholes).
var rings: int = 0
var passing: bool = true
## The classroom whose class the wizard started by its cord (MapInfo.pull_cord), until the period is
## rung out (-1 for none), and the cord rung last (none may be rung twice running).
var started: int = -1
var last_bell: Vector2i = Vector2i(-1, -1)
## The period (by LevelRecord.rings) the wizard last studied at the library's desk in, or -1: once a
## period (MapInfo.study_at_desk).
var studied: int = -1
## Whether the way on has taken the exam paper its classroom asks for (MapInfo.hand_in_way_on): it
## asks no more.
var way_on_paid: bool = false
var lifted: Dictionary = {}
var pigeonholes: Dictionary = {}
## Each department's tier in the level (department -> tier; one not yet climbed is at I,
## Timetable.climb).
var dept_tiers: Dictionary = {}
## The classrooms whose master, beaten by the wizard, has left its top-tier paper (by hall,
## MapInfo.instructor_fell).
var prizes: Dictionary = {}
## Relics left lying by beaten masters (MapInfo.relic_left), by id (from next_drop): [where, the
## move, whether it is the level's own relic].
var relics_left: Dictionary = {}
## The crags: which of its gondola's stations are on, a bit each from the bottom (-1 before the first
## visit deals them: only the one nearest the way in on; MapInfo.station_on, flip_tower).
var stations: int = -1
## The crags' cold towers woken by an empowered strike on their spire (Spire), by tower number: their
## switches work from then on (MapInfo.tower_cold).
var woken: Dictionary = {}

## Every field saved, in the order they are written.
const FIELDS: Array[StringName] = [&"taken", &"opened", &"slain", &"broken", &"dropped", &"next_drop", &"deeper_paid", &"up_paid",
	&"doors_paid", &"lateral_open", &"ways_taken", &"shrine_used", &"mapped", &"seen",
	&"bridges", &"vanes_on", &"wind_way", &"temple_open", &"temple_progress", &"bells_free", &"secrets", &"spent_lanterns", &"switched", &"rifts", &"mended", &"lessons", &"stations", &"rings", &"passing", &"lifted", &"pigeonholes", &"prizes", &"dept_tiers", &"relics_left", &"started", &"last_bell", &"way_on_paid", &"studied", &"woken"]


## The record as a plain dictionary, for the save file.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for f: StringName in FIELDS:
		out[String(f)] = get(f)
	return out


## A record read back from a saved dictionary (older saves may lack some fields: they keep their
## defaults).
static func from_dict(data: Dictionary) -> LevelRecord:
	var rec: LevelRecord = LevelRecord.new()
	for f: StringName in FIELDS:
		if data.has(String(f)):
			rec.set(f, data[String(f)])
	return rec


## Leave a key of `color` lying at `pos`: kept until taken. Returns its id.
func drop_key(pos: Vector2, color: int) -> int:
	var id: int = next_drop
	next_drop = id + 1
	dropped[id] = [pos, color]
	return id


## The seen bytes for a level of `cells` cells, made fresh if they were for another size (all seen
## if its map was inked whole before its layout was known: MapInfo.ink_place).
func seen_for(cells: int) -> PackedByteArray:
	if seen.size() != cells:
		seen = PackedByteArray()
		seen.resize(cells)
		if mapped:
			seen.fill(1)
	return seen
