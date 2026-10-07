extends TestKit
## F7 character choices, their state cues, and smoke without changes to the run or collision.


func run() -> void:
	await boot()
	player.set_physics_process(false)
	player.end_invulnerable()
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED
	var wizard: RisoWizard = player.get_node("RisoWizard") as RisoWizard
	wizard.set_process(false)
	wizard.set_physics_process(false)
	wizard.t = 1.0
	var riso: RisoPrint = RisoPrint.instance
	var picker: OptionButton = riso._options[&"character"] as OptionButton
	check_eq(picker.item_count, 4, "F7 offers the wizard and all three travelers")
	check_eq(picker.get_item_text(picker.selected), "Wizard", "the original wizard remains the default")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F7
	key.pressed = true
	riso._unhandled_key_input(key)
	check(riso.panel.visible, "F7 opens the character controls")
	riso.panel.visible = false
	var collider: CollisionShape2D = player.get_node("CollisionShape2D") as CollisionShape2D
	var size: Vector2 = (collider.shape as RectangleShape2D).size
	var rng_state: int = info.world.rng.state
	var corpse: Ghost = (load("res://prefabs/corpse.tscn") as PackedScene).instantiate() as Ghost
	main.add_child(corpse)
	await process_frame
	await process_frame
	var ghost_art: RisoProp = corpse.get_node("RisoArt") as RisoProp
	ghost_art.set_process(false)
	ghost_art.t = 1.0
	var ghost_shapes: Dictionary = {}
	var outlines: Dictionary = {}
	for index: int in range(RisoPrint.CHARACTER_STYLES.size()):
		picker.select(index)
		picker.item_selected.emit(index)
		check_eq(wizard.character_style(), RisoPrint.CHARACTER_STYLES[index], "F7 selects " + picker.get_item_text(index))
		riso._sync_panel()
		check_eq(picker.selected, index, "the panel follows the chosen appearance")
		var outline: int = hash(wizard._silhouette(Transform2D.IDENTITY, 1.0))
		check(not outlines.has(outline), "each traveler has its own echo silhouette")
		outlines[outline] = true
		ghost_art._redraw()
		var ghost_print: int = fingerprint(ghost_art.ink)
		check(not ghost_shapes.has(ghost_print), "the death ghost follows the chosen appearance")
		ghost_shapes[ghost_print] = true
		if index == 0:
			continue
		Abilities.set_tier(player, &"hex", 1)
		player.health.health = 3
		info.run.vulnerable = false
		player.dash.acted = false
		wizard._draw_body()
		riso.robe_by_spell = false
		riso.robe_color = Color(-1, -1, -1)
		riso._ease_robe(1.0)
		check_eq(riso.robe_color, RisoPrint.ROBES[&"hex"], "the accessory keeps its spell ink with Robe set to Blue")
		riso._update_uniforms(Vector2(1280, 720))
		var cloth: Vector3 = Vector3(RisoPrint.CLOTH_INK.r, RisoPrint.CLOTH_INK.g, RisoPrint.CLOTH_INK.b)
		check_eq(riso.print_material.get_shader_parameter("ink7"), cloth, "traveler cloth keeps its own blue in the garden")
		check_eq(riso.ui_material.get_shader_parameter("ink7"), cloth, "the UI shares all eight inks")
		var full: int = fingerprint(wizard.body)
		player.health.health = 1
		wizard._draw_body()
		check(full != fingerprint(wizard.body), "lost hearts change the printed beads")
		var hurt: int = fingerprint(wizard.body)
		info.run.vulnerable = true
		wizard._draw_body()
		check(hurt != fingerprint(wizard.body), "the lantern independently goes dark")
		var unprotected: int = fingerprint(wizard.body)
		player.dash.acted = true
		wizard._draw_body()
		check(unprotected != fingerprint(wizard.body), "a spent dash still changes its own mark while unprotected")
		wizard.lantern_smoke.clear()
		for step: int in range(12):
			wizard._step_smoke(RisoWizard.SMOKE_STEP)
			player.position.x += 2.0
		check(wizard.lantern_smoke.size() >= 10, "an unlit lantern leaves a trail")
		check(wizard.lantern_smoke[0].x < wizard.lantern_smoke[-1].x, "smoke stays at the lantern's past positions")
		wizard._draw_world()
		check(wizard.world._used > 0, "the smoke is printed in the world")
		info.run.vulnerable = false
		wizard._step_smoke(RisoWizard.SMOKE_LIFE + 0.1)
		check(wizard.lantern_smoke.is_empty(), "after relighting, the old smoke fades and no new smoke appears")
		var spell_shapes: Dictionary = {}
		var accessory_shapes: Dictionary = {}
		for spell: StringName in Abilities.spells():
			Abilities.set_tier(player, spell, 1)
			wizard._draw_body()
			var print: int = fingerprint(wizard.body)
			check(not spell_shapes.has(print), "the carried " + String(spell) + " has a distinct print")
			spell_shapes[print] = true
			if index >= 2:
				var accessory: int = hash(RisoCostume.mask_shape(spell, Vector2.ZERO) if index == 2 else RisoCostume.bindle_shape(spell, Vector2.ZERO))
				check(not accessory_shapes.has(accessory), "the whole accessory changes shape for " + String(spell))
				accessory_shapes[accessory] = true
		Abilities.set_tier(player, &"vigor", 3)
		player.health.health = player.health.max_health
		wizard._draw_body()
		check_eq(player.health.max_health, 6, "the beads support vigor's additional health")
		Abilities.set_tier(player, &"vigor", 0)
		player.health.health = 3
		player.phasing = true
		wizard._draw_body()
		check(is_equal_approx(wizard.body.coverage, AstralProjection.PROJECTION_COVER), "the selected figure supports astral translucency")
		player.phasing = false
		wizard._draw_body()
		check(is_equal_approx(wizard.body.coverage, 1.0), "the selected figure returns to full coverage")
		check_eq((collider.shape as RectangleShape2D).size, size, "choosing an appearance never changes collision")
		check_eq(info.world.rng.state, rng_state, "drawing and smoke do not consume the level RNG")
	riso.set_character_style(&"cosmonaut")
	info.run.vulnerable = true
	wizard._step_smoke(RisoWizard.SMOKE_STEP)
	riso.set_character_style(&"fool")
	check(wizard.lantern_smoke.is_empty(), "changing appearance clears the former lantern's smoke")
	for step: int in range(120):
		wizard._step_smoke(RisoWizard.SMOKE_STEP)
	check(wizard.lantern_smoke.size() <= int(ceil(RisoWizard.SMOKE_LIFE / RisoWizard.SMOKE_STEP)) + 1, "the smoke trail stays bounded over time")
	wizard._on_event(&"teleport", wizard.global_position)
	check(wizard.lantern_smoke.is_empty(), "teleporting clears the former location's smoke")
	var fx: RisoPortalWarp = RisoPrint._warp(wizard, 0, Vector2.ZERO, wizard.global_position, RisoPrint.ACCENT)
	check_eq(fx.character_style, &"fool", "portal effects carry the chosen silhouette")
	fx.free()
	info.run.vulnerable = false
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	check_eq(riso.character_style, &"fool", "the appearance survives travel")
	main.queue_free()
	await process_frame
	await process_frame
	finish()


## The actual ordered ink and geometry, rather than a copy of the state being tested.
func fingerprint(ink: InkCanvas) -> int:
	var printed: Array = []
	for i: int in range(ink._used):
		var op: RisoInkOp = ink._ops[i]
		printed.append([op.visibility_layer, op.lift, op.cover, op.polys, op.alphas])
	return hash(printed)
