class_name Duel
extends RefCounted
## The hero against the big knight, with no drawing or input so tests can
## run it. Time goes in steps, everyone together. Everyone is a puppet
## (RigArt): an attack plays a clip, one frame a step, and the blade hits
## wherever the puppet's blade really is, swept from where it was at the
## step before (checked SWEEP_CHECKS times between, both bodies moving as
## they go). A swing hits each body at most once. Numbers: Acts.HERO,
## Acts.KNIGHT.
##
## An action: {k, label, steps, b, hit (it has landed)}. A step:
## {ph: wind / act / rec / move / roll / drink / wait / hurt / block, clip, frame,
## live (the blade hits), safe (hits miss you), to (walk there), fwd (px
## forward), track (turn toward the hero), dmg, heal, guard (hits from the
## front do nothing)}.

var hero: Unit
var knight: Unit
var units: Array = []
var step_n := 0
var result := ""  # "", "win", "lose"
var stamina := 0
var flasks := 0
var last_attack := ""  # the knight's last attack
var rng := RandomNumberGenerator.new()

# Effects (the view draws them; they don't change play).
var numbers: Array = []  # {p, s, life, col}
var sparks: Array = []  # {p, v, life, max, col}
var shake_amt := 0.0
var wiggle := {}  # HUD thing -> seconds left (a stamina bar that's too low)


func _init(seed_ := 0) -> void:
	rng.seed = seed_ if seed_ != 0 else int(Time.get_ticks_usec())
	hero = _add("hero", Vector2(110, 92), 0.0)
	knight = _add("knight", Vector2(270, 92), PI)
	knight.side = "enemy"
	hero.side = "hero"
	stamina = int(Acts.HERO["stamina"])
	flasks = int(Acts.HERO["flasks"])


func _add(k: String, at: Vector2, a: float) -> Unit:
	var u := Unit.new(k, at, a)
	u.col = Pal.INK
	u.pose = rest(u)
	units.append(u)
	return u


func art(u: Unit) -> String:
	return String(u.data()["art"])


## The puppet's own pose (between actions).
func rest(u: Unit) -> Dictionary:
	return RigArt.pose(art(u), "", 0.0)


# ---------------------------------------------------------------- actions

## The steps of an attack (Acts.HERO / Acts.KNIGHT entry a).
static func attack_steps(a: Dictionary) -> Array:
	var steps := []
	var wind := int(a["wind"])
	var swing := int(a["swing"])
	var n := wind + swing + int(a["rec"])
	for i in range(1, n + 1):
		var st := {"clip": a["clip"], "frame": i, "ph": "wind" if i <= wind else ("act" if i <= wind + swing else "rec")}
		if st["ph"] == "wind":
			st["track"] = true
		if st["ph"] == "act":
			st["fwd"] = float(a.get("lunge", 0.0))
			if (i - wind) in a["live"]:
				st["live"] = true
				st["dmg"] = int(a["dmg"])
		steps.append(st)
	return steps


func _act(k: String, steps: Array) -> Dictionary:
	return {"k": k, "label": k.to_upper(), "steps": steps, "b": 0, "hit": false}


## What the hero would do with tool k aimed at `at` ({} = can't).
func shape(k: String, at: Vector2) -> Dictionary:
	var u := hero
	var aim := (at - u.pos).angle() if at.distance_to(u.pos) > 0.5 else u.ang
	match k:
		"move":
			if at.distance_to(u.pos) < 1.0 or not Acts.ARENA.has_point(at):
				return {}
			var speed := float(Acts.HERO["walk"])
			var steps := []
			for i in range(1, ceili(u.pos.distance_to(at) / speed) + 1):
				steps.append({"ph": "move", "to": u.pos.move_toward(at, speed * i), "face": aim})
			return _act(k, steps)
		"roll":
			var r: Dictionary = Acts.HERO["roll"]
			var steps := []
			for i in range(1, int(r["steps"]) + 1):
				steps.append({"ph": "roll", "clip": r["clip"], "frame": i, "face": aim,
					"to": u.pos + Vector2.from_angle(aim) * float(r["px"]) * i, "safe": i <= int(r["safe"])})
			return _act(k, steps)
		"light", "heavy":
			var steps := attack_steps(Acts.HERO[k])
			for st in steps:
				st.erase("track")
			steps[0]["face"] = aim
			return _act(k, steps)
		"flask":
			if flasks <= 0:
				return {}
			var steps := []
			for i in int(Acts.HERO["drink"]):
				steps.append({"ph": "drink"})
			steps[steps.size() - 1]["heal"] = int(Acts.HERO["heal"])
			return _act(k, steps)
		"wait":
			return _act(k, [{"ph": "wait"}])
		"block":
			return _act(k, [{"ph": "block", "clip": Acts.HERO["block"]["clip"], "frame": 1, "face": aim, "guard": true}])
	return {}


