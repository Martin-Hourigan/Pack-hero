extends Node2D
## Title -> the route map -> fights along it -> the last fight. You are the
## Great Skreel, no grid (Games/Pack is the hex version).
##
## Title: Space a run; S the start setup (pick the stats and aspect levels
## to start with: up/down picks a row, left/right or clicking - / + changes
## it, Enter starts the run, F goes straight into a fight with them, Esc
## back).
## Map: click a lit stop. H hunters (a fight), P prey (eat: health back),
## N nest (rest: more health back), B the last fight. After a won fight, a
## level: pick a stat (click or 1-3); every third level, then an aspect.
##
## In a fight:
## 1 MOVE, 2 LEAP, 3 ATTACK pick the tool (ATTACK opens the parts: 1 HEAD
## bite, 2 BODY hip check (and, once you have it, 1 HIP 2 CHARGE), 3 TAIL
## whip, 4 ARMS combo; Esc or right click backs out).
## CHARGE: aim it, and after its first wind-up it stops: click to aim it
## again (a little either way), or Space to keep it. The mouse aims it and left click does it; the tool stays
## picked. MOVE walks straight to the point. BITE aims anywhere in front
## (turning to it). LEAP: aim ahead to jump and slam where you land, behind
## to hop back. WHIP: the tail sweeps round the side the mouse is on and it
## turns to face back. HIP: shoves out to the side the mouse is on. ARMS:
## two swipes straight ahead, stepping forward. Space WAIT. Then beats play until the leader's action is
## done and you choose again. After the fight, Space goes on.
## Dev flags (after --): --start (skip the title), --fight (straight into a
## fight), --evolve (straight to a level-up), --big (straight to the aspect
## pick), --setup (the start setup), --aspects=blades:1,strength:2 (start
## with these), --seed=N, --pose=sword / bow (a fight with that hunter winding up).

const BEAT_T := 0.22  # s a beat takes on screen
const ACT_T := 0.5  # s a beat takes when someone's attack lands in it
## The menus: the top row, and ATTACK's parts with their moves (a part
## with one move picks it straight away).
const TOP := [["1", "move"], ["2", "leap"], ["3", "attack"], ["SPC", "wait"]]
const ATTACK := [["1", "HEAD", ["bite"]], ["2", "BODY", ["hip", "charge"]], ["3", "TAIL", ["whip"]], ["4", "ARMS", ["arms"]]]
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4]

var battle: Battle
var run: Run
var mode := "title"  # title, setup, map, evolve (after a fight), run (a fight)
## The start setup: what a run starts with, and the row picked.
var setup := {"strength": 0, "speed": 0, "defense": 0, "blades": 0, "blunt": 0}
var setup_row := 0
var flags := {}
var clock := 0.0
var tool := "move"
var menu := ""  # "" = the top row, "attack" = ATTACK's parts, "part" = a part's moves
var part := 0  # the part whose moves are open
var hover := Vector2.ZERO
var u := 1.0  # how far the beat being shown has played out (1 = still)
var beat_t := BEAT_T
var view: View
var hud: Hud
var map: MapView


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=")
		flags[kv[0]] = kv[1] if kv.size() > 1 else "1"
	view = View.new()
	view.main = self
	add_child(view)
	hud = Hud.new()
	hud.main = self
	add_child(hud)
	map = MapView.new()
	map.main = self
	add_child(map)
	var straight := ["start", "fight", "pose", "evolve", "big"].any(func(f): return flags.has(f))
	if flags.has("aspects"):
		for kv in String(flags["aspects"]).split(","):
			var p := kv.split(":")
			if setup.has(p[0]):
				setup[p[0]] = int(p[1]) if p.size() > 1 else 1
	if flags.has("setup"):
		mode = "setup"
	if straight:
		begin()
	if flags.has("fight") or flags.has("pose"):
		fight(["sword", "bow"])
	elif flags.has("evolve") or flags.has("big"):
		run.go(run.choices()[0])
		run.won(run.hp)
		if flags.has("big"):
			run.level = Acts.ASPECT_EVERY
			run.take(0)
		mode = "evolve"


