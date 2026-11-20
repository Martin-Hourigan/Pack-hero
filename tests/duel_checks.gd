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
	_foes()
	_ranges()
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
		if it.has("split"):
			continue
		check(RigArt.frames(hp_art, String(it["key"]) + "_hold") == 1, "the hero can hold the %s" % th)
		if it.has("two"):
			check(RigArt.frames(hp_art, String(it["key"]) + "2_hold") == 1, "the hero can hold the %s in two hands" % th)
		var moves: Dictionary = it["does"].duplicate()
		for o in it.get("two", {}):
			moves["two " + o] = it["two"][o]
		for o in moves:
			var at: Dictionary = moves[o]
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
	# GUARD on, facing the swing: no damage, whatever he's doing. Turned
	# away: hit.
	for away in [false, true]:
		d = Duel.new(1)
		d.hero.pos = d.knight.pos + Vector2(-30, 0)
		d.knight.ang = PI
		d.start_attack("sweep")
		check(d.toggle_guard() and d.guard, "GUARD goes on")
		d.hero.ang = PI if away else 0.0
		hp = d.hero.hp
		for i in d.knight.cur["steps"].size():
			if d.hero.idle():
				d.plan("wait", d.hero.pos)
			d.step()
		if away:
			check(d.hero.hp < hp, "guarding the wrong way, hit")
		else:
			check(d.hero.hp == hp, "guarding toward the swing, no damage", str(hp - d.hero.hp))
	# Attacking doesn't drop the guard; rolling does. Stamina comes back slower.
	d = _armed("kite shield", "longsword")
	d.toggle_guard()
	d.plan("right:light", d.knight.pos)
	_until_free(d)
	check(d.guard, "an attack keeps GUARD on")
	d.stamina = 50
	d.plan("wait", d.hero.pos)
	d.step()
	check(d.stamina == 50 + int(Acts.HERO["guard_back"]), "guarding, stamina comes back slower", str(d.stamina))
	d.plan("roll", d.hero.pos + Vector2(-20, 0))
	check(not d.guard, "a roll drops GUARD")
	d = _armed("crossbow", "longsword")
	check(not d.toggle_guard() and d.wiggle.has("guard"), "nothing to block with: GUARD wiggles")
	# LOCK: picked by where you tap; shots aim at it wherever you point,
	# swings where you point; walking, he faces it.
	d = _armed("longsword", "staff")
	var dummy := d._add("knight", d.hero.pos + Vector2(0, 60), 0.0)
	dummy.side = "enemy"
	check(d.enemy_at(d.knight.pos + Vector2(3, 0)) == d.knight and d.enemy_at(dummy.pos) == dummy, "a tap on an enemy picks it")
	check(d.enemy_at(d.hero.pos) == null, "a tap off them picks nothing")
	d.target = dummy
	var b := d.shape("right:bolt", d.hero.pos + Vector2(50, 0))
	check(is_equal_approx(float(b["steps"][0]["face"]), (dummy.pos - d.hero.pos).angle()), "locked on to the other: a shot aims at it")
	d.target = d.knight
	var a := d.shape("right:bolt", d.hero.pos + Vector2(0, -50))
	check(is_equal_approx(float(a["steps"][0]["face"]), (d.knight.pos - d.hero.pos).angle()), "locked on: a shot aims at him")
	var sw := d.shape("left:light", d.hero.pos + Vector2(0, -50))
	check(is_equal_approx(float(sw["steps"][0]["face"]), -PI / 2.0), "locked on: a swing goes where you aim")
	d.plan("move", d.hero.pos + Vector2(0, 30))
	d.step()
	check(absf(angle_difference(d.hero.ang, (d.knight.pos - d.hero.pos).angle())) < 0.01, "locked on: walking, he faces him")
	dummy.hp = 0
	d.target = dummy
	d.step()
	check(d.target == null, "the one locked on to dies: LOCK lets go")
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