## The stamina tool k costs.
static func cost(k: String) -> int:
	return int(Acts.HERO[k].get("st", 0)) if Acts.HERO.get(k) is Dictionary else 0


## The hero starts doing k at `at`. False if it can't (busy, out of
## stamina: the bar wiggles).
func plan(k: String, at: Vector2) -> bool:
	if not hero.idle() or result != "":
		return false
	if cost(k) > stamina:
		wiggle["stamina"] = 0.4
		return false
	var a := shape(k, at)
	if a.is_empty():
		if k == "flask":
			wiggle["flasks"] = 0.4
		return false
	stamina -= cost(k)
	if k == "flask":
		flasks -= 1
	hero.cur = a
	return true


# ---------------------------------------------------------------- the knight

func _choose() -> void:
	var u := knight
	var d := u.pos.distance_to(hero.pos)
	var aim := (hero.pos - u.pos).angle()
	if d <= float(Acts.KNIGHT["reach"]):
		var off := rad_to_deg(absf(angle_difference(u.ang, aim)))
		var k := "sweep"
		if last_attack == "sweep" and rng.randf() < float(Acts.KNIGHT["backhand_odds"]):
			k = "backhand"
		elif off < float(Acts.KNIGHT["overhead_cone"]) and d > float(Acts.KNIGHT["overhead_near"]):
			k = "overhead"
		start_attack(k)
		return
	last_attack = ""
	var go := minf(float(Acts.KNIGHT["walk"]), maxf(d - float(Acts.KNIGHT["reach"]) + 1.0, 0.0))
	u.cur = _act("walk", [{"ph": "move", "to": u.pos.move_toward(hero.pos, go), "face": aim}])


func start_attack(k: String) -> void:
	knight.cur = _act(k, attack_steps(Acts.KNIGHT[k]))
	last_attack = k


# ---------------------------------------------------------------- steps

## Plays one step: everyone moves and poses together, then the blades hit.
func step() -> void:
	if result != "":
		return
	step_n += 1
	for u in units:
		u.was = {"pos": u.pos, "ang": u.ang, "pose": u.pose}
	if knight.idle():
		_choose()
	var walking := String(hero.cur.get("k", "")) == "move"
	var resting := not String(current(hero).get("ph", "")) in ["wind", "act", "rec", "roll", "drink"]
	var knight_starts := int(knight.cur.get("b", 1)) == 0 and _has_live(knight.cur)
	for u in units:
		_do(u)
	_keep_apart()
	# The blades.
	for u in units:
		var st := current(u)
		if st.get("live", false) and not u.cur.get("hit", false):
			var v: Unit = knight if u == hero else hero
			if current(v).get("safe", false):
				continue
			var at: Variant = sweep_contact(u, v)
			if at == null:
				continue
			u.cur["hit"] = true
			if blocks(v, at):
				_blocked(at)
			else:
				_hurt(v, u, int(st["dmg"]))
	for u in units:
		if u.idle():
			continue
		var st := current(u)
		if st.has("heal"):
			hero.hp = mini(hero.hp + int(st["heal"]), hero.max_hp)
			_number(hero.pos + Vector2(0, -10), "+%d" % int(st["heal"]), Pal.INK)
		u.cur["b"] = int(u.cur["b"]) + 1
		if int(u.cur["b"]) >= u.cur["steps"].size():
			u.cur = {}
	if resting:
		stamina = mini(stamina + int(Acts.HERO["stamina_back"]), int(Acts.HERO["stamina"]))
	# A walk stops when the knight starts an attack: you choose again.
	if walking and knight_starts and String(hero.cur.get("k", "")) == "move":
		hero.cur = {}
	if hero.hp <= 0:
		result = "lose"
	elif knight.hp <= 0:
		result = "win"


## The step u is doing (this step, before it's counted).
func current(u: Unit) -> Dictionary:
	if u.idle():
		return {}
	return u.cur["steps"][mini(int(u.cur["b"]), u.cur["steps"].size() - 1)]


static func _has_live(a: Dictionary) -> bool:
	for st in a.get("steps", []):
		if st.get("live", false):
			return true
	return false


