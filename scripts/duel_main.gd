extends Node2D
## The hero against the big knight (duel.gd), and the way to the raptor
## fight kept from Pack-free (scenes/main.tscn).
##
## Title: Space the knight, R the raptor (not on the phone: its controls are
## keys). The update button checks GitHub for a newer APK.
## Gear (before the knight): two slots a hand down each side (the top one
## held first), a grid of every item (Acts.GEAR) between. Tap a slot to
## pick it, then an item to put it there. The name of what the mouse is
## over (on the phone, what was last tapped) shows under the grid. FIGHT
## or Space.
## In the fight: the view (VIEW) is a square in the middle, the camera on
## the hero (as far as the room goes); drag on it (the right mouse button
## on PC) to look around, as far as the hero being at its edge; doing
## anything puts it back. The buttons are in the columns either side: the
## left hand's on the left, the right hand's on the right.
## 1 MOVE, 2 ROLL, 5 FLASK; 3 and 4 open the left and right
## hand's menus (the item's name on the button; the menu lists what it can
## do: LIGHT, HEAVY, BLOCK, ARROW...; spells with their casts left), and
## picking one makes it the tool (RELOAD, SWAP, TWO HANDS, ONE HAND and
## TRANSFORM just do it). An item held in both hands has one wide button.
## The mouse
## aims the tool and left click does it; Space WAIT (a step). The buttons
## along the bottom do the same. The tool stays picked until another is
## Steps play until the hero's action is done
## and you choose again (a walk also stops when the knight starts an attack).
## Esc (or the phone's back) to the title. After the fight, Space or a tap.
## On a phone (or with --touch) a tap aims (the preview shows there) and a
## second tap on the same spot does it (locked on, a shot: one tap);
## LOCK: then tap (click) an enemy to lock on to it (the mouse is a reticle
## meanwhile; LOCK again stops picking); locked on, LOCK lets go.
## holding WAIT (or Space) keeps waiting, a step every HOLD_T.
## Toggles above the bottom right: LOCK (Q), 2H (E), GUARD (F); lit when
## on. BLOCK, TWO HANDS and ONE HAND aren't in the menus: they're these.
## Dev flags (after --): --duel (straight in), --seed=N, --at=x,y (the hero
## there), --knight=sweep / backhand / overhead (he starts it now),
## --foes=soldier,spearman,archer (them in the old arena instead of the
## run), --room=N (start in the map's area N, from 0),
## --steps=N (play N steps first), --tool=right:light (picked) with
## --mouse=x,y (aimed there), --touch, --blocking (GUARD on), --lock (LOCK on), --menu=right (that hand's menu open), --gear=left,right or
## left,left2,right,right2 (e.g. crossbow,staff; _ for a space; the slots
## not named keep Acts.HANDS'), --gearscreen (open the gear
## screen), --dohero=right:heavy_bolt (the hero starts it, before --steps).

const STEP_T := 0.07  # s a step takes on screen
const HOLD_T := 0.3  # s from one step to the next while WAIT is held
const STEER_T := 0.12  # s a step takes on screen while MOVE is held (one after another, no gap)
const TOOLS := [["1", "move"], ["2", "roll"], ["3", "hand:left"], ["4", "hand:right"], ["5", "flask"]]
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const TOGGLES := [["Q", "lock", "LOCK"], ["C", "crouch", "CROUCH"], ["E", "two", "2H"], ["F", "guard", "GUARD"]]
const TOGGLE_KEYS := [KEY_Q, KEY_C, KEY_E, KEY_F]
const NOT_IN_MENU := ["block", "two hands", "one hand"]  # the toggles do these
const SAME_TAP := 10.0  # px: a second tap this near the aim does it
const VIEW := Rect2(84, 0, 216, 216)  # the world's square on the screen
const DRAG := 6.0  # px a press moves before it's a drag (to look around)
## PC: the mouse further than LOOK_NEAR px from the view's middle leans
## the view that way, LOOK_LEAN px for each px further. PLACEHOLDER.
const LOOK_NEAR := 40.0
const LOOK_LEAN := 0.8

