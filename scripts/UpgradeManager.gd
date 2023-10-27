extends Node

class_name UpgradeManager

var upgrades: Array[Upgrade] = [
				#name			#cost	#description					# prefab
	Upgrade.new("Double Jump", 	30, 	"Do a barrelroll!", 			"res://prefabs/upgrades/DoubleJump.tscn"),
	Upgrade.new("Blink", 		40, 	"Do blink or you'll miss it", 	"res://prefabs/upgrades/Blink.tscn"),
]

func get_upgrade () -> Upgrade:
	return upgrades[randi_range(0, len(upgrades)-1)]