func _do(u: Unit) -> void:
	if u.idle():
		u.pose = rest(u)
		return
	var st := current(u)
	if st.has("face"):
		u.ang = float(st["face"])
	if st.get("track", false) and u == knight:
		var aim := (hero.pos - u.pos).angle()
		var most := deg_to_rad(float(Acts.KNIGHT["turn"]))
		u.ang += clampf(angle_difference(u.ang, aim), -most, most)
	if st.has("to"):
		_walk(u, st["to"])
	if float(st.get("fwd", 0.0)) > 0.0:
		_walk(u, u.pos + Vector2.from_angle(u.ang) * float(st["fwd"]))
	u.pose = RigArt.pose(art(u), String(st["clip"]), float(st["frame"])) if st.has("clip") else rest(u)


## Moves u toward `to`, a pixel at a time, stopping at the arena's edge. The
## hero stops at the knight; the knight pushes the hero aside (_keep_apart).
func _walk(u: Unit, to: Vector2) -> void:
	var from := u.pos
	var n := ceili(from.distance_to(to))
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n)
		if not _in_arena(u, p):
			return
		if u == hero and knight.alive() and _overlap(p, knight.pos):
			return
		u.pos = p


func _in_arena(u: Unit, p: Vector2) -> bool:
	var r := float(u.data()["body"][0][1])
	return Acts.ARENA.grow(-r).has_point(p)


func _overlap(hp_: Vector2, kp: Vector2) -> bool:
	return hp_.distance_to(kp) < _radius(hero) + _radius(knight)


static func _radius(u: Unit) -> float:
	return float(u.data()["body"][0][1])


## The knight is the big one: a hero he walks or lunges into is pushed out
## of the way (and slides along the arena's edge).
func _keep_apart() -> void:
	var v := hero.pos - knight.pos
	var over := _radius(hero) + _radius(knight) - v.length()
	if over <= 0.0:
		return
	var way := v.normalized() if v.length() > 0.01 else Vector2.from_angle(knight.ang)
	var box := Acts.ARENA.grow(-_radius(hero))
	var p := hero.pos + way * over
	var q := p.clamp(box.position, box.end)
	if q != p:
		# Pinned at the edge: squeeze along it.
		var side := Vector2(0, signf(v.y) if absf(v.y) > 0.01 else 1.0) if q.x != p.x else Vector2(signf(v.x) if absf(v.x) > 0.01 else 1.0, 0)
		q = (q + side * over).clamp(box.position, box.end)
	hero.pos = q


func _hurt(v: Unit, by: Unit, d: int) -> void:
	v.hp -= d
	v.flash = 1.0
	_number(v.pos + Vector2(0, -12), str(d), Pal.DANGER if v == hero else Pal.INK)
	_sparks(v.pos, 6, Pal.DANGER if v == hero else Pal.INK)
	shake_amt = maxf(shake_amt, 2.0 if v == hero else 1.0)
	if v == hero and v.alive():
		# Knocked back, and what it was doing stops.
		var way := (v.pos - by.pos).normalized()
		var steps := []
		for i in int(Acts.HERO["hurt"]):
			steps.append({"ph": "hurt"})
		v.cur = _act("hurt", steps)
		v.cur["b"] = -1  # (counted up at the end of this step)
		_walk(v, v.pos + way * float(Acts.HERO["hurt_push"]))


# ---------------------------------------------------------------- blades

## Whether v, guarding, stops a hit landing at `at` (within the block's
## arc of where v faces).
func blocks(v: Unit, at: Vector2) -> bool:
	if not current(v).get("guard", false):
		return false
	var off := absf(angle_difference(v.ang, (at - v.pos).angle()))
	return rad_to_deg(off) <= float(Acts.HERO["block"]["arc"]) / 2.0


func _blocked(at: Vector2) -> void:
	_sparks(at, 5, Pal.INK)
	shake_amt = maxf(shake_amt, 1.0)


## u's blade polygons, posed `pose`, standing at p facing a.
func blade(u: Unit, pose: Dictionary, p: Vector2, a: float) -> Array:
	var s := float(u.data()["scale"])
	var polys := []
	for e in RigArt.geometry(art(u), Transform2D(a, Vector2(s, s), 0.0, p), {"pose": pose, "only": ["blade"]}):
		polys.append_array(e["polys"])
	return polys