var duel: Duel
var mode := "title"  # title, gear, duel
var gear := {"left": Array(Acts.HANDS["left"]).duplicate(), "right": Array(Acts.HANDS["right"]).duplicate()}
var flags := {}
var clock := 0.0
var tool := "move"
var hover := Vector2.ZERO
var u := 1.0  # how far the step being shown has played out (1 = still)
var view: DuelView
var hud: DuelHud
var cam := Vector2.ZERO  # the world point at VIEW's top left
var pan := Vector2.ZERO  # how far you've dragged the view off the hero
var pressed_at := Vector2.INF  # a press on the view, until it's let go
var dragged := false  # that press has become a drag
var touch := false  # taps: aim, then tap again to do it
var aimed := false  # touch: a spot has been tapped
var held := ""  # the button being held down
var waited_at := 0.0  # clock when a held WAIT last waited
var step_t := STEP_T  # s the step being shown takes on screen
var look := Vector2.ZERO  # PC: how far the view leans toward the mouse
## MOVE's way of walking (tap MOVE again to choose): "to" (tap a spot:
## walk there), "hold" (held down: walk straight toward it, a step at a
## time, until let go), "step" (one step toward where you tap).
var walk := "to"
const WALKS := [["to", "WALK TO"], ["hold", "HOLD"], ["step", "1 STEP"]]
var menu := ""  # the hand whose menu is open ("left", "right")
var picking := false  # LOCK tapped: tap an enemy to lock on
var slot := "right0"  # the gear screen's slot being filled
var memory := {}  # what the hero's seen of each room (kept when he dies)

var update_state := "idle"  # idle, checking, latest, new, failed, downloading, ready, download_failed
var update_tag := ""
var update_url := ""
var update_page := ""
var update_asked := false  # the player tapped to check, so say if nothing turned up
var update_note := 0.0  # s left showing "no new version"
var http: HTTPRequest
var download: HTTPRequest


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=")
		flags[kv[0]] = kv[1] if kv.size() > 1 else "1"
	touch = OS.has_feature("mobile") or flags.has("touch")
	view = DuelView.new()
	view.main = self
	add_child(view)
	hud = DuelHud.new()
	hud.main = self
	add_child(hud)
	# an update downloaded last time has been installed (or given up on)
	if FileAccess.file_exists(Update.APK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Update.APK))
	if OS.has_feature("mobile"):
		_check_update()
	if flags.has("gear"):
		var lr := String(flags["gear"]).replace("_", " ").split(",")
		if lr.size() == 4:
			gear = {"left": [lr[0], lr[1]], "right": [lr[2], lr[3]]}
		else:
			gear["left"][0] = lr[0]
			gear["right"][0] = lr[1]
	if flags.has("gearscreen"):
		mode = "gear"
	if flags.has("duel"):
		begin()
		if flags.has("at"):
			var xy := String(flags["at"]).split(",")
			duel.hero.pos = Vector2(float(xy[0]), float(xy[1]))
		if flags.has("knight"):
			duel.knight.ang = (duel.hero.pos - duel.knight.pos).angle()
			duel.start_attack(String(flags["knight"]))
		if flags.has("dohero"):
			duel.plan(String(flags["dohero"]).replace("_", " "), duel.foes[0].pos)
		if flags.has("blocking"):
			duel.toggle_guard()
		if flags.has("crouch"):
			duel.toggle_crouch()
		if flags.has("menu"):
			menu = String(flags["menu"])
		if flags.has("lock"):
			duel.target = duel.foes[0]
		picking = flags.has("picking")
		for i in int(flags.get("steps", "0")):
			if duel.hero.idle():
				duel.hero.cur = duel.shape("wait", duel.hero.pos)
			duel.step()
		tool = String(flags.get("tool", tool)).replace("_", " ")
		menu = String(flags.get("menu", ""))


## The map: Acts.MAP, or one room of --foes' in a column on the right of
## the old arena (they've seen you).
func run_map() -> Dictionary:
	if not flags.has("foes"):
		return Acts.MAP
	var out := []
	var ks := String(flags["foes"]).split(",")
	for i in ks.size():
		out.append({"k": ks[i], "at": Vector2(280 + 30 * (i % 2), 40 + 110.0 * (i + 0.5) / ks.size()), "a": PI, "aware": true})
	return {"area": Acts.ARENA, "start": Vector2(110, 92), "foes": out}