## A room of these enemies (Acts.FOES), lined up at x 280.
func _room(ks: Array, gear := {"left": ["kite shield", "staff"], "right": ["longsword", "claymore"]}) -> Duel:
	var room := []
	for i in ks.size():
		room.append({"k": ks[i], "at": Vector2(280, 40 + 40 * i), "a": PI})
	return Duel.new(1, gear, room)


func _foes() -> void:
	for k in ["soldier", "spearman", "archer"]:
		var path := String(Acts.DUEL_UNITS[k]["art"])
		check(not RigArt.get_rig(path).is_empty(), "the %s puppet loads" % k)
		for a in Acts.FOES[k]["attacks"]:
			var at: Dictionary = Acts.FOES[k][a]
			check(RigArt.frames(path, String(at["clip"])) == int(at["wind"]) + int(at["swing"]) + int(at["rec"]) + 1, "the %s's %s clip has a frame a step" % [k, a])
	# A soldier walks in and cuts the hero (standing still).
	var d := _room(["soldier"])
	d.hero.pos = Vector2(200, 40)
	var hp := d.hero.hp
	for i in 60:
		if d.hero.idle():
			_still(d, 1)
		d.step()
	check(d.hero.hp < hp, "a soldier walks in and cuts you", str(hp - d.hero.hp))
	# A spearman's thrust reaches; an archer keeps away and shoots.
	for k in ["spearman", "archer"]:
		d = _room([k])
		d.hero.pos = Vector2(200, 40)
		hp = d.hero.hp
		for i in 80:
			if d.hero.idle():
				_still(d, 1)
			d.step()
		check(d.hero.hp < hp, "a %s hurts you" % k, str(hp - d.hero.hp))
	d = _room(["archer"])
	d.hero.pos = Vector2(260, 40)
	for i in 6:
		_still(d, 1)
		d.step()
	check(d.foes[0].pos.distance_to(d.hero.pos) > 20.0 + 6.0 * 0.5, "an archer backs away from you")
	# Enemies don't hurt each other: an archer shooting past a soldier.
	d = _room(["soldier", "archer"])
	d.foes[0].pos = Vector2(240, 40)
	d.foes[1].pos = Vector2(300, 40)
	d.hero.pos = Vector2(160, 40)
	for i in 40:
		_still(d, 1)
		d.step()
	check(d.foes[0].hp == d.foes[0].max_hp, "an enemy's arrow doesn't hurt another enemy")
	# One sweep hits two soldiers.
	d = _room(["soldier", "soldier"], {"left": ["kite shield", "staff"], "right": ["claymore", "longsword"]})
	d.hero.pos = Vector2(200, 92)
	d.foes[0].pos = Vector2(218, 84)
	d.foes[1].pos = Vector2(218, 100)
	for f in d.foes:
		_still_foe(f, 30)
	d.plan("right:light", Vector2(230, 92))
	_until_free(d)
	check(d.foes.all(func(f): return f.hp < f.max_hp), "one sweep hits both soldiers", str(d.foes.map(func(f): return f.hp)))
	# Enough damage staggers a soldier; all dead: won.
	d = _room(["soldier"])
	d.hero.pos = Vector2(262, 40)
	d.foes[0].taken = int(Acts.SOLDIER["poise"]) - 1
	_still_foe(d.foes[0], 30)
	d.plan("right:light", d.foes[0].pos)
	for i in 8:
		d.step()
		if d.foes[0].hp < d.foes[0].max_hp:
			break
	check(String(d.foes[0].cur.get("k", "")) == "stagger", "a soldier staggers")
	d.foes[0].hp = 1
	_still_foe(d.foes[0], 30)
	d.hero.cur = {}
	d.plan("right:light", d.foes[0].pos)
	_until_free(d)
	check(d.result == "win", "every enemy dead: won", d.result)


func _still_foe(f: Unit, n: int) -> void:
	f.cur = {"k": "wait", "label": "", "b": 0, "struck": [], "steps": []}
	for i in n:
		f.cur["steps"].append({"ph": "wait"})


