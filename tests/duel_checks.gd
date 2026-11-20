extends RefCounted
## The duel's rules, checked headless (run by smoke.gd).

var fails := 0


func check(ok: bool, name: String, info := "") -> void:
	if ok:
		print("  ok   ", name)
	else:
		fails += 1
		print("  FAIL ", name, "  ", info)


func run() -> int:
	print("the duel")
	_puppets()
	_blade_hits()
	_hero()
	_bodies()
	_whole()
	return fails


## The hero standing at p, facing the knight, doing nothing for n steps.
func _still(d: Duel, n: int) -> void:
	d.hero.cur = {"k": "wait", "label": "", "b": 0, "hit": false, "steps": []}
	for i in n:
		d.hero.cur["steps"].append({"ph": "wait"})


## Plays the knight's attack k through; returns the hero's health lost.
func _take(d: Duel, k: String) -> int:
	var hp := d.hero.hp
	d.knight.ang = (d.hero.pos - d.knight.pos).angle()
	d.start_attack(k)
	var n: int = d.knight.cur["steps"].size()
	if d.hero.idle():
		_still(d, n)
	for i in n:
		d.step()
	return hp - d.hero.hp


func _puppets() -> void:
	for k in ["knight", "hero"]:
		var path := String(Acts.DUEL_UNITS[k]["art"])
		check(not RigArt.get_rig(path).is_empty(), "the %s puppet loads" % k)
	var path := String(Acts.DUEL_UNITS["knight"]["art"])
	for a in ["sweep", "backhand", "overhead"]:
		var at: Dictionary = Acts.KNIGHT[a]
		check(RigArt.frames(path, a) == int(at["wind"]) + int(at["swing"]) + int(at["rec"]) + 1, "the %s clip has a frame a step" % a)
	for a in ["light", "heavy"]:
		var at: Dictionary = Acts.HERO[a]
		check(RigArt.frames(String(Acts.DUEL_UNITS["hero"]["art"]), a) == int(at["wind"]) + int(at["swing"]) + int(at["rec"]) + 1, "the hero's %s clip has a frame a step" % a)
	var d := Duel.new(1)
	var poly: PackedVector2Array = d.blade(d.knight, d.rest(d.knight), Vector2.ZERO, 0.0)[0]
	var far := 0.0
	for q in poly:
		far = maxf(far, q.length())
	check(far > 38.0 and far < 50.0, "the greatsword's blade is its real length", str(far))
	var mid := RigArt.pose(path, "sweep", 5.5)
	var a5 := float(RigArt.pose(path, "sweep", 5.0)["grip"]["rot"])
	var a6 := float(RigArt.pose(path, "sweep", 6.0)["grip"]["rot"])
	check(is_equal_approx(float(mid["grip"]["rot"]), (a5 + a6) / 2.0), "between steps the clip is part way")
	check(String(RigArt.pose(path, "overhead", 3.0)["blade"]["part"]) != "blade", "raised overhead, the blade is seen short")


func _blade_hits() -> void:
	# Beside him, inside the sweep: hit once (not once a step).
	var d := Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-26, 10)
	var lost := _take(d, "sweep")
	check(lost == int(Acts.KNIGHT["sweep"]["dmg"]), "the sweep hits a hero beside him, once", str(lost))
	# Out past the blade's tip: missed.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-60, 0)
	d.knight.ang = PI
	d.start_attack("sweep")
	_still(d, 12)
	var hp := d.hero.hp
	for i in 10:
		d.step()
	check(d.hero.hp == hp, "past the blade's tip, missed")
	# The overhead only hits ahead of him, not to the side.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-34, 0)
	check(_take(d, "overhead") == int(Acts.KNIGHT["overhead"]["dmg"]), "the overhead hits straight ahead")
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-24, 18)
	var aim := (d.hero.pos - d.knight.pos).angle()
	d.knight.ang = aim + 0.9  # turned well away
	d.start_attack("overhead")
	d.knight.cur["steps"] = d.knight.cur["steps"].map(func(s):
		var e: Dictionary = s.duplicate()
		e.erase("track")
		return e)
	_still(d, 12)
	hp = d.hero.hp
	for i in 12:
		d.step()
	check(d.hero.hp == hp, "the overhead misses a hero off to his side")
	# Raised, the overhead's blade doesn't hit, even over the hero.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(14, 0)  # behind him, where it's raised
	d.knight.ang = PI
	d.start_attack("overhead")
	d.knight.cur["steps"] = d.knight.cur["steps"].slice(0, 6)
	_still(d, 6)
	hp = d.hero.hp
	for i in 6:
		d.step()
	check(d.hero.hp == hp, "the raised blade doesn't hit")
	# A fast blade can't skip past: a whole sweep in one step still hits.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-30, 0)
	d.knight.ang = PI
	d.knight.cur = {"k": "test", "label": "", "b": 0, "hit": false, "steps": [
		{"ph": "act", "clip": "sweep", "frame": 3}, {"ph": "act", "clip": "sweep", "frame": 8, "live": true, "dmg": 10}]}
	_still(d, 2)
	d.step()
	d.step()
	check(d.hero.hp == d.hero.max_hp - 10, "a swing between two far apart steps still hits what it passes")