func begin() -> void:
	duel = Duel.new(int(flags.get("seed", "0")), gear, run_map(), int(flags.get("room", "0")), memory)
	mode = "duel"
	tool = "move"
	u = 1.0
	aimed = false
	menu = ""
	picking = false
	pan = Vector2.ZERO


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	clock += dt
	update_note = maxf(0.0, update_note - dt)
	if not touch:
		hover = get_global_mouse_position()
	if flags.has("mouse"):
		var xy := String(flags["mouse"]).split(",")
		hover = Vector2(float(xy[0]), float(xy[1]))
		aimed = true
	if not touch:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if mode == "duel" and picking else Input.MOUSE_MODE_VISIBLE
	if mode == "duel":
		if ":" in tool and duel.spec(tool).is_empty():
			tool = "move"  # its item has been put away or changed
		duel.fx(dt)
		_camera(dt)
		u = minf(u + dt / step_t, 1.0)
		if u >= 1.0 and duel.result == "" and not duel.hero.idle():
			_step()
		elif held == "wait" and duel.result == "" and duel.hero.idle() and clock - waited_at >= HOLD_T:
			_wait()
		elif held == "walk" and duel.result == "" and duel.hero.idle() and u >= 1.0:
			_steer()
	view.queue_redraw()
	hud.queue_redraw()


## The camera: on the hero (where he's drawn), kept to the room (a room
## smaller than the view sits in its middle), leaning toward the mouse
## (PC), moved by `pan`, but never so far the hero's off the view.
func _camera(dt: float) -> void:
	var h := duel.hero
	var p := h.pos if h.was.is_empty() or u >= 1.0 else Vector2(h.was["pos"]).lerp(h.pos, u)
	if not touch and VIEW.has_point(hover):
		var off := hover - VIEW.get_center()
		var want_look := off.normalized() * maxf(off.length() - LOOK_NEAR, 0.0) * LOOK_LEAN if off.length() > 0.0 else Vector2.ZERO
		look = look.lerp(want_look, 1.0 - exp(-dt * 6.0))  # eased
	var a := duel.area.grow(12)
	var c := p + look - VIEW.size / 2.0
	for i in 2:
		if a.size[i] <= VIEW.size[i]:
			c[i] = a.position[i] + (a.size[i] - VIEW.size[i]) / 2.0
		else:
			c[i] = clampf(c[i], a.position[i], a.end[i] - VIEW.size[i])
	var want := (c + pan).clamp(p - VIEW.size + Vector2(8, 8), p - Vector2(8, 8))
	pan = want - c
	cam = want.round()
	var sh: float = duel.shake_amt
	view.position = VIEW.position - cam + Vector2(round(randf_range(-sh, sh)), round(randf_range(-sh, sh)))


## Screen point p in the world.
func to_world(p: Vector2) -> Vector2:
	return p - VIEW.position + cam


## Where you're aiming, in the world.
func aim() -> Vector2:
	return to_world(hover)


func _step() -> void:
	duel.step()
	u = 0.0
	if held == "walk" and duel.foe_started:
		held = ""  # an enemy's attack: steering stops until pressed again
		pressed_at = Vector2.INF


## What the tool does: MOVE walking a step at a time is "steer".
func tool_k() -> String:
	return "steer" if tool == "move" and walk != "to" else tool


## The name of MOVE's way of walking.
func walk_name() -> String:
	for w in WALKS:
		if w[0] == walk:
			return w[1]
	return ""


## A held MOVE: a step straight toward where it's held.
func _steer() -> void:
	if act("steer", aim()):
		step_t = STEER_T


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "title":
			get_tree().quit()
		else:
			_to_title()


func _to_title() -> void:
	mode = "title"
	duel = null
	held = ""
	menu = ""
	picking = false


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		_key(ev.keycode, ev.echo)
	elif ev is InputEventKey and ev.keycode == KEY_SPACE and held == "wait":
		held = ""
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press(get_global_mouse_position())
		else:
			var steered := held == "walk"
			held = ""
			if pressed_at != Vector2.INF and not dragged and not steered and mode == "duel" and duel != null:
				_tap_view(get_global_mouse_position())  # (on the phone a tap is done when let go)
			pressed_at = Vector2.INF
	elif ev is InputEventMouseMotion and mode == "duel":
		if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			pan -= ev.relative  # PC: the right button drags the view
		elif pressed_at != Vector2.INF and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var p := get_global_mouse_position()
			if held == "walk":
				hover = p  # steering: the hero walks toward it
				return
			if p.distance_to(pressed_at) > DRAG:
				dragged = true
			if dragged:
				if aimed:
					hover = p  # dragging moves the aim
				else:
					pan -= ev.relative


