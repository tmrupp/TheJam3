class_name Placeables
extends RefCounted
## What each kind of thing a level holds (LevelGen.Type) is in the game, in one place: the prefab
## MapInfo loads for it, the ink art RisoPrint dresses it in (a RisoProp kind, see RisoPrint.DRESS),
## the box of cells it takes, and what is true of it (FLAGS). A new hazard or enemy is a prefab, a
## script, a RisoProp kind, a LevelGen.Type, an entry here, and a populate pass that places it.
##
## The flags:
## - enemy: a nightmare. It gets a Wound (hex bolts and the dash hurt it), is a hex target, and
##   stays slain until the wizard dies (MapInfo.mark_slain).
## - stander: something you stand at to use it. It always keeps something under it: where the rock
##   under one is broken, a ledge appears in its place (MapInfo.prop_up, LevelGen._holds_up).
## - floats: a floating pickup, set anywhere inside its cell rather than on the grid (LevelLoader.JITTER).
## - colored: it carries a key colour (meta "key_color"), dealt with the level (LevelGen.deal_colors).

## Type -> {"scene": prefab path, "art": RisoProp kind (&"" when the terrain prints it), "flags":
## [StringName], "size": cells across and up from its own cell, where more than one (LevelGen.make_room),
## "setup": how many things its prefab's `setup` takes as it is placed (LevelLoader.place_cell): 2
## for (the MapInfo, its cell), 3 for those and its cell's extra info; none when it has no setup}.
## unit_test checks each count against the prefab's script.
const TABLE: Dictionary = {
	LevelGen.Type.MOON: {"scene": "res://prefabs/moon.tscn", "art": &"moon", "flags": [&"floats"], "setup": 2},
	LevelGen.Type.SPIKES: {"scene": "res://prefabs/spikes.tscn", "art": &"thorns", "setup": 2},
	LevelGen.Type.ENEMY: {"scene": "res://prefabs/mover_enemy.tscn", "art": &"wisp", "flags": [&"enemy"]},
	LevelGen.Type.SHOOTER: {"scene": "res://prefabs/shooter_enemy.tscn", "art": &"watcher", "flags": [&"enemy"]},
	LevelGen.Type.COIN: {"scene": "res://prefabs/coin.tscn", "art": &"mote", "flags": [&"floats"]},
	LevelGen.Type.KEY: {"scene": "res://prefabs/key.tscn", "art": &"key", "flags": [&"floats", &"colored"], "setup": 2},
	LevelGen.Type.DOOR: {"scene": "res://prefabs/door.tscn", "art": &"door", "flags": [&"colored"]},
	LevelGen.Type.CHECKPOINT: {"scene": "res://prefabs/checkpoint.tscn", "art": &"lantern", "flags": [&"stander"], "size": Vector2i(1, 2)},
	LevelGen.Type.PORTAL: {"scene": "res://prefabs/portal.tscn", "art": &"portal", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 3},
	LevelGen.Type.PLATFORM: {"scene": "res://prefabs/platform.tscn", "art": &""},
	LevelGen.Type.MOVING_PLATFORM: {"scene": "res://prefabs/moving_platform.tscn", "art": &"lift", "setup": 3},
	LevelGen.Type.ROLLING_LADDER: {"scene": "res://prefabs/rolling_ladder.tscn", "art": &"ladder", "setup": 3},
	LevelGen.Type.EXIT: {"scene": "res://prefabs/level_exit.tscn", "art": &"exit", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 3},
	LevelGen.Type.SHRINE: {"scene": "res://prefabs/shrine.tscn", "art": &"shrine", "flags": [&"stander"], "size": Vector2i(2, 2), "setup": 2},
	LevelGen.Type.CRACKED: {"scene": "res://prefabs/cracked_wall.tscn", "art": &"cracked", "setup": 2},
	LevelGen.Type.INKWELL: {"scene": "res://prefabs/inkwell.tscn", "art": &"inkwell", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 2},
	LevelGen.Type.SWITCH_GATE: {"scene": "res://prefabs/switch_gate.tscn", "art": &"gate", "setup": 3},
	LevelGen.Type.SWITCH: {"scene": "res://prefabs/switch.tscn", "art": &"switch", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.HOPPER: {"scene": "res://prefabs/hopper_enemy.tscn", "art": &"hopper", "flags": [&"enemy"]},
	LevelGen.Type.LASER: {"scene": "res://prefabs/laser.tscn", "art": &"laser", "setup": 3},
	LevelGen.Type.RELIC: {"scene": "res://prefabs/relic.tscn", "art": &"relic", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 3},
	LevelGen.Type.CLUSTER: {"scene": "res://prefabs/star_cluster.tscn", "art": &"cluster"},
	LevelGen.Type.MOTHS: {"scene": "res://prefabs/moths.tscn", "art": &"moths", "setup": 2},
	LevelGen.Type.FOG: {"scene": "res://prefabs/sleep_fog.tscn", "art": &"fog", "setup": 2},
	LevelGen.Type.WRAITH: {"scene": "res://prefabs/wraith_enemy.tscn", "art": &"wraith", "flags": [&"enemy"]},
	LevelGen.Type.BRIDGE: {"scene": "res://prefabs/bridge.tscn", "art": &"bridge", "setup": 3},
	LevelGen.Type.BELL: {"scene": "res://prefabs/bell.tscn", "art": &"bell", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.PAD: {"scene": "res://prefabs/pad.tscn", "art": &"pad", "flags": [&"stander"]},
	LevelGen.Type.PUFF: {"scene": "res://prefabs/puff.tscn", "art": &"puff"},
	LevelGen.Type.VANE: {"scene": "res://prefabs/vane.tscn", "art": &"vane", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.WIND: {"scene": "res://prefabs/wind.tscn", "art": &"wind", "setup": 3},
	LevelGen.Type.BIRD: {"scene": "res://prefabs/bird_enemy.tscn", "art": &"bird", "flags": [&"enemy"]},
	LevelGen.Type.BOSS: {"scene": "res://prefabs/boss.tscn", "art": &"wisp", "flags": [&"enemy"], "setup": 3},
	LevelGen.Type.GONDOLA: {"scene": "res://prefabs/gondola.tscn", "art": &"gondola", "setup": 3},
	LevelGen.Type.TOLL: {"scene": "res://prefabs/toll_gate.tscn", "art": &"toll", "setup": 3},
	LevelGen.Type.BUG: {"scene": "res://prefabs/rock_bug.tscn", "art": &"rockbug", "flags": [&"enemy"]},
	LevelGen.Type.STALACTITE: {"scene": "res://prefabs/stalactite.tscn", "art": &"stalactite", "setup": 2},
	LevelGen.Type.TRAPDOOR: {"scene": "res://prefabs/trapdoor.tscn", "art": &"trapdoor"},
	LevelGen.Type.NEST: {"scene": "res://prefabs/bug_nest.tscn", "art": &"nest", "flags": [&"enemy"], "setup": 2},
	LevelGen.Type.DRAUGHT: {"scene": "res://prefabs/draught.tscn", "art": &"draught", "flags": [&"floats"]},
	LevelGen.Type.WELL: {"scene": "res://prefabs/mend_well.tscn", "art": &"well", "flags": [&"stander"], "setup": 2},
	LevelGen.Type.TEMPLE: {"scene": "res://prefabs/temple.tscn", "art": &"temple", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 3},
	LevelGen.Type.BALLOON: {"scene": "res://prefabs/balloon.tscn", "art": &"balloon", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 2},
	LevelGen.Type.CROSSBOW: {"scene": "res://prefabs/crossbow.tscn", "art": &"crossbow", "flags": [&"enemy"], "setup": 3},
	LevelGen.Type.SNUFFER: {"scene": "res://prefabs/snuffer.tscn", "art": &"snuffer", "flags": [&"stander"], "setup": 2},
	LevelGen.Type.SKELETON: {"scene": "res://prefabs/skeleton_enemy.tscn", "art": &"skeleton", "flags": [&"enemy"]},
	LevelGen.Type.LIGHT_GATE: {"scene": "res://prefabs/light_gate.tscn", "art": &"lightgate", "setup": 3},
	LevelGen.Type.STUDENT: {"scene": "res://prefabs/student.tscn", "art": &"scholar", "flags": [&"enemy"], "setup": 3},
	LevelGen.Type.MASTER: {"scene": "res://prefabs/master.tscn", "art": &"scholar", "flags": [&"enemy"], "setup": 3},
	LevelGen.Type.PROCTOR: {"scene": "res://prefabs/proctor.tscn", "art": &"scholar", "flags": [&"enemy"], "setup": 3},
	LevelGen.Type.LIBRARIAN: {"scene": "res://prefabs/librarian.tscn", "art": &"scholar", "flags": [&"enemy"], "setup": 3},
	LevelGen.Type.ABOMINATION: {"scene": "res://prefabs/abomination.tscn", "art": &"abomination", "flags": [&"enemy"]},
	LevelGen.Type.BREACH: {"scene": "res://prefabs/breach.tscn", "art": &"breach", "flags": [&"enemy"], "setup": 2},
	LevelGen.Type.EXAM_DOOR: {"scene": "res://prefabs/exam_door.tscn", "art": &"examdoor", "setup": 3},
	LevelGen.Type.DEPARTMENT: {"scene": "res://prefabs/department.tscn", "art": &"department", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 3},
	LevelGen.Type.STATION_GATE: {"scene": "res://prefabs/switch_gate.tscn", "art": &"gate", "setup": 3},
	LevelGen.Type.TOWER_SWITCH: {"scene": "res://prefabs/tower_switch.tscn", "art": &"towerswitch", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.SCHOOL_BELL: {"scene": "res://prefabs/school_bell.tscn", "art": &"schoolbell", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.LECTERN: {"scene": "res://prefabs/lectern.tscn", "art": &"lectern", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.STUDY_DESK: {"scene": "res://prefabs/study_desk.tscn", "art": &"studydesk", "flags": [&"stander"], "setup": 3},
	LevelGen.Type.TIMETABLE_BOARD: {"scene": "res://prefabs/timetable_board.tscn", "art": &"board", "setup": 3},
	LevelGen.Type.PHASE_BLOCK: {"scene": "res://prefabs/phase_block.tscn", "art": &"phaseblock", "setup": 3},
	LevelGen.Type.OSSUARY_DOOR: {"scene": "res://prefabs/ossuary_door.tscn", "art": &"ossuary", "setup": 3},
	LevelGen.Type.SPIRE: {"scene": "res://prefabs/spire.tscn", "art": &"spire", "setup": 3},
	LevelGen.Type.LODESTONE: {"scene": "res://prefabs/lodestone.tscn", "art": &"lodestone", "flags": [&"stander"], "size": Vector2i(1, 2), "setup": 3},
	LevelGen.Type.ACID: {"scene": "res://prefabs/acid.tscn", "art": &"acid", "setup": 3},
	LevelGen.Type.WRECK: {"scene": "res://prefabs/wreck.tscn", "art": &"wreck", "setup": 3},
	LevelGen.Type.TALLY: {"scene": "res://prefabs/practice_tally.tscn", "art": &"", "setup": 2},
}

## Prefabs loaded so far, by Type (each is loaded the first time one is placed).
static var _scenes: Dictionary = {}
## Type by prefab path (see type_of).
static var _by_path: Dictionary = {}


## Whether `type` is placed in the scene at all (rock and open air are not).
static func placed(type: LevelGen.Type) -> bool:
	return TABLE.has(type)


## The prefab for `type`.
static func scene(type: LevelGen.Type) -> PackedScene:
	if not _scenes.has(type):
		_scenes[type] = load(String(TABLE[type]["scene"]))
	return _scenes[type]


## Whether `type` has `flag` (see the class description).
static func has_flag(type: LevelGen.Type, flag: StringName) -> bool:
	return TABLE.has(type) and flag in (TABLE[type].get("flags", []) as Array)


## How many things the prefab for `type` takes in its `setup` (see TABLE), or 0 when it has none.
static func setup_args(type: LevelGen.Type) -> int:
	return int(TABLE[type].get("setup", 0)) if TABLE.has(type) else 0


## The cells across and up `type` takes from its own cell (the bottom left).
static func size(type: LevelGen.Type) -> Vector2i:
	return TABLE[type].get("size", Vector2i.ONE) if TABLE.has(type) else Vector2i.ONE


## The ink art (RisoProp kind) a prefab at `path` is dressed in, by its Type, or &"".
static func art_for_scene(path: String) -> StringName:
	var type: int = type_of_scene(path)
	return TABLE[type]["art"] if type >= 0 else &""


## The Type whose prefab is at `path`, or -1.
static func type_of_scene(path: String) -> int:
	if _by_path.is_empty():
		for t: int in TABLE:
			_by_path[String(TABLE[t]["scene"])] = t
	return int(_by_path.get(path, -1))


## The Type a node in the scene was placed as (by its prefab), or -1.
static func type_of(node: Node) -> int:
	return type_of_scene(node.scene_file_path)
