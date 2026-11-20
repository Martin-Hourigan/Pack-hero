class_name Battle
extends RefCounted
## One fight, with no drawing or input so tests can run it. You are the
## pack's leader; the hunters are the enemy. No grid: everyone stands at a
## point and takes up a circle; attacks land on shapes on the ground. One
## beat at a time: the leader's step first, then the hunters'. A hit lands
## on whoever is in its shape the beat it lands, so stepping out of a
## hunter's attack before then dodges it.

var units: Array = []
var leader: Unit
var beat_n := 0
var result := ""  # "", "win", "lose"
var tell_started := false  # a hunter started an attack this beat
var build := {}  # what the leader has grown: {stats: {stat: n}, aspects: {aspect: level}, max_hp}
var cool := {}  # the leader's action -> beats before it can be used again
var rng := RandomNumberGenerator.new()

# Effects (the view draws them; they don't change play).
var fx_wait := 0.0
var numbers: Array = []  # {p, s, life, col, wait}
var sparks: Array = []  # {p, v, life, max, col, wait}
var hurt_shapes: Array = []  # shapes hit this beat
var shake_amt := 0.0


## Where a party's hunters start, in order.
const STARTS := [Vector2(280, 72), Vector2(310, 118), Vector2(296, 44), Vector2(330, 146)]


## party = the hunters to fight; hp = the leader's health coming in (-1 =
## full); build = what it has grown (Run.build()).
func _init(seed_ := 0, party: Array = ["sword", "bow"], hp := -1, build_ := {}) -> void:
	rng.seed = seed_ if seed_ != 0 else int(Time.get_ticks_usec())
	build = build_
	leader = add("leader", Vector2(80, 92), 0.0)
	leader.max_hp = int(build.get("max_hp", leader.max_hp))
	leader.hp = mini(hp, leader.max_hp) if hp > 0 else leader.max_hp
	for i in party.size():
		add(String(party[i]), STARTS[i % STARTS.size()], PI)


func stat(k: String) -> int:
	return int(build.get("stats", {}).get(k, 0))


## The level of aspect k the leader has (0 = none).
func aspect(k: String) -> int:
	return int(build.get("aspects", {}).get(k, 0))


## Can the leader use k at all? (The charge comes with the second aspect
## level.)
func knows(k: String) -> bool:
	if k == "charge":
		var n := 0
		for a in build.get("aspects", {}):
			n += int(build["aspects"][a])
		return n >= int(Acts.LEADER["charge"]["unlock"])
	return true


## A step's hits: the step itself if it has one, then any `also` (a second
## part of the same attack, with its own damage).
static func hits_of(st: Dictionary) -> Array:
	var out := []
	if st.has("hit"):
		out.append(st)
	out.append_array(st.get("also", []))
	return out


func add(k: String, at: Vector2, a: float) -> Unit:
	var u := Unit.new(k, at, a)
	u.col = Pal.INK if u.side == "pack" else Pal.HUNTERS[units.filter(func(x): return x.side == "hunters").size() % Pal.HUNTERS.size()]
	units.append(u)
	return u


func hunters() -> Array:
	return units.filter(func(u): return u.side == "hunters" and u.alive())


## Can u stand at p facing a (in the arena, not overlapping anyone else)?
func free_at(p: Vector2, u: Unit, a := NAN) -> bool:
	if not in_arena(p, u, a):
		return false
	for c in u.body(p, u.ang if is_nan(a) else a):
		for o in units:
			if o != u and o.alive() and o.gap(c[0], c[1]) < 0.0:
				return false
	return true


## Is all of u's body in the arena, standing at p facing a?
func in_arena(p: Vector2, u: Unit, a := NAN) -> bool:
	for c in u.body(p, u.ang if is_nan(a) else a):
		if not Acts.ARENA.grow(-c[1]).has_point(c[0]):
			return false
	return true