## Where each button is in the side columns: left MOVE, ROLL, the left
## hand; right FLASK, WAIT, the right hand.
const PLACES := {"move": Rect2(4, 28, 76, 18), "roll": Rect2(4, 50, 76, 18), "hand:left": Rect2(4, 80, 76, 22),
	"flask": Rect2(304, 28, 76, 18), "wait": Rect2(304, 50, 76, 18), "hand:right": Rect2(304, 80, 76, 22),
	"back": Rect2(4, 194, 22, 18)}


## The fight's buttons: [rect, id, label]. A hand's button is named for
## what's in it (held in both hands: only that hand's).
func buttons() -> Array:
	var out := []
	for t in TOOLS:
		var id: String = t[1]
		var label := id.to_upper()
		if id.begins_with("hand:"):
			var h := id.trim_prefix("hand:")
			if not h in duel.hands():
				continue
			label = duel.item(h)["name"]
		out.append([PLACES[id], id, label if touch else "%s %s" % [t[0], label]])
	out.append([PLACES["wait"], "wait", "WAIT" if touch else "SPC WAIT"])
	out.append([PLACES["back"], "back", "<"])
	return out


## The toggles: LOCK and CROUCH on the left, 2H and GUARD on the right:
## [rect, id, label].
const TOGGLE_PLACES := {"lock": Rect2(4, 140, 76, 16), "crouch": Rect2(4, 160, 76, 16),
	"two": Rect2(304, 140, 76, 16), "guard": Rect2(304, 160, 76, 16)}
func toggle_buttons() -> Array:
	var out := []
	for t in TOGGLES:
		out.append([TOGGLE_PLACES[t[1]], t[1], t[2] if touch else "%s %s" % [t[0], t[2]]])
	return out


## Whether toggle id is on.
func toggled(id: String) -> bool:
	match id:
		"lock":
			return duel.target != null
		"two":
			return duel.grip != "" and duel.two_handed(duel.grip)
		"guard":
			return duel.guard
		"crouch":
			return duel.hero.crouch
	return false


## Whether toggle id can do anything now.
func can_toggle(id: String) -> bool:
	match id:
		"two":
			return duel.two_tool() != ""
		"guard":
			return duel.guard or not duel.guard_spec().is_empty()
	return true


func toggle(id: String) -> void:
	match id:
		"lock":
			if duel.target != null:
				duel.target = null
			else:
				picking = not picking
		"two":
			var t := duel.two_tool()
			if t == "":
				duel.wiggle["two"] = 0.4
			else:
				act(t, duel.hero.pos)
		"guard":
			duel.toggle_guard()
		"crouch":
			duel.toggle_crouch()


## The hand whose item does tool k ("" = none).
static func hand_of(k: String) -> String:
	return k.split(":")[0] if ":" in k else ""


## The hand whose menu key n (3, 4) opens.
func _hand_key(h: String) -> String:
	return duel.hands()[0] if duel.hands().size() == 1 else h


## The open hand menu's options, down from its button's top, on the view
## beside it: [rect, id, label].
func menu_buttons() -> Array:
	if menu == "":
		return []
	if menu == "move":
		var out := []
		for i in WALKS.size():
			out.append([Rect2(VIEW.position.x + 2.0, PLACES["move"].position.y + 18 * i, 80, 16), "walk:" + WALKS[i][0], WALKS[i][1]])
		return out
	var at := Rect2()
	for b in buttons():
		if b[1] == "hand:" + menu:
			at = b[0]
	var out := []
	var does: Array = duel.options(menu).keys().filter(func(o): return not o in NOT_IN_MENU)
	var w := 80.0
	var x := VIEW.position.x + 2.0 if at.position.x < VIEW.position.x else VIEW.end.x - 2.0 - w
	for i in does.size():
		var id := menu + ":" + String(does[i])
		var label := String(does[i]).to_upper()
		if duel.casts_left(id) >= 0:
			label += " %d" % duel.casts_left(id)
		out.append([Rect2(x, at.position.y + 18 * i, w, 16), id, label])
	return out


