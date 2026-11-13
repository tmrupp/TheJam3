class_name InstituteRecord
extends RefCounted
## What changed in one level of the institute, apart from the rest of the level's record
## (LevelRecord.institute; docs/CODE_REVIEW.md 2.2): the band's own part of the record, kept by
## the band and saved under its name. InstitutePlay plays it out; Timetable's rules read it.

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
## The period (by rings) the wizard last studied at the library's desk in, or -1: once a
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

## Every field saved, in the order they are written.
const FIELDS: Array[StringName] = [&"lessons", &"rings", &"passing", &"started", &"last_bell", &"studied", &"way_on_paid", &"lifted", &"pigeonholes", &"dept_tiers", &"prizes", &"relics_left"]


## The record as a plain dictionary, for the save file.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for f: StringName in FIELDS:
		out[String(f)] = get(f)
	return out


## A record read back from a saved dictionary (fields it lacks keep their defaults).
static func from_dict(data: Dictionary) -> InstituteRecord:
	var rec: InstituteRecord = InstituteRecord.new()
	for f: StringName in FIELDS:
		if data.has(String(f)):
			rec.set(f, data[String(f)])
	return rec
