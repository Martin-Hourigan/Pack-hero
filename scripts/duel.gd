class_name Duel
extends RefCounted
## The hero through one map (Acts.MAP: areas joined by halls, doors in
## them), against its enemies (Acts.FOES: the big knight, soldiers,
## spearmen, archers), with no drawing or input so tests can run it. Walls,
## pillars and closed doors block walking, shots and sight; walking into a
## door opens it (a step); the boss door shuts behind him in the boss area.
## The hero sees what a straight line from him reaches (sight), and
## remembers what he's seen (memory, kept when he dies); an enemy comes for
## him once it sees him within Acts.AGGRO (or is hit, or hears another
## yell), finding its way round walls (paths); until then it stands at its
## post or walks its patrol, and goes to look at what it hears. Walking somewhere out of a straight line finds the
## way too. Time goes in steps, everyone together. Everyone is a puppet
## (RigArt): an attack plays a clip, one frame a step, and the blade hits
## wherever the puppet's blade really is, swept from where it was at the
## step before (checked SWEEP_CHECKS times between, both bodies moving as
## they go). A swing hits each body at most once. Shots (arrows, bolts,
## spells) fly a set distance a step and hit the first body they reach.
## Numbers: Acts.HERO, Acts.ITEMS, Acts.SHOTS, Acts.KNIGHT.
##
## The hero's tools: move, roll, flask, wait, and "hand:thing" for what the
## item in that hand does (Acts.ITEMS), e.g. "right:light", "left:bolt",
## or SWAP, TWO HANDS, ONE HAND, TRANSFORM ("left:swap"; Acts.CHANGE).
## Toggles: LOCK (on an enemy picked: he faces it; shots aim at it), GUARD (a
## shield's or two-handed weapon's BLOCK, held up whatever he's doing, until
## anything but walking, waiting or a "keeps guard" attack; stamina comes
## back slower).
## Each hand has two slots and holds one; an item held in both hands (a
## two-handed one, or one taken in TWO HANDS) puts the other hand's away.
##
## An action: {k, label, steps, b, hit (it has landed)}. A step:
## {ph: wind / act / rec / move / roll / drink / wait / hurt / reload / change, clip, frame,
## live (the blade hits), safe (hits miss you), to (walk there), fwd (px
## forward), track (turn toward the hero), dmg, heal, shoot (Acts.SHOTS
## entry), unload (the slot it empties), reload
## (that slot is loaded), change ([hand, Acts.CHANGE entry]: done now),
## mirror (the clip is played in the left hand)}.

var hero: Unit
var knight: Unit  # the knight, if he's here (null if not)
var foes: Array = []  # every enemy (the knight too)
var units: Array = []
var step_n := 0
var result := ""  # "", "win", "lose"
var stamina := 0
var flasks := 0
var rng := RandomNumberGenerator.new()
var gear := {}  # hand -> [Acts.ITEMS key, Acts.ITEMS key]: its two slots
var up := {"left": 0, "right": 0}  # the slot each hand holds
var grip := ""  # the hand whose item is held in both hands ("" = none)
var casts := {}  # "item:thing" -> casts left (full until used)
var loaded := {}  # slot ("left0") -> its crossbow is loaded (it is until shot)
var shots: Array = []  # {k, p, from, ang, left (px it can still go), by}
var gone: Array = []  # shots that ended this step (drawn for one more step)
var target: Unit = null  # LOCK: the enemy locked on to (null = none)
var guard := false  # GUARD: the hero's block is up

# Effects (the view draws them; they don't change play).
var numbers: Array = []  # {p, s, life, col}
var sparks: Array = []  # {p, v, life, max, col}
var shake_amt := 0.0
var foe_started := false  # an enemy started an attack in the last step
var wiggle := {}  # HUD thing -> seconds left (a stamina bar that's too low)


## The knight alone, in the old arena (the tests' room); he's seen you.
const KNIGHT_ROOM := {"area": Acts.ARENA, "start": Vector2(110, 92),
	"foes": [{"k": "knight", "at": Vector2(270, 92), "a": PI, "aware": true}]}
## What a fog square is.
enum {OPEN, WALL, PILLAR, DOOR, LOW, SHRUB}
## What stops sight, a body, a shot (bits of the kinds of square).
const SIGHT_STOPS := (1 << WALL) | (1 << PILLAR) | (1 << DOOR)
const CROUCH_SIGHT_STOPS := SIGHT_STOPS | (1 << SHRUB) | (1 << LOW)
const WALK_STOPS := (1 << WALL) | (1 << PILLAR) | (1 << DOOR) | (1 << LOW)
const SHOT_STOPS := (1 << WALL) | (1 << PILLAR) | (1 << DOOR)
const SOUND_STOPS := (1 << WALL) | (1 << DOOR)
const LANTERNS_NEAR := 320.0
const LOOK_FAR := 216.0  # px: the view's size; sight goes no further
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var map := {}  # Acts.MAP (or a room like KNIGHT_ROOM: one area)
var room_i := 0  # (one map: always 0; memory's key)
var area := Rect2()  # the box round it all (and a square of wall round that)
var floors: Array = []  # Rect2s: the areas and halls
var pillars: Array = []  # Rect2s
var shrubs: Array = []  # Rect2s
var low_walls: Array = []  # Rect2s
var doors: Array = []  # {rect, open, boss, shut (the boss door, shut behind him)}
var boss_area := Rect2()  # (none: empty)
var memory := {}  # room_i -> PackedByteArray: the squares (Acts.FOG) seen
var sight := PackedByteArray()  # the squares seen now
var fog_size := Vector2i.ZERO  # squares across, down
var solid := PackedByteArray()  # each square: OPEN, WALL, PILLAR, DOOR (closed), LOW, SHRUB
var light := PackedByteArray()  # each square: 0 dark, 1 dim, 2 lit (now)
var fixed_light := PackedByteArray()  # the same from the sun and the lights that stay put
var lights: Array = []  # {k (Acts.LIGHTS), at}
var touches := PackedByteArray()  # each square: which sides (bits) are next to one sight stops at
var paths := AStarGrid2D.new()  # the squares a body's middle can go (room to spare)


## map_: Acts.MAP, or a room (KNIGHT_ROOM); the hero starts in area
## `first`. memory: what's been seen before (a Dictionary, kept by the
## caller across deaths).
func _init(seed_ := 0, gear_ := Acts.HANDS, map_: Dictionary = KNIGHT_ROOM, first := 0, memory_ := {}) -> void:
	rng.seed = seed_ if seed_ != 0 else int(Time.get_ticks_usec())
	gear = {"left": Array(gear_["left"]).duplicate(), "right": Array(gear_["right"]).duplicate()}
	_settle("right")
	hero = _add("hero", Vector2.ZERO, 0.0)
	hero.side = "hero"
	stamina = int(Acts.HERO["stamina"])
	flasks = int(Acts.HERO["flasks"])
	map = map_
	memory = memory_
	floors = Array(map.get("areas", [map.get("area", Rect2())])) + Array(map.get("halls", []))
	area = floors[0]
	for fl in floors:
		area = area.merge(fl)
	area = area.grow(Acts.FOG)
	pillars = map.get("pillars", [])
	shrubs = map.get("shrubs", [])
	low_walls = map.get("low walls", [])
	lights = map.get("lights", [])
	for dr in map.get("doors", []):
		doors.append({"rect": dr["rect"], "open": false, "boss": dr.get("boss", false), "shut": false})
	if map.has("boss"):
		boss_area = map["areas"][int(map["boss"])]
	hero.pos = map["starts"][first] if map.has("starts") else map["start"]
	hero.pose = rest(hero)
	for f in map.get("foes", []):
		var e := add_foe(String(f["k"]), f["at"], float(f.get("a", PI)))
		e.aware = f.get("aware", false)
		e.patrol = f.get("patrol", [])
	fog_size = Vector2i(ceili(area.size.x / Acts.FOG), ceili(area.size.y / Acts.FOG))
	if not memory.has(room_i) or memory[room_i].size() != fog_size.x * fog_size.y:
		var m := PackedByteArray()
		m.resize(fog_size.x * fog_size.y)
		memory[room_i] = m
	_build()
	_light()
	_look()
	_sketches()


