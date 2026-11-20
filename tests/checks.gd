extends RefCounted
## The fight's rules, checked headless (run by smoke.gd).

var fails := 0


func check(name: String, ok: bool, info := "") -> void:
	if ok:
		print("  ok   ", name)
	else:
		fails += 1
		print("  FAIL ", name, "  ", info)


func run(_tree: SceneTree) -> int:
	_shapes()
	_move()
	_bite()
	_leap()
	_whip()
	_hip()
	_arms()
	_cool()
	_stagger()
	_hunters()
	_soak()
	_run()
	_levels()
	_blades()
	_charge()
	print("DONE fails=%d" % fails)
	return fails


## A fight with only the leader, and a hunter far off doing nothing (so
## the fight isn't won).
func _bare() -> Battle:
	var b := Battle.new(3)
	b.units = [b.leader]
	var far := b.add("bow", Vector2(360, 160), PI)
	far.cur = {"k": "wait", "label": "", "b": 0, "steps": []}
	for i in 50:
		far.cur["steps"].append({"ph": "wait"})
	return b


## A hunter that stands still for a while.
func _dummy(b: Battle, k: String, at: Vector2) -> Unit:
	var h := b.add(k, at, PI)
	h.cur = {"k": "wait", "label": "", "b": 0, "steps": [{"ph": "wait"}, {"ph": "wait"}, {"ph": "wait"}, {"ph": "wait"}]}
	return h


func _beats(b: Battle, n: int) -> void:
	for i in n:
		b.beat()


func _shapes() -> void:
	var f := Shape.fan(Vector2.ZERO, 20.0, 0.0, PI / 4.0)
	check("a fan hits in front", Shape.hits(f, Vector2(15, 0), 1.0))
	check("a fan misses behind", not Shape.hits(f, Vector2(-15, 0), 1.0))
	check("a fan misses past its side", not Shape.hits(f, Vector2(0, 15), 1.0))
	check("a body's edge in a fan counts", Shape.hits(f, Vector2(24, 0), 5.0))
	var bar := Shape.bar(Vector2.ZERO, Vector2(50, 0), 4.0)
	check("a bar hits along it", Shape.hits(bar, Vector2(30, 3), 2.0))
	check("a bar misses beside it", not Shape.hits(bar, Vector2(30, 8), 2.0))
	var sw := Shape.sweep(Vector2.ZERO, 20.0, 0.0, PI / 3.0, 5.0)
	check("a sweep hits along its path", Shape.hits(sw, Vector2.from_angle(PI / 6.0) * 20.0, 1.0))
	check("a sweep misses past its end", not Shape.hits(sw, Vector2.from_angle(-PI / 3.0) * 20.0, 1.0))
	var r := Shape.raster(Shape.disc(Vector2(50, 50), 5.0))
	check("a disc covers its pixels", r["rows"].size() >= 9 and r["edge"].size() > 10)


func _move() -> void:
	var b := _bare()
	var l := b.leader
	var to := l.pos + Vector2(40, 0)
	check("move to a point", b.plan("move", to))
	check("move takes a beat per 16 px", l.cur["steps"].size() == 3)
	_beats(b, 3)
	check("move gets there", l.pos.distance_to(to) < 0.5, str(l.pos))
	b = _bare()
	l = b.leader
	var block := _dummy(b, "sword", l.pos + Vector2(40, 0))
	to = l.pos + Vector2(48, 0)
	b.plan("move", to)
	_beats(b, 3)
	check("walking into a hunter moves it along", l.pos.distance_to(to) < 0.5
		and block.pos.x > to.x + 12.0, str(l.pos, block.pos))
	check("it's moved just clear, not shoved", l.gap(block.pos, 4.0) < 0.5
		and l.gap(block.pos, 4.0) >= -0.01, str(l.gap(block.pos, 4.0)))
	b = _bare()
	l = b.leader
	block = _dummy(b, "sword", Vector2(l.pos.x, 17))
	b.plan("move", Vector2(l.pos.x, 30))
	_beats(b, 6)
	check("a hunter against the edge squeezes out along it, and you keep going",
		l.pos.distance_to(Vector2(80, 30)) < 0.5 and block.pos.y >= 16.0 and absf(block.pos.x - 80.0) > 3.0
		and l.gap(block.pos, 4.0) >= -0.05, str(l.pos, block.pos))
	b = _bare()
	l = b.leader
	block = _dummy(b, "sword", l.pos + Vector2(36, 0))
	var sw: Dictionary = Shape.fan(block.pos, 26.0, PI, 1.4)
	block.cur = {"k": "slash", "label": "", "b": 0, "steps": [{"ph": "wind"}, {"ph": "wind"}, {"ph": "act", "hit": [sw], "dmg": 1}]}
	var p0 := block.pos
	b.plan("move", l.pos + Vector2(16, 0))
	_beats(b, 1)
	var c1: Vector2 = block.cur["steps"][2]["hit"][0]["c"]
	check("being moved doesn't stop its attack", String(block.cur["k"]) == "slash")
	check("its swing moves with it", block.pos.x > p0.x + 0.5
		and c1.distance_to(sw["c"] + block.pos - p0) < 0.01, str(p0, block.pos, c1))
	b = _bare()
	check("can't move off the arena", not b.plan("move", Vector2(-50, 50)))


