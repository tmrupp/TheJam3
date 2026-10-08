class_name RisoFx
extends Node2D
## Printed particle bursts in world space: pickups, jumps, hits, shots and impacts.
## Presentation only; calls are ignored while the print is off.

enum Shape { DOT, SPARKLE, STREAK, SHARD, BLOOM }

static var instance: RisoFx

var ink: InkCanvas
var parts: Array[Dictionary] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func burst(kind: StringName, at: Vector2, dir: Vector2 = Vector2.ZERO, plates: Array[int] = []) -> void:
	if instance != null and is_instance_valid(instance) and RisoPrint.is_on():
		instance._burst(kind, at, dir, plates)


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	z_index = 60
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	rng.randomize()


func _add(shape: Shape, plate: int, cover: float, at: Vector2, v: Vector2, life: float, size: float, drag: float = 3.0, grav: float = 0.0, grow: float = 0.0) -> void:
	parts.append({"shape": shape, "plate": plate, "cover": cover, "p": at, "v": v, "life": life, "age": 0.0,
		"size": size, "drag": drag, "grav": grav, "grow": grow, "rot": rng.randf() * TAU, "spin": rng.randf_range(-9.0, 9.0)})


func _spray(dir: Vector2, spread: float, lo: float, hi: float) -> Vector2:
	var a: float = (dir.angle() if dir != Vector2.ZERO else rng.randf() * TAU) + rng.randf_range(-spread, spread)
	return Vector2(cos(a), sin(a)) * rng.randf_range(lo, hi)


func _burst(kind: StringName, at: Vector2, dir: Vector2, plates: Array[int]) -> void:
	if plates.is_empty():
		plates = [RisoPrint.ACCENT]
	match kind:
		&"gain":
			for i: int in range(10):
				_add(Shape.SPARKLE, plates[i % plates.size()], 1.0, at, _spray(Vector2.ZERO, PI, 120.0, 280.0), rng.randf_range(0.45, 0.8), rng.randf_range(6.0, 10.0), 3.5, -80.0)
			for i: int in range(14):
				var a: float = TAU * float(i) / 14.0
				_add(Shape.DOT, plates[i % plates.size()], 1.0, at, Vector2(cos(a), sin(a)) * 260.0, 0.35, 3.5, 6.0)
			_add(Shape.BLOOM, plates[0], 0.3, at, Vector2.ZERO, 0.22, 10.0, 0.0, 0.0, 220.0)
		&"jump":
			for i: int in range(8):
				var side: float = -1.0 if i % 2 == 0 else 1.0
				var v: Vector2 = Vector2(side * rng.randf_range(60.0, 190.0), -rng.randf_range(10.0, 60.0))
				_add(Shape.DOT, RisoPrint.BLUE, 0.5, at + Vector2(side * rng.randf_range(4.0, 16.0), -4.0), v, rng.randf_range(0.3, 0.5), rng.randf_range(7.0, 12.0), 4.0)
			for i: int in range(5):
				_add(Shape.DOT, RisoPrint.ACCENT, 1.0, at, _spray(Vector2.UP, 1.1, 140.0, 260.0), rng.randf_range(0.35, 0.55), rng.randf_range(2.5, 4.0), 1.5, 900.0)
		&"hit":
			_add(Shape.BLOOM, RisoPrint.PINK, 0.35, at, Vector2.ZERO, 0.18, 12.0, 0.0, 0.0, 300.0)
			for i: int in range(10):
				_add(Shape.SHARD, RisoPrint.PINK, 1.0, at, _spray(dir, PI if dir == Vector2.ZERO else 1.3, 250.0, 460.0), rng.randf_range(0.4, 0.6), rng.randf_range(7.0, 11.0), 3.0, 500.0)
			for i: int in range(6):
				_add(Shape.STREAK, RisoPrint.PINK, 1.0, at, _spray(Vector2.ZERO, PI, 380.0, 560.0), rng.randf_range(0.15, 0.25), 3.0, 6.0)
		&"shot":
			_add(Shape.BLOOM, RisoPrint.EYE, 0.4, at, Vector2.ZERO, 0.15, 5.0, 0.0, 0.0, 150.0)
			for i: int in range(6):
				_add(Shape.SPARKLE, RisoPrint.EYE, 1.0, at, _spray(dir, 0.5, 150.0, 320.0), rng.randf_range(0.25, 0.4), rng.randf_range(4.0, 6.5), 6.0)
		&"parry":
			# A catch: a flash of spell light, sparks thrown back the way the hit came from, and a ring
			# of motes.
			_add(Shape.BLOOM, RisoPrint.EYE, 0.5, at, Vector2.ZERO, 0.22, 14.0, 0.0, 0.0, 420.0)
			for i: int in range(10):
				_add(Shape.SPARKLE, RisoPrint.EYE, 1.0, at, _spray(dir, 0.9, 260.0, 520.0), rng.randf_range(0.3, 0.5), rng.randf_range(6.0, 10.0), 4.0)
			for i: int in range(12):
				var a: float = TAU * float(i) / 12.0
				_add(Shape.DOT, RisoPrint.ACCENT, 1.0, at, Vector2(cos(a), sin(a)) * 320.0, 0.3, 3.5, 5.0)
		&"impact":
			_add(Shape.BLOOM, RisoPrint.PINK, 0.3, at, Vector2.ZERO, 0.16, 6.0, 0.0, 0.0, 200.0)
			for i: int in range(8):
				_add(Shape.STREAK, RisoPrint.PINK if i % 2 == 0 else RisoPrint.ACCENT, 1.0, at, _spray(dir, 1.2, 200.0, 380.0), rng.randf_range(0.3, 0.5), 2.5, 2.0, 700.0)
			for i: int in range(5):
				_add(Shape.DOT, RisoPrint.ACCENT, 1.0, at, _spray(dir, 1.4, 90.0, 220.0), rng.randf_range(0.3, 0.5), 3.0, 2.0, 700.0)
	set_process(true)


