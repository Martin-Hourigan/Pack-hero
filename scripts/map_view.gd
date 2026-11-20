class_name MapView
extends Node2D
## The route map: stops left to right, the last fight at the right. The
## ones you can go to next are lit; under the mouse, a hunting stop shows
## its party. Click one to go. Along the top: its level, stats and aspects.
## After a fight, a level: pick a stat (click, or 1-3); every third level
## then an aspect.

var main = null

const X0 := 28
const DX := 44
const Y0 := 46
const DY := 34
const GLYPH := {"hunt": "H", "prey": "P", "nest": "N", "boss": "B"}


func pos(n: Dictionary) -> Vector2:
	if int(n["lane"]) < 0:
		return Vector2(X0 + DX * int(n["col"]), Y0 + DY * (Run.LANES - 1) / 2.0)
	return Vector2(X0 + DX * int(n["col"]), Y0 + DY * int(n["lane"]))


## The stop under the mouse (-1 if none).
func stop_at(p: Vector2) -> int:
	var r: Run = main.run
	for n in r.nodes:
		if p.distance_to(pos(n)) < 9.0:
			return n["id"]
	return -1


const CARD := Vector2(116, 74)
const CARD_Y := 54


func _card_rect(i: int, n: int) -> Rect2:
	var w := n * CARD.x + (n - 1) * 8
	return Rect2(Vector2(192 - w / 2.0 + i * (CARD.x + 8), CARD_Y), CARD)


## The upgrade card under the mouse (-1 if none).
func card_at(p: Vector2) -> int:
	var n: int = main.run.offer.size()
	for i in n:
		if _card_rect(i, n).has_point(p):
			return i
	return -1


func _draw() -> void:
	if main.mode == "setup":
		_setup()
		return
	var r: Run = main.run
	if r == null:
		return
	if main.mode == "evolve":
		_evolve(r)
		return
	if main.mode != "map":
		return
	var can: Array = r.choices()
	var hv: int = stop_at(get_global_mouse_position())
	for n in r.nodes:
		for id in n["next"]:
			_dots(pos(n), pos(r.nodes[id]), Pal.DARK if not (n["id"] == r.at and id in can) else Pal.DIM)
	for n in r.nodes:
		var p := pos(n)
		var lit: bool = n["id"] in can
		var here: bool = n["id"] == r.at
		var col := Pal.INK if lit or here else Pal.DIM.darkened(0.3)
		if n["id"] == hv and lit:
			col = Color.WHITE
		_ring(p, 7.0 if n["kind"] != "boss" else 10.0, col)
		var g: String = GLYPH[n["kind"]]
		Pal.text(self, p - Vector2(1, 2), g, col)
		if here:
			draw_rect(Rect2(p + Vector2(-1, 9), Vector2(3, 1)), Pal.INK)
	# The party at the stop under the mouse.
	if hv >= 0 and r.is_fight(hv):
		var party: Array = r.nodes[hv]["party"]
		var s := " ".join(party.map(func(k): return String(Acts.UNITS[k]["label"])))
		Pal.text(self, Vector2(4, 196), s, Pal.DANGER)
	# Health.
	draw_rect(Rect2(4, 3, 100, 4), Pal.DARK)
	draw_rect(Rect2(4, 3, round(100.0 * r.hp / r.max_hp), 4), Pal.INK)
	_build(r)
	if r.result != "":
		var t := "THE TERRITORY IS YOURS" if r.result == "win" else "THE PACK FALLS"
		Pal.text(self, Vector2(192 - Pal.width(t, 2) / 2.0, 186), t, Pal.INK if r.result == "win" else Pal.DANGER, 2)
		Pal.text(self, Vector2(192 - Pal.width("R NEW RUN") / 2.0, 204), "R NEW RUN", Pal.DIM)


## What the leader is: its level, its stats, its aspects.
func _build(r: Run) -> void:
	var x := 110
	x += Pal.text(self, Vector2(x, 3), "LV %d" % r.level, Pal.INK) + 10
	for s in r.stats:
		x += Pal.text(self, Vector2(x, 3), "%s %d" % [Acts.STATS[s]["label"], int(r.stats[s])], Pal.DIM) + 8
	x = 4
	for k in r.aspects:
		x += Pal.text(self, Vector2(x, 186), "%s %d" % [Acts.ASPECTS[k]["label"], int(r.aspects[k])], _col(k)) + 8