const CELL := 32.0  # a gear screen square, px


## The gear screen's buttons: [rect, id, label]. A slot's id is
## "slot:" + its hand and number ("slot:left0"), an item's "item:" + it.
func gear_buttons() -> Array:
	var out := []
	for h in ["left", "right"]:
		for i in 2:
			var x := 36.0 if h == "left" else 316.0
			var th: String = gear[h][i]
			out.append([Rect2(x, 52 + (CELL + 4) * i, CELL, CELL), "slot:" + h + str(i), th])
	for i in Acts.GEAR.size():
		var th: String = Acts.GEAR[i]
		var x := 192.0 - 2.5 * (CELL + 2) + (CELL + 2) * (i % 5)
		out.append([Rect2(x, 52 + (CELL + 4) * (i / 5), CELL, CELL), "item:" + th, th])
	out.append([Rect2(132, 150, 120, 20), "fight", "FIGHT" if touch else "SPACE  FIGHT"])
	out.append([Rect2(358, 188, 22, 20), "back", "<"])
	return out


## The name the gear screen shows: what's under the mouse (or the last tap).
func gear_name() -> String:
	for b in gear_buttons():
		if Rect2(b[0]).has_point(hover) and (String(b[1]).begins_with("slot:") or String(b[1]).begins_with("item:")):
			return Acts.ITEMS[b[2]]["name"]
	return ""


## The title's buttons: [rect, id, label].
func title_buttons() -> Array:
	var out := [[Rect2(132, 92, 120, 20), "knight", "THE KNIGHT" if touch else "SPACE  THE KNIGHT"]]
	if not OS.has_feature("mobile"):
		out.append([Rect2(132, 118, 120, 20), "raptor", "R  THE RAPTOR"])
	out.append([Rect2(256, 190, 124, 20), "update", update_label()])
	return out


func _hit(list: Array, p: Vector2) -> String:
	for b in list:
		if Rect2(b[0]).has_point(p):
			return b[1]
	return ""


func _press(p: Vector2) -> void:
	if mode == "title":
		match _hit(title_buttons(), p):
			"update":
				_update_tap()
			"raptor":
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			"knight":
				mode = "gear"
			_:
				if not touch:
					mode = "gear"
		return
	if mode == "gear":
		if touch:
			hover = p
		var g := _hit(gear_buttons(), p)
		if g.begins_with("slot:"):
			slot = g.trim_prefix("slot:")
		elif g.begins_with("item:"):
			gear[slot.left(-1)][int(slot.right(1))] = g.trim_prefix("item:")
		match g:
			"fight":
				begin()
			"back":
				_to_title()
		return
	if duel.result != "":
		begin()
		return
	if menu != "":
		var m := _hit(menu_buttons(), p)
		var was := menu
		menu = ""
		if m.begins_with("walk:"):
			walk = m.trim_prefix("walk:")
			return
		if was == "move" and _hit(buttons(), p) == "move":
			return  # MOVE again: just closed
		if m != "":
			if duel.spec(m).has("reload") or duel.spec(m).has("change"):
				act(m, duel.hero.pos)
			else:
				tool = m
				aimed = false
			return
		if _hit(buttons(), p) == "hand:" + was:
			return  # its button again: just closed
	var tg := _hit(toggle_buttons(), p)
	if tg != "":
		toggle(tg)
		return
	var b := _hit(buttons(), p)
	if b == "" and VIEW.has_point(p):
		if tool == "move" and walk == "hold" and not picking:
			pressed_at = p  # steering until let go
			hover = p
			held = "walk"
			_steer()
		elif touch:
			pressed_at = p  # a tap, or a drag to look around
			dragged = false
		else:
			_tap_view(p)
		return
	if b.begins_with("hand:"):
		menu = b.trim_prefix("hand:")
	elif b == "back":
		_to_title()
	elif b == "wait":
		held = "wait"
		_wait()
	elif b == "flask":
		act("flask", duel.hero.pos)
	elif b == "move" and tool == "move":
		menu = "move"  # MOVE again: how to walk
	elif b != "":
		tool = b
		aimed = false


