class_name Upgrade

var cost : int = 100
var name : String = "Double Jump"
var description : String = "Get an additional jump"
var effect : String
var prereqs = []

func _init(_name, _cost, _description, _effect, _prereqs=[]):
	cost = _cost
	name = _name
	description = _description
	effect = _effect

func format ():
	return {
		"name": name,
		"cost": str(cost),
		"description": description
	}

func attach (player):
	player.add_child(load(effect).instantiate())