## A new run: a new map.
func begin() -> void:
	run = Run.new(int(flags.get("seed", "0")))
	battle = null
	mode = "map"
	for k in setup:
		if run.stats.has(k):
			run.stats[k] = int(setup[k])
			run.level += int(setup[k])
		elif int(setup[k]) > 0:
			run.aspects[k] = int(setup[k])


## The start setup's rows, in order.
func setup_rows() -> Array:
	return setup.keys()


## Changes row i of the start setup by d.
func setup_change(i: int, d: int) -> void:
	var k: String = setup_rows()[i]
	var most := Acts.ASPECT_MAX if Acts.ASPECTS.has(k) else 20
	setup[k] = clampi(int(setup[k]) + d, 0, most)


## The row of tools to show: [[key, text, action (or ""), picked]].
func tools() -> Array:
	var out := []
	if menu == "attack":
		out.append(["ESC", "ATTACK", "", false])
		for i in ATTACK.size():
			var t: Array = ATTACK[i]
			var ms := moves(i)
			var picked: bool = tool in ms
			var s: String = t[1]
			if ms.size() > 1 and picked:
				s += " " + String(Acts.LEADER[tool]["label"])
			out.append([t[0], s, ms[0] if ms.size() == 1 else (tool if picked else ""), picked])
		return out
	if menu == "part":
		out.append(["ESC", ATTACK[part][1], "", false])
		var ms := moves(part)
		for i in ms.size():
			out.append([str(i + 1), String(Acts.LEADER[ms[i]]["label"]), ms[i], tool == ms[i]])
		return out
	var attacking := ATTACK.any(func(t): return tool in t[2])
	for t in TOP:
		if t[1] == "attack":
			var s := "ATTACK"
			if attacking:
				s += " " + String(Acts.LEADER[tool]["label"])
			out.append([t[0], s, tool if attacking else "", attacking])
		else:
			out.append([t[0], String(Acts.LEADER[t[1]]["label"]), t[1], tool == t[1]])
	return out


## Part i's moves the leader has.
func moves(i: int) -> Array:
	return ATTACK[i][2].filter(func(k): return battle == null or battle.knows(k))


func fight(party: Array) -> void:
	battle = Battle.new(run.rng.randi(), party, run.hp, run.build())
	mode = "run"
	tool = "move"
	menu = ""
	u = 1.0
	if flags.has("pose"):
		_pose(String(flags["pose"]))


## A fight's over: a level-up, or back to the map (or the run's over).
func _after_fight() -> void:
	if battle.result == "win":
		run.won(battle.leader.hp)
	else:
		run.lost()
	battle = null
	mode = "evolve" if not run.offer.is_empty() else "map"


## Picks card i; back to the map once nothing's left to pick.
func _take(i: int) -> void:
	run.take(i)
	if run.offer.is_empty():
		mode = "map"


func _map_click() -> void:
	if run.result != "":
		return
	var id := map.stop_at(get_global_mouse_position())
	if id < 0 or not id in run.choices():
		return
	var party := run.go(id)
	if run.is_fight(id):
		fight(party)


## Dev: --pose=sword / --pose=bow puts just that hunter by the leader,
## already winding up its attack, so its shape can be seen.
func _pose(k: String) -> void:
	var l := battle.leader
	for h in battle.hunters():
		if h.kind != k:
			h.hp = 0
		else:
			h.pos = l.pos + (Vector2(22, -10) if k == "sword" else Vector2(56, -24))
			battle._choose(h)
			battle.beat_n = 0


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	clock += dt
	hover = get_global_mouse_position()
	if mode == "run":
		battle.fx(dt)
		u = minf(u + dt / beat_t, 1.0)
		if u >= 1.0 and battle.result == "" and not battle.leader.idle() and not battle.reaiming():
			_beat()
	view.queue_redraw()
	hud.queue_redraw()
	map.queue_redraw()


