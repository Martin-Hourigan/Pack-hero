class_name DuelView
extends Node2D
## Draws the duel: the arena, the knight's coming swing (a ghost of the
## blade at each step still to come, the ground its hitting steps sweep
## over, and the steps left on each), what the hero's tool would do at the
## mouse, the puppets (posed part way through the step being shown,
## main.u 0..1), then sparks, numbers and the bars.

var main = null

const STEAL := Color("#6fb7a8")  # the stamina bar


func _draw() -> void:
	if main.mode == "title":
		_title()
		return
	var d: Duel = main.duel
	if d == null:
		return
	var sh: float = d.shake_amt
	position = Vector2(round(randf_range(-sh, sh)), round(randf_range(-sh, sh)))
	_arena()
	_ghosts(d)
	_preview(d)
	var order: Array = d.units.filter(func(u): return u.alive())
	order.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for u in order:
		_unit(d, u)
	for s in d.sparks:
		draw_rect(Rect2(_px(s["p"]), Vector2.ONE * (2.0 if s["life"] / s["max"] > 0.5 else 1.0)), s["col"])
	for n in d.numbers:
		Pal.text(self, _px(n["p"]) - Vector2(Pal.width(n["s"]) / 2.0, 0), n["s"], n["col"])
	_bars(d)
	_tools(d)
	if d.result != "":
		_result(d)


func _arena() -> void:
	var a := Acts.ARENA
	draw_rect(Rect2(a.position - Vector2.ONE, a.size + Vector2(2, 2)), Pal.DARK, false)
	for x in range(int(a.position.x) + 8, int(a.end.x), 16):
		for y in range(int(a.position.y) + 8, int(a.end.y), 16):
			draw_rect(Rect2(x + ((y / 16) % 2) * 8, y, 1, 1), Pal.DARK)


## The knight's swing still to come: the ground each hitting step sweeps
## (the next one brightest), the blade where each step leaves it, and on
## each hitting step the steps left.
func _ghosts(d: Duel) -> void:
	var k := d.knight
	if k.idle() or String(k.cur["k"]) == "walk" or main.u < 1.0:
		return
	var tr := d.trace(k)
	var first := -1
	for e in tr:
		if e["live"]:
			if first < 0:
				first = int(e["n"])
			var col := Pal.DANGER_DIM if int(e["n"]) == first else Pal.DANGER_DIM.darkened(0.45)
			for h in e["swept"]:
				if h.size() >= 3:
					draw_colored_polygon(h, col)
	for e in tr:
		var col := Pal.DARK
		if e["live"]:
			col = Pal.DANGER if int(e["n"]) == first else Pal.DANGER.darkened(0.35)
		for poly in d.blade(k, e["pose"], e["pos"], e["ang"]):
			_outline(poly, col)
	var labels := []
	for e in tr:
		if not e["live"]:
			continue
		var polys := d.blade(k, e["pose"], e["pos"], e["ang"])
		if polys.is_empty():
			continue
		var tip := _far(polys[0], e["pos"])
		if labels.any(func(q): return q.distance_to(tip) < 6.0):
			continue  # a step whose blade ends where an earlier one does: that one's number shows
		labels.append(tip)
		var s := str(e["n"])
		var at := _px(tip + (tip - Vector2(e["pos"])).normalized() * 5.0) - Vector2(Pal.width(s) / 2.0 - 0.5, 2)
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(Pal.width(s) + 1, 7)), Pal.BG)
		Pal.text(self, at, s, Pal.INK if int(e["n"]) == first else Pal.DIM)


## What the picked tool would do where the mouse is.
func _preview(d: Duel) -> void:
	var h := d.hero
	if not h.idle() or main.u < 1.0 or d.result != "" or (main.touch and not main.aimed):
		return
	var a: Dictionary = d.shape(main.tool, main.hover)
	if a.is_empty():
		return
	if main.tool == "block":
		# The front it guards.
		var aim := float(a["steps"][0]["face"])
		var half := deg_to_rad(float(Acts.HERO["block"]["arc"])) / 2.0
		draw_arc(_px(h.pos), Duel._radius(h) + 4.0, aim - half, aim + half, 16, Pal.INK.darkened(0.3))
		return
	var tr := d.trace(h, a)
	if tr.is_empty():
		return
	var dim := Pal.INK.darkened(0.8)
	for e in tr:
		for poly in e["swept"]:
			if poly.size() >= 3:
				draw_colored_polygon(poly, dim)
	for e in tr:
		if e["live"]:
			for poly in d.blade(h, e["pose"], e["pos"], e["ang"]):
				_outline(poly, Pal.INK.darkened(0.45))
	var end: Vector2 = tr[tr.size() - 1]["pos"]
	if end.distance_to(h.pos) > 1.0:
		_dots(h.pos, end, Pal.INK.darkened(0.4))
		_ring(end, Duel._radius(h), Pal.INK.darkened(0.3))
	if main.tool == "roll":
		# Where the roll is safe from hits.
		for e in tr:
			if d.shape("roll", main.hover)["steps"][int(e["n"]) - 1].get("safe", false):
				_ring(e["pos"], Duel._radius(h), Pal.INK.darkened(0.6))


