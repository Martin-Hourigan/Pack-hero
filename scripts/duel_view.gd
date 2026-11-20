class_name DuelView
extends Node2D
## Draws the world, moved by the camera (main.cam; main sets position):
## the room (floor, pillars, walls), the fog (never seen: blank; seen
## before: greyed), the enemies' coming swings (a ghost of the blade at
## each step still to come, the ground its hitting steps sweep over, and
## the steps left on each), what the hero's tool would do where you aim,
## the puppets (posed part way through the step being shown, main.u 0..1),
## shots, then sparks and numbers. Enemies, their swings and shots only
## show where the hero can see. The side columns are DuelHud.

var main = null

## The floor in sight: just lighter than the black it greys back to.
const FLOOR := Color("#161514")

var _fog_tex: ImageTexture
var _fog_key := []  # what the fog texture was made from


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if main.mode != "duel" or main.duel == null:
		return
	var d: Duel = main.duel
	_room(d)
	_fog(d)
	_walls(d)
	_ghosts(d)
	_preview(d)
	var order: Array = d.units.filter(func(u): return u.alive() and (u == d.hero or d.can_see(u.pos)))
	order.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for u in order:
		_unit(d, u)
	_foe_bars(d)
	_shots(d)
	_reticles(d)
	for s in d.sparks:
		draw_rect(Rect2(_px(s["p"]), Vector2.ONE * (2.0 if s["life"] / s["max"] > 0.5 else 1.0)), s["col"])
	for n in d.numbers:
		Pal.text(self, _px(n["p"]) - Vector2(Pal.width(n["s"]) / 2.0, 0), n["s"], n["col"])
	_guard(d)


## The floor's dots and the pillars (the fog goes over them).
func _room(d: Duel) -> void:
	var a := d.area
	draw_rect(a, FLOOR)
	for x in range(int(a.position.x) + 8, int(a.end.x), 16):
		for y in range(int(a.position.y) + 8, int(a.end.y), 16):
			draw_rect(Rect2(x + ((y / 16) % 2) * 8, y, 1, 1), Pal.DARK)
	for pl in d.pillars:
		draw_rect(pl, Pal.DARK)
		draw_rect(Rect2(pl).grow(-0.5), Pal.DIM, false)


## Never seen: blank. Seen before but not now: greyed.
func _fog(d: Duel) -> void:
	var key := [d, d.room_i, d.step_n]
	if key != _fog_key:
		_fog_key = key
		var img := Image.create(d.fog_size.x, d.fog_size.y, false, Image.FORMAT_RGBA8)
		var greyed := Color(Pal.BG, 0.65)
		for y in d.fog_size.y:
			for x in d.fog_size.x:
				var f := d.fog_at(x, y)
				img.set_pixel(x, y, Color(0, 0, 0, 0) if f == 2 else (greyed if f == 1 else Pal.BG))
		if _fog_tex == null or _fog_tex.get_size() != Vector2(img.get_size()):
			_fog_tex = ImageTexture.create_from_image(img)
		else:
			_fog_tex.update(img)
	draw_texture_rect(_fog_tex, Rect2(d.area.position, Vector2(d.fog_size) * Acts.FOG), false)


## The room's walls, a square at a time, as seen as the squares inside
## them; the doorway is a gap.
func _walls(d: Duel) -> void:
	var a := d.area
	var f := float(Acts.FOG)
	var n := d.fog_size
	for x in n.x:
		for e in [[0, a.position.y - 1.0], [n.y - 1, a.end.y]]:
			var c := _wall_col(d.fog_at(x, e[0]))
			if c.a > 0.0:
				draw_rect(Rect2(a.position.x + x * f, e[1], f, 1), c)
	for y in n.y:
		var yy := a.position.y + y * f
		for e in [[0, a.position.x - 1.0], [n.x - 1, a.end.x]]:
			if e[0] == n.x - 1 and not d.door.is_empty() and yy + f > float(d.door[0]) and yy < float(d.door[1]):
				continue  # the doorway
			var c := _wall_col(d.fog_at(e[0], y))
			if c.a > 0.0:
				draw_rect(Rect2(e[1], yy, 1, f), c)


func _wall_col(fog: int) -> Color:
	return [Color(0, 0, 0, 0), Pal.DARK, Pal.DIM][fog]


## A small health bar over the smaller enemies (seen), once hurt.
func _foe_bars(d: Duel) -> void:
	for f in d.foes:
		if f != d.knight and f.alive() and f.hp < f.max_hp and d.can_see(f.pos):
			var at := _px(f.pos + Vector2(-5, -11))
			draw_rect(Rect2(at, Vector2(10, 1)), Pal.DARK)
			draw_rect(Rect2(at, Vector2(round(10.0 * f.hp / f.max_hp), 1)), Pal.DIM)


## Every enemy's swing still to come: the ground each hitting step sweeps
## (the next one brightest), the blade where each step leaves it, and on
## each hitting step the steps left.
func _ghosts(d: Duel) -> void:
	for k in d.foes:
		if k.alive() and d.can_see(k.pos):
			_ghost(d, k)