## Bodies push each other like solid things. The leader is the big one:
## nothing moves it, and any hunter it overlaps is pushed out of the way.
## Hunters overlapping each other both give way. Everyone is kept in the
## arena, so a hunter pushed against the edge slides along it.
func _settle() -> void:
	for it in 8:
		var moved := false
		for h in hunters():
			var r := float(h.data()["body"][0][1])
			var p: Vector2 = h.pos
			for c in leader.body():
				p += _out_of(p, r, c[0], c[1])
			for o in hunters():
				if o != h:
					p += _out_of(p, r, o.pos, float(o.data()["body"][0][1])) / 2.0
			var box := Acts.ARENA.grow(-r)
			var q := p.clamp(box.position, box.end)
			# Pinned against the edge by the leader: it squeezes out along it.
			if q != p:
				for c in leader.body():
					var over := _out_of(q, r, c[0], c[1]).length()
					if over > 0.0:
						var off: Vector2 = q - c[0]
						if q.x != p.x:
							q.y += over * (signf(off.y) if absf(off.y) > 0.01 else 1.0)
						else:
							q.x += over * (signf(off.x) if absf(off.x) > 0.01 else 1.0)
				q = q.clamp(box.position, box.end)
			p = q
			if p.distance_to(h.pos) > 0.001:
				_shift(h, p - h.pos)
				moved = true
		if not moved:
			return


## How far a circle (p, r) has to move to get out of the circle (c, cr).
func _out_of(p: Vector2, r: float, c: Vector2, cr: float) -> Vector2:
	var v := p - c
	var over := cr + r - v.length()
	if over <= 0.0:
		return Vector2.ZERO
	var way := v.normalized() if v.length() > 0.01 else (c - leader.pos).normalized()
	if way == Vector2.ZERO:
		way = Vector2.UP
	return way * over


## Keeps the leader's whole body in the arena (after it turns at the edge).
func _keep_in(u: Unit) -> void:
	for c in u.body():
		var box := Acts.ARENA.grow(-c[1])
		var q: Vector2 = c[0]
		u.pos += q.clamp(box.position, box.end) - q


# ---------------------------------------------------------------- beats

## Plays one beat: everyone does their next step, the leader first.
func beat() -> void:
	if result != "":
		return
	beat_n += 1
	for k in cool:
		cool[k] = maxi(int(cool[k]) - 1, 0)
	tell_started = false
	hurt_shapes = []
	var order: Array = [leader]
	order.append_array(hunters())
	# Where each stood when the beat began, so a push slides on screen.
	var was := {}
	for u in order:
		was[u] = u.pos
	for u in order:
		if not u.alive():
			continue
		if u.idle() and u != leader:
			_choose(u)
		_do_step(u, was[u])
		if u != leader and u.alive():
			_bleed(u, was[u])
	# Anyone pushed after their own step slides there too.
	for u in order:
		var trail: Array = u.played.get("trail", [])
		if not trail.is_empty() and trail[trail.size() - 1] != u.pos:
			trail.append(u.pos)
	# A walk stops when a hunter starts an attack: you choose again.
	if tell_started and String(leader.cur.get("k", "")) == "move":
		leader.cur = {}
	if not leader.alive():
		result = "lose"
	elif hunters().is_empty():
		result = "win"


func _do_step(u: Unit, was := u.pos) -> void:
	u.played = {"from_ang": u.ang, "trail": [was], "step": {}, "k": ""}
	if u.idle():
		if was != u.pos:
			u.played["trail"].append(u.pos)
		return
	var st: Dictionary = u.next_step()
	u.played["step"] = st
	u.played["k"] = u.cur["k"]
	if int(u.cur["b"]) == 0 and u.side == "hunters" and _has_hit(u.cur):
		tell_started = true
	if st.has("face"):
		u.ang = float(st["face"])
	if st.get("hit_first", false):
		# (A charge: those in its path are knocked aside before it runs.)
		for h in hits_of(st):
			_hit(u, h["hit"], h)
	if st.has("to"):
		var to: Vector2 = st["to"]
		if st.get("air", false):
			# A jump goes over what's between; anyone where it lands is pushed aside.
			if in_arena(to, u):
				u.pos = to
		else:
			if not st.has("face") and to.distance_to(u.pos) > 0.5:
				u.ang = (to - u.pos).angle()
			u.pos = _walk(u, to)
		u.played["trail"].append(u.pos)
	elif was != u.pos:
		u.played["trail"].append(u.pos)
	if u == leader:
		_keep_in(u)
		_settle()
	if not st.get("hit_first", false):
		for h in hits_of(st):
			_hit(u, h["hit"], h)
	u.cur["b"] = int(u.cur["b"]) + 1
	if int(u.cur["b"]) >= u.cur["steps"].size():
		u.cur = {}


