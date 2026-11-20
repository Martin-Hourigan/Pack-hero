class_name Duel
extends RefCounted
## The hero through a run of rooms (Acts.ROOMS), against the enemies in
## each (Acts.FOES: the big knight, soldiers, spearmen, archers), with no
## drawing or input so tests can run it. Walking into a room's doorway
## goes on to the next. Pillars block walking, shots and sight; the hero
## sees what a straight line from him reaches (sight), and remembers what
## he's seen (memory, kept when he dies); an enemy acts once it has seen
## him (or been hit). Time goes in steps, everyone together. Everyone is a puppet
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
## a roll; stamina comes back slower).
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
var wiggle := {}  # HUD thing -> seconds left (a stamina bar that's too low)


## The knight alone, in the old arena (the tests' room).
const KNIGHT_ROOM := {"area": Acts.ARENA, "start": Vector2(110, 92),
	"foes": [{"k": "knight", "at": Vector2(270, 92), "a": PI}]}

var rooms: Array = []  # the run (Acts.ROOMS entries)
var room_i := 0
var area := Rect2()
var pillars: Array = []  # Rect2s
var door: Array = []  # [from y, to y] in the right wall; [] = none
var memory := {}  # room_i -> PackedByteArray: the squares (Acts.FOG) seen
var sight := PackedByteArray()  # the squares seen now
var fog_size := Vector2i.ZERO  # squares across, down


## rooms: the run; it starts in room `first`. memory: what's been seen
## before (a Dictionary, kept by the caller across deaths).
func _init(seed_ := 0, gear_ := Acts.HANDS, rooms_: Array = [KNIGHT_ROOM], first := 0, memory_ := {}) -> void:
	rng.seed = seed_ if seed_ != 0 else int(Time.get_ticks_usec())
	gear = {"left": Array(gear_["left"]).duplicate(), "right": Array(gear_["right"]).duplicate()}
	_settle("right")
	hero = _add("hero", Vector2.ZERO, 0.0)
	hero.side = "hero"
	stamina = int(Acts.HERO["stamina"])
	flasks = int(Acts.HERO["flasks"])
	rooms = rooms_
	memory = memory_
	enter(first)


## The hero comes into room i: its enemies, nothing else carried over but
## him.
func enter(i: int) -> void:
	room_i = i
	var r: Dictionary = rooms[i]
	units = [hero]
	foes = []
	knight = null
	shots = []
	gone = []
	target = null
	area = r["area"]
	pillars = r.get("pillars", [])
	door = r.get("door", [])
	hero.pos = r["start"]
	hero.ang = 0.0
	hero.cur = {}
	hero.was = {}
	hero.pose = rest(hero)
	for f in r.get("foes", []):
		add_foe(String(f["k"]), f["at"], float(f.get("a", PI)))
	fog_size = Vector2i(ceili(area.size.x / Acts.FOG), ceili(area.size.y / Acts.FOG))
	if not memory.has(i):
		var m := PackedByteArray()
		m.resize(fog_size.x * fog_size.y)
		memory[i] = m
	_look()


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


## Hand h's menu: {thing: what it does}, the item's own, then TWO HANDS or
## ONE HAND, TRANSFORM and SWAP (in the hand whose slot it is).
func options(h: String) -> Dictionary:
	if not h in hands():
		return {}
	var it := item(h)
	var out: Dictionary = (it["two"] if two_handed(h) and it.has("two") else it["does"]).duplicate()
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
		if u.side != "enemy" or not u.alive() or not can_see(u.pos):
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
			if at.distance_to(u.pos) < 1.0 or not area.has_point(at):
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
	if not k in ["move", "wait"] and not s.get("keeps guard", false):
		guard = false
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
	elif d > float(f["far"]):
		_walk_to(u, d - float(f["far"]) + 1.0)
	else:
		start_attack(String(f["attacks"][0]), u)