## The ground u's blade sweeps over going from pose a (at pa, facing aa) to
## pose b (at pb, facing ab): one hull for each check between.
func swept(u: Unit, a: Dictionary, pa: Vector2, aa: float, b: Dictionary, pb: Vector2, ab: float) -> Array:
	var out := []
	var prev := blade(u, a, pa, aa)
	for k in range(1, Acts.SWEEP_CHECKS + 1):
		var t := float(k) / Acts.SWEEP_CHECKS
		var now := blade(u, RigArt.blend(a, b, t), pa.lerp(pb, t), lerp_angle(aa, ab, t))
		for i in mini(prev.size(), now.size()):
			out.append(Geometry2D.convex_hull(prev[i] + now[i]))
		prev = now
	return out


## Did u's blade, this step, sweep over any of v's body? Both move as they
## go: each check uses where v was by then.
func sweep_hits(u: Unit, v: Unit) -> bool:
	return sweep_contact(u, v) != null


## Where u's blade first touched v this step (null = it didn't).
func sweep_contact(u: Unit, v: Unit) -> Variant:
	var a: Dictionary = u.was["pose"]
	var prev := blade(u, a, u.was["pos"], u.was["ang"])
	for k in range(1, Acts.SWEEP_CHECKS + 1):
		var t := float(k) / Acts.SWEEP_CHECKS
		var now := blade(u, RigArt.blend(a, u.pose, t), Vector2(u.was["pos"]).lerp(u.pos, t), lerp_angle(u.was["ang"], u.ang, t))
		var vp: Vector2 = Vector2(v.was["pos"]).lerp(v.pos, t)
		var hulls := []
		for i in mini(prev.size(), now.size()):
			hulls.append(Geometry2D.convex_hull(prev[i] + now[i]))
		for c in v.body(vp, lerp_angle(v.was["ang"], v.ang, t)):
			var g := RigArt.gap(c[0], hulls)
			if float(g[0]) <= float(c[1]):
				if float(g[0]) > 0.0:
					return g[1]
				# Right over the middle of the body: where the blade is.
				var sum := Vector2.ZERO
				var n := 0
				for h in hulls:
					for q in h:
						sum += q
						n += 1
				return sum / maxi(n, 1)
		prev = now
	return null


## u's coming steps from now, as they'd go if nobody moved: [{n (steps
## from now), ph, pose, pos, ang, live, swept (hulls, live steps only)}].
## For the knight's ghosts, and the hero's aim preview (a = an action not
## started yet).
func trace(u: Unit, a := {}) -> Array:
	var act: Dictionary = u.cur if a.is_empty() else a
	var out := []
	if act.is_empty():
		return out
	var pose := u.pose
	var p := u.pos
	var ang := u.ang
	var steps: Array = act["steps"]
	for i in range(maxi(int(act["b"]), 0), steps.size()):
		var st: Dictionary = steps[i]
		var a0 := ang
		var p0 := p
		if st.has("face"):
			ang = float(st["face"])
		if st.has("to"):
			p = st["to"]
		p += Vector2.from_angle(ang) * float(st.get("fwd", 0.0))
		var np: Dictionary = RigArt.pose(art(u), String(st["clip"]), float(st["frame"])) if st.has("clip") else rest(u)
		var e := {"n": i - int(act["b"]) + 1, "ph": st["ph"], "pose": np, "pos": p, "ang": ang, "live": st.get("live", false), "swept": []}
		if e["live"]:
			e["swept"] = swept(u, pose, p0, a0, np, p, ang)
		out.append(e)
		pose = np
	return out


# ---------------------------------------------------------------- effects

func _number(p: Vector2, s: String, c: Color) -> void:
	numbers.append({"p": p, "s": s, "life": 0.8, "col": c})


func _sparks(at: Vector2, n: int, c: Color) -> void:
	for i in n:
		var v := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 60.0)
		sparks.append({"p": at, "v": v, "life": 0.4, "max": 0.4, "col": c})


func fx(dt: float) -> void:
	shake_amt = maxf(shake_amt - dt * 12.0, 0.0)
	for k in wiggle.keys():
		wiggle[k] = float(wiggle[k]) - dt
		if wiggle[k] <= 0.0:
			wiggle.erase(k)
	for u in units:
		u.flash = maxf(u.flash - dt * 4.0, 0.0)
	for list in [numbers, sparks]:
		for e in list:
			e["life"] = float(e["life"]) - dt
			if e.has("v"):
				e["p"] += e["v"] * dt
			else:
				e["p"] += Vector2(0, -12) * dt
	numbers = numbers.filter(func(e): return e["life"] > 0.0)
	sparks = sparks.filter(func(e): return e["life"] > 0.0)