func _unit(d: Duel, u: Unit) -> void:
	var t: float = main.u
	var was: Dictionary = u.was
	var p := u.pos
	var a := u.ang
	var pose := u.pose
	if not was.is_empty() and t < 1.0:
		p = Vector2(was["pos"]).lerp(u.pos, t)
		a = lerp_angle(float(was["ang"]), u.ang, t)
		pose = RigArt.blend(was["pose"], u.pose, t)
	var s := float(u.data()["scale"])
	var o := {"pose": pose}
	if u.flash >= 0.5:
		o["all"] = Color.WHITE
	RigArt.draw(self, d.art(u), Transform2D(a, Vector2(s, s), 0.0, _px(p)), o)


## Health (and stamina, flasks) along the top.
func _bars(d: Duel) -> void:
	var h := d.hero
	var wx := _wig(d, "stamina")
	draw_rect(Rect2(4, 3, 100, 4), Pal.DARK)
	draw_rect(Rect2(4, 3, round(100.0 * maxf(h.hp, 0) / h.max_hp), 4), Pal.INK)
	draw_rect(Rect2(4 + wx, 9, 100, 2), Pal.DARK)
	draw_rect(Rect2(4 + wx, 9, round(100.0 * d.stamina / float(Acts.HERO["stamina"])), 2), STEAL)
	var fx := _wig(d, "flasks")
	for i in int(Acts.HERO["flasks"]):
		draw_rect(Rect2(110 + i * 5 + fx, 3, 3, 4), Pal.DANGER if i < d.flasks else Pal.DARK)
	var k := d.knight
	draw_rect(Rect2(280, 3, 100, 4), Pal.DARK)
	draw_rect(Rect2(280, 3, round(100.0 * maxf(k.hp, 0) / k.max_hp), 4), Pal.DIM)


func _wig(d: Duel, k: String) -> float:
	return round(sin(main.clock * 60.0) * 2.0) if d.wiggle.has(k) else 0.0


## The buttons along the bottom (main.buttons()), and a hand's menu when
## it's open. A hand's button, when its item has the tool, says which.
func _tools(d: Duel) -> void:
	for b in main.buttons():
		var id: String = b[1]
		var hand := id.trim_prefix("hand:") if id.begins_with("hand:") else ""
		var picked: bool = main.tool == id or (hand != "" and main.hand_of(main.tool) == hand)
		var col: Color = Pal.INK if picked or main.held == id or (hand != "" and main.menu == hand) else Pal.DIM
		if Duel.cost(id) > d.stamina or (id == "flask" and d.flasks <= 0):
			col = Pal.DIM.darkened(0.45)
		_button(b[0], b[2], col, picked, main.tool.to_upper() if hand != "" and picked else "")
	for b in main.menu_buttons():
		var col: Color = Pal.DIM.darkened(0.45) if Duel.cost(b[1]) > d.stamina else Pal.INK
		_button(b[0], b[2], col, main.tool == b[1])
	var s := str(d.step_n)
	Pal.text(self, Vector2(380 - Pal.width(s), 178), s, Pal.DARK.lightened(0.2))


## A button; `under` is a second, dimmer line below the label.
func _button(r: Rect2, label: String, col: Color, picked := false, under := "") -> void:
	draw_rect(r, Pal.BG)
	draw_rect(r.grow(-0.5), col if picked else Pal.DARK, false)
	var y: float = round(r.size.y / 2.0) - (5.0 if under != "" else 2.0)
	Pal.text(self, r.position + Vector2(round((r.size.x - Pal.width(label)) / 2.0), y), label, col)
	if under != "":
		Pal.text(self, r.position + Vector2(round((r.size.x - Pal.width(under)) / 2.0), y + 6.0), under, Pal.DIM)


func _result(d: Duel) -> void:
	draw_rect(Rect2(0, 80, 384, 40), Color(0, 0, 0, 0.85))
	var s := "THE KNIGHT FALLS" if d.result == "win" else "YOU FALL"
	var w := Pal.width(s, 2)
	Pal.text(self, Vector2(192 - w / 2.0, 88), s, Pal.INK if d.result == "win" else Pal.DANGER, 2)
	Pal.text(self, Vector2(192 - Pal.width("SPACE") / 2.0, 104), "SPACE", Pal.DIM)


func _title() -> void:
	position = Vector2.ZERO
	for b in main.title_buttons():
		var col := Pal.DIM
		if b[1] == "knight" and fmod(main.clock, 1.0) >= 0.8:
			col = Pal.INK
		elif b[1] == "update" and main.update_state in ["new", "downloading", "ready", "download_failed"]:
			col = Pal.INK
		_button(b[0], b[2], col)
	Pal.text(self, Vector2(4, 203), "V" + Update.current(), Pal.DARK.lightened(0.2))


# ---------------------------------------------------------------- helpers

func _px(p: Vector2) -> Vector2:
	return Vector2(round(p.x), round(p.y))


func _outline(poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 2:
		return
	var ring := poly.duplicate()
	ring.append(poly[0])
	draw_polyline(ring, col)


func _far(poly: PackedVector2Array, from: Vector2) -> Vector2:
	var best := from
	for q in poly:
		if q.distance_to(from) > best.distance_to(from):
			best = q
	return best


func _ring(c: Vector2, r: float, col: Color) -> void:
	draw_arc(_px(c), r, 0.0, TAU, 16, col)


func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 4.0)
	for i in range(1, n):
		draw_rect(Rect2(_px(a.lerp(b, float(i) / n)), Vector2.ONE), col)
