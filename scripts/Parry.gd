extends Node2D

var duration = 0.75
@onready var player = $".."
@onready var area = $"Area2D"
@onready var sprite = $Sprite2D
@onready var collider
var scaling = 1.1
var timer
@onready var cooldown = ActionTimer.new(1.0, player.refresh_self)
var old_hurt

func stop_parry ():
	player.hurt_ability = player.normal_hurt
	collider.disabled = true
	sprite.visible = false

func parry (damage, v, origin):
	var stunner = origin.attacker.get_node_or_null("Stunner")
	if stunner:
		stunner.stun()

func check_parry ():
	player.hurt_ability = parry
	sprite.visible = true
	await get_tree().create_timer(duration).timeout
	stop_parry()

func execute ():
	if not cooldown.acted:
		cooldown.enable()
		collider.disabled = false
		check_parry()

# Called when the node enters the scene tree for the first time.
func _ready():
	player.parry.connect(execute)
	player.timers.append(cooldown)
	
	area.scale = player.scale*scaling
	collider = player.get_node("CollisionShape2D").duplicate()
	area.add_child(collider)
	collider.disabled = true