## Plays the next beat; slower when an attack lands in it.
func _beat() -> void:
	beat_t = BEAT_T
	for x in battle.units:
		if x.alive() and String(x.next_step().get("ph", "")) == "act" and x.next_step().has("hit"):
			beat_t = ACT_T
	battle.fx_wait = beat_t * 0.5
	battle.beat()
	u = 0.0


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev.keycode)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		menu = ""
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if mode == "title":
			begin()
		elif mode == "setup":
			var at := map.setup_at(get_global_mouse_position())
			if at.x >= 0:
				setup_row = at.x
				setup_change(at.x, at.y)
		elif mode == "map":
			_map_click()
		elif mode == "evolve":
			var i := map.card_at(get_global_mouse_position())
			if i >= 0:
				_take(i)
		elif battle.result != "":
			_after_fight()
		elif battle.reaiming():
			if u >= 1.0:
				battle.reaim(get_global_mouse_position())
				_beat()
		else:
			menu = ""
			act(tool, get_global_mouse_position())


func _key(k: int) -> void:
	if mode == "title":
		if k == KEY_ENTER or k == KEY_SPACE:
			begin()
		elif k == KEY_S:
			mode = "setup"
	elif mode == "setup":
		var n := setup_rows().size()
		if k == KEY_ESCAPE:
			mode = "title"
		elif k == KEY_UP or k == KEY_W:
			setup_row = (setup_row + n - 1) % n
		elif k == KEY_DOWN or k == KEY_S:
			setup_row = (setup_row + 1) % n
		elif k == KEY_LEFT or k == KEY_A:
			setup_change(setup_row, -1)
		elif k == KEY_RIGHT or k == KEY_D:
			setup_change(setup_row, 1)
		elif k == KEY_ENTER or k == KEY_SPACE:
			begin()
		elif k == KEY_F:
			begin()
			fight(["sword", "bow"])
	elif mode == "map":
		if run.result != "" and (k == KEY_R or k == KEY_ENTER or k == KEY_SPACE):
			begin()
	elif mode == "evolve":
		var i := [KEY_1, KEY_2, KEY_3].find(k)
		if i >= 0:
			_take(i)
	elif battle.result != "":
		if k == KEY_ENTER or k == KEY_SPACE:
			_after_fight()
	elif battle.reaiming():
		if k == KEY_SPACE and u >= 1.0:
			var l := battle.leader
			battle.reaim(l.pos + Vector2.from_angle(l.ang) * 20.0)
			_beat()
	elif k == KEY_ESCAPE:
		menu = ""
	elif menu == "attack" and KEYS.find(k) in range(ATTACK.size()):
		var i := KEYS.find(k)
		var ms := moves(i)
		if ms.size() == 1:
			tool = String(ms[0])
			menu = ""
		else:
			part = i
			menu = "part"
	elif menu == "part" and KEYS.find(k) in range(moves(part).size()):
		tool = String(moves(part)[KEYS.find(k)])
		menu = ""
	elif menu == "" and k == KEY_1:
		tool = "move"
	elif menu == "" and k == KEY_2:
		tool = "leap"
	elif menu == "" and k == KEY_3:
		menu = "attack"
	elif k == KEY_SPACE:
		act("wait", battle.leader.pos)


## The leader does this, if it's free (the beat plays once the last one has
## finished showing).
func act(k: String, at: Vector2) -> bool:
	if u < 1.0:
		return false
	var ok := battle.plan(k, at)
	if ok:
		_beat()
	return ok


## What the chosen tool would be at the mouse.
func preview() -> Dictionary:
	if battle.reaiming():
		return battle.reaim_shape(hover)
	if not battle.leader.idle():
		return {}
	return battle.shape(tool, hover)
