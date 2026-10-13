class_name Lamplight
extends RefCounted
## Light as the game reads it, apart from how it is printed (RisoLight): whether light falls on a
## point. Light comes from the lantern the wizard carries while its flame is lit (while a lit
## lantern protects them: not RunState.vulnerable, so not after a death or a snuffing, Snuffer) and
## from every lantern not burnt out, each reaching LIT_SHARE of the reach RisoLight prints it with,
## and rock stops it: the flame must see the point. The moon over the cemetery's terraces is no
## light here, nor are the small things that shine. What reads it: the wraiths freeze in it
## (Wraith), the skeletons wake in it (Skeleton), and the necromancer can be wounded only in it
## (Necromancer).

## How much of a light's printed reach counts as lit: past it the printed light is faint.
const LIT_SHARE: float = 0.85
## How far apart (px) the line from a light to a point is tested for rock.
const STEP: float = 16.0
## How far (px) from the flame the test for rock starts, so a flame swung against a wall still
## lights the room it is in.
const FLAME_ROOM: float = 12.0
## How high over its cell's middle a lantern's light is (px): its glass, a little over the floor.
const LANTERN_RISE: float = 24.0

## The lights as last worked out (each where it is and how far it reaches as lit, x, y, z), and the
## physics frame they were worked out in: they are worked out once a frame, however many ask.
static var _lights: Array[Vector3] = []
static var _frame: int = -1


## Whether light falls on `pos`.
static func at(pos: Vector2) -> bool:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return false
	for light: Vector3 in lights(info):
		var from: Vector2 = Vector2(light.x, light.y)
		if from.distance_to(pos) <= light.z and sees(info, from, pos):
			return true
	return false


## The lights of the level being played (see the class note), as (x, y, reach as lit).
static func lights(info: MapInfo) -> Array[Vector3]:
	var frame: int = Engine.get_physics_frames()
	if frame == _frame:
		return _lights
	_frame = frame
	_lights = []
	var player: Player = info.player
	if player != null and is_instance_valid(player) and not player.phasing and info.run != null and not info.run.vulnerable:
		var eye: Vector2 = RisoLight.eye(player)
		_lights.append(Vector3(eye.x, eye.y, RisoLight.CARRIED_REACH * LIT_SHARE))
	if info.map_elements != null and is_instance_valid(info.map_elements):
		for node: Node in info.map_elements.get_children():
			var lantern: Checkpoint = node as Checkpoint
			if lantern == null or lantern.is_queued_for_deletion() or info.is_lantern_spent(lantern):
				continue
			var reach: float = RisoLight.RESPAWN_REACH if info.is_respawn_lantern(lantern) else RisoLight.FAINT_REACH
			var at: Vector2 = info.cell_position(info.cell_at(lantern.global_position)) + Vector2(0, -LANTERN_RISE)
			_lights.append(Vector3(at.x, at.y, reach * LIT_SHARE))
	return _lights


## Whether a light at `from` sees `to`: no rock (MapInfo.solid_at) on the line between, past the
## flame's own room, nor at `to` itself.
static func sees(info: MapInfo, from: Vector2, to: Vector2) -> bool:
	var d: float = from.distance_to(to)
	if info.solid_at(to):
		return false
	var s: float = FLAME_ROOM
	while s < d:
		if info.solid_at(from.lerp(to, s / d)):
			return false
		s += STEP
	return true
