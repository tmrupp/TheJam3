extends SceneTree
## The incoming music advances throughout the crossfade and survives both loop handoffs.
## godot --headless --path . --script res://tests/music_loop_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func run() -> void:
	var music: Node = Node.new()
	music.set_script(load("res://scripts/MusicPlayer.gd"))
	var stream: AudioStream = load("res://music/big_bossanova.wav")
	for player_name: String in ["MusicPlayer1", "MusicPlayer2"]:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = player_name
		player.stream = stream
		player.volume_db = -5.842
		music.add_child(player)
	root.add_child(music)
	var a: AudioStreamPlayer = music.get_node("MusicPlayer1")
	var b: AudioStreamPlayer = music.get_node("MusicPlayer2")
	check(stream.get_length() >= 95.0, "the track reaches the loop handoff")
	check(a.playing and not b.playing, "only the first track starts")
	for loop_index: int in range(2):
		a.seek(85.2)
		await create_timer(0.3).timeout
		var position_before: float = b.get_playback_position()
		await create_timer(0.3).timeout
		var position_after: float = b.get_playback_position()
		check(b.playing and position_after > position_before + 0.15,
			"incoming track advances across frames (loop %d: %.3f -> %.3f)" % [loop_index + 1, position_before, position_after])
		a.seek(90.0)
		await create_timer(0.08).timeout
		var base_gain: float = db_to_linear(-5.842)
		check(absf(a.volume_linear + b.volume_linear - base_gain) < 0.01,
			"crossfade keeps the combined gain steady")
		position_before = b.get_playback_position()
		a.seek(95.05)
		await create_timer(0.1).timeout
		check(not a.playing and b.playing and b.get_playback_position() >= position_before,
			"handoff stops only the outgoing track")
		check(is_equal_approx(b.volume_db, -5.842), "incoming track reaches its normal volume")
		var swap: AudioStreamPlayer = a
		a = b
		b = swap
	music.queue_free()
	await process_frame
	print("FAILED" if failed else "PASS: music loops")
	quit(1 if failed else 0)
