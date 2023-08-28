extends MarginContainer

@onready var button = $Button
@onready var upgrader = $"../../../../UpgradeManager"
@onready var label = $VBoxContainer/Label
var upgrade
var player

var upgrade_text = "{name}\nCost:{cost}\n{description}"

func get_player ():
	player = $"/root/Main/Player"
	return player

func setup ():
	button.disabled = true
	upgrade = upgrader.get_upgrade()
	label.text = upgrade_text.format(upgrade.format())
	if get_player() != null and player.coins.coins > upgrade.cost:
		button.disabled = false

func select ():
	button.disabled = true
	player.collect(-upgrade.cost)
	upgrade.attach(player)
	
# Called when the node enters the scene tree for the first time.
func _ready():
	upgrade = upgrader.get_upgrade()
	label.text = upgrade_text.format(upgrade.format())
	button.connect("button_down", select)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