func _add(k: String, at: Vector2, a: float) -> Unit:
	var u := Unit.new(k, at, a)
	u.col = Pal.INK
	u.pose = rest(u)
	units.append(u)
	return u


func add_foe(k: String, at: Vector2, a: float) -> Unit:
	var u := _add(k, at, a)
	u.side = "enemy"
	u.aware = false
	u.post = at
	u.post_ang = a
	foes.append(u)
	if k == "knight" and knight == null:
		knight = u
	return u


static func foe_data(u: Unit) -> Dictionary:
	return Acts.FOES[u.kind]


func art(u: Unit) -> String:
	return String(u.data()["art"])


## The puppet's own pose (between actions).
func rest(u: Unit) -> Dictionary:
	if u == hero or (hero == null and u.kind == "hero"):
		return hero_pose("", 0.0, false)
	return RigArt.pose(art(u), "", 0.0)


# ---------------------------------------------------------------- gear

## The item in hand h's held slot (Acts.ITEMS key).
func held(h: String) -> String:
	return gear[h][up[h]]


## The hand whose slot has h's item: the gripping hand, if there is one.
func owner(h: String) -> String:
	return grip if grip != "" else h


static func other(h: String) -> String:
	return "left" if h == "right" else "right"


## Which hands have their own item: just the gripping one, unless what it
## holds is split into two halves.
func hands() -> Array:
	if grip == "" or Acts.ITEMS[held(grip)].has("split"):
		return ["left", "right"]
	return [grip]


## The Acts.ITEMS key of what hand h is holding (a split item's half).
func item_key(h: String) -> String:
	var o := owner(h)
	var it: Dictionary = Acts.ITEMS[held(o)]
	return it["split"][h] if it.has("split") else held(o)


func item(h: String) -> Dictionary:
	return Acts.ITEMS[item_key(h)]


## Whether the one-handed item in h is held in both hands.
func two_handed(h: String) -> bool:
	return grip == h and int(item(h)["hands"]) == 1


## Puppet node n of item `it` in hand h (one-handed items' end _r / _l).
static func node_of(n: String, it: Dictionary, h: String) -> String:
	return n if int(it["hands"]) == 2 else n + ("_r" if h == "right" else "_l")


## Hand h's menu: {thing: what it does}, BACKSTAB first when there's one
## to do (with a melee LIGHT), the item's own, then TWO HANDS or ONE HAND,
## TRANSFORM and SWAP (in the hand whose slot it is).
func options(h: String) -> Dictionary:
	if not h in hands():
		return {}
	var it := item(h)
	var does: Dictionary = it["two"] if two_handed(h) and it.has("two") else it["does"]
	var out := {}
	var light: Dictionary = does.get("light", {})
	if light.has("live") and backstab_target() != null:
		out["backstab"] = {"backstab": light, "times": float(Acts.BACKSTAB["times"]) + float(it.get("backstab", 0.0)), "st": light.get("st", 0)}
	out.merge(does)
	if it.has("two"):
		var g := "one hand" if two_handed(h) else "two hands"
		out[g] = {"change": g}
	if Acts.ITEMS[held(owner(h))].has("trick"):
		out["transform"] = {"change": "transform"}
	if owner(h) == h:
		out["swap"] = {"change": "swap"}
	return out


## A two-handed item takes both hands: hand h's, else the other's.
func _settle(h: String) -> void:
	if grip != "":
		return
	for x in [h, other(h)]:
		if int(Acts.ITEMS[held(x)]["hands"]) == 2:
			grip = x
			return


## Hand h does an Acts.CHANGE.
func _change(h: String, what: String) -> void:
	var o := owner(h)
	match what:
		"swap":
			up[o] = 1 - int(up[o])
			if grip == o:
				grip = ""
			_settle(o)
		"two hands":
			grip = h
		"one hand":
			grip = ""
			_settle(h)
		"transform":
			gear[o][up[o]] = Acts.ITEMS[held(o)]["trick"]
			_settle(o)


## The BLOCK the hero has: the hand's that has one (a shield, or a weapon
## held in two hands), with "hand" added ({} = none).
func guard_spec() -> Dictionary:
	for h in hands():
		var o := options(h)
		if o.has("block"):
			var g: Dictionary = o["block"].duplicate()
			g["hand"] = h
			return g
	return {}


## Whether tool k, locked on, aims itself at the target: shots do; a
## melee swing you still aim (its reach shows).
func auto_aims(k: String) -> bool:
	return spec(k).has("shot")


## The enemy whose body is at p, give or take `slack` px (null = none).
func enemy_at(p: Vector2, slack := 4.0) -> Unit:
	for u in units:
		if u.side != "enemy" or not u.alive() or not sees(u):
			continue
		for c in u.body():
			if p.distance_to(c[0]) <= float(c[1]) + slack:
				return u
	return null


## The 2H toggle's tool: take the right hand's item in two hands (else the
## left's), or let go ("" = nothing it can do).
func two_tool() -> String:
	if grip != "":
		return grip + ":one hand" if two_handed(grip) else ""
	for h in ["right", "left"]:
		if item(h).has("two"):
			return h + ":two hands"
	return ""


## Crouches or stands up.
func toggle_crouch() -> void:
	hero.crouch = not hero.crouch
	_look()
	_sketches()


## Turns GUARD on or off; false (it wiggles) if there's nothing to block with.
func toggle_guard() -> bool:
	if not guard and guard_spec().is_empty():
		wiggle["guard"] = 0.4
		return false
	guard = not guard
	hero.pose = rest(hero)
	return true


## The slot hand h holds ("left0").
func slot(h: String) -> String:
	return h + str(up[h])


func is_loaded(h: String) -> bool:
	return bool(loaded.get(slot(h), true))


## Casts tool k has left (-1: it has no limit).
func casts_left(k: String) -> int:
	var s := spec(k)
	if not s.has("casts"):
		return -1
	return int(casts.get(item_key(k.split(":")[0]) + ":" + k.split(":")[1], int(s["casts"])))


## What tool k ("hand:thing") does, from Acts.ITEMS ({} = not a hand's).
func spec(k: String) -> Dictionary:
	var hk := k.split(":")
	if hk.size() != 2 or not gear.has(hk[0]):
		return {}
	return options(hk[0]).get(hk[1], {})


## The hero's pose: what's in each hand held, and clip k at frame f on top
## (mirror: played in the left hand). parts: {node: part} swapped in.
func hero_pose(k: String, f: float, mirror: bool, parts := {}) -> Dictionary:
	var path := String(Acts.DUEL_UNITS["hero"]["art"])
	var out := RigArt.pose(path, "", 0.0)
	var shown := {}
	var look := {}
	for h in hands():
		var it := item(h)
		look.merge(it.get("look", {}))
		for n in it["nodes"]:
			shown[node_of(n, it, h)] = true
	for th in Acts.ITEMS:
		var it: Dictionary = Acts.ITEMS[th]
		for n in it["nodes"]:
			for nn in ([n] if int(it["hands"]) == 2 else [n + "_r", n + "_l"]):
				if out.has(nn):
					out[nn]["vis"] = shown.has(nn)
	for h in hands():
		var it := item(h)
		var hold := String(it["key"]) + ("2_hold" if two_handed(h) else "_hold")
		_over(out, RigArt.track_pose(path, hold, 0.0), h == "left" and int(it["hands"]) == 1)
	var g := guard_spec() if guard else {}
	if not g.is_empty():
		_over(out, RigArt.track_pose(path, g["clip"], 1.0), g["hand"] == "left" and int(item(g["hand"])["hands"]) == 1)
	if k != "":
		_over(out, RigArt.track_pose(path, k, f), mirror)
	for h in hands():
		var n := node_of("xb_bolt", item(h), h)
		if item(h)["key"] == "xb" and out.has(n):
			out[n]["vis"] = is_loaded(h)
	for n in look:
		if out.has(n):
			out[n]["part"] = look[n]
	for n in parts:
		if out.has(n):
			out[n]["part"] = parts[n]
	return out


