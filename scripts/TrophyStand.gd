extends Node2D
class_name TrophyStand
## A trophy stand, in the room by the tutorial's way out: one for each boss in the band layout
## (Tutorial, Bands.bosses), empty until the wizard comes by carrying that boss's trophy (Trophy),
## which they set on it there and then (MapInfo.set_trophy). Set, it stays for the rest of the run.
## With every boss's trophy set, the run is won (MapInfo.win_run).

## How close the wizard must come to set the trophy, across and up or down (world pixels).
const REACH: Vector2 = Vector2(80, 140)

var map_info: MapInfo
## The boss whose trophy it holds.
var boss: StringName = &""


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)


## Whether its boss's trophy is on it.
func is_set() -> bool:
	return map_info != null and int(map_info.run.trophies.get(boss, 0)) == Trophy.SET


## Whether the wizard carries its boss's trophy.
func awaited() -> bool:
	return map_info != null and int(map_info.run.trophies.get(boss, 0)) == Trophy.CARRIED


func _process(_delta: float) -> void:
	var player: Player = Stage.player()
	if player == null or not awaited() or map_info.travelling or map_info.run_ending > 0.0:
		return
	var d: Vector2 = (player.global_position - global_position).abs()
	if d.x < REACH.x and d.y < REACH.y:
		map_info.set_trophy(boss, global_position)
