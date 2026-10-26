extends TestKit
## An enemy's touch (its HitBox) lies over its body as printed, not only round the point it stands
## on: a wisp's over the body floating above its path, a scholar's up its robe. And a wizard
## touching a wisp where its body is printed is hurt. A wisp put in the level stands on its floor
## from its first step, its body dropping with it, rather than falling into place with its body
## hanging over its touch. `tests/capture_hitboxes.gd` takes stills of every kind's touch over its
## art.
## godot --headless --path . --script res://tests/hitbox_test.gd


func run() -> void:
	await boot()
	player.set_physics_process(false)
	player.global_position = Vector2(-90000, -90000)
	await covers("mover_enemy.tscn", "a wisp")
	await wisp_touch()
	await wisp_settles()
	info.coord = Vector2i(28, NextWorldDef.band_row(&"institute", 0))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.global_position = Vector2(-90000, -90000)
	for scene: String in ["student.tscn", "master.tscn"]:
		await covers(scene, scene.get_basename())
	RunState.delete_save()
	finish()


## The touch of `enemy` in the world.
func touch_rect(enemy: Node) -> Rect2:
	var shape: CollisionShape2D = enemy.get_node("HitBox/CollisionShape2D") as CollisionShape2D
	var r: Rect2 = shape.shape.get_rect()
	return Rect2(shape.global_transform * r.position, r.size * shape.global_transform.get_scale())


## The art printing `enemy`.
func art_of(enemy: Node) -> RisoProp:
	for n: Node in enemy.find_children("*", "", true, false):
		if n is RisoProp:
			return n as RisoProp
	return null


## The first few enemies from `scene` near the camera each have their touch over the middle of
## their printed body.
func covers(scene: String, what: String) -> void:
	var found: Array[Node] = placed(scene)
	check(not found.is_empty(), "%s in the level" % what)
	if found.is_empty():
		return
	var enemy: Node2D = found[0] as Node2D
	var camera: Camera2D = Stage.camera()
	for i: int in range(20):
		camera.global_position = enemy.global_position
		await process_frame
	var art: RisoProp = art_of(enemy)
	check(art != null, "%s is printed" % what)
	if art == null:
		return
	var middle: Vector2 = art.guard_center()
	var touch: Rect2 = touch_rect(enemy)
	check(touch.has_point(middle), "%s: its touch %s covers its printed body's middle %s (it stands at %s)" % [what, touch, middle, enemy.global_position])


## A wizard over the wisp's printed body, clear of the point it walks on, is hurt.
func wisp_touch() -> void:
	var wisp: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var art: RisoProp = art_of(wisp)
	var middle: Vector2 = art.guard_center()
	check(middle.y < wisp.global_position.y - 16.0, "the wisp's body floats over where it walks (%.0f px up)" % (wisp.global_position.y - middle.y))
	var damager: Damager = wisp.get_node("HitBox/Damager") as Damager
	var touched: Array[bool] = [false]
	damager.touched_player.connect(func() -> void: touched[0] = true)
	player.end_invulnerable()
	# The wizard (a box about 60 px high round their middle) just over the wisp's printed body,
	# their feet in its top and well above where it walks.
	player.global_position = middle + Vector2(0, -25)
	player.velocity = Vector2.ZERO
	await within(func() -> bool: return touched[0], 0.5)
	check(touched[0], "touching it where it is printed hurts the wizard")
	player.invulnerable.enable()
	player.health.health = player.health.max_health
	player.global_position = Vector2(-90000, -90000)


## The level puts a wisp at its cell's centre, and it settles onto its floor on its first step
## rather than hanging there to fall into place once its chunk wakes. Printed where it was put
## before that step, its body drops with it: printed again, it lies behind its head, not hanging
## over it from the drop, and its touch covers its middle.
func wisp_settles() -> void:
	var old: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var v: Vector2i = old.get_meta(&"cell")
	var floor_y: float = old.global_position.y
	old.queue_free()
	await until(gone(old))
	info.loader.place_cell(v, info.world.get_cell(v))
	var wisp: Node2D = placed("mover_enemy.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"cell") == v)[0] as Node2D
	var mover: Mover = wisp.get_node("Mover") as Mover
	# Held where it was put until its art has printed it there.
	mover.set_physics_process(false)
	var put: Vector2 = wisp.global_position
	var camera: Camera2D = Stage.camera()
	var printed: Callable = func() -> bool:
		camera.global_position = put
		var a: RisoProp = art_of(wisp)
		return a != null and a.guard_center() != wisp.global_position
	check(await until(printed), "the wisp put again is printed where it was put")
	var art: RisoProp = art_of(wisp)
	var first: Vector2 = art.guard_center()
	mover.set_physics_process(true)
	# One step: the first resumes before it, the second after it.
	await physics_frame
	await physics_frame
	check(absf(wisp.global_position.y - floor_y) < 1.0, "a wisp put in the level stands on its floor after its first step (put at %.1f, now at %.1f, its floor's wisps at %.1f)" % [put.y, wisp.global_position.y, floor_y])
	var reprinted: Callable = func() -> bool:
		camera.global_position = wisp.global_position
		return art.guard_center().y > first.y + 24.0
	check(await until(reprinted), "the wisp is printed again where it stands")
	var middle: Vector2 = art.guard_center()
	check((middle.x - wisp.global_position.x) * float(mover.direction) < -6.0, "its body dropped with it: it lies behind its head, not hanging over it (its middle %s from where it stands)" % (middle - wisp.global_position))
	check(touch_rect(wisp).has_point(middle), "and its touch covers its printed body's middle")