## Walks u straight at `to`, stopping at the arena's edge. A hunter stops
## where it would bump into someone; the leader pushes hunters out of its
## way as it goes.
func _walk(u: Unit, to: Vector2) -> Vector2:
	var from := u.pos
	var n := ceili(from.distance_to(to))
	var at := from
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n)
		if u == leader:
			if not in_arena(p, u):
				break
			u.pos = p
			_settle()
		elif not free_at(p, u):
			break
		at = p
	return at


## Moves u by d, and what's left of its action with it (its swing comes from
## where it now stands).
func _shift(u: Unit, d: Vector2) -> void:
	u.pos += d
	if u.idle():
		return
	var steps: Array = u.cur["steps"]
	for i in range(int(u.cur["b"]), steps.size()):
		var st: Dictionary = steps[i].duplicate()
		if st.has("to"):
			st["to"] = st["to"] + d
		if st.has("hit"):
			st["hit"] = st["hit"].map(func(s): return Shape.moved(s, d))
		if st.has("also"):
			st["also"] = st["also"].map(func(h):
				var e: Dictionary = h.duplicate()
				e["hit"] = e["hit"].map(func(s): return Shape.moved(s, d))
				return e)
		steps[i] = st


static func _has_hit(a: Dictionary) -> bool:
	for st in a.get("steps", []):
		if not hits_of(st).is_empty():
			return true
	return false


## A step's hit: dmg to everyone of the other side in any of its shapes.
func _hit(by: Unit, shapes: Array, st: Dictionary) -> void:
	hurt_shapes.append_array(shapes)
	for v in units:
		if not v.alive() or v.side == by.side:
			continue
		for s in shapes:
			if v.in_shape(s):
				var d := int(st.get("dmg", 0))
				if v == leader and d > 0:
					d = maxi(d - Acts.DEF_CUT * stat("defense"), 1)
				_hurt(v, d)
				if st.get("bleed", false) and v.alive() and v.side == "hunters":
					v.bleed_hits += 1
					if v.bleed_hits >= int(Acts.BLEED["hits"]):
						v.bleed_hits = 0
						v.bleeding = int(Acts.BLEED["beats"])
				if by == leader and v.alive():
					var from: Vector2 = st.get("from", by.near(v.pos))
					if st.has("line"):
						# Out to the side of the path.
						var a: Vector2 = st["line"][0]
						var b: Vector2 = st["line"][1]
						var q := Geometry2D.get_closest_point_to_segment(v.pos, a, b)
						var side: Vector2 = v.pos - q
						if side.length() < 0.5:
							side = (b - a).orthogonal()
						from = v.pos - side.normalized()
					elif st.has("way"):
						# Straight out the way it went.
						from = v.pos - Vector2.from_angle(float(st["way"]))
					_knock(v, by, float(st.get("push", Acts.PUSH)), from)
				if v == leader and v.alive():
					v.taken += d
					if v.taken > Acts.STAGGER["at"] * v.max_hp:
						_stagger(v, by)
				_sparks(v.pos, 6, Pal.DANGER if v.side == "pack" else Pal.INK)
				shake_amt = maxf(shake_amt, 2.0 if v == leader else 1.0)
				break


## Pushes v `dist` px straight away from `from` (where the hit came from).
## Whoever it's pushed into gives way (see _settle).
func _knock(v: Unit, by: Unit, dist: float, from: Vector2) -> void:
	var way := v.pos - from
	way = way.normalized() if way.length() > 0.01 else Vector2.from_angle(by.ang)
	if v == leader:
		for i in ceili(dist):
			var p := v.pos + way * minf(1.0, dist - i)
			if not in_arena(p, v):
				break
			v.pos = p
			_settle()
	else:
		_shift(v, way * dist)
		_settle()


