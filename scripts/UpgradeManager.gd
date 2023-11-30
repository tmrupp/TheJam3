extends Node

class_name UpgradeManager

var upgrades: Array[Upgrade] = [
				#name			#cost	#description					# prefab
	Upgrade.new("Double Jump", 	0, 	"Do a barrelroll!", 			"res://prefabs/upgrades/DoubleJump.tscn"),
	Upgrade.new("Blink", 		0, 	"Do blink or you'll miss it", 	"res://prefabs/upgrades/Blink.tscn"),
	Upgrade.new("Wall Climb", 	0, 	"slow down, grab the wall", 	"res://prefabs/upgrades/WallClimb.tscn"),
]

func get_upgrade (i: int = -1) -> Upgrade:
	if i < 0:
		return upgrades[randi_range(0, len(upgrades)-1)]
	else:
		return upgrades[i]