func _bite() -> void:
	var b := _bare()
	var l := b.leader
	var h := _dummy(b, "sword", l.pos + Vector2.from_angle(0.6) * 24.0)
	var hp0 := h.hp
	check("bite aimed at an angle", b.plan("bite", h.pos))
	check("bite turns to where it's aimed", absf(float(l.cur["steps"][1]["face"]) - 0.6) < 0.01)
	var p0 := h.pos
	_beats(b, 2)
	var from := l.near(p0)
	check("bite hits", h.hp < hp0, str(h.hp))
	check("a hit pushes it back", absf(h.pos.distance_to(p0) - Acts.PUSH) < 0.01
		and (h.pos - p0).normalized().dot((p0 - from).normalized()) > 0.95, str(p0, h.pos))
	b = _bare()
	l = b.leader
	l.pos = Vector2(80, 40)
	l.ang = -PI / 2.0
	h = _dummy(b, "sword", Vector2(80, 16.5))
	b.plan("bite", h.pos)
	_beats(b, 2)
	check("a hunter at the edge isn't pushed out", h.pos.y >= 16.0 and h.pos.y <= 16.5, str(h.pos))
	b = _bare()
	l = b.leader
	var a: Dictionary = b.shape("bite", l.pos + Vector2(-20, 0))
	check("bite aimed behind turns only as far as it can", absf(absf(float(a["steps"][1]["face"])) - Acts.LEADER["bite"]["turn"]) < 0.01)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2.from_angle(0.5) * 24.0)
	hp0 = h.hp
	b.plan("bite", l.pos + Vector2.from_angle(1.0) * 20.0)
	_beats(b, 2)
	check("a side bite sweeps through what's between", h.hp < hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(40, 0))
	hp0 = h.hp
	b.plan("bite", h.pos)
	_beats(b, 2)
	check("bite doesn't reach far", h.hp == hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(-16, 0))
	hp0 = h.hp
	b.plan("bite", h.pos)
	_beats(b, 2)
	check("bite can't reach behind", h.hp == hp0)


func _leap() -> void:
	var b := _bare()
	var l := b.leader
	var from := l.pos
	var h := _dummy(b, "sword", l.pos + Vector2(48, 0))
	var hp0 := h.hp
	var p0 := h.pos
	check("leap ahead", b.plan("leap", l.pos + Vector2(26, 0)))
	check("leap lands where aimed (any distance in its reach)", l.cur.get("steps", [{}, {}])[1].get("to", Vector2.ZERO).distance_to(from + Vector2(26, 0)) < 0.01)
	_beats(b, 2)
	check("leap slams round where it lands", h.hp < hp0)
	check("the slam pushes harder", absf(h.pos.x - p0.x - Acts.LEADER["leap"]["push"]) < 0.01, str(p0, h.pos))
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(26, 15))
	hp0 = h.hp
	b.plan("leap", l.pos + Vector2(26, 0))
	_beats(b, 2)
	check("the slam hits beside where it lands too", h.hp < hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(26, 24))
	hp0 = h.hp
	b.plan("leap", l.pos + Vector2(26, 0))
	_beats(b, 2)
	check("the slam is only just wider than the body", h.hp == hp0)
	b = _bare()
	l = b.leader
	var a: Dictionary = b.shape("leap", l.pos + Vector2(100, 0))
	check("leap is held to its reach", a["steps"][1]["to"].distance_to(l.pos) <= Acts.LEADER["leap"]["reach"] + 0.01)
	b = _bare()
	l = b.leader
	from = l.pos
	check("aimed behind, it's a hop", b.plan("leap", l.pos + Vector2(-26, 0)) and l.cur["label"] == "HOP")
	_beats(b, 1)
	check("the hop goes back and keeps facing", l.pos.x < from.x - 20 and absf(l.ang) < 0.01)
	b = _bare()
	l = b.leader
	var h2 := _dummy(b, "sword", l.pos + Vector2(28, 0))
	check("you can leap onto someone", b.plan("leap", l.pos + Vector2(28, 0)))
	_beats(b, 2)
	check("they're pushed out from under you", l.pos.distance_to(from + Vector2(28, 0)) < 0.5
		and l.gap(h2.pos, 4.0) >= -0.05, str(l.pos, h2.pos))