## v is staggered: pushed away from `by`, it stops what it was doing and
## loses its next beat. Its count starts again.
func _stagger(v: Unit, by: Unit) -> void:
	v.taken = 0
	v.cur = {"k": "stagger", "label": "", "steps": [{"ph": "stagger"}], "b": 0}
	_knock(v, by, float(Acts.STAGGER["push"]), by.pos)
	shake_amt = maxf(shake_amt, 3.0)


## A bleeding hunter loses health for what it did this beat: moving, or
## attacking.
func _bleed(u: Unit, was: Vector2) -> void:
	if u.bleeding <= 0:
		return
	u.bleeding -= 1
	var st: Dictionary = u.played.get("step", {})
	var d := 0
	if String(st.get("ph", "")) == "act":
		d = int(Acts.BLEED["attack"])
	elif String(st.get("ph", "")) == "move" and u.pos.distance_to(was) > 0.5:
		d = int(Acts.BLEED["move"])
	if d > 0:
		_hurt(u, d)


func _hurt(v: Unit, d: int) -> void:
	if d <= 0:
		return
	v.hp -= d
	v.flash = 1.0
	_number(v.pos + Vector2(0, -10), str(d), Pal.DANGER if v == leader else Pal.INK)
	if not v.alive():
		v.cur = {}
		_sparks(v.pos, 12, v.col)


# ---------------------------------------------------------------- the leader

