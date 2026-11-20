class_name DuelHud
extends Node2D
## What stays put on the screen: the title, the gear screen, and in the
## fight the two side columns either side of the view (main.VIEW): the
## bars, the buttons and menus, and how the fight ended.

var main = null

const STEAL := Color("#6fb7a8")  # the stamina bar


func _draw() -> void:
	if main.mode == "title":
		_title()
		return
	if main.mode == "gear":
		_gear()
		return
	var d: Duel = main.duel
	if d == null:
		return
	# The columns cover whatever of the world is past the view's sides.
	var r: Rect2 = main.VIEW
	draw_rect(Rect2(0, 0, r.position.x, 216), Pal.BG)
	draw_rect(Rect2(r.end.x, 0, 384 - r.end.x, 216), Pal.BG)
	draw_rect(Rect2(r.position.x - 1, 0, 1, 216), Pal.DARK)
	draw_rect(Rect2(r.end.x, 0, 1, 216), Pal.DARK)
	_bars(d)
	_tools(d)
	if d.result != "":
		_result(d)


## Health, stamina and flasks atop the left column; the knight's health
## (poise, burns) atop the right one when he's here.
func _bars(d: Duel) -> void:
	var h := d.hero
	var wx := _wig(d, "stamina")
	draw_rect(Rect2(4, 4, 76, 4), Pal.DARK)
	draw_rect(Rect2(4, 4, round(76.0 * maxf(h.hp, 0) / h.max_hp), 4), Pal.INK)
	draw_rect(Rect2(4 + wx, 10, 76, 2), Pal.DARK)
	draw_rect(Rect2(4 + wx, 10, round(76.0 * d.stamina / float(Acts.HERO["stamina"])), 2), STEAL)
	var fx := _wig(d, "flasks")
	for i in int(Acts.HERO["flasks"]):
		draw_rect(Rect2(4 + i * 5 + fx, 15, 3, 4), Pal.DANGER if i < d.flasks else Pal.DARK)
	var k := d.knight
	if k == null or not k.alive():
		return
	draw_rect(Rect2(304, 4, 76, 4), Pal.DARK)
	draw_rect(Rect2(304, 4, round(76.0 * maxf(k.hp, 0) / k.max_hp), 4), Pal.DIM)
	# Poise: how near he is to staggering.
	draw_rect(Rect2(304, 9, round(76.0 * minf(float(k.taken) / float(Acts.KNIGHT["poise"]), 1.0)), 1), Pal.INK.darkened(0.3))
	# Burning, poisoned: a pip each under his bar, as long as steps are left.
	var y := 12
	for b in k.burns:
		draw_rect(Rect2(380 - int(k.burns[b]) * 2, y, int(k.burns[b]) * 2, 1), Color(Acts.BURNS[b]["col"]))
		y += 2


func _wig(d: Duel, k: String) -> float:
	return round(sin(main.clock * 60.0) * 2.0) if d.wiggle.has(k) else 0.0


## The buttons down the sides (main.buttons(), main.toggle_buttons()), and
## a hand's menu when it's open. A hand's button, when its item has the
## tool, says which.
func _tools(d: Duel) -> void:
	for b in main.buttons():
		var id: String = b[1]
		var hand := id.trim_prefix("hand:") if id.begins_with("hand:") else ""
		var picked: bool = main.tool == id or (hand != "" and main.hand_of(main.tool) == hand)
		var col: Color = Pal.INK if picked or main.held == id or (hand != "" and main.menu == hand) else Pal.DIM
		if (id == "roll" and d.cost(id) > d.stamina) or (id == "flask" and d.flasks <= 0):
			col = Pal.DIM.darkened(0.45)
		var r: Rect2 = b[0]
		r.position.x += _wig(d, id)
		_button(r, b[2], col, picked, main.tool.split(":")[1].to_upper() if hand != "" and picked else "")
	for b in main.menu_buttons():
		var id: String = b[1]
		var sp := d.spec(id)
		var no: bool = d.cost(id) > d.stamina or d.casts_left(id) == 0 \
			or (sp.get("loaded", false) and not d.is_loaded(main.hand_of(id)))
		_button(b[0], b[2], Pal.DIM.darkened(0.45) if no else Pal.INK, main.tool == id)
	for b in main.toggle_buttons():
		var id: String = b[1]
		var on: bool = main.toggled(id) or (id == "lock" and main.picking and fmod(main.clock, 0.6) < 0.3)
		var col: Color = Pal.INK if on else (Pal.DIM if main.can_toggle(id) else Pal.DIM.darkened(0.45))
		var r: Rect2 = b[0]
		r.position.x += _wig(d, id)
		_button(r, b[2], col, on)
	var s := str(d.step_n)
	Pal.text(self, Vector2(380 - Pal.width(s), 204), s, Pal.DARK.lightened(0.2))


