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
	var hp_art := String(Acts.DUEL_UNITS["hero"]["art"])
	for th in Acts.ITEMS:
		var it: Dictionary = Acts.ITEMS[th]
		check(RigArt.frames(hp_art, String(it["key"]) + "_hold") == 1, "the hero can hold the %s" % th)
		for o in it["does"]:
			var at: Dictionary = it["does"][o]
			var n := 1
			if at.has("wind"):
				n = int(at["wind"]) + int(at["swing"]) + int(at["rec"])
			elif at.has("reload"):
				n = int(at["reload"])
			check(RigArt.frames(hp_art, String(at["clip"])) == n + 1, "the %s's %s clip has a frame a step" % [th, o])
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
	check(d.stamina == st - d.cost("roll"), "a roll costs stamina")
	d = Duel.new(1)
	d.stamina = d.cost("right:heavy") - 1
	check(not d.plan("right:heavy", d.knight.pos) and d.wiggle.has("stamina"), "too little stamina: no, and the bar wiggles")
	# The hero's swing hits the knight, once.
	d = Duel.new(1)
	d.hero.pos = d.knight.pos + Vector2(-14, 0)
	d.knight.cur = {"k": "wait", "label": "", "b": 0, "hit": false, "steps": []}
	for i in 12:
		d.knight.cur["steps"].append({"ph": "wait"})
	d.plan("right:light", d.knight.pos)
	for i in 7:
		d.step()
	check(d.knight.hp == d.knight.max_hp - int(Acts.ITEMS["longsword"]["does"]["light"]["dmg"]), "the light attack hits the knight once", str(d.knight.max_hp - d.knight.hp))
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
				d.plan("left:block", face)
			d.step()
		if away:
			check(d.hero.hp < hp, "blocking the wrong way, hit")
		else:
			check(d.hero.hp == hp, "blocking toward the swing, no damage", str(hp - d.hero.hp))
	check(d.shape("left:block", d.knight.pos)["steps"].size() == 1, "a block is one step")
	_gear()
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
				elif not d.plan("right:light", d.knight.pos):
					d.plan("wait", d.hero.pos)
			d.step()
		if d.result != "":
			ended += 1
	check(ended == 3, "3 whole fights end")


## A duel with this gear, the knight standing still far off (or at `at`).
func _armed(left: String, right: String, at := Vector2(-80, 0)) -> Duel:
	var d := Duel.new(1, Duel.equip(Duel.equip(Acts.HANDS, "left", left), "right", right))
	d.knight.pos = d.hero.pos + at.abs()
	d.knight.ang = PI
	_still_knight(d, 60)
	return d


func _still_knight(d: Duel, n: int) -> void:
	d.knight.cur = {"k": "wait", "label": "", "b": 0, "hit": false, "steps": []}
	for i in n:
		d.knight.cur["steps"].append({"ph": "wait"})


## Plays until the hero is free again (at most n steps).
func _until_free(d: Duel, n := 40) -> void:
	for i in n:
		d.step()
		if d.hero.idle():
			return


func _gear() -> void:
	# Every item, in every hand it fits, does everything in its menu.
	for th in Acts.GEAR:
		for h in ["left", "right"]:
			var d := Duel.new(1, Duel.equip(Acts.HANDS, h, th))
			var hand: String = h if d.hands().size() == 2 else "right"
			for o in d.item(hand)["does"]:
				check(not d.shape(hand + ":" + o, d.knight.pos).is_empty(), "%s in the %s hand: %s" % [th, h, o])
	var g := Duel.equip(Acts.HANDS, "left", "bow")
	check(g["left"] == "bow" and g["right"] == "bow", "a two-handed item fills both hands")
	g = Duel.equip(g, "right", "staff")
	check(g["right"] == "staff" and int(Acts.ITEMS[g["left"]]["hands"]) == 1, "a one-handed item beside it: the other hand gets one too")
	# The claymore's swing hits; so does the longsword in the left hand.
	for lr in [["kite shield", "claymore", "right:light"], ["longsword", "staff", "left:light"]]:
		var d := _armed(lr[0], lr[1], Vector2(18, 0))
		d.plan(lr[2], d.knight.pos)
		_until_free(d)
		check(d.knight.hp < d.knight.max_hp, "%s with %s / %s hits" % [lr[2], lr[0], lr[1]], str(d.knight.hp))
	# An arrow flies its speed a step and hits the knight far off.
	var d := _armed("bow", "bow", Vector2(150, 0))
	check(d.plan("right:arrow", d.knight.pos), "the bow shoots")
	for i in int(Acts.ITEMS["bow"]["does"]["arrow"]["wind"]) + 1:
		d.step()
	check(d.shots.size() == 1, "the arrow is in the air")
	var p0: Vector2 = d.shots[0]["p"]
	d.step()
	check(d.shots.is_empty() or is_equal_approx(Vector2(d.shots[0]["p"]).distance_to(p0), float(Acts.SHOTS["arrow"]["speed"])), "it flies its speed a step")
	_until_free(d)
	for i in 10:
		d.step()
	check(d.knight.max_hp - d.knight.hp == int(Acts.SHOTS["arrow"]["dmg"]), "the arrow hits the knight", str(d.knight.max_hp - d.knight.hp))
	# Fire burns for steps after.
	d = _armed("bow", "bow", Vector2(60, 0))
	d.plan("right:fire arrow", d.knight.pos)
	for i in 8:
		d.step()
	var after := d.knight.hp
	check(d.knight.burns.has("fire"), "a fire arrow sets him burning")
	d.step()
	check(d.knight.hp < after, "burning hurts every step")
	# Crossbow: shoots when loaded, not again until reloaded.
	d = _armed("crossbow", "longsword", Vector2(60, 0))
	check(d.plan("left:poison bolt", d.knight.pos), "the loaded crossbow shoots")
	_until_free(d)
	check(not d.loaded["left"], "then it's empty")
	check(not d.plan("left:bolt", d.knight.pos) and d.wiggle.has("hand:left"), "empty: can't shoot, the hand wiggles")
	check(d.plan("left:reload", d.knight.pos), "reload")
	_until_free(d)
	check(d.loaded["left"] and d.plan("left:bolt", d.knight.pos), "loaded again, it shoots")
	for i in 6:
		d.step()
	check(d.knight.burns.has("poison"), "the poison bolt poisoned him")
	# Enough hits and the knight staggers: his swing stops.
	d = _armed("kite shield", "claymore", Vector2(18, 0))
	d.start_attack("overhead")
	d.knight.taken = int(Acts.KNIGHT["poise"]) - 1
	d.plan("right:light", d.knight.pos)
	for i in 12:
		d.step()
		if d.knight.hp < d.knight.max_hp:
			break
	check(String(d.knight.cur.get("k", "")) == "stagger", "enough hits: he staggers, his swing stopped", str(d.knight.cur.get("k", "")))
	d = Duel.new(1)
	d.knight.taken = 50
	d.hero.pos = Vector2(30, 30)
	for i in int(Acts.KNIGHT["calm"]) + 1:
		_still_knight(d, 1)
		d.step()
	check(d.knight.taken == 0, "left alone a while, his poise comes back")
	# Staff: casts run out.
	d = _armed("kite shield", "staff", Vector2(60, 0))
	var c := int(d.casts["right:bolt"])
	check(d.plan("right:bolt", d.knight.pos) and int(d.casts["right:bolt"]) == c - 1, "a cast uses one up")
	_until_free(d)
	d.casts["right:heavy bolt"] = 0
	check(not d.plan("right:heavy bolt", d.knight.pos), "none left: no")