## The action the leader would do with tool k aimed at the point `at` ({} =
## can't). Aim is free: bite and leap take the nearest way they can go.
func shape(k: String, at: Vector2) -> Dictionary:
	var u := leader
	match k:
		"move":
			if at.distance_to(u.pos) < 1.0 or not Acts.ARENA.has_point(at):
				return {}
			var speed := float(Acts.LEADER["move"]["speed"]) + Acts.SPEED_PX * stat("speed")
			var n := ceili(u.pos.distance_to(at) / speed)
			var steps := []
			for i in range(1, n + 1):
				steps.append({"ph": "move", "to": u.pos.move_toward(at, speed * i)})
			return _act(k, steps)
		"bite":
			var a: Dictionary = Acts.LEADER["bite"]
			var face := _clamp_turn(u.ang, _aim(at), float(a["turn"]))
			# Straight ahead it's just the jaws; to a side they sweep round to there.
			var bite := {"ph": "act", "face": face, "dmg": a["dmg"], "push": a["push"],
				"hit": [Shape.sweep(u.pos, float(a["reach"]), u.ang, face, float(a["r"]))]}
			return _act(k, [{"ph": "wind"}, bite])
		"leap":
			var a: Dictionary = Acts.LEADER["leap"]
			var back := absf(angle_difference(u.ang, _aim(at))) > PI / 2.0
			var way := _clamp_turn(u.ang + (PI if back else 0.0), _aim(at), float(a["turn"]))
			var d := clampf(u.pos.distance_to(at), float(a["min"]), float(a["reach"]))
			var land := u.pos + Vector2.from_angle(way) * d
			if not in_arena(land, u, u.ang if back else way):
				return {}
			if back:
				return _act(k, [{"ph": "move", "to": land, "air": true, "hop": true}], "HOP")
			var jump := {"ph": "act", "to": land, "air": true, "face": way, "dmg": a["dmg"], "push": a["push"],
				"hit": [Shape.oval(_middle(land, way), way, float(a["long"]) / 2.0, float(a["wide"]) / 2.0)]}
			return _act(k, [{"ph": "wind", "face": way}, jump], "LEAP")
		"whip":
			var a: Dictionary = Acts.LEADER["whip"]
			var back := u.ang + PI
			# -1 = round its right, +1 = round its left (the way it turns).
			var spin := 1.0 if angle_difference(u.ang, _aim(at)) <= 0.0 else -1.0
			var big_r := (float(a["r_in"]) + float(a["r_out"])) / 2.0
			var r := (float(a["r_out"]) - float(a["r_in"])) / 2.0
			var whip := {"ph": "act", "face": back, "spin": spin, "dmg": a["dmg"], "from": u.pos,
				"hit": [Shape.sweep(u.pos, big_r, back, u.ang, r, spin * PI)]}
			if aspect("blades") >= 1:
				# The claw: the front swings round the other side as it turns.
				var c: Dictionary = Acts.BLADES["claw"]
				var cr := (float(c["r_out"]) - float(c["r_in"])) / 2.0
				whip["also"] = [{"dmg": c["dmg"], "from": u.pos, "bleed": true,
					"hit": [Shape.sweep(u.pos, float(c["r_in"]) + cr, u.ang, back, cr, spin * PI)]}]
			return _act(k, [{"ph": "wind"}, whip])
		"hip":
			var a: Dictionary = Acts.LEADER["hip"]
			var way := _hip_way(at)
			var out := float(a["side"]) + float(a["out"]) / 2.0
			var hip := {"ph": "act", "face": u.ang, "to": u.pos + Vector2.from_angle(way) * float(a["move"]),
				"dmg": a["dmg"], "push": a["push"], "way": way,
				"hit": [Shape.box(_middle(u.pos, u.ang) + Vector2.from_angle(way) * out, way,
					float(a["out"]) / 2.0, float(a["long"]) / 2.0)]}
			return _act(k, [{"ph": "wind"}, hip])
		"arms":
			var a: Dictionary = Acts.LEADER["arms"]
			var f := Vector2.from_angle(u.ang)
			var steps: Array = [{"ph": "wind"}]
			var blades := aspect("blades") >= 1
			var n := 3 if blades else 2
			for i in range(1, n + 1):
				var at_i: Vector2 = u.pos + f * float(a["step"]) * i
				var reach := float(Acts.BLADES["reach"]) if blades else float(a["reach"])
				var r := float(a["r"])
				var dmg := int(a["dmg"])
				if blades and i == n:
					r = float(Acts.BLADES["last_r"])
					dmg = int(Acts.BLADES["last_dmg"])
				steps.append({"ph": "act", "face": u.ang, "to": at_i, "dmg": dmg, "push": a["step"], "way": u.ang,
					"bleed": blades, "hit": [Shape.disc(at_i + f * reach, r)]})
			return _act(k, steps)
		"charge":
			var way := _aim(at)
			var steps: Array = [{"ph": "wind", "face": way, "reaim": true}]
			steps.append_array(_charge(u.pos, way))
			return _act(k, steps)
		"wait":
			return _act(k, [{"ph": "wait"}])
	return {}


## The rest of a charge from p going `way`: the second wind-up and the run.
func _charge(p: Vector2, way: float) -> Array:
	var a: Dictionary = Acts.LEADER["charge"]
	var f := Vector2.from_angle(way)
	var head := float(leader.data()["body"][0][0])
	var end := p + f * float(a["long"])
	var w := float(a["w"])
	var blades := aspect("blades") >= 2
	if blades:
		w += float(Acts.BLADES["charge_w"])
	return [{"ph": "wind", "face": way},
		{"ph": "act", "face": way, "to": end, "hit_first": true, "dmg": a["dmg"], "push": a["push"],
			"line": [p, end + f * head], "bleed": blades, "hit": [Shape.bar(p + f * head, end + f * head, w)]}]


## Is the leader stopped part way through an attack, to aim it again?
func reaiming() -> bool:
	if leader.idle() or leader.cur.get("reaimed", false):
		return false
	var b := int(leader.cur["b"])
	return b > 0 and leader.cur["steps"][b - 1].get("reaim", false)


## What the leader's attack would be, aimed again at `at`: no further than
## `turn` from where it was first aimed.
func reaim_shape(at: Vector2) -> Dictionary:
	var c: Dictionary = leader.cur
	var b := int(c["b"])
	var first := float(c["steps"][b - 1]["face"])
	var way := _clamp_turn(first, _aim(at), float(Acts.LEADER[c["k"]]["turn"]))
	var out := c.duplicate()
	out["steps"] = c["steps"].slice(0, b) + _charge(leader.pos, way)
	return out


