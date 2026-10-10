extends Node2D
class_name MothSwarm
## A swarm of moths, in cemetery levels. They flutter round where they were laid until a light draws
## them: the lantern the wizard carries, while it burns (while a lit lantern protects them), within
## CARRIED_PULL; else that lit lantern itself, within DRAW of their home. So the light that keeps
## you safe draws danger to it, and to you. With no lantern lit, they stay home.
## A moth that touches the wizard stings (a heart, like any hit). A dash, hex bolt through the
## swarm, or a parry, scatters it: the moths burst outward and sting no one,
## then flutter back together after SCATTER_TIME. They are never killed and never counted slain.

const COUNT: int = 6
const DRAW: float = 1100.0
## How near the wizard's lit, carried lantern draws them.
const CARRIED_PULL: float = 560.0
## Where the wizard carries their lantern, from their feet.
const CARRIED: Vector2 = Vector2(0, -40)
const SPEED: float = 170.0
const SCATTER_TIME: float = 6.0
const STING: float = 36.0
## Where a lantern's glass hangs, over its cell's middle.
const GLASS: Vector2 = Vector2(30, -40)

## Each moth: [angle, radius, angular speed, height squash, phase], and where it is now (local).
var moths: Array[Array] = []
var spots: Array[Vector2] = []
var home: Vector2 = Vector2.ZERO
## Seconds the swarm stays scattered, and which way it was struck from.
var scattered: float = 0.0
var scatter_dir: Vector2 = Vector2.ZERO
## What draws it now: &"carried" (the wizard's lantern), &"lantern" or &"home" (for the art and
## tests).
var drawn_to: StringName = &"home"
var t: float = 0.0

@onready var player: Player = Stage.player()


func setup(_info: MapInfo, _v: Vector2i) -> void:
	home = global_position


func _ready() -> void:
	add_to_group(&"hex_target")
	if home == Vector2.ZERO:
		home = global_position
	for i: int in range(COUNT):
		var r: float = randf()
		moths.append([TAU * float(i) / float(COUNT) + r, 30.0 + 34.0 * r, (1.6 + r * 1.4) * (1.0 if i % 2 == 0 else -1.0), 0.45 + 0.3 * r, r * TAU])
		spots.append(Vector2.ZERO)


## Where the swarm is headed: the nearby wizard's lit lantern, else the lit lantern in this level,
## else home.
func target() -> Vector2:
	var info: MapInfo = MapInfo.instance
	var lit: bool = info != null and info.run != null and not info.run.vulnerable
	if lit and player != null and is_instance_valid(player):
		var carried: Vector2 = player.global_position + CARRIED
		if carried.distance_to(global_position) <= CARRIED_PULL:
			drawn_to = &"carried"
			return carried
	if lit and info.world != null and info.run.respawn_coord == info.coord:
		var lantern: Vector2 = info.cell_position(info.run.respawn_cell) + GLASS
		if lantern.distance_to(home) <= DRAW:
			drawn_to = &"lantern"
			return lantern
	drawn_to = &"home"
	return home


func _physics_process(delta: float) -> void:
	t += delta
	scattered = maxf(0.0, scattered - delta)
	if scattered <= 0.0:
		# A little faster on a harder preset (Difficulty.speed).
		global_position = global_position.move_toward(target(), SPEED * Difficulty.speed() * delta)
	# Scattered, the moths fly outward from where they were struck and drift back as it wears off.
	var spread: float = 1.0 + 5.0 * clampf(scattered / SCATTER_TIME, 0.0, 1.0) * clampf((SCATTER_TIME - scattered) * 3.0, 0.0, 1.0)
	for i: int in range(moths.size()):
		var m: Array = moths[i]
		m[0] = float(m[0]) + float(m[2]) * delta
		var a: float = float(m[0])
		var r: float = float(m[1]) * (1.0 + 0.18 * sin(t * 3.1 + float(m[4])))
		spots[i] = Vector2(cos(a) * r, sin(a) * r * float(m[3]) + sin(t * 5.0 + float(m[4])) * 6.0) * spread + scatter_dir * 60.0 * (spread - 1.0)
	if scattered <= 0.0:
		_sting()


func _sting() -> void:
	if player == null or not is_instance_valid(player) or player.has_meta(&"portal_trip"):
		return
	var body: Vector2 = player.global_position + Vector2(0, -40)
	for spot: Vector2 in spots:
		var at: Vector2 = global_position + spot
		if at.distance_to(body) <= STING + 30.0:
			player.hurt(-1, (body - at).normalized() * 300.0, self)
			return


## A hex bolt through the swarm scatters it.
func hex_hit(_damage: int, dir: Vector2) -> void:
	scatter(dir)


func scatter(dir: Vector2 = Vector2.ZERO) -> void:
	scattered = SCATTER_TIME
	scatter_dir = dir.normalized()
	RisoFx.burst(&"hit", global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])


func is_scattered() -> bool:
	return scattered > 0.0