func _hero() -> void:
	# Rolling through the swing on the safe steps: no hit.
	var d := Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-30, 0)
	d.knight.ang = PI
	d.start_attack("sweep")
	for i in 3:  # the wind-up
		_still(d, 1)
		d.step()
	check(d.plan("roll", d.hero.pos + Vector2(0, -50)), "the hero can roll")
	var hp := d.hero.hp
	d.step()
	d.step()
	check(d.hero.hp == hp, "rolling, the first steps are safe")
	# Waiting there instead: hit.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-30, 0)
	check(_take(d, "sweep") > 0, "standing there instead, hit")
	# Stamina: paid, and not enough means no.
	d = Duel.new(1)
	var st := d.stamina
	d.plan("roll", d.hero.pos + Vector2(20, 0))
	check(d.stamina == st - Duel.cost("roll"), "a roll costs stamina")
	d = Duel.new(1)
	d.stamina = Duel.cost("heavy") - 1
	check(not d.plan("heavy", d.knight.pos) and d.wiggle.has("stamina"), "too little stamina: no, and the bar wiggles")
	# The hero's swing hits the knight, once.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-14, 0)
	d.knight.cur = {"k": "wait", "label": "", "b": 0, "hit": false, "steps": []}
	for i in 12:
		d.knight.cur["steps"].append({"ph": "wait"})
	d.plan("light", d.knight.pos)
	for i in 7:
		d.step()
	check(d.knight.hp == d.knight.max_hp - int(Acts.HERO["light"]["dmg"]), "the light attack hits the knight once", str(d.knight.max_hp - d.knight.hp))
	# A flask heals, and there are only so many.
	d = Duel.new(1)
	d.hero.hp = 50
	d.knight.pos = Vector2(360, 160)
	d.plan("flask", d.hero.pos)
	for i in int(Acts.HERO["drink"]):
		d.knight.cur = {"k": "wait", "label": "", "b": 0, "hit": false, "steps": [{"ph": "wait"}]}
		d.step()
	check(d.hero.hp == 50 + int(Acts.HERO["heal"]) and d.flasks == int(Acts.HERO["flasks"]) - 1, "a flask heals")
	d.flasks = 0
	check(not d.plan("flask", d.hero.pos), "no flasks left: no")
	# Blocking toward the swing, step after step: no damage. Turned away: hit.
	for away in [false, true]:
		d = Duel.new(1)
		d.hero.pos = d.knight.pos + Vector2(-30, 0)
		d.knight.ang = PI
		d.start_attack("sweep")
		var face := d.hero.pos + (Vector2(-20, 0) if away else Vector2(20, 0))
		hp = d.hero.hp
		for i in d.knight.cur["steps"].size():
			if d.hero.idle():
				d.plan("block", face)
			d.step()
		if away:
			check(d.hero.hp < hp, "blocking the wrong way, hit")
		else:
			check(d.hero.hp == hp, "blocking toward the swing, no damage", str(hp - d.hero.hp))
	check(d.shape("block", d.knight.pos)["steps"].size() == 1, "a block is one step")
	for h in Acts.HANDS:
		var it: Dictionary = Acts.ITEMS[Acts.HANDS[h]]
		for k in it["does"]:
			check(not d.shape(k, d.knight.pos).is_empty(), "the %s hand's %s works" % [h, k])
	# A walk stops when the knight starts an attack.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-60, 0)
	d.plan("move", d.hero.pos + Vector2(-100, 0))
	d.knight.ang = PI
	d.start_attack("sweep")
	d.knight.cur["b"] = 0
	d.step()
	check(d.hero.idle(), "a walk stops when the knight starts a swing")


func _bodies() -> void:
	var d := Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-30, 0)
	d.plan("move", d.knight.pos)
	for i in 10:
		d.knight.cur = {"k": "wait", "label": "", "b": 0, "hit": false, "steps": [{"ph": "wait"}]}
		d.step()
	check(d.hero.pos.distance_to(d.knight.pos) >= Duel._radius(d.hero) + Duel._radius(d.knight) - 0.01, "the hero can't walk through the knight")
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-34, 0)
	d.knight.ang = PI
	d.start_attack("overhead")
	_still(d, 12)
	for i in 12:
		d.step()
	check(d.hero.pos.distance_to(d.knight.pos) >= Duel._radius(d.hero) + Duel._radius(d.knight) - 0.01, "his lunge pushes the hero aside")


## Whole fights, the hero pressing light attacks: they end.
func _whole() -> void:
	var ended := 0
	for s in 3:
		var d := Duel.new(s + 1)
		for i in 3000:
			if d.result != "":
				break
			if d.hero.idle():
				if d.hero.pos.distance_to(d.knight.pos) > 22.0:
					d.plan("move", d.knight.pos)
				elif not d.plan("light", d.knight.pos):
					d.plan("wait", d.hero.pos)
			d.step()
		if d.result != "":
			ended += 1
	check(ended == 3, "3 whole fights end")
