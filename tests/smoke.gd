extends SceneTree
## Headless checks:  godot --headless --path . --script res://tests/smoke.gd
## The checks live in checks.gd and run on the first frame, once the tree
## is live.

var _done := false


func _process(_dt: float) -> bool:
	if _done:
		return true
	_done = true
	# Every game script has to compile, or the checks can pass on nothing.
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			var g = load("res://scripts/" + f)
			if g == null or not g.can_instantiate():
				print("  FAIL scripts/%s doesn't compile (see the SCRIPT ERRORs above)" % f)
				print("DONE fails=1")
				quit(1)
				return false
	var scr = load("res://tests/checks.gd")
	if scr == null or not scr.can_instantiate():
		print("  FAIL the checks don't compile (see the SCRIPT ERRORs above)")
		print("DONE fails=1")
		quit(1)
		return false
	var c = scr.new()
	var fails: int = c.run(self)
	var duel = load("res://tests/duel_checks.gd")
	if duel == null or not duel.can_instantiate():
		print("  FAIL the duel checks don't compile")
		fails += 1
	else:
		fails += int(duel.new().run())
		print("DONE (with the duel) fails=%d" % fails)
	quit(1 if fails > 0 else 0)
	return false