func _whip() -> void:
	var b := _bare()
	var l := b.leader
	var h := _dummy(b, "sword", l.pos + Vector2(-6, -22))
	var hp0 := h.hp
	var p0 := h.pos
	check("whip aimed at its left", b.plan("whip", l.pos + Vector2(0, -30)))
	check("whip winds up first", String(l.cur["steps"][0]["ph"]) == "wind")
	_beats(b, 2)
	check("the tail sweeps its left side", h.hp < hp0, str(h.hp))
	check("it ends up facing back", absf(angle_difference(l.ang, PI)) < 0.01)
	check("it turns on the spot", l.pos.distance_to(Vector2(80, 92)) < 0.01)
	check("the tail pushes it out from the spin", h.pos.distance_to(p0) > 3.9
		and (h.pos - p0).normalized().dot((p0 - l.pos).normalized()) > 0.95, str(h.pos))
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(-6, 22))
	hp0 = h.hp
	b.plan("whip", l.pos + Vector2(0, -30))
	_beats(b, 2)
	check("it doesn't hit the other side", h.hp == hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(-6, 22))
	hp0 = h.hp
	b.plan("whip", l.pos + Vector2(0, 30))
	_beats(b, 2)
	check("aimed right, it sweeps the right", h.hp < hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(40, 0))
	hp0 = h.hp
	b.plan("whip", l.pos + Vector2(0, -30))
	_beats(b, 2)
	check("the tail doesn't reach past its tip", h.hp == hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(-14, 0))
	check("a hunter where its head will be doesn't stop the whip", b.plan("whip", l.pos + Vector2(0, -30)))
	_beats(b, 2)
	check("it's pushed out of the way", l.gap(h.pos, 4.0) >= -0.05, str(h.pos))


func _hip() -> void:
	var b := _bare()
	var l := b.leader
	var start := l.pos
	var h := _dummy(b, "sword", l.pos + Vector2(4, -20))
	var hp0 := h.hp
	var p0 := h.pos
	check("hip check aimed at its left", b.plan("hip", l.pos + Vector2(0, -30)))
	check("hip check winds up first", String(l.cur["steps"][0]["ph"]) == "wind")
	_beats(b, 2)
	check("it hits out to the side", h.hp < hp0, str(h.hp))
	check("the raptor moves 8 px that way", l.pos.distance_to(start + Vector2(0, -8)) < 0.5, str(l.pos))
	check("it keeps facing the same way", absf(l.ang) < 0.01)
	check("the hunter is pushed out", h.pos.y < p0.y - 15.0, str(p0, h.pos))
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(4, 20))
	hp0 = h.hp
	b.plan("hip", l.pos + Vector2(0, -30))
	_beats(b, 2)
	check("it doesn't hit the other side", h.hp == hp0)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(40, -10))
	hp0 = h.hp
	b.plan("hip", l.pos + Vector2(0, -30))
	_beats(b, 2)
	check("it doesn't hit far ahead", h.hp == hp0)
	b = _bare()
	l = b.leader
	var a: Dictionary = b.shape("hip", l.pos + Vector2(30, -30))
	var way := float(a["steps"][1]["way"])
	check("its aim turns only 20 degrees off straight out", absf(angle_difference(-PI / 2.0, way) - PI / 9.0) < 0.01, str(way))