## Shots go their range and no further; the greatbow's is the farthest.
func _ranges() -> void:
	var most := ""
	for k in Acts.SHOTS:
		if most == "" or float(Acts.SHOTS[k]["range"]) > float(Acts.SHOTS[most]["range"]):
			most = k
	check(most.contains("great"), "the greatbow reaches the farthest", most)
	for k in ["arrow", "great arrow", "magic bolt"]:
		var d := _room(["soldier"])  # (off the line, standing still)
		_still_foe(d.foes[0], 60)
		d.hero.pos = Vector2(20, 92)
		d.hero.ang = 0.0
		d._shoot(k, "")
		var start: Vector2 = d.shots[0]["p"]
		var far := 0.0
		for i in 40:
			_still(d, 1)
			d.step()
			if d.shots.is_empty():
				break
			far = Vector2(d.shots[0]["p"]).distance_to(start)
		check(d.shots.is_empty() and far <= float(Acts.SHOTS[k]["range"]) + 0.01, "a %s goes its range, then it's gone" % k, str(far))


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


## Gear with these held in the left and right hands (second slots: a
## staff, a longsword).
func _kit(left: String, right: String, left2 := "staff", right2 := "longsword") -> Dictionary:
	return {"left": [left, left2], "right": [right, right2]}


## A duel with this gear, the knight standing still far off (or at `at`).
func _armed(left: String, right: String, at := Vector2(-80, 0), left2 := "staff", right2 := "longsword") -> Duel:
	var d := Duel.new(1, _kit(left, right, left2, right2))
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
	# Every item, in either hand, one- or two-handed, in every form, does
	# everything in its menu.
	for th in Acts.GEAR:
		for h in ["left", "right"]:
			var kit := _kit("kite shield", "longsword")
			kit[h][0] = th
			var d := _armed(kit["left"][0], kit["right"][0])
			for form in 3:
				for hand in d.hands():
					for o in d.options(hand):
						if o == "block":
							continue  # GUARD's
						check(not d.shape(hand + ":" + o, d.knight.pos).is_empty(), "%s in the %s hand (%s): %s" % [th, h, d.item_key(hand), o])
				var hand0: String = d.hands()[0] if h in d.hands() else h
				var change := ""
				for c in ["two hands", "transform"]:
					if d.options(hand0).has(c):
						change = c
				if change == "" or form == 2:
					break
				check(d.plan(hand0 + ":" + change, d.hero.pos), "%s: %s" % [th, change])
				_until_free(d)
	var d0 := Duel.new(1, _kit("bow", "longsword"))
	check(d0.hands() == ["left"], "a two-handed item takes both hands", str(d0.hands()))
	# SWAP: a step, then the other slot's item is held.
	var d := _armed("kite shield", "longsword", Vector2(-80, 0), "staff", "claymore")
	check(d.plan("right:swap", d.hero.pos), "swap")
	_until_free(d)
	check(d.held("right") == "claymore" and d.hands().size() == 2, "swapped: the claymore, in one hand")
	var one := d.cost("right:light")
	var one_dmg := int(d.spec("right:light")["dmg"])
	check(d.two_tool() == "right:two hands", "2H: the right hand's item")
	d.plan(d.two_tool(), d.hero.pos)
	_until_free(d)
	check(d.hands() == ["right"] and d.options("right").has("block"), "in two hands: one button, and it can block")
	check(d.cost("right:light") < one and int(d.spec("right:light")["dmg"]) > one_dmg, "one-handed, the claymore costs more and hits less")
	check(d.two_tool() == "right:one hand", "2H again: let go")
	d.plan(d.two_tool(), d.hero.pos)
	_until_free(d)
	check(d.hands().size() == 2, "back to one hand")
	d.plan("right:swap", d.hero.pos)
	_until_free(d)
	check(d.held("right") == "longsword", "swapped back")
	# A two-handed longsword blocks half a swing, and isn't knocked back.
	d = Duel.new(1, _kit("kite shield", "longsword"))
	d.grip = "right"
	d.toggle_guard()
	d.hero.pos = d.knight.pos + Vector2(-30, 0)
	d.hero.ang = 0.0
	d.knight.ang = PI
	d.start_attack("sweep")
	var hp := d.hero.hp
	for i in d.knight.cur["steps"].size():
		if d.hero.idle():
			d.plan("wait", d.hero.pos)
		d.step()
		check(String(d.hero.cur.get("k", "")) != "hurt", "a weapon block: not knocked back")
	check(hp - d.hero.hp == roundi(int(Acts.KNIGHT["sweep"]["dmg"]) * 0.5), "a weapon block stops half", str(hp - d.hero.hp))
	# The quarterstaff turns into a bow and back.
	d = _armed("kite shield", "quarterstaff", Vector2(150, 0))
	check(d.hands() == ["right"] and d.options("right").has("light"), "the quarterstaff takes both hands")
	d.plan("right:transform", d.hero.pos)
	_until_free(d)
	check(d.item_key("right") == "quarterstaff bow", "transformed: a bow")
	check(d.plan("right:arrow", d.knight.pos), "it shoots")
	_until_free(d)
	for i in 10:
		d.step()
	check(d.knight.hp < d.knight.max_hp, "the arrow hits")
	d.plan("right:transform", d.hero.pos)
	_until_free(d)
	check(d.item_key("right") == "quarterstaff", "and back to a staff")
	d = _armed("kite shield", "quarterstaff", Vector2(16, 0))
	d.plan("right:light", d.knight.pos)
	_until_free(d)
	check(d.knight.hp < d.knight.max_hp, "the quarterstaff's strike hits")
	# The greatspear thrusts from further off, and separates.
	d = _armed("kite shield", "greatspear", Vector2(26, 0))
	d.plan("right:light", d.knight.pos)
	_until_free(d)
	check(d.knight.hp < d.knight.max_hp, "the greatspear's thrust reaches", str(d.knight.hp))
	d.plan("right:transform", d.hero.pos)
	_until_free(d)
	check(d.hands().size() == 2 and d.item_key("left") == "spear staff" and d.item_key("right") == "shortsword", "separated: staff left, shortsword right")
	check(d.options("left").has("transform") and not d.options("left").has("swap"), "both halves can transform; swap's in the spear's hand")
	check(d.plan("left:bolt", d.knight.pos), "the spear staff casts")
	_until_free(d)
	d.knight.pos = d.hero.pos + Vector2(14, 0)
	var was := d.knight.hp
	d.plan("right:light", d.knight.pos)
	_until_free(d)
	check(d.knight.hp < was, "the shortsword stabs")
	d.plan("left:transform", d.hero.pos)
	_until_free(d)
	check(d.hands() == ["right"] and d.item_key("right") == "greatspear", "joined back: the greatspear")
	# The claymore's swing hits; so does the longsword in the left hand.
	for lr in [["kite shield", "claymore", "right:light"], ["longsword", "staff", "left:light"]]:
		var dl := _armed(lr[0], lr[1], Vector2(18, 0))
		dl.plan(lr[2], dl.knight.pos)
		_until_free(dl)
		check(dl.knight.hp < dl.knight.max_hp, "%s with %s / %s hits" % [lr[2], lr[0], lr[1]], str(dl.knight.hp))
	# An arrow flies its speed a step and hits the knight far off.
	d = _armed("bow", "bow", Vector2(150, 0))
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
	check(not d.is_loaded("left"), "then it's empty")
	check(not d.plan("left:bolt", d.knight.pos) and d.wiggle.has("hand:left"), "empty: can't shoot, the hand wiggles")
	check(d.plan("left:reload", d.knight.pos), "reload")
	_until_free(d)
	check(d.is_loaded("left") and d.plan("left:bolt", d.knight.pos), "loaded again, it shoots")
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
	var c := d.casts_left("right:bolt")
	check(d.plan("right:bolt", d.knight.pos) and d.casts_left("right:bolt") == c - 1, "a cast uses one up")
	_until_free(d)
	d.casts["staff:heavy bolt"] = 0
	check(not d.plan("right:heavy bolt", d.knight.pos), "none left: no")