## Puts the tracked values in tp over pose `out` (flipped to the other side
## when mirror).
static func _over(out: Dictionary, tp: Dictionary, mirror: bool) -> void:
	for n in tp:
		var e: Dictionary = tp[n]
		var nn: String = n
		if mirror:
			if nn.ends_with("_r"):
				nn = nn.left(-2) + "_l"
			elif nn.ends_with("_l"):
				nn = nn.left(-2) + "_r"
		if not out.has(nn):
			continue
		for key in e:
			var v = e[key]
			if mirror and key == "pos":
				v = Vector2(v.x, -v.y)
			elif mirror and key == "rot":
				v = -float(v)
			out[nn][key] = v


## u's pose doing step st of action a.
func pose_for(u: Unit, st: Dictionary, a: Dictionary) -> Dictionary:
	if not st.has("clip"):
		return rest(u)
	if u == hero:
		return hero_pose(String(st["clip"]), float(st["frame"]), st.get("mirror", false), a.get("parts", {}))
	return RigArt.pose(art(u), String(st["clip"]), float(st["frame"]))


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
			if i == wind + 1 and a.has("shot"):
				st["shoot"] = a["shot"]
			if (i - wind) in a.get("live", []):
				st["live"] = true
				st["dmg"] = int(a["dmg"])
		steps.append(st)
	for i in int(a.get("after", 0)):
		steps.append({"ph": "wait"})
	return steps


func _act(k: String, steps: Array) -> Dictionary:
	return {"k": k, "label": k.to_upper(), "steps": steps, "b": 0, "struck": []}


## What the hero would do with tool k aimed at `at` ({} = can't).
func shape(k: String, at: Vector2) -> Dictionary:
	var u := hero
	if target != null and auto_aims(k):
		at = target.pos
	var aim := (at - u.pos).angle() if at.distance_to(u.pos) > 0.5 else u.ang
	match k:
		"move":
			if at.distance_to(u.pos) < 1.0 or not on_floor(at):
				return {}
			var way := route(u, at)
			if way.is_empty():
				return {}
			# A step's walk at a time along the way, round its corners.
			var speed := float(Acts.HERO["crouch_walk" if u.crouch else "walk"])
			var steps := []
			var p := u.pos
			var last := u.pos  # where the step before ended
			var left := speed  # px this step can still go
			for q in way:
				while p.distance_to(q) > 0.01:
					var nxt := p.move_toward(q, left)
					left -= p.distance_to(nxt)
					p = nxt
					if left <= 0.01:
						steps.append({"ph": "move", "to": p, "face": (p - last).angle()})
						last = p
						left = speed
			if last.distance_to(p) > 0.01:
				steps.append({"ph": "move", "to": p, "face": (p - last).angle()})
			return _act(k, steps)
		"steer":
			# One step's walk straight toward `at` (held down: steering).
			if at.distance_to(u.pos) < 1.0:
				return {}
			var go := minf(float(Acts.HERO["crouch_walk" if u.crouch else "walk"]), at.distance_to(u.pos))
			return _act("move", [{"ph": "move", "to": u.pos + Vector2.from_angle(aim) * go, "face": aim}])
		"roll":
			var r: Dictionary = Acts.HERO["roll"]
			var steps := []
			for i in range(1, int(r["steps"]) + 1):
				steps.append({"ph": "roll", "clip": r["clip"], "frame": i, "face": aim,
					"to": u.pos + Vector2.from_angle(aim) * float(r["px"]) * i, "safe": i <= int(r["safe"])})
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
	var s := spec(k)
	if s.is_empty() or s.has("block"):
		return {}  # (a block is GUARD's)
	var h := k.split(":")[0]
	var it := item(h)
	var mirror := h == "left" and int(it["hands"]) == 1
	var a: Dictionary
	if s.has("change"):
		var steps := []
		for i in int(Acts.CHANGE[s["change"]]):
			steps.append({"ph": "change"})
		steps[steps.size() - 1]["change"] = [h, s["change"]]
		a = _act(k, steps)
	elif s.has("backstab"):
		var v := backstab_target()
		if v == null:
			return {}
		var l: Dictionary = s["backstab"]
		var top := int(l["wind"]) + int(l["swing"])
		var steps := []
		for i in range(1, int(l["wind"]) + 1):
			steps.append({"ph": "wind", "clip": l["clip"], "frame": i, "mirror": mirror})
		steps.append({"ph": "act", "clip": l["clip"], "frame": top, "mirror": mirror,
			"stab": roundi(int(l["dmg"]) * float(s["times"]))})
		for i in int(Acts.BACKSTAB["hold"]):
			steps.append({"ph": "rec", "clip": l["clip"], "frame": top, "mirror": mirror})
		for i in range(top + 1, top + int(l["rec"]) + 1):
			steps.append({"ph": "rec", "clip": l["clip"], "frame": i, "mirror": mirror})
		steps[0]["face"] = (v.pos - hero.pos).angle()
		a = _act(k, steps)
		a["victim"] = v
	elif s.has("reload"):
		var steps := []
		for i in range(1, int(s["reload"]) + 1):
			steps.append({"ph": "reload", "clip": s["clip"], "frame": i, "mirror": mirror})
		steps[steps.size() - 1]["reload"] = slot(h)
		a = _act(k, steps)
	else:
		var steps := attack_steps(s)
		for st in steps:
			st.erase("track")
			st["mirror"] = mirror
			if guard and s.get("keeps guard", false):
				st.erase("fwd")
			if st.has("shoot") and s.get("loaded", false):
				st["unload"] = slot(h)
		steps[0]["face"] = aim
		a = _act(k, steps)
		if it.has("blade"):
			a["blade"] = node_of(String(it["blade"]), it, h)
	a["label"] = k.split(":")[1].to_upper()
	if s.has("parts"):
		a["parts"] = s["parts"]
	return a


## The stamina tool k costs.
func cost(k: String) -> int:
	if k == "roll":
		return int(Acts.HERO["roll"]["st"])
	return int(spec(k).get("st", 0))


## The hero starts doing k at `at`. False if it can't (busy, out of
## stamina: the bar wiggles).
func plan(k: String, at: Vector2) -> bool:
	if not hero.idle() or result != "":
		return false
	if cost(k) > stamina:
		wiggle["stamina"] = 0.4
		return false
	var s := spec(k)
	var h := k.split(":")[0]
	if casts_left(k) == 0 or (s.get("loaded", false) and not is_loaded(h)):
		wiggle["hand:" + (hands()[0] if hands().size() == 1 else h)] = 0.4
		return false
	var a := shape(k, at)
	if a.is_empty():
		if k == "flask":
			wiggle["flasks"] = 0.4
		return false
	stamina -= cost(k)
	if not k in ["move", "steer", "wait"] and not s.get("keeps guard", false):
		guard = false
	if not k in ["move", "steer", "wait"] and not s.has("live") and not s.has("backstab"):
		hero.crouch = false  # (a melee attack or BACKSTAB keeps him crouching)
	if a.has("victim"):
		_hold(a["victim"], int(s["backstab"]["wind"]) + 1 + int(Acts.BACKSTAB["hold"]))
	if casts_left(k) > 0:
		casts[item_key(h) + ":" + k.split(":")[1]] = casts_left(k) - 1
	if k == "flask":
		flasks -= 1
	hero.cur = a
	return true