func _arms() -> void:
	var b := _bare()
	var l := b.leader
	var start := l.pos
	var h := _dummy(b, "sword", l.pos + Vector2(26, 0))
	var hp0 := h.hp
	check("arm combo", b.plan("arms", l.pos + Vector2(0, -30)))
	check("it winds up, then two swipes", l.cur["steps"].size() == 3 and String(l.cur["steps"][0]["ph"]) == "wind")
	check("it goes straight ahead wherever it's aimed", absf(float(l.cur["steps"][2]["to"].y - start.y)) < 0.01)
	_beats(b, 2)
	var hp1 := h.hp
	check("the first swipe hits", hp1 < hp0)
	_beats(b, 1)
	check("the second swipe hits too", h.hp < hp1, str(h.hp))
	check("it steps 32 px in all", l.pos.distance_to(start + Vector2(32, 0)) < 0.5, str(l.pos))
	check("it drives the hunter on ahead", h.pos.x > start.x + 32.0 + 20.0, str(h.pos))
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(80, 0))
	b.plan("arms", l.pos)
	b.tell_started = true
	_beats(b, 2)
	check("once started it isn't stopped", not l.idle())


func _cool() -> void:
	var b := _bare()
	var l := b.leader
	b.plan("leap", l.pos + Vector2(26, 0))
	_beats(b, 2)
	check("after a leap it's cooling down", l.idle() and b.cooling("leap") == 3)
	check("it can't leap while cooling", not b.plan("leap", l.pos + Vector2(26, 0)))
	check("the bite has no cooldown", b.plan("bite", l.pos + Vector2(20, 0)))
	_beats(b, 2)
	b.plan("wait", l.pos)
	_beats(b, 1)
	check("once it's cooled it can leap again", b.cooling("leap") == 0 and b.plan("leap", l.pos + Vector2(26, 0)))


func _stagger() -> void:
	var b := _bare()
	var l := b.leader
	var h := _dummy(b, "sword", l.pos + Vector2(30, 0))
	b.plan("move", l.pos + Vector2(-60, 0))
	b._hit(h, [Shape.disc(l.pos, 4.0)], {"dmg": 50})
	check("under 60% of its health, no stagger", String(l.cur["k"]) == "move")
	var p0 := l.pos
	b._hit(h, [Shape.disc(l.pos, 4.0)], {"dmg": 11})
	check("over 60%, it's staggered", String(l.cur["k"]) == "stagger")
	check("the stagger pushes it away from the hit", absf(l.pos.x - (p0.x - Acts.STAGGER["push"])) < 0.01, str(l.pos))
	check("the count starts again", l.taken == 0)
	_beats(b, 1)
	check("it loses a beat, then it's free", l.idle() and absf(l.pos.x - (p0.x - Acts.STAGGER["push"])) < 0.01)
	b = _bare()
	l = b.leader
	h = _dummy(b, "sword", l.pos + Vector2(-30, 0))
	b.plan("arms", l.pos + Vector2(40, 0))
	_beats(b, 2)
	b._hit(h, [Shape.disc(l.pos, 4.0)], {"dmg": 61})
	check("a stagger stops the arm combo too", String(l.cur["k"]) == "stagger")


func _hunters() -> void:
	var b := Battle.new(5, ["sword"])
	var l := b.leader
	var s: Unit = b.hunters()[0]
	s.pos = l.pos + Vector2(60, 0)
	b.plan("wait", l.pos)
	b.beat()
	check("sword walks at the leader", s.pos.distance_to(l.pos) < 60.0)
	s.pos = l.pos + Vector2(12, 0)
	s.cur = {}
	var hp0 := l.hp
	for i in 4:
		b.plan("wait", l.pos)
		b.beat()
	check("sword hits a leader that stands there", l.hp < hp0)
	b = Battle.new(5, ["sword"])
	l = b.leader
	s = b.hunters()[0]
	s.pos = l.pos + Vector2(12, 0)
	b.plan("wait", l.pos)
	b.beat()
	check("sword starts a slash", s.cur.get("k", "") == "slash")
	hp0 = l.hp
	b.plan("leap", l.pos + Vector2(-30, 0))
	_beats(b, 3)
	check("hopping out of the slash dodges it", l.hp == hp0)
	b = Battle.new(5, ["bow"])
	l = b.leader
	var w: Unit = b.hunters()[0]
	w.pos = l.pos + Vector2(10, 40)
	b.plan("wait", l.pos)
	b.beat()
	check("bow shoots at any angle", w.cur.get("k", "") == "shot")
	hp0 = l.hp
	for i in 3:
		b.plan("wait", l.pos)
		b.beat()
	check("the shot lands", l.hp < hp0)