## Aims it again and carries on.
func reaim(at: Vector2) -> void:
	if not reaiming():
		return
	var more := (Acts.STR_BITE if leader.cur["k"] == "bite" else Acts.STR_OTHER) * stat("strength")
	var c := reaim_shape(at)
	for i in range(int(c["b"]), c["steps"].size()):
		for h in hits_of(c["steps"][i]):
			h["dmg"] = int(h["dmg"]) + more
	c["reaimed"] = true
	leader.cur = c


## Where the leader can aim it again: [shapes].
func reaim_reach() -> Array:
	var c: Dictionary = leader.cur
	var first := float(c["steps"][int(c["b"]) - 1]["face"])
	var a: Dictionary = Acts.LEADER[c["k"]]
	return [Shape.fan(leader.pos, float(a["long"]) + float(leader.data()["body"][0][0]), first, float(a["turn"]))]


## The way a hip check aimed at `at` goes: out to the side the mouse is on,
## turned toward it as far as it can.
func _hip_way(at: Vector2) -> float:
	var u := leader
	var side := u.ang - PI / 2.0 if angle_difference(u.ang, _aim(at)) <= 0.0 else u.ang + PI / 2.0
	return _clamp_turn(side, _aim(at), float(Acts.LEADER["hip"]["turn"]))


## Where a tool can be aimed, to draw under it: [shapes].
func reach(k: String) -> Array:
	var u := leader
	match k:
		"bite":
			var a: Dictionary = Acts.LEADER["bite"]
			return [Shape.fan(u.pos, float(a["reach"]) + float(a["r"]), u.ang, float(a["turn"]))]
		"leap":
			var a: Dictionary = Acts.LEADER["leap"]
			return [Shape.band(u.pos, float(a["min"]), float(a["reach"]), u.ang, float(a["turn"])),
				Shape.band(u.pos, float(a["min"]), float(a["reach"]), u.ang + PI, float(a["turn"]))]
		"whip":
			var a: Dictionary = Acts.LEADER["whip"]
			return [Shape.band(u.pos, float(a["r_in"]), float(a["r_out"]), u.ang, PI)]
		"hip":
			# Straight out to either side.
			var a: Dictionary = Acts.LEADER["hip"]
			var out := float(a["side"]) + float(a["out"]) / 2.0
			var m := _middle(u.pos, u.ang)
			var all := []
			for way in [u.ang - PI / 2.0, u.ang + PI / 2.0]:
				all.append(Shape.box(m + Vector2.from_angle(way) * out, way, float(a["out"]) / 2.0, float(a["long"]) / 2.0))
			return all
	return []


## The middle of the leader's body if it stood at p facing a.
func _middle(p: Vector2, a: float) -> Vector2:
	var b := leader.body(p, a)
	return (b[0][0] + b[b.size() - 1][0]) / 2.0


func _aim(at: Vector2) -> float:
	return (at - leader.pos).angle() if at.distance_to(leader.pos) > 0.5 else leader.ang


## want, turned no further than `most` from `from`.
static func _clamp_turn(from: float, want: float, most: float) -> float:
	return from + clampf(angle_difference(from, want), -most, most)


func _act(k: String, steps: Array, label := "") -> Dictionary:
	return {"k": k, "label": label if label != "" else String(Acts.LEADER[k]["label"]), "steps": steps, "b": 0}


## Does it: the leader starts the action.
func plan(k: String, at: Vector2) -> bool:
	if not leader.idle() or result != "" or cooling(k) > 0 or not knows(k):
		return false
	var a := shape(k, at)
	if a.is_empty():
		return false
	# Strength adds to every hit.
	var more := (Acts.STR_BITE if k == "bite" else Acts.STR_OTHER) * stat("strength")
	for st in a["steps"]:
		for h in hits_of(st):
			h["dmg"] = int(h["dmg"]) + more
	leader.cur = a
	if Acts.LEADER[k].has("cool"):
		# Counted from when it ends.
		cool[k] = a["steps"].size() + int(Acts.LEADER[k]["cool"])
	return true


