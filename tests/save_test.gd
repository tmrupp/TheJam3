extends TestKit
## How the run is saved (docs/CODE_REVIEW.md 1.6, 1.7, 2.5). A save file is written whole or not at
## all (SafeFile): a file cut short is read from the last good one, and one left half written is
## passed over. Whatever changes the run only marks it (MapInfo.save_run), and the save is written
## once as the frame is processed; save_now writes at once. The kept map (Known) is noted on
## arriving in a level and by save_now, not with every autosave.
## godot --headless --path . --script res://tests/save_test.gd


func run() -> void:
	_safe_file()
	_records()
	await boot(28)
	freeze()

	print("one write a frame")
	await settle()
	RunState.delete_save()
	for i: int in range(5):
		info.save_run()
	check(RunState.read_save().is_empty(), "asked five times in a frame, nothing is written yet")
	await frames(2)
	var saved: Dictionary = RunState.read_save()
	check(saved.get("coord") == info.coord, "the frame processed, the run is saved")
	RunState.delete_save()
	await frames(2)
	check(RunState.read_save().is_empty(), "and it is not written again until something changes")
	player.collect(7)
	info.save_now()
	check_eq(int(RunState.read_save().get("stars", -1)), player.coins.coins, "save_now writes at once")
	info.save_run()
	check(info.continue_run(), "a run continued takes up a change not yet written")
	await settle()
	freeze()

	print("the kept map")
	var at: Vector2i = Vector2i(info.run.run_seed, 1)
	await go(at)
	check(Known.has(at), "arriving in a level notes it in the kept map")
	var kept_before: int = _kept_seen(at)
	var far: Vector2i = info.world.free_floors()[-1]
	info.reveal(far)
	check(info.seen().count(1) > kept_before, "more of it seen")
	info.save_run()
	await frames(2)
	check_eq(_kept_seen(at), kept_before, "an autosave leaves the kept map as it was")
	info.save_now()
	check_eq(_kept_seen(at), info.seen().count(1), "save_now (pausing, quitting) notes what was seen since")
	info.reveal(info.world.free_floors()[0])
	var seen: int = info.seen().count(1)
	await go(Vector2i(info.run.run_seed, 0))
	check_eq(_kept_seen(at), seen, "and so does arriving in the next level")
	RunState.delete_save()
	Known.forget()
	finish()


## How many cells of place `c` the kept map holds as seen.
func _kept_seen(c: Vector2i) -> int:
	var place: Dictionary = (Known.kept()["places"] as Dictionary).get(c, {})
	return (place.get("seen", PackedByteArray()) as PackedByteArray).count(1)


## SafeFile alone, on a file of the test's own.
func _safe_file() -> void:
	print("a file written whole or not at all")
	var path: String = "user://%s.safe" % test_name()
	SafeFile.remove(path)
	check(SafeFile.read(path) == null and not SafeFile.exists(path), "nothing kept: nothing read")
	check(SafeFile.write(path, {"n": 1}) and SafeFile.read(path) == {"n": 1}, "written and read back")
	check(not FileAccess.file_exists(path + SafeFile.NEW), "nothing left half written beside it")
	check(SafeFile.write(path, {"n": 2}) and SafeFile.read(path) == {"n": 2}, "written over")
	var last: FileAccess = FileAccess.open(path + SafeFile.LAST, FileAccess.READ)
	check(last != null and last.get_var() == {"n": 1}, "the file before it is kept as the last good one")
	last.close()
	# A write cut short in the file itself (as before SafeFile, or the disk's own doing).
	var whole: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var cut: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	cut.store_buffer(whole.slice(0, whole.size() / 2))
	cut.close()
	check(SafeFile.read(path) == {"n": 1}, "the file cut short: the last good one is read")
	cut = FileAccess.open(path, FileAccess.WRITE)
	cut.close()
	check(SafeFile.read(path) == {"n": 1}, "the file empty: the last good one is read")
	# A crash between the two moves: the file gone aside, the new one not yet given its name.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var half: FileAccess = FileAccess.open(path + SafeFile.NEW, FileAccess.WRITE)
	half.store_buffer(whole.slice(0, 3))
	half.close()
	check(SafeFile.exists(path) and SafeFile.read(path) == {"n": 1}, "the file missing, one half written beside it: the last good one is read")
	check(SafeFile.write(path, {"n": 3}) and SafeFile.read(path) == {"n": 3}, "and the next write goes through")
	SafeFile.remove(path)
	check(not SafeFile.exists(path) and not FileAccess.file_exists(path + SafeFile.NEW) and SafeFile.read(path) == null, "removed: the file, the last good one and the half written one")


## A level's record keeps the institute's part under its own name (InstituteRecord), and reads a
## save from before it did, whose fields lay among the level's.
func _records() -> void:
	print("the institute's part of a record")
	var rec: LevelRecord = LevelRecord.new()
	rec.institute.rings = 3
	rec.institute.passing = false
	rec.institute.dept_tiers = {&"hex": 2}
	rec.mapped = true
	var saved: Dictionary = rec.to_dict()
	check(saved.has("institute") and not saved.has("rings") and int((saved["institute"] as Dictionary)["rings"]) == 3, "saved under its own name, not among the level's fields")
	var back: LevelRecord = LevelRecord.from_dict(saved)
	check(back.mapped and back.institute.rings == 3 and not back.institute.passing and back.institute.dept_tiers == {&"hex": 2}, "and read back")
	var old: LevelRecord = LevelRecord.from_dict({"mapped": true, "rings": 5, "passing": false, "started": 2})
	check(old.mapped and old.institute.rings == 5 and not old.institute.passing and old.institute.started == 2, "a save from before, its fields among the level's, is read all the same")