# ---------------------------------------------------------------- the enemies

func _choose(u: Unit) -> void:
	match String(foe_data(u)["ai"]):
		"knight":
			_choose_knight(u)
		"melee":
			_choose_melee(u)
		"archer":
			_choose_archer(u)


func _choose_knight(u: Unit) -> void:
	var d := u.pos.distance_to(hero.pos)
	var aim := (hero.pos - u.pos).angle()
	if d <= float(Acts.KNIGHT["reach"]):
		var off := rad_to_deg(absf(angle_difference(u.ang, aim)))
		var k := "sweep"
		if u.last == "sweep" and rng.randf() < float(Acts.KNIGHT["backhand_odds"]):
			k = "backhand"
		elif off < float(Acts.KNIGHT["overhead_cone"]) and d > float(Acts.KNIGHT["overhead_near"]):
			k = "overhead"
		start_attack(k, u)
		return
	u.last = ""
	_walk_to(u, d - float(Acts.KNIGHT["reach"]) + 1.0)


## In to its reach and attack; nearer than `near`, back off a step.
func _choose_melee(u: Unit) -> void:
	var f := foe_data(u)
	var d := u.pos.distance_to(hero.pos)
	if f.has("near") and d < float(f["near"]):
		_walk_to(u, -float(f["walk"]))
	elif d <= float(f["reach"]):
		start_attack(String(f["attacks"][rng.randi() % f["attacks"].size()]), u)
	else:
		_walk_to(u, d - float(f["reach"]) + 1.0)


## Between `near` and `far` of the hero: shoot; else get there.
func _choose_archer(u: Unit) -> void:
	var f := foe_data(u)
	var d := u.pos.distance_to(hero.pos)
	if d < float(f["near"]):
		_walk_to(u, -float(f["walk"]))
	elif d > float(f["far"]) or not los(u.pos, hero.pos, SHOT_STOPS):
		_walk_to(u, maxf(d - float(f["far"]) + 1.0, float(f["walk"])))
	else:
		start_attack(String(f["attacks"][0]), u)


## An enemy that hasn't spotted the hero: having heard him, it turns to
## where it heard him (and if it's going to look, goes there) and looks
## for Acts.LOOK_STEPS; then it's back to its patrol, or its post.
func _idle(u: Unit) -> void:
	var calm := float(foe_data(u)["walk"]) * Acts.CALM_WALK
	if u.heard != Vector2.INF:
		var there := u.pos.distance_to(u.heard) <= 2.0
		if u.inspect and not there and _stroll(u, u.heard, float(foe_data(u)["walk"]) if u.rush else calm):
			return
		u.inspect = false
		u.rush = false
		u.looking += 1
		if u.looking <= Acts.LOOK_STEPS:
			u.cur = _act("wait", [{"ph": "wait", "face": u.ang if there else (u.heard - u.pos).angle()}])
			return
		u.heard = Vector2.INF
		u.looking = 0
	if not u.patrol.is_empty():
		var to: Vector2 = u.patrol[u.patrol_i]
		if u.pos.distance_to(to) > 0.5 and _stroll(u, to, calm):
			return
		u.waited += 1
		if u.waited > Acts.PATROL_WAIT:
			u.waited = 0
			u.patrol_i = (u.patrol_i + 1) % u.patrol.size()
		u.cur = _act("wait", [{"ph": "wait"}])
		return
	if u.pos.distance_to(u.post) > 0.5 and _stroll(u, u.post, calm):
		return
	u.cur = _act("wait", [{"ph": "wait", "face": u.post_ang}])


## u walks a step (at most `go` px) toward `to`, the way round if it must;
## false if there's no way.
func _stroll(u: Unit, to: Vector2, go: float) -> bool:
	var way := route(u, to)
	if way.is_empty():
		return false
	var a := (Vector2(way[0]) - u.pos).angle()
	go = minf(go, u.pos.distance_to(way[0]))
	u.cur = _act("walk", [{"ph": "move", "to": u.pos + Vector2.from_angle(a) * go, "face": a}])
	return true


## u walks a step toward the hero, at most `go` px (away, if negative),
## facing him.
## Out of a straight line from him, it goes the way round instead.
func _walk_to(u: Unit, go: float) -> void:
	var aim := (hero.pos - u.pos).angle()
	var w := float(foe_data(u)["walk"])
	if go > 0.0 and not clear(u, u.pos, hero.pos):
		var way := route(u, hero.pos)
		if not way.is_empty():
			aim = (Vector2(way[0]) - u.pos).angle()
			go = minf(go, u.pos.distance_to(way[0]))
	u.cur = _act("walk", [{"ph": "move", "to": u.pos + Vector2.from_angle(aim) * clampf(go, -w, w), "face": aim}])


## u staggers (the knight, if not said): what it was doing stops for its
## `stagger` steps.
func stagger(u: Unit = null) -> void:
	if u == null:
		u = knight
	var steps := []
	for i in int(foe_data(u)["stagger"]):
		steps.append({"ph": "stagger"})
	u.cur = _act("stagger", steps)
	u.cur["b"] = -1  # (counted up at the end of this step)
	u.taken = 0
	u.last = ""
	shake_amt = maxf(shake_amt, 2.0 if u == knight else 1.0)


## u (the knight, if not said) starts its attack k.
func start_attack(k: String, u: Unit = null) -> void:
	if u == null:
		u = knight
	u.cur = _act(k, attack_steps(foe_data(u)[k]))
	u.last = k


# ---------------------------------------------------------------- steps

## Plays one step: everyone moves and poses together, then the blades hit.
func step() -> void:
	if result != "":
		return
	step_n += 1
	gone = []
	for u in units:
		u.was = {"pos": u.pos, "ang": u.ang, "pose": u.pose}
	var foe_starts := false
	var loud := noise() if not hero.idle() and String(current(hero).get("ph", "")) != "wait" else 0.0
	for u in foes:
		if not u.alive():
			continue
		u.calm += 1
		if u.calm >= int(foe_data(u)["calm"]):
			u.taken = 0
		if not u.aware and spots(u):
			_alarm(u)
		if not u.aware:
			_hear(u, loud)
		if u.idle():
			if u.aware:
				_choose(u)
			else:
				_idle(u)
		if int(u.cur.get("b", 1)) == 0 and _threat(u.cur):
			foe_starts = true
	var walking := String(hero.cur.get("k", "")) == "move"
	var resting := not String(current(hero).get("ph", "")) in ["wind", "act", "rec", "roll", "drink", "reload"]
	for u in units:
		if u.alive():
			_do(u)
	_keep_apart()
	_doors()
	for u in foes:
		if u.alive() and current(u).has("shoot"):
			_shoot(String(current(u)["shoot"]), "", u)
	var st_h := current(hero)
	if st_h.has("stab") and hero.cur.has("victim") and (hero.cur["victim"] as Unit).alive():
		var v: Unit = hero.cur["victim"]
		_hurt(v, hero, int(st_h["stab"]))
		if v.alive():
			_hold(v, int(Acts.BACKSTAB["hold"]) + 1)
			v.cur["b"] = -1  # (counted up at the end of this step)
	if st_h.has("shoot"):
		_shoot(String(st_h["shoot"]), String(st_h.get("unload", "")))
	if st_h.has("reload"):
		loaded[String(st_h["reload"])] = true
	if st_h.has("change"):
		_change(String(st_h["change"][0]), String(st_h["change"][1]))
		if guard_spec().is_empty():
			guard = false  # nothing left to block with
		hero.pose = rest(hero)
	# The blades: the hero's hits every enemy it sweeps over (each once a
	# swing); an enemy's only the hero.
	for u in units:
		var st := current(u)
		if not u.alive() or not st.get("live", false):
			continue
		if not u.cur.has("struck"):
			u.cur["struck"] = []
		for v in (foes if u == hero else [hero]):
			if not v.alive() or v in u.cur["struck"] or current(v).get("safe", false):
				continue
			if u != hero and not u.cur["struck"].is_empty():
				continue
			var at: Variant = sweep_contact(u, v)
			if at == null:
				continue
			u.cur["struck"].append(v)
			if blocks(v, at):
				_blocked(at)
				var through := roundi(int(st["dmg"]) * float(guarding(v).get("cut", 0.0)))
				if through > 0:
					_chip(v, through)
			else:
				_hurt(v, u, roundi(int(st["dmg"]) * (hit_times(v) if u == hero else 1.0)))
	for u in units:
		if u.idle():
			continue
		if not u.alive():
			u.cur = {}
			continue
		var st := current(u)
		if st.has("heal"):
			hero.hp = mini(hero.hp + int(st["heal"]), hero.max_hp)
			_number(hero.pos + Vector2(0, -10), "+%d" % int(st["heal"]), Pal.INK)
		u.cur["b"] = int(u.cur["b"]) + 1
		if int(u.cur["b"]) >= u.cur["steps"].size():
			u.cur = {}
	_fly()
	_burn()
	if resting:
		var back := int(Acts.HERO["guard_back" if guard else "stamina_back"])
		stamina = mini(stamina + back, int(Acts.HERO["stamina"]))
	# A walk stops when an enemy starts an attack: you choose again.
	foe_started = foe_starts
	if walking and foe_starts and String(hero.cur.get("k", "")) == "move":
		hero.cur = {}
	_light()
	_look()
	_sketches()
	if target != null and (not target.alive() or not sees(target)):
		target = null
	if hero.hp <= 0:
		result = "lose"
	elif (knight != null and not knight.alive()) or (knight == null and foes.all(func(f): return not f.alive())):
		result = "win"


