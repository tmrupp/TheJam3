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
## Whether the deeper exit has been paid for, and the side-world doors paid for (by exit).
var deeper_paid: bool = false
var doors_paid: Dictionary = {}
## Side doors left open behind the wizard (by exit), and every exit taken (for the worlds map).
var lateral_open: Dictionary = {}
var ways_taken: Dictionary = {}
## Whether the shrine has been used, and the spell a swap there left in a niche ([spell, tier,
## niche], or [] for none).
var shrine_used: bool = false
var left_spell: Array = []
## The spell a relic swap left on the relic's plinth ([spell, tier], or [] for none).
var relic_left: Array = []
## Whether the ink well has been paid (the whole map inked), and what has been seen: a byte per
## cell, 1 once seen (see MapInfo.reveal).
var mapped: bool = false
var seen: PackedByteArray = PackedByteArray()
## Chasms bridged (or blown over), by chasm; the cell each chasm's wind blows from; bells and vanes
## unchained, by cell; secret rooms opened, by number; lanterns burned out, by cell; switches
## thrown, by cell.
var bridges: Dictionary = {}
var winds: Dictionary = {}
var bells_free: Dictionary = {}
var secrets: Dictionary = {}
var spent_lanterns: Dictionary = {}
var switched: Dictionary = {}
## The wizard's own teleporters standing here (Rift): their positions.
var rifts: Array = []

## Every field saved, in the order they are written.
const FIELDS: Array[StringName] = [&"taken", &"opened", &"slain", &"broken", &"dropped", &"next_drop", &"deeper_paid",
	&"doors_paid", &"lateral_open", &"ways_taken", &"shrine_used", &"left_spell", &"relic_left", &"mapped", &"seen",
	&"bridges", &"winds", &"bells_free", &"secrets", &"spent_lanterns", &"switched", &"rifts"]


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


## The seen bytes for a level of `cells` cells, made fresh if they were for another size.
func seen_for(cells: int) -> PackedByteArray:
	if seen.size() != cells:
		seen = PackedByteArray()
		seen.resize(cells)
	return seen
