extends Node2D
@onready var area: Area2D = $HitBox
@onready var player: Player = $"/root/Main/Player"
var velocity: Vector2 = Vector2(1, 1).normalized()
var exclude: Array[Node]

func setup(v: Vector2, ignore: Array[Node], sender: Node) -> void:
	velocity = v
	exclude = ignore
	$HitBox/Damager.attacker = sender

func touch (other: Node) -> void:
	if other not in exclude:
#		print("bullet colliding with=", other)
		queue_free()

func _ready() -> void:
	area.connect("body_entered", touch)
	
func _process(delta: float) -> void:
	position += velocity*delta
