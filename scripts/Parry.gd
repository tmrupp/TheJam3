extends Node2D
class_name Parry
## Parry, a spell: press Spell to raise a guard for a moment. A hit that lands inside it is turned
## aside, and pays off:
## - a touching enemy takes `damage` (double while stunned, as ever) and, if it lives, is stunned;
##   one behind a shield (Shield) loses a plate per point of `damage` instead, as a dash or a bolt
##   takes one, and is neither wounded nor stunned while the shield holds;
## - a shot is reflected back at whoever fired it, as a bolt of spell light dealing `damage`;
## - a hazard's touch (thorns) is caught too, with nothing to strike;
## - either way the wizard is pushed away from what hit them (_push: from the side, just as a wall
##   jump off it; from below, off an enemy landed on or thorns underfoot, a jump's worth up, POGO,
##   with the air jump back and control kept, so a parry can bounce off them and parry again; from
##   above, a short knock, PUSH), the dash comes back, the guard is
##   ready again at once, the wizard is untouchable for a moment (SAFE), and the action freezes for
##   an instant (hit-stop); from tier IV it heals 1.
## A guard that catches nothing has a short cooldown. No guard can be raised while the wizard is
## untouchable from a hit taken (hurt_guarded); a parry's own untouchable moment does not count,
## so parries still chain (a pogo off thorns). Tiers (Abilities): II a longer window and
## shorter cooldown, III double damage, IV heals. It is the spell every run starts with.
## How it shows (RisoWizard._draw_guard): the guard is a yellow gleam band sweeping across the
## figure, the same all round (it guards from every side); a catch bursts in spell light where it
## landed and the wizard shimmers gold (not the hurt pink) while untouchable.

const STUN: float = 3.0
## Real seconds the action freezes on a parry, and how slow it runs meanwhile.
const HIT_STOP: float = 0.08
const HIT_STOP_SCALE: float = 0.05
## The push back on a catch from above (px/s), and straight up when the hit came from below (a
## jump's worth). From the side it is a wall jump's (Player.WALL_JUMP_SPEED, WALL_JUMP_Y_FACTOR).
const PUSH: float = 300.0
const POGO: float = -600.0

## How long a catch keeps the wizard untouchable: long enough to get clear of what was caught, but
## shorter than a pogo's bounce (about 1.2 s in the air), so landing on thorns again needs another
## parry.
const SAFE: float = 0.8

## How long the guard stays up (seconds): short, so a catch takes timing; a little longer from
## tier II.
const WINDOW: float = 0.1
const WINDOW_II: float = 0.15
var duration: float = WINDOW
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
## How long a catch's burst shows, in seconds.
const CATCH_SHOW: float = 0.35

func stop_parry () -> void:
	if guarding and clock - parried_at > 0.01:
		missed_at = clock
	guarding = false
	player.hurt_ability = player.normal_hurt
	collider.disabled = true
	sprite.visible = false


## How much of the guard's window is left, 1 as it goes up to 0 as it closes; -1 when it is down.
func guard_left() -> float:
	if not guarding or duration <= 0.0:
		return -1.0
	return clampf(timer.time_left / duration, 0.0, 1.0)


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
	parried_real = Time.get_ticks_msec() / 1000.0
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
	_push(away)
	player.invulnerable.enable(true)
	player.invulnerable.acting = SAFE
	if heals:
		player.health.modify_health(1 if player.health.health < player.health.max_health else 0)
	_hit_stop()


## Pushed away from the hit (`away`). From below (an enemy landed on, thorns underfoot): a pogo,
## a jump's worth straight up with the air jump given back, and the wizard keeps control and their
## way across, so they can carry on or parry again on landing. From the side: just as a wall jump
## off it (away at the wall jump's speed, lifted by its jump), control back after the knock. From
## above: a short knock away.
func _push(away: Vector2) -> void:
	if away.y < -0.3:
		player.velocity.y = POGO
		player.jumps = maxi(player.jumps, player.MAX_JUMPS - 1)
		return
	var push: Vector2 = away * PUSH
	if away.y <= 0.3:
		var side: float = signf(away.x) if away.x != 0.0 else 1.0
		push = Vector2(side * player.WALL_JUMP_SPEED, player.JUMP_VELOCITY * player.WALL_JUMP_Y_FACTOR)
	player.knock = push
	player.knock_back.enable(true)


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


## An enemy that touched the guard: wounded, then stunned if it lives; behind a shield, the shield
## loses a plate per point of damage instead.
func _strike(attacker: Node) -> void:
	var dir: Vector2 = ((attacker as Node2D).global_position - player.global_position).normalized() if attacker is Node2D else Vector2.RIGHT
	var shield: Shield = Shield.of(attacker)
	if shield != null and shield.holds():
		for i: int in range(damage):
			shield.absorb(false, dir)
		return
	var wound: Wound = attacker.get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hit(damage, dir)
	if is_instance_valid(attacker) and not attacker.is_queued_for_deletion():
		var stunner: Stunner = Stunner.of(attacker)
		if stunner != null:
			stunner.stun(STUN, true)
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
	guarding = true
	raised_at = clock
	timer.start(duration)



## Keeps the time the art reads the guard against.
func _process(delta: float) -> void:
	clock += delta

## Its tier (Abilities): I the guard (WINDOW), 1 damage, reflects shots, refunds the dash. II
## WINDOW_II and a shorter cooldown on a miss. III 2 damage. IV each parry heals 1. Untaught it keeps
## tier I's tuning (it does nothing until learned, see execute).
func set_tier(n: int) -> void:
	n = maxi(n, 1)
	duration = WINDOW_II if n >= 2 else WINDOW
	damage = 2 if n >= 3 else 1
	heals = n >= 4
	if cooldown != null:
		cooldown.MAX_TIME = 0.9 if n >= 2 else 1.2


## The Spell button, with parry in the slot: raise the guard (not while untouchable from a hit).
func cast_spell() -> bool:
	if hurt_guarded():
		return false
	player.parry.emit()
	return true


## Ready unless cooling down after a guard (0..1 as the cooldown runs out, the spell orb shows it),
## or untouchable from a hit taken (0).
func readiness() -> float:
	if hurt_guarded():
		return 0.0
	if cooldown == null or not cooldown.acted:
		return 1.0
	return 1.0 - clampf(cooldown.acting / cooldown.MAX_TIME, 0.0, 1.0) if cooldown.is_acting() else 0.0


## The guard is too brief to show: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)

func execute () -> void:
	if Abilities.tier(player, &"parry") <= 0:
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
