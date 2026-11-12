extends Node2D
class_name Parry
## Parry: not a spell of its own, but what every damage spell does as it is cast (Player: the Spell
## button raises the guard as it casts the damage spell, when that spell is ready; the guard has no
## cooldown of its own, only the spell's). The guard is up for a moment; a hit that lands inside it
## is turned aside, and pays off:
## - a touching enemy takes `damage` (double while stunned, as ever) and, if it lives, is stunned;
##   one behind a shield (Shield) loses a plate per point of `damage` instead, as a dash or a bolt
##   takes one, and is neither wounded nor stunned while the shield holds;
## - a shot is reflected back at whoever fired it, as a bolt of spell light dealing `damage` that
##   steers for its shooter however far it is (HexBolt.home);
## - a hazard's touch (thorns) is caught too, with nothing to strike: caught underfoot, it bounces
##   the wizard up (a pogo, POGO, the air jump back and control kept), so they can parry their way
##   off thorns;
## - either way the dash comes back, the spell comes back at once whatever its cooldown
##   (Abilities.refill), so the guard is ready again too, the wizard is untouchable for a moment
##   (SAFE), and the action freezes for an instant (hit-stop).
## A parry never pushes the wizard away from an enemy: the throw back comes from landing a blow
## (SpellStrike.recoil), so a slash down onto an enemy is what bounces off it.
## A guard that catches nothing leaves the spell on its own cooldown. Untouchable or not (after a
## hit, the grace on arriving, a catch), the guard goes up and catches all the same, so the wizard
## can parry and bounce off thorns whenever the spell is ready. It has no tiers.
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
const WINDOW: float = Rules.GUARD_WINDOW
## What a catch wounds (double while stunned, as ever: Wound).
const DAMAGE: int = 1
@onready var player: Player = $".."
@onready var area: Area2D = $"Area2D"
@onready var sprite: Sprite2D = $Sprite2D
@onready var collider: CollisionShape2D
var scaling: float = 1.1
@onready var timer: Timer = $Timer

@onready var parry_sfx: AudioStreamPlayer = $AudioStreamPlayer

@onready var camera: Camera2D = Stage.camera()

## Whether the guard is up, and when (game seconds, see `clock`) it last went up, caught something
## and closed empty; where the last catch landed. For the art.
var guarding: bool = false
var raised_at: float = -INF
var parried_at: float = -INF
var missed_at: float = -INF
var caught_at: Vector2 = Vector2.ZERO
## When (game seconds, see `clock`) a catch underfoot last bounced the wizard up (_pogo; the
## tutorial's pogo card reads it, ControlHint).
var pogo_at: float = -INF
## When the last catch was, as an order stamp (GameClock.order), against Player.hit_order.
var parried_order: int = -1
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


## Whether the wizard is untouchable because of a parry (the art shimmers gold, not hurt pink):
## soon enough after the last catch, and no hit taken since it.
func glory() -> bool:
	return player.is_invulnerable() and clock - parried_at < SAFE + 0.05 and player.hit_order < parried_order

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
	parried_order = GameClock.order()
	if shot != null:
		_reflect(shot, attacker)
	else:
		_strike(attacker)
	stop_parry()
	RisoFx.burst(&"parry", caught_at, (from - player.global_position).normalized())
	Abilities.refill(player)
	timer.stop()
	parry_sfx.play()
	camera.shake(10, 0.2)
	player.dash.refresh()
	if _hazard(attacker) and (away.y < -0.3 or _underfoot(origin)):
		_pogo()
	player.invulnerable.enable(true)
	player.invulnerable.acting = SAFE
	Wound.hit_stop(HIT_STOP, HIT_STOP_SCALE)


## Whether the hazard behind `origin` (a Damager) lies under the wizard's middle as they come down
## onto it: caught underfoot, whichever piece of a bed of thorns was touched first (landing on the
## move, the one behind them is, and its knock points mostly sideways).
func _underfoot(origin: Node) -> bool:
	var hit: Damager = origin as Damager
	return hit != null and player.velocity.y >= 0.0 and hit.collider.global_position.y > player.global_position.y


## Bounced off a hazard caught underfoot: a jump's worth straight up with the air jump given back,
## and the wizard keeps control and their way across, so they can carry on or parry again on landing.
func _pogo() -> void:
	pogo_at = clock
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
	if attacker is Node2D:
		bolt.home = attacker as Node2D
		bolt.range_px = INF
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

## Raise the guard, if a damage spell is held to parry with and it is ready to cast (the Spell press
## calls this just before it casts, Player): the guard goes up with the cast, on the spell's own
## cooldown, whether the wizard is untouchable or not.
func execute () -> void:
	if Abilities.spell(player) == &"" or Abilities.readiness(player) < 1.0:
		return
	collider.disabled = false
	check_parry()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.parry.connect(execute)

	timer.connect("timeout", stop_parry)
	timer.one_shot = true

	area.scale = player.scale*scaling
	collider = player.get_node("CollisionShape2D").duplicate()
	area.add_child(collider)
	collider.disabled = true
