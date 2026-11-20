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
## In the duel: 1 MOVE, 2 ROLL, 5 FLASK; 3 and 4 open the left and right
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
## holding WAIT keeps waiting.
## Toggles above the bottom right: LOCK (Q), 2H (E), GUARD (F); lit when
## on. BLOCK, TWO HANDS and ONE HAND aren't in the menus: they're these.
## Dev flags (after --): --duel (straight in), --seed=N, --at=x,y (the hero
## there), --knight=sweep / backhand / overhead (he starts it now),
## --steps=N (play N steps first), --tool=right:light (picked) with
## --mouse=x,y (aimed there), --touch, --blocking (GUARD on), --lock (LOCK on), --menu=right (that hand's menu open), --gear=left,right or
## left,left2,right,right2 (e.g. crossbow,staff; _ for a space; the slots
## not named keep Acts.HANDS'), --gearscreen (open the gear
## screen), --dohero=right:heavy_bolt (the hero starts it, before --steps).

const STEP_T := 0.07  # s a step takes on screen
const TOOLS := [["1", "move"], ["2", "roll"], ["3", "hand:left"], ["4", "hand:right"], ["5", "flask"]]
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const TOGGLES := [["Q", "lock", "LOCK"], ["E", "two", "2H"], ["F", "guard", "GUARD"]]
const TOGGLE_KEYS := [KEY_Q, KEY_E, KEY_F]
const NOT_IN_MENU := ["block", "two hands", "one hand"]  # the toggles do these
const SAME_TAP := 10.0  # px: a second tap this near the aim does it

var duel: Duel
var mode := "title"  # title, gear, duel
var gear := {"left": Array(Acts.HANDS["left"]).duplicate(), "right": Array(Acts.HANDS["right"]).duplicate()}
var flags := {}
var clock := 0.0
var tool := "move"
var hover := Vector2.ZERO
var u := 1.0  # how far the step being shown has played out (1 = still)
var view: DuelView
var touch := false  # taps: aim, then tap again to do it
var aimed := false  # touch: a spot has been tapped
var held := ""  # the button being held down
var menu := ""  # the hand whose menu is open ("left", "right")
var picking := false  # LOCK tapped: tap an enemy to lock on
var slot := "right0"  # the gear screen's slot being filled

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
			duel.plan(String(flags["dohero"]).replace("_", " "), duel.knight.pos)
		if flags.has("blocking"):
			duel.toggle_guard()
		if flags.has("lock"):
			duel.target = duel.knight
		picking = flags.has("picking")
		for i in int(flags.get("steps", "0")):
			if duel.hero.idle():
				duel.hero.cur = duel.shape("wait", duel.hero.pos)
			duel.step()
		tool = String(flags.get("tool", tool)).replace("_", " ")
		menu = String(flags.get("menu", ""))


func begin() -> void:
	duel = Duel.new(int(flags.get("seed", "0")), gear)
	mode = "duel"
	tool = "move"
	u = 1.0
	aimed = false
	menu = ""
	picking = false


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
		u = minf(u + dt / STEP_T, 1.0)
		if u >= 1.0 and duel.result == "" and not duel.hero.idle():
			_step()
		elif held == "wait" and duel.result == "" and duel.hero.idle():
			act("wait", duel.hero.pos)
	view.queue_redraw()


func _step() -> void:
	duel.step()
	u = 0.0


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
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press(get_global_mouse_position())
		else:
			held = ""
	elif ev is InputEventMouseMotion and touch and aimed and held == "" and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
		hover = get_global_mouse_position()  # dragging moves the aim


## The buttons along the bottom of the duel: [rect, id, label]. A hand's
## button is named for what's in it.
func buttons() -> Array:
	var out := []
	var x := 4.0
	for t in TOOLS:
		var id: String = t[1]
		var w := 72.0 if id.begins_with("hand:") else 40.0
		var label := id.to_upper()
		if id.begins_with("hand:"):
			var h := id.trim_prefix("hand:")
			if duel.hands().size() == 1:
				if h != duel.hands()[0]:
					continue  # one wide button
				w = 148.0
			label = duel.item(h)["name"]
		out.append([Rect2(x, 188, w, 20), id, label if touch else "%s %s" % [t[0], label]])
		x += w + 4
	out.append([Rect2(x, 188, 40, 20), "wait", "WAIT" if touch else "SPC WAIT"])
	out.append([Rect2(358, 188, 22, 20), "back", "<"])
	return out


## The toggles, above the bottom right: [rect, id, label].
func toggle_buttons() -> Array:
	var out := []
	for i in TOGGLES.size():
		var t: Array = TOGGLES[i]
		out.append([Rect2(254 + 42 * i, 168, 40, 16), t[1], t[2] if touch else "%s %s" % [t[0], t[2]]])
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


## The hand whose item does tool k ("" = none).
static func hand_of(k: String) -> String:
	return k.split(":")[0] if ":" in k else ""


## The hand whose menu key n (3, 4) opens.
func _hand_key(h: String) -> String:
	return duel.hands()[0] if duel.hands().size() == 1 else h


## The open hand menu's options, stacked above its button: [rect, id, label].
func menu_buttons() -> Array:
	if menu == "":
		return []
	var at := Rect2()
	for b in buttons():
		if b[1] == "hand:" + menu:
			at = b[0]
	var out := []
	var does: Array = duel.options(menu).keys().filter(func(o): return not o in NOT_IN_MENU)
	var w := minf(at.size.x, 80.0)
	for i in does.size():
		var id := menu + ":" + String(does[i])
		var label := String(does[i]).to_upper()
		if duel.casts_left(id) >= 0:
			label += " %d" % duel.casts_left(id)
		out.append([Rect2(at.position.x, at.position.y - 18 * (does.size() - i), w, 16), id, label])
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
		var x := 192.0 - 2.0 * (CELL + 2) + (CELL + 2) * (i % 4)
		out.append([Rect2(x, 52 + (CELL + 4) * (i / 4), CELL, CELL), "item:" + th, th])
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
	if picking and _hit(buttons(), p) == "":
		var e := duel.enemy_at(p, 8.0 if touch else 4.0)
		if e != null:
			duel.target = e
			picking = false
		return  # (anywhere else: still picking)
	var b := _hit(buttons(), p)
	if b.begins_with("hand:"):
		menu = b.trim_prefix("hand:")
	elif b == "back":
		_to_title()
	elif b == "wait":
		held = "wait"
		act("wait", duel.hero.pos)
	elif b == "flask":
		act("flask", duel.hero.pos)
	elif b != "":
		tool = b
		aimed = false
	elif not touch or (duel.target != null and duel.auto_aims(tool)):
		act(tool, p)
	elif aimed and p.distance_to(hover) <= SAME_TAP:
		if act(tool, hover):
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
		else:
			tool = t
			menu = ""
	elif k == KEY_SPACE:
		act("wait", duel.hero.pos)  # held: keeps waiting


## The hero does this, if free (once the last step has finished showing).
func act(k: String, at: Vector2) -> bool:
	if u < 1.0:
		return false
	var ok := duel.plan(k, at)
	if ok:
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