## A tap (click) on the view at screen point p: picking LOCK's enemy, or the
## tool (on the phone: the first tap aims, a second on the same spot does
## it).
func _tap_view(p: Vector2) -> void:
	if picking:
		var e := duel.enemy_at(to_world(p), 8.0 if touch else 4.0)
		if e != null:
			duel.target = e
			picking = false
		return  # (anywhere else: still picking)
	if not touch or (duel.target != null and duel.auto_aims(tool)):
		act(tool_k(), to_world(p))
	elif aimed and p.distance_to(hover) <= SAME_TAP:
		if act(tool_k(), aim()):
			aimed = false
	else:
		hover = p
		aimed = true


func _key(k: int, echo: bool) -> void:
	if mode == "title":
		if echo:
			return
		if k == KEY_SPACE or k == KEY_ENTER:
			mode = "gear"
		elif k == KEY_R:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	if mode == "gear":
		if echo:
			return
		if k == KEY_SPACE or k == KEY_ENTER:
			begin()
		elif k == KEY_ESCAPE:
			_to_title()
		return
	if k == KEY_ESCAPE and not echo:
		if menu != "":
			menu = ""
		else:
			_to_title()
		return
	if duel.result != "":
		if (k == KEY_SPACE or k == KEY_ENTER) and not echo:
			begin()
		return
	if TOGGLE_KEYS.has(k) and not echo:
		toggle(TOGGLES[TOGGLE_KEYS.find(k)][1])
	elif KEYS.has(k) and not echo:
		var t: String = TOOLS[KEYS.find(k)][1]
		if t == "flask":
			act("flask", duel.hero.pos)
		elif t.begins_with("hand:"):
			var h := _hand_key(t.trim_prefix("hand:"))
			menu = "" if menu == h else h
		elif t == "move" and tool == "move":
			menu = "" if menu == "move" else "move"
		else:
			tool = t
			menu = ""
	elif k == KEY_SPACE and not echo:
		held = "wait"  # until it's let go
		_wait()


func _wait() -> void:
	if act("wait", duel.hero.pos):
		waited_at = clock


## The hero does this, if free (once the last step has finished showing).
func act(k: String, at: Vector2) -> bool:
	if u < 1.0:
		return false
	step_t = STEP_T
	var ok := duel.plan(k, at)
	if ok:
		pan = Vector2.ZERO
		_step()
	return ok


# ---------------------------------------------------------------- updates

func _check_update() -> void:
	if http == null:
		http = HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(_on_release)
	update_state = "checking"
	if http.request(Update.API, ["User-Agent: Pack-hero", "Accept: application/vnd.github+json"]) != OK:
		update_state = "failed"


func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var rel := {}
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		rel = Update.read_release(body.get_string_from_utf8())
	if rel.is_empty():
		update_state = "failed"
		return
	update_tag = rel.tag
	update_url = rel.url
	update_page = rel.page
	update_state = "new" if Update.newer(update_tag, Update.current()) else "latest"
	if update_state == "latest" and update_asked:
		update_note = 2.0
	update_asked = false


## Download the new APK in the game, then hand it to Android's installer.
func _download_update() -> void:
	if download == null:
		download = HTTPRequest.new()
		download.use_threads = true
		download.download_file = Update.APK
		add_child(download)
		download.request_completed.connect(_on_downloaded)
	update_state = "downloading"
	if download.request(update_url, ["User-Agent: Pack-hero"]) != OK:
		update_state = "download_failed"


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(Update.APK):
		update_state = "download_failed"
		return
	update_state = "ready"
	Update.install()


func update_label() -> String:
	match update_state:
		"checking":
			return "CHECKING..."
		"latest":
			return "NO NEW VERSION" if update_note > 0.0 else "CHECK FOR UPDATES"
		"new":
			return "UPDATE TO " + update_tag
		"downloading":
			var size := download.get_body_size()
			if size > 0:
				return "DOWNLOADING %d" % (100 * download.get_downloaded_bytes() / size)
			return "DOWNLOADING..."
		"ready":
			return "INSTALL " + update_tag
		"download_failed":
			return "FAILED. RETRY"
	return "CHECK FOR UPDATES"


func _update_tap() -> void:
	match update_state:
		"new", "download_failed":
			if OS.get_name() == "Android":
				_download_update()
			else:
				OS.shell_open(update_page)
		"ready":
			Update.install()
		"checking", "downloading":
			pass
		_:
			update_asked = true
			_check_update()