## The step u is doing (this step, before it's counted).
func current(u: Unit) -> Dictionary:
	if u.idle():
		return {}
	return u.cur["steps"][mini(int(u.cur["b"]), u.cur["steps"].size() - 1)]


## Whether action a hits or shoots.
static func _threat(a: Dictionary) -> bool:
	for st in a.get("steps", []):
		if st.get("live", false) or st.has("shoot"):
			return true
	return false


func _do(u: Unit) -> void:
	if u.idle():
		u.pose = rest(u)
		return
	var st := current(u)
	if st.has("face"):
		u.ang = float(st["face"]) if u == hero else turned(u, u.ang, float(st["face"]))
	if st.get("track", false) and u != hero:
		u.ang = turned(u, u.ang, (hero.pos - u.pos).angle())
	if st.has("to"):
		_walk(u, st["to"])
	if float(st.get("fwd", 0.0)) > 0.0:
		_walk(u, u.pos + Vector2.from_angle(u.ang) * float(st["fwd"]))
	if u == hero and target != null and not st.has("clip"):
		u.ang = (target.pos - u.pos).angle()  # walking, waiting...: facing it
	u.pose = pose_for(u, st, u.cur)


## Enemy u, facing `from`, turned toward `to` as far as it turns in a step.
func turned(u: Unit, from: float, to: float) -> float:
	var most := deg_to_rad(float(foe_data(u)["turn"]))
	return from + clampf(angle_difference(from, to), -most, most)


## Moves u toward `to`, a pixel at a time, sliding along a wall it meets
## at a slant, stopping at other bodies; but the knight pushes the hero
## aside (_keep_apart).
func _walk(u: Unit, to: Vector2) -> void:
	var n := ceili(u.pos.distance_to(to))
	for i in n:
		var go := u.pos.move_toward(to, 1.0) - u.pos
		var p := u.pos + go
		if not _in_arena(u, p):
			p = u.pos + Vector2(signf(go.x), 0)
			if absf(go.x) < 0.05 or not _in_arena(u, p):
				p = u.pos + Vector2(0, signf(go.y))
				if absf(go.y) < 0.05 or not _in_arena(u, p):
					return
		for v in units:
			if v == u or not v.alive() or (u == knight and v == hero):
				continue
			if p.distance_to(v.pos) < _radius(u) + _radius(v) and p.distance_to(v.pos) < u.pos.distance_to(v.pos):
				return
		u.pos = p


## Whether u's body fits at p: on the floor, clear of the pillars, low
## walls and closed doors.
func _in_arena(u: Unit, p: Vector2) -> bool:
	return fits(_radius(u), p)


func fits(r: float, p: Vector2) -> bool:
	if not on_floor(p):
		return false
	for i in 8:
		if not on_floor(p + Vector2.from_angle(i * PI / 4.0) * r):
			return false
	for pl in pillars + low_walls:
		if Rect2(pl).grow(r).has_point(p):
			return false
	for dr in doors:
		if not dr["open"] and Rect2(dr["rect"]).grow(r).has_point(p):
			return false
	return true


## Whether p is on the floor (an area or a hall).
func on_floor(p: Vector2) -> bool:
	for fl in floors:
		if Rect2(fl).has_point(p):
			return true
	return false


## Whether a shot at p is still in the open (on the floor, not in a pillar
## or a closed door).
func open_at(p: Vector2) -> bool:
	if not on_floor(p):
		return false
	for pl in pillars:
		if Rect2(pl).has_point(p):
			return false
	for dr in doors:
		if not dr["open"] and Rect2(dr["rect"]).has_point(p):
			return false
	return true


# ---------------------------------------------------------------- doors

## The hero walking into a closed door opens it (that step's walk is done
## again next step); in the boss area, the boss door shuts behind him while
## the knight lives.
func _doors() -> void:
	var st := current(hero)
	if String(st.get("ph", "")) == "move" and hero.pos.distance_to(st["to"]) > 0.5:
		var ahead := hero.pos + (Vector2(st["to"]) - hero.pos).normalized() * 2.0
		for dr in doors:
			if not dr["open"] and not dr["shut"] and Rect2(dr["rect"]).grow(_radius(hero)).has_point(ahead):
				dr["open"] = true
				hero.cur["steps"].insert(int(hero.cur["b"]) + 1, st.duplicate())
				_build()
				break
	if knight != null and knight.alive() and boss_area.has_area() and boss_area.grow(-_radius(hero)).has_point(hero.pos):
		for dr in doors:
			if dr["boss"] and not dr["shut"]:
				dr["open"] = false
				dr["shut"] = true
				_build()


## The squares (solid) and the ways round (paths), after a door changes.
func _build() -> void:
	var f := float(Acts.FOG)
	solid.resize(fog_size.x * fog_size.y)
	for y in fog_size.y:
		for x in fog_size.x:
			var c := area.position + Vector2((x + 0.5) * f, (y + 0.5) * f)
			var t := OPEN
			if not on_floor(c):
				t = WALL
			else:
				for pl in pillars:
					if Rect2(pl).has_point(c):
						t = PILLAR
				for lw in low_walls:
					if Rect2(lw).has_point(c):
						t = LOW
				for sh in shrubs:
					if Rect2(sh).has_point(c):
						t = SHRUB
				for dr in doors:
					if not dr["open"] and Rect2(dr["rect"]).has_point(c):
						t = DOOR
			solid[y * fog_size.x + x] = t
	touches.resize(solid.size())
	for y in fog_size.y:
		for x in fog_size.x:
			var bits := 0
			for b in 4:
				var q: Vector2i = Vector2i(x, y) + SIDES[b]
				if q.x >= 0 and q.y >= 0 and q.x < fog_size.x and q.y < fog_size.y and (CROUCH_SIGHT_STOPS >> solid[q.y * fog_size.x + q.x]) & 1:
					bits |= 1 << b
			touches[y * fog_size.x + x] = bits
	_fixed_light()
	paths = AStarGrid2D.new()
	paths.region = Rect2i(Vector2i.ZERO, fog_size)
	paths.cell_size = Vector2(f, f)
	paths.offset = area.position + Vector2(f, f) / 2.0
	paths.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	paths.update()
	# Room to spare: no square within 2 of something solid. A closed door
	# that'll open isn't (the hero's way goes through it; an enemy's stops).
	for y in fog_size.y:
		for x in fog_size.x:
			var t := solid[y * fog_size.x + x]
			if t == OPEN or t == SHRUB or (t == DOOR and not _door_at(x, y).get("shut", true)):
				continue
			var edge := t != WALL
			for e in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + e
				if paths.is_in_boundsv(q) and solid[q.y * fog_size.x + q.x] != WALL:
					edge = true
			if edge:
				paths.fill_solid_region(Rect2i(x - 2, y - 2, 5, 5).intersection(paths.region))
			else:
				paths.set_point_solid(Vector2i(x, y))


