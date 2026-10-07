extends Node2D
class_name Parry
## Parry, a spell: press Spell to raise a guard for a moment. A hit that lands inside it is turned
## aside, and pays off:
## - a touching enemy takes `damage` (double while stunned, as ever) and, if it lives, is stunned;
## - a shot is reflected back at whoever fired it, as a bolt of spell light dealing `damage`;
## - either way the dash comes back, the guard is ready again at once, the wizard is untouchable
##   for a moment, and the action freezes for an instant (hit-stop); from tier IV it heals 1.
## A guard that catches nothing has a short cooldown. Tiers (Abilities): II a longer window and
## shorter cooldown, III double damage, IV heals.

const STUN: float = 3.0
## Real seconds the action freezes on a parry, and how slow it runs meanwhile.
const HIT_STOP: float = 0.08
const HIT_STOP_SCALE: float = 0.05

var duration: float = 0.3
var damage: int = 1
var heals: bool = false
@onready var player: Player = $".."
@onready var area: Area2D = $"Area2D"
@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D
var scaling: float = 1.1
@onready var timer: Timer = $Timer
@onready var cooldown: ActionTimer = ActionTimer.new(1.2, player.refresh_self)

@onready var parry_sfx: AudioStreamPlayer = $AudioStreamPlayer

@onready var camera: Camera2D = Stage.camera()

func stop_parry () -> void:
	player.hurt_ability = player.normal_hurt
	collider.disabled = true
	sprite.visible = false

func parry (_damage: int, _v: Vector2, origin: Node) -> void:
	var attacker: Node = Damager.attacker_of(origin)
	if attacker == null or not is_instance_valid(attacker):
		return
	var shot: Node2D = _shot_of(origin)
	if shot != null:
		_reflect(shot, attacker)
	else:
		_strike(attacker)
	stop_parry()
	cooldown.refresh()
	timer.stop()
	parry_sfx.play()
	camera.shake(10, 0.2)
	player.dash.refresh()
	player.invulnerable.enable()
	if heals:
		player.health.modify_health(1 if player.health.health < player.health.max_health else 0)
	_hit_stop()


## The bullet a damager belongs to, or null for an enemy's own body.
func _shot_of(origin: Node) -> Bullet:
	var box: Node = origin.get_parent()
	return box.get_parent() as Bullet if box != null else null


## A shot turned back: the bullet is gone, and a bolt of spell light flies back at its shooter.
func _reflect(shot: Bullet, attacker: Node) -> void:
	var from: Vector2 = shot.global_position
	var aim: Vector2 = ((attacker as Node2D).global_position - from).normalized() if attacker is Node2D else -shot.velocity.normalized()
	shot.queue_free()
	var bolt: HexBolt = HexBolt.new()
	bolt.dir = aim
	bolt.damage = damage
	bolt.reflected = true
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(bolt)
	bolt.global_position = from


## An enemy that touched the guard: wounded, then stunned if it lives.
func _strike(attacker: Node) -> void:
	var dir: Vector2 = ((attacker as Node2D).global_position - player.global_position).normalized() if attacker is Node2D else Vector2.RIGHT
	var wound: Wound = attacker.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hit(damage, dir)
	if is_instance_valid(attacker) and not attacker.is_queued_for_deletion():
		var stunner: Stunner = Stunner.of(attacker)
		if stunner != null:
			stunner.stun(STUN)
		# A swarm of moths scatters instead.
		if attacker is MothSwarm:
			(attacker as MothSwarm).scatter(dir)


## Freeze the action for an instant, so the parry lands with weight.
func _hit_stop() -> void:
	Engine.time_scale = HIT_STOP_SCALE
	await get_tree().create_timer(HIT_STOP, true, false, true).timeout
	Engine.time_scale = 1.0

func check_parry () -> void:
	player.hurt_ability = parry
	sprite.visible = true
	timer.start(duration)

## Its tier (Abilities): I the guard (0.3 s), 1 damage, reflects shots, refunds the dash. II
## 0.45 s and a shorter cooldown on a miss. III 2 damage. IV each parry heals 1. Untaught it keeps
## tier I's tuning (it does nothing until learned, see execute).
func set_tier(n: int) -> void:
	n = maxi(n, 1)
	duration = 0.45 if n >= 2 else 0.3
	damage = 2 if n >= 3 else 1
	heals = n >= 4
	if cooldown != null:
		cooldown.MAX_TIME = 0.9 if n >= 2 else 1.2


## The Spell button, with parry in the slot: raise the guard.
func cast_spell() -> bool:
	player.parry.emit()
	return true


## Ready unless cooling down after a guard: 0..1 as the cooldown runs out (the spell orb shows it).
func readiness() -> float:
	if cooldown == null or not cooldown.acted:
		return 1.0
	return 1.0 - clampf(cooldown.acting / cooldown.MAX_TIME, 0.0, 1.0) if cooldown.is_acting() else 0.0


## The guard is too brief to show: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)

func execute () -> void:
	if Abilities.tier(player, &"parry") <= 0:
		return
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
