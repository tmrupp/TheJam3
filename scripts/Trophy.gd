extends Node2D
class_name Trophy
## A boss's trophy: its seal, won (Bosses, RisoMarks.trophy). As a boss falls it drops one beside
## its relic (MapInfo.boss_slain), and it waits there until the wizard touches it. Then it is theirs
## for the rest of the run (RunState.trophies), through a death at a lantern but not past the end of
## the run, until they bring it back to its stand in the room by the tutorial's way out
## (TrophyStand). With every boss's trophy on its stand, the run is won (MapInfo.win_run).

## Where a trophy is in the run (RunState.trophies): carried by the wizard, or set on its stand.
const CARRIED: int = 1
const SET: int = 2
## How close the wizard must come to pick it up, across and up or down (world pixels).
const REACH: Vector2 = Vector2(60, 100)

var map_info: MapInfo
## The boss it is the trophy of.
var boss: StringName = &""


func setup(info: MapInfo, which: StringName) -> void:
	map_info = info
	boss = which


func _process(_delta: float) -> void:
	var player: Player = Stage.player()
	if map_info == null or player == null or map_info.travelling or map_info.run_ending > 0.0:
		return
	var d: Vector2 = (player.global_position - global_position).abs()
	if d.x < REACH.x and d.y < REACH.y:
		map_info.trophy_taken(boss, global_position)
		queue_free()
