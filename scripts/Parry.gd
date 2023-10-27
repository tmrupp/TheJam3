extends Node2D

var duration: float = 0.3
@onready var player: Player = $".."
@onready var area: Area2D = $"Area2D"
@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D
var scaling: float = 1.1
@onready var timer: Timer = $Timer
@onready var cooldown: ActionTimer = ActionTimer.new(2.0, player.refresh_self)

func stop_parry () -> void:
	player.hurt_ability = player.normal_hurt
	collider.disabled = true
	sprite.visible = false

func parry (_damage: int, _v: Vector2, origin: Node) -> void:
	var stunner: Stunner = origin.attacker.get_node_or_null("Stunner")
	if stunner:
		stunner.stun()
		stop_parry()
		cooldown.refresh()
		timer.stop()

func check_parry () -> void:
	player.hurt_ability = parry
	sprite.visible = true
	timer.start(duration)

func execute () -> void:
	if not cooldown.acted:
		cooldown.enable()
		collider.disabled = false
		check_parry()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.parry.connect(execute)
	player.timers.append(cooldown)
	
	timer.connect("timeout", stop_parry)
	timer.one_shot = true
	
	area.scale = player.scale*scaling
	collider = player.get_node("CollisionShape2D").duplicate()
	area.add_child(collider)
	collider.disabled = true