## Random fights to the end: nothing breaks, and they end.
func _soak() -> void:
	for sd in range(1, 21):
		var b := Battle.new(sd)
		var r := RandomNumberGenerator.new()
		r.seed = sd
		for i in 400:
			if b.result != "":
				break
			if b.leader.idle():
				var k: String = ["move", "bite", "leap", "wait"][r.randi() % 4]
				var h: Array = b.hunters()
				var at: Vector2 = h[0].pos if not h.is_empty() and r.randf() < 0.6 else Vector2(r.randf_range(20, 360), r.randf_range(20, 160))
				if not b.plan(k, at):
					b.plan("wait", at)
			b.beat()
			for u in b.units:
				if u.alive() and not Acts.ARENA.grow(0.01).has_point(u.pos):
					check("seed %d: everyone stays in the arena" % sd, false, str(u.pos))
					return
	check("20 random fights play without breaking", true)


func _run() -> void:
	for seed_ in range(1, 6):
		var r := Run.new(seed_)
		var firsts := r.choices()
		check("a run starts with stops to pick (seed %d)" % seed_, not firsts.is_empty() and r.nodes[firsts[0]]["kind"] == "hunt")
		var ok := true
		for n in r.nodes:
			if n["kind"] != "boss" and n["next"].is_empty():
				ok = false
		check("every stop leads on (seed %d)" % seed_, ok)
		# Walk a route to the end, winning every fight.
		var steps := 0
		while r.result == "" and steps < 20:
			var c: Array = r.choices()
			var id: int = c[r.rng.randi() % c.size()]
			var party := r.go(id)
			if r.is_fight(id):
				var b := Battle.new(seed_, party, r.hp, r.build())
				check("the fight has that party and your health", b.hunters().size() == party.size() and b.leader.hp == r.hp)
				r.won(maxi(r.hp - 20, 1))
				while not r.offer.is_empty():
					r.take(0)
			steps += 1
		check("a route ends at the last fight, won (seed %d)" % seed_, r.result == "win" and r.nodes[r.at]["kind"] == "boss")
	var r := Run.new(9)
	r.hp = 10
	r.go(r.choices()[0])
	r.won(10)
	r.take(0)
	var nest := -1
	for n in r.nodes:
		if n["kind"] == "nest" and n["id"] in r.nodes[r.at]["next"]:
			nest = n["id"]
	if nest >= 0:
		r.go(nest)
		check("a nest gives health back", r.hp > 10)


func _levels() -> void:
	var r := Run.new(4)
	r.go(r.choices()[0])
	r.won(80)
	check("a won fight is a level", r.level == 2)
	var ids := r.offer.map(func(o): return o["id"])
	check("every level offers the three stats", not r.big() and ids == ["strength", "speed", "defense"], str(ids))
	r.take(0)
	check("the stat goes up, then back to the map", r.stats["strength"] == 1 and r.offer.is_empty())
	r.won(80)
	r.take(2)
	ids = r.offer.map(func(o): return o["id"])
	check("every third level, after the stat, the aspects", r.level == 3 and r.stats["defense"] == 1 and r.big()
		and ids == ["blades", "blunt"], str(ids))
	r.take(0)
	check("the aspect goes up a level", int(r.aspects["blades"]) == 1 and r.aspect_levels() == 1 and r.offer.is_empty())
	r.aspects["blades"] = Acts.ASPECT_MAX
	check("an aspect at its top level isn't offered", r.aspect_offer().map(func(o): return o["id"]) == ["blunt"])
	# Stats reach the fight.
	var b := Battle.new(1, ["sword"], -1, {"stats": {"strength": 2, "speed": 2, "defense": 3}})
	var l := b.leader
	b.plan("bite", l.pos + Vector2(20, 0))
	check("strength adds to the bite", int(l.cur["steps"][1]["dmg"]) == int(Acts.LEADER["bite"]["dmg"]) + 2 * Acts.STR_BITE)
	b = Battle.new(1, ["sword"], -1, {"stats": {"strength": 2}})
	b.plan("whip", b.leader.pos + Vector2(0, -20))
	check("and to the other attacks", int(b.leader.cur["steps"][1]["dmg"]) == int(Acts.LEADER["whip"]["dmg"]) + 2 * Acts.STR_OTHER)
	b = Battle.new(1, ["sword"], -1, {"stats": {"speed": 2, "defense": 3}})
	l = b.leader
	var walk: Dictionary = b.shape("move", l.pos + Vector2(100, 0))
	var first: Vector2 = walk["steps"][0]["to"]
	check("speed walks further a beat", absf(first.distance_to(l.pos) - (float(Acts.LEADER["move"]["speed"]) + 2 * Acts.SPEED_PX)) < 0.01)
	var h: Unit = b.hunters()[0]
	b._hit(h, [Shape.disc(l.pos, 4.0)], {"dmg": 16})
	check("defense takes some off every hit", l.hp == l.max_hp - (16 - 3 * Acts.DEF_CUT), "%d" % l.hp)
	b = Battle.new(1, ["sword"], 40)
	check("the fight starts with the health you bring", b.leader.hp == 40)


