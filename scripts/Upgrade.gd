class_name Upgrade

var cost : int = 100
var name : String = "Double Jump"
var description : String = "Get an additional jump"
var effect : String
var prereqs: Array[Upgrade] = []

func _init(_name: String, _cost: int, _description: String, _effect: String, _prereqs:Array[Upgrade]=[]) -> void:
	cost = _cost
	name = _name
	description = _description
	effect = _effect

func format () -> Dictionary:
	return {
		"name": name,
		"cost": str(cost),
		"description": description
	}

func attach (player: Player) -> void:
	player.add_child(load(effect).instantiate())
