extends Node2D
class_name Parry
## Parry: not a spell of its own, but what every damage spell does as it is cast (Player: the Spell
## button raises the guard whenever a damage spell is held, on the guard's own cooldown, whether
## or not the spell itself is ready). The guard is up for a moment; a hit that lands inside it is
## turned aside, and pays off:
## - a touching enemy takes `damage` (double while stunned, as ever) and, if it lives, is stunned;
##   one behind a shield (Shield) loses a plate per point of `damage` instead, as a dash or a bolt
##   takes one, and is neither wounded nor stunned while the shield holds;
## - a shot is reflected back at whoever fired it, as a bolt of spell light dealing `damage`;
## - a hazard's touch (thorns) is caught too, with nothing to strike: caught underfoot, it bounces
##   the wizard up (a pogo, POGO, the air jump back and control kept), so they can parry their way
##   off thorns;
## - either way the dash comes back, the guard is ready again at once, the wizard is untouchable for
##   a moment (SAFE), and the action freezes for an instant (hit-stop).
## A parry never pushes the wizard away from an enemy: the throw back comes from landing a blow
## (SpellStrike.recoil), so a slash down onto an enemy is what bounces off it.
## A guard that catches nothing has a short cooldown (COOLDOWN). No guard can be raised while the
## wizard is untouchable from a hit taken (hurt_guarded); a parry's own untouchable moment does not
## count, so parries still chain (a pogo off thorns). It has no tiers.
## How it shows (RisoWizard._draw_guard): the guard is a yellow gleam band sweeping across the
## figure, the same all round (it guards from every side); a catch bursts in spell light where it
## landed and the wizard shimmers gold (not the hurt pink) while untouchable.

const STUN: float = 3.0
## Real seconds the action freezes on a parry, and how slow it runs meanwhile.
const HIT_STOP: float = 0.08
const HIT_STOP_SCALE: float = 0.05
## The bounce straight up off a hazard caught underfoot (px/s: a jump's worth).
const POGO: float = -600.0

## How long a catch keeps the wizard untouchable: long enough to get clear of what was caught, but
## shorter than a pogo's bounce (about 1.2 s in the air), so landing on thorns again needs another
## parry.
const SAFE: float = 0.8

## How long the guard stays up (seconds): short, so a catch takes timing.
const WINDOW: float = 0.2
## What a catch wounds (double while stunned, as ever: Wound).
const DAMAGE: int = 1
## How long (seconds) a guard that caught nothing keeps another from going up.
const COOLDOWN: float = 1.2
@onready var player: Player = $".."
@onready var area: Area2D = $"Area2D"
@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D
var scaling: float = 1.1
@onready var timer: Timer = $Timer
@onready var cooldown: ActionTimer = ActionTimer.new(COOLDOWN, player.refresh_self)

@onready var parry_sfx: AudioStreamPlayer = $AudioStreamPlayer

@onready var camera: Camera2D = Stage.camera()

## Whether the guard is up, and when (game seconds, see `clock`) it last went up, caught something
## and closed empty; where the last catch landed. For the art.
var guarding: bool = false
var raised_at: float = -INF
var parried_at: float = -INF
var missed_at: float = -INF
var caught_at: Vector2 = Vector2.ZERO
## When (real seconds) the last catch was, against Player.hit_at.
var parried_real: float = -INF
## The time the art reads these against.
var clock: float = 0.0

func stop_parry () -> void:
	if guarding and clock - parried_at > 0.01:
		missed_at = clock
	guarding = false
	player.hurt_ability = player.normal_hurt
	collider.disabled = true
	sprite.visible = false


## How much of the guard's window is left, 1 as it goes up to 0 as it closes; -1 when it is down.
func guard_left() -> float:
	if not guarding:
		return -1.0
	return clampf(timer.time_left / WINDOW, 0.0, 1.0)


## Whether the wizard is untouchable from a hit taken (a wound, or the ward breaking), when no
## guard can be raised. A parry's own untouchable moment (glory) and arrival grace do not count.
func hurt_guarded() -> bool:
	return player.invulnerable.is_acting() and not glory()