## The door at square (x, y) ({} if none).
func _door_at(x: int, y: int) -> Dictionary:
	var c := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * float(Acts.FOG)
	for dr in doors:
		if Rect2(dr["rect"]).has_point(c):
			return dr
	return {}


## The square p is in.
func square(p: Vector2) -> Vector2i:
	var q := ((p - area.position) / float(Acts.FOG)).floor()
	return Vector2i(clampi(int(q.x), 0, fog_size.x - 1), clampi(int(q.y), 0, fog_size.y - 1))


## Whether u's body can go straight from a to b (nothing solid in the way
## of its middle or its sides, with a little to spare).
func clear(u: Unit, a: Vector2, b: Vector2) -> bool:
	var side := (b - a).orthogonal().normalized() * (_radius(u) + 2.0)
	return los(a, b, WALK_STOPS) and los(a + side, b + side, WALK_STOPS) and los(a - side, b - side, WALK_STOPS)


## The way u goes to p: corner points ending at p ([] = there's none). A
## straight line if it's clear; else round, through squares with room
## to spare, cut short wherever a straight line will do.
func route(u: Unit, p: Vector2) -> Array:
	if clear(u, u.pos, p):
		return [p]
	var from := _free(square(u.pos))
	var to := _free(square(p))
	if from == Vector2i(-1, -1) or to == Vector2i(-1, -1):
		return []
	var ids := paths.get_id_path(from, to, true)
	if ids.is_empty():
		return []
	var pts: Array = []
	for id in ids:
		pts.append(paths.get_point_position(id))
	pts.append(p)
	var out: Array = []
	var at := u.pos
	var i := 0
	while i < pts.size():
		var j := i
		while j + 1 < pts.size() and clear(u, at, pts[j + 1]):
			j += 1
		at = pts[j]
		out.append(at)
		i = j + 1
	return out


## The nearest square to c that a body can stand in (-1, -1: none near).
func _free(c: Vector2i) -> Vector2i:
	for r in 4:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				var q := Vector2i(x, y)
				if paths.is_in_boundsv(q) and not paths.is_point_solid(q):
					return q
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- sight

## Whether a straight line from a to b is clear of what `stops` (bits of
## the kinds of square; the squares it goes through, but a's own, and any
## in the Rect2s `skip`).
func los(a: Vector2, b: Vector2, stops := SIGHT_STOPS, skip := []) -> bool:
	var n := ceili(a.distance_to(b) / 2.0)
	var sa := square(a)
	for i in range(1, n + 1):
		var pt := a.lerp(b, float(i) / n)
		var q := square(pt)
		if q != sa and (stops >> solid[q.y * fog_size.x + q.x]) & 1 and not skip.any(func(r): return Rect2(r).has_point(pt)):
			return false
	return true


## SOUND: how loud the hero is (what he holds added up; halved crouching).
func noise() -> float:
	var n := 0.0
	var counted := []
	for h in ["left", "right"]:
		var k := held(owner(h))
		if not k in counted:
			counted.append(k)
			n += float(Acts.ITEMS[k].get("noise", 0))
	return n / 2.0 if hero.crouch else n


## How noise n sounds d px away: "loud", "medium", "low" or "" (not heard).
static func heard(n: float, d: float) -> String:
	if d > n:
		return ""
	if d > n - Acts.NOISE_BAND:
		return "low"
	if d > n - 2.0 * Acts.NOISE_BAND:
		return "medium"
	return "loud"


## Enemy u hearing the hero make noise n: low, it turns to him; medium, it
## walks over to look; loud, it goes over at its full walk. Not through
## walls or closed doors.
func _hear(u: Unit, n: float) -> void:
	var how := heard(n, u.pos.distance_to(hero.pos))
	if how == "" or not los(u.pos, hero.pos, SOUND_STOPS):
		return
	u.heard = hero.pos
	u.looking = 0
	if how != "low":
		u.inspect = true
	if how == "loud":
		u.rush = true
	if String(u.cur.get("k", "")) in ["wait", "walk"]:
		u.cur = {}  # it turns now


## Enemy u notices the hero (spotted, or hit) and yells: every enemy within
## Acts.YELL of it that hears it notices him too.
func _alarm(u: Unit) -> void:
	if u.aware:
		return
	u.aware = true
	for f in foes:
		if f != u and f.alive() and not f.aware and f.pos.distance_to(u.pos) <= Acts.YELL and los(u.pos, f.pos, SOUND_STOPS):
			f.aware = true


## HIDDEN: the hero is hidden from an enemy that hasn't spotted him yet.
func hidden_from(u: Unit) -> bool:
	return u.side == "enemy" and u.alive() and not u.aware


## Whether enemy u spots the hero: within aggro range, in the cone ahead
## of it (or, not crouching, near it), and it can see him.
func spots(u: Unit) -> bool:
	var v := hero.pos - u.pos
	var near := v.length() <= Acts.NEAR_SENSE and not hero.crouch
	if v.length() > minf(Acts.AGGRO, seen_within(hero.pos, INF)) or (not near and rad_to_deg(absf(angle_difference(u.ang, v.angle()))) > Acts.CONE / 2.0):
		return false
	return sees_body(u, hero)


## FROM BEHIND: whether the hero is behind enemy v.
func from_behind(v: Unit) -> bool:
	return rad_to_deg(absf(angle_difference(v.ang, (hero.pos - v.pos).angle()))) >= 180.0 - float(Acts.FROM_BEHIND["behind"])


## How much the hero's melee hit on v does: more FROM BEHIND, more again if
## it hadn't noticed him.
func hit_times(v: Unit) -> float:
	if v.side != "enemy" or not from_behind(v):
		return 1.0
	return 1.0 + float(Acts.FROM_BEHIND["bonus"]) + (0.0 if v.aware else float(Acts.FROM_BEHIND["sneak"]))


## BACKSTAB: the enemy the hero could do one on now (null = none): near,
## humanoid, he's behind it and it hasn't noticed him.
func backstab_target() -> Unit:
	if hero == null:
		return null
	for v in foes:
		var f := foe_data(v)
		if v.alive() and not v.aware and f.get("humanoid", false) and not f.get("no backstab", false) \
				and hero.pos.distance_to(v.pos) <= float(Acts.BACKSTAB["reach"]) and from_behind(v):
			return v
	return null


## Whether the hero can see enemy u now.
func sees(u: Unit) -> bool:
	return can_see(u.pos) and hero.pos.distance_to(u.pos) <= seen_within(u.pos, INF) and sees_body(hero, u)


## Whether a can see b: nothing in the way that hides (walls, pillars,
## closed doors; shrubs and low walls too if a's crouching); b not in a
## shrub, unless a's in it too or touching it; b, low, not just past a
## shrub or low wall between them. From in a shrub, only so far.
func sees_body(a: Unit, b: Unit) -> bool:
	var mine := shrub_at(a.pos)
	if mine.has_area() and a.pos.distance_to(b.pos) > Acts.SHRUB_SIGHT:
		return false
	var skip := [mine] if mine.has_area() else []
	var theirs := shrub_at(b.pos)
	if theirs.has_area() and theirs != mine:
		if not theirs.grow(_radius(a) + 1.0).has_point(a.pos):
			return false
		skip.append(theirs)
	if is_low(b):
		for r in low_walls + shrubs:
			if r != mine and r != theirs and _gap(r, b) <= Acts.LOW_SHADOW and _crosses(a.pos, b.pos, r):
				return false
	return los(a.pos, b.pos, CROUCH_SIGHT_STOPS if a.crouch else SIGHT_STOPS, skip)