static func _col(k: String) -> Color:
	return Color(Acts.ASPECTS[k].get("col", Pal.INK))


func _evolve(r: Run) -> void:
	_build(r)
	var t := "ASPECT" if r.big() else "LEVEL %d" % r.level
	Pal.text(self, Vector2(192 - Pal.width(t, 2) / 2.0, 30), t, Pal.INK, 2)
	var n := r.offer.size()
	var hv := card_at(get_global_mouse_position())
	for i in n:
		var o: Dictionary = r.offer[i]
		var rc := _card_rect(i, n)
		var lit := i == hv
		var col := Pal.INK if lit else Pal.DIM
		draw_rect(rc, Pal.DARK if lit else Pal.BG)
		draw_rect(rc, _col(o["id"]) if o["kind"] == "aspect" else col, false)
		Pal.text(self, rc.position + Vector2(4, 4), str(i + 1), Pal.DIM)
		var title := ""
		var say := ""
		if o["kind"] == "stat":
			var v := int(r.stats[o["id"]])
			title = "%s %d>%d" % [Acts.STATS[o["id"]]["label"], v, v + 1]
			say = String(Acts.STATS[o["id"]]["say"])
		else:
			var v := int(r.aspects.get(o["id"], 0))
			title = "%s %d>%d" % [Acts.ASPECTS[o["id"]]["label"], v, v + 1]
		Pal.text(self, rc.position + Vector2(4, 14), title, Pal.INK)
		var y := 26
		for line in _wrap(say, int(rc.size.x) - 8):
			Pal.text(self, rc.position + Vector2(4, y), line, col)
			y += 8


static func _wrap(s: String, w: int) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var t := word if line == "" else line + " " + word
		if Pal.width(t) > w and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 3.0)
	for i in range(3, n - 2):
		var q := a.lerp(b, float(i) / n)
		draw_rect(Rect2(Vector2(round(q.x), round(q.y)), Vector2.ONE), col)


func _ring(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(int(r * 6.0), 8)
	for i in n:
		var a := TAU * i / n
		draw_rect(Rect2(Vector2(round(c.x + cos(a) * r), round(c.y + sin(a) * r)), Vector2.ONE), col)


# ---------------------------------------------------------------- start setup

const SETUP_Y := 56
const SETUP_DY := 14
const SETUP_MINUS := 224
const SETUP_PLUS := 252


## The start setup row and change under p: Vector2i(row, -1 / +1), or row -1.
func setup_at(p: Vector2) -> Vector2i:
	var rows: Array = main.setup_rows()
	for i in rows.size():
		var y := SETUP_Y + i * SETUP_DY
		if p.y >= y - 3 and p.y < y + 9:
			if absf(p.x - (SETUP_MINUS + 2)) < 6:
				return Vector2i(i, -1)
			if absf(p.x - (SETUP_PLUS + 2)) < 6:
				return Vector2i(i, 1)
	return Vector2i(-1, 0)


func _setup() -> void:
	var t := "START SETUP"
	Pal.text(self, Vector2(192 - Pal.width(t, 2) / 2.0, 26), t, Pal.INK, 2)
	var rows: Array = main.setup_rows()
	for i in rows.size():
		var k: String = rows[i]
		var y := SETUP_Y + i * SETUP_DY
		var on: bool = i == main.setup_row
		var label: String = Acts.STATS[k]["label"] if Acts.STATS.has(k) else Acts.ASPECTS[k]["label"]
		var col := Pal.INK if on else Pal.DIM
		if Acts.ASPECTS.has(k):
			col = _col(k) if on else _col(k).darkened(0.35)
		if on:
			Pal.text(self, Vector2(112, y), ">", Pal.INK)
		Pal.text(self, Vector2(120, y), label, col)
		Pal.text(self, Vector2(SETUP_MINUS, y), "-", col)
		var v := str(main.setup[k])
		Pal.text(self, Vector2(SETUP_MINUS + 15 - Pal.width(v) / 2.0, y), v, col)
		Pal.text(self, Vector2(SETUP_PLUS, y), "+", col)
	var help := "ENTER RUN   F FIGHT   ESC BACK"
	Pal.text(self, Vector2(192 - Pal.width(help) / 2.0, SETUP_Y + rows.size() * SETUP_DY + 14), help, Pal.DIM)