## Whether the wizard is untouchable because of a parry (the art shimmers gold, not hurt pink):
## soon enough after the last catch, and no hit taken since it.
func glory() -> bool:
	return player.is_invulnerable() and clock - parried_at < SAFE + 0.05 and player.hit_at < parried_real

func parry (_damage: int, v: Vector2, origin: Node) -> void:
	var attacker: Node = Damager.attacker_of(origin)
	if attacker == null or not is_instance_valid(attacker):
		return
	var shot: Node2D = _shot_of(origin)
	# Away from what hit: the hit's own knock, else from the shot or the enemy.
	var away: Vector2 = v.normalized()
	if away == Vector2.ZERO:
		var from_at: Vector2 = shot.global_position if shot != null else ((attacker as Node2D).global_position if attacker is Node2D else player.global_position + Vector2.DOWN)
		away = (player.global_position - from_at).normalized()
	var from: Vector2 = player.global_position - away * 60.0
	caught_at = player.global_position.lerp(from, 0.6) + Vector2(0, -40)
	parried_at = clock
	parried_real = Time.get_ticks_usec() / 1000000.0
	if shot != null:
		_reflect(shot, attacker)
	else:
		_strike(attacker)
	stop_parry()
	RisoFx.burst(&"parry", caught_at, (from - player.global_position).normalized())
	cooldown.refresh()
	timer.stop()
	parry_sfx.play()
	camera.shake(10, 0.2)
	player.dash.refresh()
	if _hazard(attacker) and away.y < -0.3:
		_pogo()
	player.invulnerable.enable(true)
	player.invulnerable.acting = SAFE
	Wound.hit_stop(HIT_STOP, HIT_STOP_SCALE)


## Bounced off a hazard caught underfoot: a jump's worth straight up with the air jump given back,
## and the wizard keeps control and their way across, so they can carry on or parry again on landing.
func _pogo() -> void:
	player.velocity.y = POGO
	player.jumps = maxi(player.jumps, player.MAX_JUMPS - 1)


## Whether `attacker` is a hazard (thorns, a laser, a falling stalactite) rather than an enemy:
## nothing a blow can strike.
static func _hazard(attacker: Node) -> bool:
	return attacker.get_node_or_null("Wound") == null and not attacker.is_in_group(&"hex_target")


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
	bolt.damage = DAMAGE
	bolt.reflected = true
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(bolt)
	bolt.global_position = from


## An enemy that touched the guard: wounded, then stunned if it lives; behind a shield, the shield
## loses a plate per point of damage instead.
func _strike(attacker: Node) -> void:
	var dir: Vector2 = ((attacker as Node2D).global_position - player.global_position).normalized() if attacker is Node2D else Vector2.RIGHT
	var shield: Shield = Shield.of(attacker)
	if shield != null and shield.holds():
		for i: int in range(DAMAGE):
			shield.absorb(false, dir)
		return
	var wound: Wound = attacker.get_node_or_null("Wound") as Wound
	if attacker is Scholar:
		(attacker as Scholar).wizard_blow = true
	if wound != null:
		wound.hit(DAMAGE, dir)
	if is_instance_valid(attacker) and not attacker.is_queued_for_deletion():
		var stunner: Stunner = Stunner.of(attacker)
		if stunner != null:
			stunner.stun(STUN, true)
		# A swarm of moths scatters instead.
		if attacker is MothSwarm:
			(attacker as MothSwarm).scatter(dir)


func check_parry () -> void:
	player.hurt_ability = parry
	sprite.visible = true
	guarding = true
	raised_at = clock
	timer.start(WINDOW)



## Keeps the time the art reads the guard against.
func _process(delta: float) -> void:
	clock += delta

## Ready unless cooling down after a guard (0..1 as the cooldown runs out), or untouchable from a
## hit taken (0).
func readiness() -> float:
	if hurt_guarded():
		return 0.0
	if cooldown == null or not cooldown.acted:
		return 1.0
	return 1.0 - clampf(cooldown.acting / cooldown.MAX_TIME, 0.0, 1.0) if cooldown.is_acting() else 0.0


## Raise the guard, if a damage spell is held to parry with, it has come back and no hit taken
## keeps the wizard untouchable.
func execute () -> void:
	if Abilities.spell(player) == &"":
		return
	if not cooldown.acted and not hurt_guarded():
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