func _process(delta: float) -> void:
	ink.begin()
	var groups: Dictionary = {}
	for i: int in range(parts.size() - 1, -1, -1):
		var q: Dictionary = parts[i]
		q.age += delta
		if q.age >= q.life:
			parts.remove_at(i)
			continue
		var v: Vector2 = q.v
		v *= maxf(0.0, 1.0 - float(q.drag) * delta)
		v.y += float(q.grav) * delta
		q.v = v
		q.p = (q.p as Vector2) + v * delta
		q.rot = float(q.rot) + float(q.spin) * delta
		var u: float = float(q.age) / float(q.life)
		var poly: PackedVector2Array = _shape(q, u)
		if poly.size() < 3:
			continue
		var cover: float = float(q.cover) * (1.0 - u if q.shape == Shape.BLOOM else 1.0)
		var key: Vector2i = Vector2i(int(q.plate), roundi(cover * 20.0))
		if not groups.has(key):
			var fresh: Array[PackedVector2Array] = []
			groups[key] = fresh
		var group: Array[PackedVector2Array] = groups[key]
		group.append(poly)
	for key: Vector2i in groups:
		var polys: Array[PackedVector2Array] = groups[key]
		ink.ink(key.x, float(key.y) / 20.0, polys)
	ink.finish()
	if parts.is_empty():
		set_process(false)


func _shape(q: Dictionary, u: float) -> PackedVector2Array:
	var p: Vector2 = q.p
	var s: float = float(q.size)
	# Anything under ~2px is dropped: it prints nothing and can fail to triangulate far from the origin.
	match int(q.shape):
		Shape.DOT:
			# Puffs swell then shrink; flecks just shrink.
			var r: float = s * (sin(PI * minf(1.0, u * 1.4 + 0.3)) if float(q.cover) < 1.0 else 1.0 - u)
			return RisoShapes.circle(p, r, 10) if r > 1.5 else PackedVector2Array()
		Shape.SPARKLE:
			var r: float = s * (1.0 - u * u)
			return Transform2D(float(q.rot) * 0.2, p) * RisoShapes.sparkle(Vector2.ZERO, r) if r > 2.5 else PackedVector2Array()
		Shape.STREAK:
			var v: Vector2 = q.v
			if v.length() < 1.0 or s * (1.0 - u) < 0.8:
				return PackedVector2Array()
			var d: Vector2 = v.normalized()
			var n: Vector2 = d.orthogonal() * s * (1.0 - u)
			var tail: Vector2 = p - d * clampf(v.length() * 0.06, 4.0, 28.0)
			return PackedVector2Array([p + d * s, p + n, tail, p - n])
		Shape.SHARD:
			var k: float = s * (1.0 - u)
			if k < 2.0:
				return PackedVector2Array()
			return Transform2D(float(q.rot), p) * PackedVector2Array([Vector2(k, 0), Vector2(-k * 0.5, k * 0.45), Vector2(-k * 0.4, -k * 0.5)])
		Shape.BLOOM:
			return RisoShapes.circle(p, s + float(q.grow) * u * (2.0 - u) * 0.5, 28)
	return PackedVector2Array()
