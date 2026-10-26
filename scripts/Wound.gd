extends Node
class_name Wound
## An enemy's health against the hex bolt. A stunned (parried) enemy takes double damage. At
## 0 it bursts, drops a star or two (unless `stars` is off), and the
## level record keeps it slain until the player dies. One `unhurt` (a wraith, a skeleton) takes no
## harm: a blow shows on it, pale, and it says so (`warded`), but it is not knocked back, loses
## nothing and is never slain.
## A blow that wounds is felt (felt): the action freezes for an instant (hit_stop, HIT_STOP, longer
## for a blow that slays, KILL_STOP), the camera kicks, and the enemy's art jolts away from the blow
## and wobbles (RisoProp.struck).

## Real seconds the action freezes when a blow wounds an enemy, and when it slays one, and how slow
## it runs meanwhile.
const HIT_STOP: float = 0.05
const KILL_STOP: float = 0.09
const STOP_SCALE: float = 0.05
## When the latest hit-stop ends (msec, Time.get_ticks_msec), so overlapping ones end together.
static var _stop_until: int = 0

var hp: int = 1
## The least a hex bolt or a dash wounds it by, even one of no damage (0: as the
## blow says). The worm's soft segments are cut by anything that strikes them (WormWound).
var least: int = 0
## Whether it drops stars when slain (the necromancer's skeletons do not, Necromancer).
var stars: bool = true
## Whether blows leave it unhurt (see the class note).
var unhurt: bool = false
## Its host has been slain (just before it is freed).
signal slain
## A blow has struck it, unhurt, heading `dir`.
signal warded(dir: Vector2)
## A blow has wounded it by `damage` (doubled while it was stunned), before it is slain by it if it
## is (the practice range's tally counts it, PracticeTally).
signal hurt(damage: int)

## What a blow of `damage` deals to `wound`: at least its `least`, and at least 1 while it is stunned,
## so even a blow of no damage (a push at tier I) wounds an enemy a parry has left stunned.
static func dealt(wound: Wound, damage: int) -> int:
	return maxi(maxi(damage, wound.least), 1 if wound.stunned() else 0)


## Hit points by depth: 2 to start with (so a parry, 1 damage, stuns rather than kills), 3 from
## depth 6.
static func hp_for(depth: int) -> int:
	@warning_ignore("integer_division")
	return clampi(1 + depth / 3, 2, 3)


func stunned() -> bool:
	var box: HitBox = get_parent().get_node_or_null("HitBox") as HitBox
	return box != null and box.stunned


func hit(damage: int, dir: Vector2) -> void:
	var host: Node2D = get_parent() as Node2D
	if host == null or host.is_queued_for_deletion():
		return
	if unhurt:
		RisoFx.burst(&"hit", host.global_position, dir, [RisoPrint.BLUE, RisoPrint.NIGHT])
		Wound.shake(4.0, 0.1)
		warded.emit(dir)
		return
	var taken: int = damage * (2 if stunned() else 1)
	hp -= taken
	hurt.emit(taken)
	RisoFx.burst(&"hit", host.global_position, dir, [RisoPrint.PINK, RisoPrint.GLOW])
	Wound.felt(host, dir, hp <= 0)
	host.global_position += dir * 14.0
	if hp <= 0:
		_die(host)


## How a blow that wounds `host` is felt (heading `dir`; `slays` when it is the last): the action
## freezes for an instant, the camera kicks, and its art jolts and wobbles.
static func felt(host: Node2D, dir: Vector2, slays: bool) -> void:
	Wound.shake(7.0 if not slays else 12.0, 0.14 if not slays else 0.22)
	Wound.hit_stop(KILL_STOP if slays else HIT_STOP)
	var art: RisoProp = host.get_node_or_null("RisoArt") as RisoProp if host != null else null
	if art != null:
		art.struck(dir)


## Freeze the action for `seconds` (real time), running it at `slow` meanwhile, so a blow lands
## with weight. Hit-stops that overlap end with the last of them.
static func hit_stop(seconds: float, slow: float = STOP_SCALE) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	Engine.time_scale = minf(Engine.time_scale, slow)
	# A timer can come due a little before the clock does: wait out whatever is left.
	var left: int = _stop_until - Time.get_ticks_msec()
	while left > 0:
		await tree.create_timer(float(left) / 1000.0, true, false, true).timeout
		left = _stop_until - Time.get_ticks_msec()
	Engine.time_scale = 1.0


## What a struck part belongs to, so a move (a bolt, a dash) strikes the whole only once: a worm
## segment's worm (each move cuts one segment), anything else itself.
static func whole(part: Node) -> Node:
	var segment: WormSegment = part as WormSegment
	return segment.worm if segment != null and segment.worm != null else part


## A small camera kick for hits and kills.
static func shake(intensity: float, sustain: float) -> void:
	var cam: CameraEffects = Stage.camera()
	if cam != null:
		cam.shake(intensity, sustain)


func _die(host: Node2D) -> void:
	slain.emit()
	var info: MapInfo = MapInfo.instance
	if info != null and stars:
		info.mark_slain(host)
		var coin: PackedScene = Placeables.scene(LevelGen.Type.COIN)
		for i: int in range(randi_range(1, 2)):
			var star: Node2D = coin.instantiate()
			info.map_elements.add_child(star)
			star.global_position = host.global_position + Vector2(-18.0 + 36.0 * float(i), -10.0)
	RisoFx.burst(&"gain", host.global_position, Vector2.ZERO, [RisoPrint.PINK, RisoPrint.NIGHT])
	host.queue_free()