## u walks a step toward the hero, at most `go` px (away, if negative),
## facing him.
func _walk_to(u: Unit, go: float) -> void:
	var aim := (hero.pos - u.pos).angle()
	var w := float(foe_data(u)["walk"])
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
	for u in foes:
		if not u.alive():
			continue
		u.calm += 1
		if u.calm >= int(foe_data(u)["calm"]):
			u.taken = 0
		if not u.aware and los(u.pos, hero.pos):
			u.aware = true
		if u.idle():
			if u.aware:
				_choose(u)
			else:
				u.cur = _act("wait", [{"ph": "wait"}])
		if int(u.cur.get("b", 1)) == 0 and _threat(u.cur):
			foe_starts = true
	var walking := String(hero.cur.get("k", "")) == "move"
	var resting := not String(current(hero).get("ph", "")) in ["wind", "act", "rec", "roll", "drink", "reload"]
	for u in units:
		if u.alive():
			_do(u)
	_keep_apart()
	for u in foes:
		if u.alive() and current(u).has("shoot"):
			_shoot(String(current(u)["shoot"]), "", u)
	var st_h := current(hero)
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
				_hurt(v, u, int(st["dmg"]))
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
	if walking and foe_starts and String(hero.cur.get("k", "")) == "move":
		hero.cur = {}
	_look()
	if target != null and (not target.alive() or not can_see(target.pos)):
		target = null
	if hero.hp <= 0:
		result = "lose"
	elif at_door():
		enter(room_i + 1)
	elif door.is_empty() and foes.all(func(f): return not f.alive()):
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
		u.ang = float(st["face"])
	if st.get("track", false) and u != hero:
		var aim := (hero.pos - u.pos).angle()
		var most := deg_to_rad(float(foe_data(u)["turn"]))
		u.ang += clampf(angle_difference(u.ang, aim), -most, most)
	if st.has("to"):
		_walk(u, st["to"])
	if float(st.get("fwd", 0.0)) > 0.0:
		_walk(u, u.pos + Vector2.from_angle(u.ang) * float(st["fwd"]))
	if u == hero and target != null and not st.has("clip"):
		u.ang = (target.pos - u.pos).angle()  # walking, waiting...: facing it
	u.pose = pose_for(u, st, u.cur)


## Moves u toward `to`, a pixel at a time, stopping at the arena's edge and
## at other bodies; but the knight pushes the hero aside (_keep_apart).
func _walk(u: Unit, to: Vector2) -> void:
	var from := u.pos
	var n := ceili(from.distance_to(to))
	for i in range(1, n + 1):
		var p := from.lerp(to, float(i) / n)
		if not _in_arena(u, p):
			return
		for v in units:
			if v == u or not v.alive() or (u == knight and v == hero):
				continue
			if p.distance_to(v.pos) < _radius(u) + _radius(v) and p.distance_to(v.pos) < u.pos.distance_to(v.pos):
				return
		u.pos = p


## Whether u's body fits at p: in the room, clear of the pillars.
func _in_arena(u: Unit, p: Vector2) -> bool:
	var r := float(u.data()["body"][0][1])
	if not area.grow(-r).has_point(p):
		return false
	for pl in pillars:
		if Rect2(pl).grow(r).has_point(p):
			return false
	return true


## Whether a shot at p is still in the open (in the room, not in a pillar).
func open_at(p: Vector2) -> bool:
	if not area.has_point(p):
		return false
	for pl in pillars:
		if Rect2(pl).has_point(p):
			return false
	return true


## Whether the hero is in the doorway (and there's a room after).
func at_door() -> bool:
	if door.is_empty() or not hero.alive() or room_i + 1 >= rooms.size():
		return false
	return hero.pos.x >= area.end.x - _radius(hero) - 1.5 and hero.pos.y >= float(door[0]) and hero.pos.y <= float(door[1])


# ---------------------------------------------------------------- sight

## Whether a straight line from a to b is clear of the pillars (but
## `skip`).
func los(a: Vector2, b: Vector2, skip := Rect2()) -> bool:
	for pl in pillars:
		if pl != skip and _crosses(a, b, pl):
			return false
	return true


## Whether segment a-b goes through rect r (Liang-Barsky).
static func _crosses(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for e in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var p: float = e[0]
		var q: float = e[1]
		if absf(p) < 0.000001:
			if q < 0.0:
				return false
		else:
			var t := q / p
			if p < 0.0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
			if t0 > t1:
				return false
	return true


## Whether the hero can see p now.
func can_see(p: Vector2) -> bool:
	return los(hero.pos, p)


## The squares the hero sees now; they're remembered as seen.
func _look() -> void:
	var n := fog_size.x * fog_size.y
	sight.resize(n)
	var seen: PackedByteArray = memory[room_i]
	if pillars.is_empty():
		sight.fill(1)
		seen.fill(1)
		memory[room_i] = seen
		return
	var f := float(Acts.FOG)
	for y in fog_size.y:
		for x in fog_size.x:
			var i := y * fog_size.x + x
			var c := area.position + Vector2((x + 0.5) * f, (y + 0.5) * f)
			var ok := los(hero.pos, c, _pillar_at(c))  # (a pillar's seen if what's before it is)
			sight[i] = 1 if ok else 0
			if ok:
				seen[i] = 1
	memory[room_i] = seen


## The pillar p is in (an empty Rect2 if none).
func _pillar_at(p: Vector2) -> Rect2:
	for pl in pillars:
		if Rect2(pl).has_point(p):
			return pl
	return Rect2()


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
	var box := area.grow(-_radius(hero))
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
	if v != hero and v.alive():
		v.aware = true
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
			ang = float(st["face"])
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
