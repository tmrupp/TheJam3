extends MarginContainer

@onready var button: Button = $Button
@onready var upgrader: UpgradeManager = $"../../../../UpgradeManager"
@onready var label: Label = $VBoxContainer/Label
var upgrade: Upgrade
var player: Player

var upgrade_text: String = "{name}\nCost:{cost}\n{description}"

func get_player () -> Player:
	player = $"/root/Main/Player"
	return player

func setup () -> void:
	button.disabled = true
	upgrade = upgrader.get_upgrade()
	label.text = upgrade_text.format(upgrade.format())
	if get_player() != null and player.coins.coins > upgrade.cost:
		button.disabled = false

func select () -> void:
	button.disabled = true
	player.collect(-upgrade.cost)
	upgrade.attach(player)

func focused () -> void:
	button.grab_focus()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	upgrade = upgrader.get_upgrade()
	label.text = upgrade_text.format(upgrade.format())
	button.connect("button_down", select)
	
	connect("focus_entered", focused)