## Whether u is low: crouching, or one that always is (a dog, a rat).
func is_low(u: Unit) -> bool:
	return u.crouch or (u.side == "enemy" and foe_data(u).get("low", false))


## Where the hero last saw each enemy: kept once it's out of sight, until
## it's seen again, dies, or he sees the spot and it isn't there.
func _sketches() -> void:
	for f in foes:
		if not f.alive():
			f.sketch = {}
		elif sees(f):
			f.sketch = {"pos": f.pos, "ang": f.ang, "pose": f.pose}
		elif not f.sketch.is_empty() and can_see(f.sketch["pos"]) and f.pos.distance_to(f.sketch["pos"]) > 8.0:
			f.sketch = {}


## Px from u's body to r.
static func _gap(r: Rect2, u: Unit) -> float:
	var c := u.pos.clamp(r.position, r.end)
	return maxf(u.pos.distance_to(c) - _radius(u), 0.0)


## The shrub p is in (an empty Rect2 if none).
func shrub_at(p: Vector2) -> Rect2:
	for sh in shrubs:
		if Rect2(sh).has_point(p):
			return sh
	return Rect2()


## Whether a straight line from a to b goes through r.
static func _crosses(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var n := ceili(a.distance_to(b))
	for i in n + 1:
		if r.has_point(a.lerp(b, float(i) / maxi(n, 1))):
			return true
	return false


## LIGHT: how lit p is: 0 dark, 1 dim, 2 lit.
func light_at(p: Vector2) -> int:
	var q := square(p)
	return light[q.y * fog_size.x + q.x]


## How far someone at p can be seen from (as far as `sight` if lit).
func seen_within(p: Vector2, sight: float) -> float:
	return [Acts.DARK_SIGHT, Acts.DIM_SIGHT, sight][light_at(p)]


## The light from the sun (or none) and the lights that stay put, after a
## door changes.
func _fixed_light() -> void:
	var n := fog_size.x * fog_size.y
	fixed_light.resize(n)
	var sun: Dictionary = Acts.SUNS.get(map.get("sun", ""), {})
	if sun.is_empty():
		fixed_light.fill(0 if map.get("dark", false) else 2)
	else:
		fixed_light.fill(2)
		var to := Vector2.from_angle(deg_to_rad(float(sun["from"])))
		var far := float(sun["len"])
		if far > 0.0:
			for y in fog_size.y:
				for x in fog_size.x:
					var c := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * Acts.FOG
					var i := y * fog_size.x + x
					if (SIGHT_STOPS >> solid[i]) & 1:
						continue
					var t := float(Acts.FOG)
					while t <= far:
						var q := square(c + to * t)
						if (SIGHT_STOPS >> solid[q.y * fog_size.x + q.x]) & 1:
							fixed_light[i] = 1
							break
						t += Acts.FOG
	for l in lights:
		_shine(fixed_light, l["at"], Acts.LIGHTS[l["k"]])


## Light now: the fixed light and every enemy's lantern (only near the
## hero, where it can matter: LANTERNS_NEAR px).
func _light() -> void:
	if fixed_light.size() != fog_size.x * fog_size.y:
		_fixed_light()
	light = fixed_light.duplicate()
	for f in foes:
		if f.alive() and f.pos.distance_to(hero.pos) <= LANTERNS_NEAR:
			_shine(light, f.pos, Acts.LIGHTS["lantern"])


## Adds a light at p to `into`: lit near, dim further, not past what
## throws a shadow (which is lit itself on the side facing it).
func _shine(into: PackedByteArray, p: Vector2, l: Dictionary) -> void:
	var dim := float(l["dim"])
	var a := square(p - Vector2(dim, dim))
	var b := square(p + Vector2(dim, dim))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var c := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * Acts.FOG
			var d := c.distance_to(p)
			var i := y * fog_size.x + x
			var v := 2 if d <= float(l["lit"]) else 1
			if d > dim or into[i] >= v:
				continue
			var to := c
			if (SIGHT_STOPS >> solid[i]) & 1:
				to = c + (p - c).normalized() * Acts.FOG
			if square(to) == square(p) or los(p, to):
				into[i] = v


## Whether the hero can see p now.
func can_see(p: Vector2) -> bool:
	var q := square(p)
	return sight[q.y * fog_size.x + q.x] == 1


## The squares the hero sees now (a line from him to every edge square,
## up to the first one sight stops at, which is seen too, as is anything
## sight stops at next to a square seen; a shrub seen is seen whole); from
## in a shrub, only so far (and out through it); crouching, not past shrubs
## and low walls; no further than LOOK_FAR. They're remembered.
func _look() -> void:
	var n := fog_size.x * fog_size.y
	sight.resize(n)
	sight.fill(0)
	var seen: PackedByteArray = memory[room_i]
	var h := square(hero.pos)
	var mine := shrub_at(hero.pos)
	var far := Acts.SHRUB_SIGHT / Acts.FOG if mine.has_area() else INF
	var stops := CROUCH_SIGHT_STOPS if hero.crouch else SIGHT_STOPS
	# Only as far as the view could show (it never leaves the hero).
	var k := ceili(LOOK_FAR / Acts.FOG)
	var lo := Vector2i(maxi(h.x - k, 0), maxi(h.y - k, 0))
	var hi := Vector2i(mini(h.x + k, fog_size.x - 1), mini(h.y + k, fog_size.y - 1))
	var ends: Array = []
	for x in range(lo.x, hi.x + 1):
		ends.append(Vector2i(x, lo.y))
		ends.append(Vector2i(x, hi.y))
	for y in range(lo.y, hi.y + 1):
		ends.append(Vector2i(lo.x, y))
		ends.append(Vector2i(hi.x, y))
	for e in ends:
		# A line of squares (Bresenham) from h to e.
		var x := h.x
		var y := h.y
		var dx := absi(e.x - h.x)
		var dy := -absi(e.y - h.y)
		var sx := 1 if e.x > h.x else -1
		var sy := 1 if e.y > h.y else -1
		var err := dx + dy
		while true:
			var i := y * fog_size.x + x
			if Vector2(x - h.x, y - h.y).length() > far:
				break
			sight[i] = 1
			seen[i] = 1
			var c := area.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * Acts.FOG
			if (stops >> solid[i]) & 1 and Vector2i(x, y) != h and not mine.has_point(c):
				break
			if touches[i] != 0:
				for b in 4:
					if touches[i] & (1 << b):
						var j: int = i + SIDES[b].x + SIDES[b].y * fog_size.x
						sight[j] = 1
						seen[j] = 1
			if x == e.x and y == e.y:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x += sx
			if e2 <= dx:
				err += dx
				y += sy
	for sh in shrubs:
		var r: Rect2 = sh
		var a := square(r.position)
		var b := square(r.end - Vector2.ONE)
		var cells: Array = []
		var any := false
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				var i := y * fog_size.x + x
				if solid[i] == SHRUB:
					cells.append(i)
					any = any or sight[i] == 1
		if any:
			for i in cells:
				sight[i] = 1
				seen[i] = 1
	memory[room_i] = seen


## Square (x, y): 2 seen now, 1 seen before, 0 never.
func fog_at(x: int, y: int) -> int:
	var i := y * fog_size.x + x
	if sight[i] == 1:
		return 2
	return 1 if memory[room_i][i] == 1 else 0


static func _radius(u: Unit) -> float:
	return float(u.data()["body"][0][1])


## The knight is the big one: a hero he walks or lunges into is pushed out
## of the way (and slides along the arena's edge).
func _keep_apart() -> void:
	if knight == null or not knight.alive():
		return
	var v := hero.pos - knight.pos
	var over := _radius(hero) + _radius(knight) - v.length()
	if over <= 0.0:
		return
	var way := v.normalized() if v.length() > 0.01 else Vector2.from_angle(knight.ang)
	var r := _radius(hero)
	var p := hero.pos + way * over
	if fits(r, p):
		hero.pos = p
		return
	# Pinned at a wall: squeeze along it.
	for side in [way.orthogonal(), -way.orthogonal()]:
		for k in range(1, 9):
			var q: Vector2 = hero.pos + side * over * k * 0.5
			if fits(r, q) and q.distance_to(knight.pos) >= r + _radius(knight) - 0.01:
				hero.pos = q
				return


## Enemy v held still (staggered) for n steps from now.
func _hold(v: Unit, n: int) -> void:
	var steps := []
	for i in n:
		steps.append({"ph": "stagger"})
	v.cur = _act("stagger", steps)


func _hurt(v: Unit, by: Unit, d: int) -> void:
	v.hp -= d
	v.flash = 1.0
	_number(v.pos + Vector2(0, -12), str(d), Pal.DANGER if v == hero else Pal.INK)
	_sparks(v.pos, 6, Pal.DANGER if v == hero else Pal.INK)
	shake_amt = maxf(shake_amt, 2.0 if v == hero else 1.0)
	if v != hero and v.alive():
		_alarm(v)
		v.calm = 0
		v.taken += d
		if v.taken >= int(foe_data(v)["poise"]):
			stagger(v)
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

## v's block, if it's up ({} = none).
func guarding(v: Unit) -> Dictionary:
	if v != hero or not guard or current(v).get("safe", false):
		return {}
	return guard_spec()


## Whether v, guarding, stops a hit landing at `at` (within the block's
## arc of where v faces).
func blocks(v: Unit, at: Vector2) -> bool:
	var arc := float(guarding(v).get("block", 0.0))
	if arc <= 0.0:
		return false
	var off := absf(angle_difference(v.ang, (at - v.pos).angle()))
	return rad_to_deg(off) <= arc / 2.0


func _blocked(at: Vector2) -> void:
	_sparks(at, 5, Pal.INK)
	shake_amt = maxf(shake_amt, 1.0)


## What gets through a block: damage, but no knock back.
func _chip(v: Unit, d: int) -> void:
	v.hp -= d
	v.flash = 1.0
	_number(v.pos + Vector2(0, -12), str(d), Pal.DANGER)


## u's blade polygons (node `node`), posed `pose`, standing at p facing a.
func blade(u: Unit, pose: Dictionary, p: Vector2, a: float, node := "blade") -> Array:
	var s := float(u.data()["scale"])
	var polys := []
	for e in RigArt.geometry(art(u), Transform2D(a, Vector2(s, s), 0.0, p), {"pose": pose, "only": [node]}):
		polys.append_array(e["polys"])
	return polys


## The ground u's blade sweeps over going from pose a (at pa, facing aa) to
## pose b (at pb, facing ab): one hull for each check between.
func swept(u: Unit, a: Dictionary, pa: Vector2, aa: float, b: Dictionary, pb: Vector2, ab: float, node := "blade") -> Array:
	var out := []
	var prev := blade(u, a, pa, aa, node)
	for k in range(1, Acts.SWEEP_CHECKS + 1):
		var t := float(k) / Acts.SWEEP_CHECKS
		var now := blade(u, RigArt.blend(a, b, t), pa.lerp(pb, t), lerp_angle(aa, ab, t), node)
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
	var node := String(u.cur.get("blade", "blade"))
	var a: Dictionary = u.was["pose"]
	var prev := blade(u, a, u.was["pos"], u.was["ang"], node)
	for k in range(1, Acts.SWEEP_CHECKS + 1):
		var t := float(k) / Acts.SWEEP_CHECKS
		var now := blade(u, RigArt.blend(a, u.pose, t), Vector2(u.was["pos"]).lerp(u.pos, t), lerp_angle(u.was["ang"], u.ang, t), node)
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
			ang = float(st["face"]) if u == hero else turned(u, ang, float(st["face"]))
		if st.has("to"):
			p = st["to"]
		p += Vector2.from_angle(ang) * float(st.get("fwd", 0.0))
		var np := pose_for(u, st, act)
		var e := {"n": i - int(act["b"]) + 1, "ph": st["ph"], "pose": np, "pos": p, "ang": ang, "live": st.get("live", false),
			"swept": [], "blade": String(act.get("blade", "blade")), "shoot": st.get("shoot", "")}
		if e["live"]:
			e["swept"] = swept(u, pose, p0, a0, np, p, ang, e["blade"])
		out.append(e)
		pose = np
	return out


# ---------------------------------------------------------------- shots

## Where a shot from u starts.
func shot_from(u: Unit, ang: float, p := Vector2.INF) -> Vector2:
	return (u.pos if p == Vector2.INF else p) + Vector2.from_angle(ang) * (_radius(u) + 2.0)


## Shot k leaves u (the hero, if not said); `unload`: the crossbow's slot
## it empties.
func _shoot(k: String, unload: String, u: Unit = null) -> void:
	if u == null:
		u = hero
	shots.append({"k": k, "p": shot_from(u, u.ang), "from": shot_from(u, u.ang), "ang": u.ang,
		"left": float(Acts.SHOTS[k]["range"]), "by": u, "new": true})
	if unload != "":
		loaded[unload] = false
		hero.pose = pose_for(hero, current(hero), hero.cur)


## Every shot flies its step; one that reaches a body (not its shooter's)
## hits it and is gone. Checked SWEEP_CHECKS times along, bodies moving.
func _fly() -> void:
	var keep := []
	for s in shots:
		var sp: Dictionary = Acts.SHOTS[s["k"]]
		var a: Vector2 = s["p"]
		var b := a + Vector2.from_angle(float(s["ang"])) * minf(float(sp["speed"]), float(s["left"]))
		s["from"] = a
		s["p"] = b
		s.erase("new")
		var hit: Unit = null
		for k in range(1, Acts.SWEEP_CHECKS + 1):
			var t := float(k) / Acts.SWEEP_CHECKS
			var q := a.lerp(b, t)
			for v in units:
				if v.side == s["by"].side or not v.alive():
					continue
				var vp: Vector2 = Vector2(v.was.get("pos", v.pos)).lerp(v.pos, t)
				for c in v.body(vp, v.ang):
					if q.distance_to(c[0]) <= float(c[1]) + float(sp["r"]):
						hit = v
				if hit != null:
					break
			if hit != null:
				s["p"] = q
				break
			if not open_at(q):
				s["p"] = q
				s["left"] = 0.0
				break
		if hit != null:
			_hurt(hit, s["by"], int(sp["dmg"]))
			if sp.has("burn"):
				hit.burns[sp["burn"]] = int(Acts.BURNS[sp["burn"]]["steps"])
			gone.append(s)
			continue
		s["left"] = float(s["left"]) - a.distance_to(b)
		if float(s["left"]) > 0.01:
			keep.append(s)
		else:
			gone.append(s)
	shots = keep



## Burning and poison: their damage every step.
func _burn() -> void:
	for u in units:
		for k in u.burns.keys():
			var b: Dictionary = Acts.BURNS[k]
			u.hp -= int(b["dmg"])
			_number(u.pos + Vector2(rng.randf_range(-4, 4), -12), str(int(b["dmg"])), Color(b["col"]))
			u.burns[k] = int(u.burns[k]) - 1
			if int(u.burns[k]) <= 0:
				u.burns.erase(k)


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