func _blades() -> void:
	var b := Battle.new(3, ["sword"], -1, {"aspects": {"blades": 1}})
	var l := b.leader
	b.units = [l]
	var a: Dictionary = b.shape("arms", l.pos + Vector2(40, 0))
	var acts: Array = a["steps"].filter(func(st): return st["ph"] == "act")
	check("BLADES 1: the arm combo is three slashes", acts.size() == 3)
	check("each slash bleeds", acts.all(func(st): return st.get("bleed", false)))
	check("the last slash is bigger", int(acts[2]["dmg"]) == Acts.BLADES["last_dmg"] and float(acts[2]["hit"][0]["r"]) == Acts.BLADES["last_r"])
	var plain := Battle.new(3, ["sword"])
	var pa: Dictionary = plain.shape("arms", plain.leader.pos + Vector2(40, 0))
	check("without BLADES it's two, and doesn't bleed", pa["steps"].filter(func(st): return st["ph"] == "act").size() == 2
		and not pa["steps"].any(func(st): return st.get("bleed", false)))
	# The whip's claw: the other side from the tail, bleeding; the tail doesn't.
	var w: Dictionary = b.shape("whip", l.pos + Vector2(0, -20))
	var hit: Dictionary = w["steps"][1]
	check("BLADES 1: the whip has a claw", hit.has("also") and hit["also"][0].get("bleed", false) and not hit.get("bleed", false))
	var claw: Dictionary = hit["also"][0]["hit"][0]
	var tail: Dictionary = hit["hit"][0]
	var other := l.pos + Vector2(0, 14)
	check("the claw sweeps the other side from the tail", Shape.has_point(claw, other) and not Shape.has_point(tail, other)
		and not Shape.has_point(claw, l.pos + Vector2(0, -14)))
	check("the claw doesn't reach as far as the tail", not Shape.has_point(claw, l.pos + Vector2(0, 26)))
	# Bleed: two bleeding hits start it.
	b = Battle.new(3, ["sword"], -1, {"aspects": {"blades": 1}})
	l = b.leader
	var h: Unit = b.hunters()[0]
	var sh := [Shape.disc(h.pos, 2.0)]
	b._hit(l, sh, {"dmg": 1, "bleed": true})
	check("one bleeding hit doesn't bleed yet", h.bleeding == 0 and h.bleed_hits == 1)
	b._hit(l, [Shape.disc(h.pos, 2.0)], {"dmg": 1, "bleed": true})
	check("two do", h.bleeding == Acts.BLEED["beats"] and h.bleed_hits == 0)
	b._hit(l, [Shape.disc(h.pos, 2.0)], {"dmg": 1})
	check("a hit that doesn't bleed adds nothing", h.bleed_hits == 0)
	h.bleeding = 3
	b._hit(l, [Shape.disc(h.pos, 2.0)], {"dmg": 1, "bleed": true})
	check("while bleeding, one hit doesn't start it again", h.bleeding == 3)
	b._hit(l, [Shape.disc(h.pos, 2.0)], {"dmg": 1, "bleed": true})
	check("two more put it back to the top", h.bleeding == Acts.BLEED["beats"])
	# What it costs: moving 1, attacking 2, standing still nothing.
	var hp0 := h.hp
	h.played = {"step": {"ph": "move"}}
	var was := h.pos
	h.pos += Vector2(5, 0)
	b._bleed(h, was)
	check("bleeding: moving costs %d" % Acts.BLEED["move"], h.hp == hp0 - int(Acts.BLEED["move"]))
	hp0 = h.hp
	h.played = {"step": {"ph": "act"}}
	b._bleed(h, h.pos)
	check("attacking costs %d" % Acts.BLEED["attack"], h.hp == hp0 - int(Acts.BLEED["attack"]))
	hp0 = h.hp
	h.played = {"step": {"ph": "wind"}}
	b._bleed(h, h.pos)
	check("standing still costs nothing", h.hp == hp0)
	h.bleeding = 1
	h.played = {"step": {"ph": "act"}}
	b._bleed(h, h.pos)
	check("it runs out", h.bleeding == 0)
	hp0 = h.hp
	b._bleed(h, h.pos)
	check("and then costs nothing", h.hp == hp0)
	# In a real beat: the combo's slashes start it.
	b = Battle.new(3, ["sword"], -1, {"aspects": {"blades": 1}})
	l = b.leader
	b.units = [l]
	h = _dummy(b, "sword", l.pos + Vector2(44, 0))
	for i in 10:
		h.cur["steps"].append({"ph": "wait"})
	b.plan("arms", l.pos + Vector2(40, 0))
	_beats(b, 3)
	check("the combo's slashes make it bleed", h.bleeding > 0, "hits %d bleeding %d" % [h.bleed_hits, h.bleeding])


