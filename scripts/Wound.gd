extends Node
class_name Wound
## An enemy's health against the hex bolt. A stunned (parried) enemy takes double damage. At
## 0 it bursts, drops a star or two, and the
## level record keeps it slain until the player dies.

var hp: int = 1
## The least a hex bolt or a dash wounds it by, even at a tier that only stuns (0: as the tier
## says). The worm's soft segments are cut by anything that strikes them (WormWound).
var least: int = 0
## Its host has been slain (just before it is freed).
signal slain

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
	hp -= damage * (2 if stunned() else 1)
	RisoFx.burst(&"hit", host.global_position, dir, [RisoPrint.PINK, RisoPrint.GLOW])
	Wound.shake(7.0 if hp > 0 else 12.0, 0.14 if hp > 0 else 0.22)
	host.global_position += dir * 14.0
	if hp <= 0:
		_die(host)


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
	if info != null:
		info.mark_slain(host)
		var coin: PackedScene = Placeables.scene(LevelGen.Type.COIN)
		for i: int in range(randi_range(1, 2)):
			var star: Node2D = coin.instantiate()
			info.map_elements.add_child(star)
			star.global_position = host.global_position + Vector2(-18.0 + 36.0 * float(i), -10.0)
	RisoFx.burst(&"gain", host.global_position, Vector2.ZERO, [RisoPrint.PINK, RisoPrint.NIGHT])
	host.queue_free()