func _ghost(d: Duel, k: Unit) -> void:
	if k.idle() or String(k.cur["k"]) in ["walk", "stagger"] or main.u < 1.0 or not Duel._threat(k.cur):
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
	if not h.idle() or main.u < 1.0 or d.result != "":
		return
	if main.picking or (main.touch and not main.aimed and not (d.target != null and d.auto_aims(main.tool))):
		return
	var a: Dictionary = d.shape(main.tool, main.aim())
	if a.is_empty():
		return
	var sp := d.spec(main.tool)
	if sp.has("shot"):
		_shot_path(d, String(sp["shot"]), float(a["steps"][0]["face"]), int(sp["wind"]))
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
			for poly in d.blade(h, e["pose"], e["pos"], e["ang"], e["blade"]):
				_outline(poly, Pal.INK.darkened(0.45))
	var end: Vector2 = tr[tr.size() - 1]["pos"]
	if end.distance_to(h.pos) > 1.0:
		_dots(h.pos, end, Pal.INK.darkened(0.4))
		_ring(end, Duel._radius(h), Pal.INK.darkened(0.3))
	if main.tool == "roll":
		# Where the roll is safe from hits.
		for e in tr:
			if d.shape("roll", main.aim())["steps"][int(e["n"]) - 1].get("safe", false):
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
	if String(u.cur.get("k", "")) == "stagger":
		a += sin(main.clock * 30.0) * 0.12  # reeling
	var o := {"pose": pose}
	if u.flash >= 0.5:
		o["all"] = Color.WHITE
	RigArt.draw(self, d.art(u), Transform2D(a, Vector2(s, s), 0.0, _px(p)), o)


## LOCK: a reticle on the enemy locked on to; picking one, the mouse is a
## reticle (on the phone every enemy's pulses instead).
func _reticles(d: Duel) -> void:
	if d.target != null:
		_reticle(d.target.pos, Duel._radius(d.target) + 3.0, Pal.INK)
	if not main.picking:
		return
	var pulse: float = 1.0 + round(sin(main.clock * 8.0) + 1.0)
	for u in d.units:
		if u.side == "enemy" and u.alive():
			_reticle(u.pos, Duel._radius(u) + 2.0 + pulse, Pal.INK if d.enemy_at(main.aim()) == u else Pal.DIM)
	if not main.touch:
		_reticle(main.aim(), 3.0, Pal.INK)


## Four corner ticks round c, r px out.
func _reticle(c: Vector2, r: float, col: Color) -> void:
	var p := _px(c)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var q := p + Vector2(sx, sy) * r
			draw_rect(Rect2(q.x - (2 if sx > 0 else 0), q.y, 3, 1), col)
			draw_rect(Rect2(q.x, q.y - (2 if sy > 0 else 0), 1, 3), col)


## GUARD up: the front it stops hits from, round the hero.
func _guard(d: Duel) -> void:
	var g := d.guarding(d.hero)
	if g.is_empty():
		return
	var h := d.hero
	var a := h.ang
	var p := h.pos
	if not h.was.is_empty() and main.u < 1.0:
		a = lerp_angle(float(h.was["ang"]), h.ang, main.u)
		p = Vector2(h.was["pos"]).lerp(h.pos, main.u)
	var half := deg_to_rad(float(g["block"])) / 2.0
	draw_arc(_px(p), Duel._radius(h) + 4.0, a - half, a + half, 16, Pal.INK.darkened(0.5))


## Arrows, bolts and spells in flight (between where they were and are).
func _shots(d: Duel) -> void:
	var t: float = main.u
	for s in d.shots + d.gone:
		var sp: Dictionary = Acts.SHOTS[s["k"]]
		var col := Color(sp["col"])
		var p: Vector2 = Vector2(s["from"]).lerp(s["p"], t)
		if (d.gone.has(s) and t >= 1.0) or not d.can_see(p):
			continue
		var f := Vector2.from_angle(float(s["ang"]))
		if float(sp["r"]) >= 2.0:
			draw_circle(_px(p), float(sp["r"]), col)
		else:
			draw_line(_px(p - f * 5.0), _px(p), col)


## Where a shot would go from the hero aimed `ang`: a mark where it'll be
## each step, up to where it'd reach an enemy or its range ends.
func _shot_path(d: Duel, k: String, ang: float, wind: int) -> void:
	var sp: Dictionary = Acts.SHOTS[k]
	var f := Vector2.from_angle(ang)
	var p := d.shot_from(d.hero, ang)
	var col := Pal.INK.darkened(0.45)
	var k_at: Array = []
	for e in d.foes:
		if e.alive() and d.can_see(e.pos):
			k_at.append_array(e.body())
	var left := float(sp["range"])
	for i in ceili(left / float(sp["speed"])):
		var q := p + f * minf(float(sp["speed"]), left)
		left -= float(sp["speed"])
		var hit := false
		for n in 12:
			var x := p.lerp(q, (n + 1) / 12.0)
			for c in k_at:
				if x.distance_to(c[0]) <= float(c[1]) + float(sp["r"]):
					hit = true
					q = x
			if hit or not d.open_at(x):
				q = x
				break
		_dots(p, q, col)
		draw_rect(Rect2(_px(q) - Vector2.ONE, Vector2(2, 2)), col)
		if hit:
			var s := str(wind + i + 1)
			Pal.text(self, _px(q + Vector2(-1, -18)), s, Pal.INK)
			return
		if not d.open_at(q):
			return
		p = q


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