## A button; `under` is a second, dimmer line below the label.
func _button(r: Rect2, label: String, col: Color, picked := false, under := "") -> void:
	draw_rect(r, Pal.BG)
	draw_rect(r.grow(-0.5), col if picked else Pal.DARK, false)
	var y: float = round(r.size.y / 2.0) - (5.0 if under != "" else 2.0)
	Pal.text(self, r.position + Vector2(round((r.size.x - Pal.width(label)) / 2.0), y), label, col)
	if under != "":
		Pal.text(self, r.position + Vector2(round((r.size.x - Pal.width(under)) / 2.0), y + 6.0), under, Pal.DIM)


func _result(d: Duel) -> void:
	var r: Rect2 = main.VIEW
	draw_rect(Rect2(r.position.x, 80, r.size.x, 40), Color(0, 0, 0, 0.85))
	var s := "THE KNIGHT FALLS" if d.result == "win" else "YOU FALL"
	var w := Pal.width(s, 2)
	var mid := r.get_center().x
	Pal.text(self, Vector2(mid - w / 2.0, 88), s, Pal.INK if d.result == "win" else Pal.DANGER, 2)
	Pal.text(self, Vector2(mid - Pal.width("SPACE") / 2.0, 104), "SPACE", Pal.DIM)


func _gear() -> void:
	Pal.text(self, Vector2(52 - Pal.width("LEFT") / 2.0, 42), "LEFT", Pal.DIM)
	Pal.text(self, Vector2(332 - Pal.width("RIGHT") / 2.0, 42), "RIGHT", Pal.DIM)
	var sel: String = "slot:" + main.slot
	var held := String(main.slot)
	var in_slot: String = main.gear[held.left(-1)][int(held.right(1))]
	for b in main.gear_buttons():
		var id: String = b[1]
		var r: Rect2 = b[0]
		if id.begins_with("slot:") or id.begins_with("item:"):
			var on := id == sel or id == "item:" + in_slot
			var over: bool = r.has_point(main.hover)
			draw_rect(r, Pal.BG)
			draw_rect(r.grow(-0.5), Pal.INK if on else (Pal.DIM if over else Pal.DARK), false)
			_icon(String(b[2]), r)
		else:
			_button(r, b[2], Pal.INK if b[1] != "back" else Pal.DIM, b[1] == "fight")
	var name: String = main.gear_name()
	Pal.text(self, Vector2(192 - Pal.width(name) / 2.0, 130), name, Pal.INK)


## Item th drawn in r from the hero's puppet, as big as whole pixels let
## it fit; long ones (over 14 px) lie corner to corner.
func _icon(th: String, r: Rect2) -> void:
	var it: Dictionary = Acts.ITEMS[th]
	var path := String(Acts.DUEL_UNITS["hero"]["art"])
	var only := []
	for n in it["nodes"]:
		only.append(Duel.node_of(n, it, "right"))
	var pose := {}
	for n in it.get("look", {}):
		pose[n] = {"part": it["look"][n]}
	var room := r.size.x - 6.0
	var ang := 0.0
	var box := _icon_box(path, only, pose, Transform2D.IDENTITY)
	if box.size.x > 14.0:
		ang = -PI / 4.0
		box = _icon_box(path, only, pose, Transform2D(ang, Vector2.ZERO))
	var sc := clampf(floorf(room / maxf(box.size.x, box.size.y)), 1.0, 3.0)
	var t := Transform2D(ang, Vector2(sc, sc), 0.0, Vector2.ZERO)
	box = _icon_box(path, only, pose, t)
	t.origin = (r.get_center() - box.get_center()).round()
	RigArt.draw(self, path, Transform2D.IDENTITY, {"only": only, "pose": pose, "world": {"hand_r": t, "hand_l": t}})


## The box an icon's shapes cover, its hand placed by t.
func _icon_box(path: String, only: Array, pose: Dictionary, t: Transform2D) -> Rect2:
	var box := Rect2()
	var first := true
	for e in RigArt.geometry(path, Transform2D.IDENTITY, {"only": only, "pose": pose, "world": {"hand_r": t, "hand_l": t}}):
		for poly in e["polys"]:
			for q in poly:
				if first:
					box = Rect2(q, Vector2.ZERO)
					first = false
				else:
					box = box.expand(q)
	return box


func _title() -> void:
	for b in main.title_buttons():
		var col := Pal.DIM
		if b[1] == "knight" and fmod(main.clock, 1.0) >= 0.8:
			col = Pal.INK
		elif b[1] == "update" and main.update_state in ["new", "downloading", "ready", "download_failed"]:
			col = Pal.INK
		_button(b[0], b[2], col)
	Pal.text(self, Vector2(4, 203), "V" + Update.current(), Pal.DARK.lightened(0.2))


func _px(p: Vector2) -> Vector2:
	return Vector2(round(p.x), round(p.y))
