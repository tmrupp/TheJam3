extends Node
class_name Hex
## The hex bolt: Cast (F, or the pad's X) throws a comet of glow ink from the hat, aimed like the
## dash (the held direction, else facing). It has charges that come back one per COOLDOWN, and
## lighting a lantern refills them. Tiers (Abilities): II +1 charge, III +1 damage, IV pierces
## its first enemy.

const COOLDOWN: float = 1.5
const BOLT: GDScript = preload("res://scripts/HexBolt.gd")

var charges_max: int = 1
var charges: int = 1
var recharge: float = 0.0
var damage: int = 1
var pierce: bool = false

@onready var player: Player = get_parent() as Player


## Adds the Cast action if the project does not define it.
static func ensure_input() -> void:
	if InputMap.has_action("Cast"):
		return
	InputMap.add_action("Cast")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event("Cast", key)
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	InputMap.action_add_event("Cast", pad)


func _ready() -> void:
	Hex.ensure_input()


func refill() -> void:
	charges = charges_max
	recharge = 0.0


func _physics_process(delta: float) -> void:
	if charges < charges_max:
		recharge += delta
		if recharge >= COOLDOWN:
			charges += 1
			recharge = 0.0
	if Input.is_action_just_pressed("Cast") and player.is_physics_processing():
		cast()


## Throw a bolt. Returns it, or null when out of charges.
func cast(dir: Vector2 = Vector2.ZERO) -> Node2D:
	if charges <= 0 or player == null:
		return null
	if dir == Vector2.ZERO:
		dir = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT * signf(player.sprite.scale.x if player.sprite != null else 1.0)
	charges -= 1
	var bolt: Node2D = Node2D.new()
	bolt.set_script(BOLT)
	bolt.set("dir", dir.normalized())
	bolt.set("damage", damage)
	bolt.set("pierce", pierce)
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(bolt)
	bolt.global_position = player.global_position + Vector2(0, -44)
	player.visual_event.emit(&"hex", bolt.global_position)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"hex")
	return bolt