## Beats before the leader can use k again (0 = it can).
func cooling(k: String) -> int:
	return int(cool.get(k, 0))


# ---------------------------------------------------------------- the hunters

func _choose(u: Unit) -> void:
	match u.kind:
		"sword":
			_sword(u)
		"bow":
			_bow(u)


func _wait(u: Unit) -> void:
	u.cur = {"k": "wait", "label": "", "steps": [{"ph": "wait"}], "b": 0}


func _sword(u: Unit) -> void:
	var t := _prey(u)
	if t == null:
		_wait(u)
		return
	var at := t.near(u.pos)
	var a := (at - u.pos).angle()
	if t.gap(u.pos) <= float(Acts.SWORD["r"]) * 0.6:
		var steps := []
		for i in int(Acts.SWORD["wind"]):
			steps.append({"ph": "wind", "face": a})
		var hand := u.pos + Vector2(Acts.SWORD["hand"]).rotated(a)
		steps.append({"ph": "act", "dmg": Acts.SWORD["slash"],
			"hit": [Shape.fan(hand, float(Acts.SWORD["r"]), a, float(Acts.SWORD["arc"]))]})
		steps.append({"ph": "rec"})
		u.cur = {"k": "slash", "label": "SLASH", "b": 0, "steps": steps}
		return
	var go := minf(float(Acts.SWORD["speed"]), t.gap(u.pos, 4.0) - 2.0)
	u.cur = {"k": "move", "label": "", "b": 0, "steps": [{"ph": "move", "to": u.pos.move_toward(at, maxf(go, 0.0))}]}


func _bow(u: Unit) -> void:
	var t := _prey(u)
	if t == null:
		_wait(u)
		return
	var b: Dictionary = Acts.BOW
	var d := u.pos.distance_to(t.pos)
	var a := (t.pos - u.pos).angle()
	if d >= float(b["near"]) and d <= float(b["far"]):
		var steps := []
		for i in int(b["wind"]):
			steps.append({"ph": "wind", "face": a})
		steps.append({"ph": "act", "dmg": b["shot"],
			"hit": [Shape.bar(u.pos + Vector2.from_angle(a) * 5.0, u.pos + Vector2.from_angle(a) * float(b["reach"]), float(b["w"]))]})
		steps.append({"ph": "rec"})
		u.cur = {"k": "shot", "label": "SHOT", "b": 0, "steps": steps}
		return
	# Too near: back off; too far: close in.
	var want := (float(b["near"]) + float(b["far"])) / 2.0
	var to := t.pos + (u.pos - t.pos).normalized() * want
	u.cur = {"k": "move", "label": "", "b": 0, "steps": [{"ph": "move", "to": u.pos.move_toward(to, float(b["speed"]))}]}


## Which pack member a hunter goes for: the leader (the only one for now).
func _prey(_u: Unit) -> Unit:
	return leader if leader.alive() else null


# ---------------------------------------------------------------- effects

func _number(p: Vector2, s: String, c: Color) -> void:
	numbers.append({"p": p, "s": s, "life": 0.8, "col": c, "wait": fx_wait})


func _sparks(at: Vector2, n: int, c: Color) -> void:
	for i in n:
		var v := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 60.0)
		sparks.append({"p": at, "v": v, "life": 0.4, "max": 0.4, "col": c, "wait": fx_wait})


func fx(dt: float) -> void:
	shake_amt = maxf(shake_amt - dt * 12.0, 0.0)
	for u in units:
		u.flash = maxf(u.flash - dt * 4.0, 0.0)
	for list in [numbers, sparks]:
		for e in list:
			if float(e.get("wait", 0.0)) > 0.0:
				e["wait"] = float(e["wait"]) - dt
				continue
			e["life"] = float(e["life"]) - dt
			if e.has("v"):
				e["p"] += e["v"] * dt
			if list == numbers:
				e["p"] += Vector2(0, -12) * dt
	numbers = numbers.filter(func(e): return e["life"] > 0.0)
	sparks = sparks.filter(func(e): return e["life"] > 0.0)