func _charge() -> void:
	var b := Battle.new(3, ["sword"], -1, {"aspects": {"blunt": 1}})
	check("one aspect level: no charge yet", not b.knows("charge") and not b.plan("charge", b.leader.pos + Vector2(40, 0)))
	b = Battle.new(3, ["sword"], -1, {"aspects": {"blades": 1, "blunt": 1}})
	check("two aspect levels, any aspects: the charge", b.knows("charge"))
	var l := b.leader
	b.units = [l]
	var h := _dummy(b, "sword", l.pos + Vector2(50, 2))
	var h2 := _dummy(b, "sword", l.pos + Vector2(70, -3))
	for x in [h, h2]:
		for i in 10:
			x.cur["steps"].append({"ph": "wait"})
	var p0 := l.pos
	check("it can be aimed", b.plan("charge", l.pos + Vector2(40, 0)))
	_beats(b, 1)
	check("after the first wind-up it stops to aim again", b.reaiming())
	b.reaim(l.pos + Vector2(40, -40))
	var way := float(l.cur["steps"][2]["face"])
	check("aimed again: no more than %d degrees" % roundi(rad_to_deg(Acts.LEADER["charge"]["turn"])), absf(way + float(Acts.LEADER["charge"]["turn"])) < 0.01, str(way))
	check("then it carries on", not b.reaiming())
	b.reaim(l.pos + Vector2(40, 0))
	l.cur["steps"] = l.cur["steps"].slice(0, 1) + b._charge(l.pos, 0.0)
	var hp1 := h.hp
	var hp2 := h2.hp
	_beats(b, 2)
	check("it runs the full length", absf(l.pos.x - (p0.x + float(Acts.LEADER["charge"]["long"]))) < 0.5, str(l.pos))
	check("both hunters on its path are hit, once each", hp1 - h.hp == int(Acts.LEADER["charge"]["dmg"]) and hp2 - h2.hp == int(Acts.LEADER["charge"]["dmg"]))
	check("they're pushed out to the side", absf(h.pos.y - p0.y) > 10.0 and absf(h2.pos.y - p0.y) > 10.0, "%s %s" % [h.pos, h2.pos])
	check("each to its own side", h.pos.y > p0.y and h2.pos.y < p0.y)
	check("not bled without BLADES 2", h.bleed_hits == 0)
	b = Battle.new(3, ["sword"], -1, {"aspects": {"blades": 2}})
	var c: Dictionary = b.shape("charge", b.leader.pos + Vector2(40, 0))
	var run: Dictionary = c["steps"][2]
	check("BLADES 2: the charge is wider and bleeds", run.get("bleed", false)
		and float(run["hit"][0]["w"]) == float(Acts.LEADER["charge"]["w"]) + float(Acts.BLADES["charge_w"]))
	check("it cools down after", b.plan("charge", b.leader.pos + Vector2(40, 0)) and b.cooling("charge") > 0)
