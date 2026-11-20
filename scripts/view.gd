class_name View
extends Node2D
## Draws the fight: the arena, the hunters' attacks on the ground (each with
## the beats left before it lands), what the leader is about to do where the
## mouse is (with where the tool can reach, dim), then everyone, then sparks
## and numbers. Everything moves over the beat being shown (main.u, 0..1).
## Shapes are drawn pixel by pixel, so their edges stay on the pixel grid.

var main = null

const TEAM := "#6fb7a8"  # on the hunter rig: repainted to the hunter's colour
const FIRE := Color("#d9784a")
## Parts of the raptor rig that are grown in the hex version: never shown here.
const GROWN := ["horns", "wing_l", "wing_r", "spikes", "tail4"]

var _raster := {}  # str(shape) -> Shape.raster(shape)


func _draw() -> void:
	if main.mode == "title":
		_title()
		return
	var f: Battle = main.battle
	if f == null or main.mode != "run":
		return
	var sh: float = f.shake_amt
	position = Vector2(round(randf_range(-sh, sh)), round(randf_range(-sh, sh)))
	if _raster.size() > 200:
		_raster.clear()
	_arena()
	_tells(f)
	_preview(f)
	var order: Array = f.units.filter(func(u): return u.alive())
	order.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for u in order:
		if _air(u) > 0.0:
			_shadow(u)
	for u in order:
		_unit(u)
	_counts(f)
	for s in f.sparks:
		if float(s.get("wait", 0.0)) <= 0.0:
			draw_rect(Rect2(_px(s["p"]), Vector2.ONE * (2.0 if s["life"] / s["max"] > 0.5 else 1.0)), s["col"])
	for n in f.numbers:
		if float(n.get("wait", 0.0)) <= 0.0:
			Pal.text(self, _px(n["p"]) - Vector2(Pal.width(n["s"]) / 2.0, 0), n["s"], n["col"])


## The arena: its edge, and a faint speckle so movement reads.
func _arena() -> void:
	var a := Acts.ARENA
	draw_rect(Rect2(a.position - Vector2.ONE, a.size + Vector2(2, 2)), Pal.DARK, false)
	for x in range(int(a.position.x) + 8, int(a.end.x), 16):
		for y in range(int(a.position.y) + 8, int(a.end.y), 16):
			draw_rect(Rect2(x + ((y / 16) % 2) * 8, y, 1, 1), Pal.DARK)


# ---------------------------------------------------------------- shapes

## Fills a shape (fill) and its edge (edge); either can be clear.
func area(s: Dictionary, fill: Color, edge := Color(0, 0, 0, 0)) -> void:
	var key := str(s)
	if not _raster.has(key):
		_raster[key] = Shape.raster(s)
	var r: Dictionary = _raster[key]
	if fill.a > 0.0:
		for row in r["rows"]:
			draw_rect(Rect2(row[1], row[0], row[2] - row[1] + 1, 1), fill)
	if edge.a > 0.0:
		for q in r["edge"]:
			draw_rect(Rect2(q, Vector2.ONE), edge)


## Stripes moving through an aimed attack the way it goes: chevrons for
## one that travels, rings for one that bursts out (see Shape.flow).
const FLOW_GAP := 6.0  # px between stripes
const FLOW_W := 2.0  # px a stripe
const FLOW_SPEED := 10.0  # px a second


func _flow(s: Dictionary, fwd: float, col: Color) -> void:
	var key := str(s)
	if not _raster.has(key):
		_raster[key] = Shape.raster(s)
	var shift: float = main.clock * FLOW_SPEED
	for row in _raster[key]["rows"]:
		var y: int = row[0]
		var start := -1
		for x in range(row[1], row[2] + 2):
			var on := false
			if x <= row[2]:
				var fl := Shape.flow(s, Vector2(x + 0.5, y + 0.5), fwd)
				on = fposmod(fl.x + absf(fl.y) * 0.7 - shift, FLOW_GAP) < FLOW_W
			if on and start < 0:
				start = x
			elif not on and start >= 0:
				draw_rect(Rect2(start, y, x - start, 1), col)
				start = -1


## The hunters' attacks on the ground, brighter the nearer they are; the
## beat one lands, it flashes.
func _tells(f: Battle) -> void:
	if main.u < 1.0:
		var hot := fmod(main.clock, 0.08) < 0.04
		for s in f.hurt_shapes:
			area(s, FIRE.darkened(0.3), Color.WHITE if hot else FIRE)
	for h in f.hunters():
		for e in h.coming_hits():
			var n: int = e[0]
			var flick := n == 1 and fmod(main.clock, 0.3) < 0.15
			for s in e[1]:
				area(s, Pal.DANGER_DIM.darkened(0.3 if n > 1 else 0.0), FIRE if n == 1 and flick else Pal.DANGER_DIM)


## On each hunter's attack, the beats left, on its part nearest the leader.
func _counts(f: Battle) -> void:
	for h in f.hunters():
		for e in h.coming_hits():
			var s := str(e[0])
			var at := _px(Shape.near_point(e[1][0], f.leader.pos)) - Vector2(Pal.width(s) / 2.0 - 0.5, 2)
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(Pal.width(s) + 1, 7)), Pal.BG)
			Pal.text(self, at, s, Pal.INK)


## What the chosen tool would do: where it can reach, dim; what it hits
## where the mouse is, bright; where you'd end up, and which way you'd face.
func _preview(f: Battle) -> void:
	var u: Unit = f.leader
	var again: bool = f.reaiming()
	if (not u.idle() and not again) or main.u < 1.0 or f.result != "":
		return
	var dim := Pal.INK.darkened(0.7)
	for s in (f.reaim_reach() if again else f.reach(main.tool)):
		area(s, Color(0, 0, 0, 0), dim)
	var a: Dictionary = main.preview()
	if a.is_empty():
		return
	var end := u.pos
	var face := u.ang
	for st in a["steps"]:
		if st.has("face"):
			face = float(st["face"])
		if st.has("to"):
			if a["k"] == "move":
				face = (st["to"] - end).angle()
			end = st["to"]
		for h in Battle.hits_of(st):
			for s in h["hit"]:
				var on := f.hunters().any(func(h): return h.in_shape(s))
				area(s, Pal.INK.darkened(0.8))
				_flow(s, face, Pal.INK.darkened(0.62))
				area(s, Color(0, 0, 0, 0), Pal.INK if on else Pal.INK.darkened(0.3))
	if end != u.pos:
		_dots(u.pos, end, Pal.INK.darkened(0.4))
	# Where its body will be, and which way it'll face.
	if end != u.pos or face != u.ang:
		for c in u.body(end, face):
			area(Shape.disc(c[0], c[1]), Color(0, 0, 0, 0), Pal.INK.darkened(0.3))


# ---------------------------------------------------------------- units

## How far through the air it is right now (0 = on the ground).
func _air(u: Unit) -> float:
	var st: Dictionary = u.played.get("step", {})
	if not st.get("air", false) or main.u >= 1.0:
		return 0.0
	return sin(PI * main.u)


func _pos(u: Unit) -> Vector2:
	var trail: Array = u.played.get("trail", [u.pos])
	if trail.size() < 2:
		return u.pos
	return trail[0].lerp(trail[trail.size() - 1], main.u)


func _angle(u: Unit) -> float:
	var a0 := float(u.played.get("from_ang", u.ang))
	var st: Dictionary = u.played.get("step", {})
	if st.has("spin"):
		# A half turn goes the way it spins.
		return a0 + float(st["spin"]) * PI * clampf(main.u * 2.0, 0.0, 1.0)
	return a0 + angle_difference(a0, u.ang) * clampf(main.u * 2.0, 0.0, 1.0)


func _shadow(u: Unit) -> void:
	draw_circle(_px(_pos(u)), 5.0, Pal.DARK)


func _unit(u: Unit) -> void:
	var d: Dictionary = u.data()
	var ang := _angle(u)
	var p := _pos(u)
	var st: Dictionary = u.played.get("step", {})
	var ph := String(st.get("ph", ""))
	var lunge := 0.0
	if ph == "act" and main.u < 1.0 and not st.get("air", false):
		lunge = sin(PI * main.u) * 3.0
	var air := _air(u)
	var s := float(d["scale"]) * (1.0 + 0.3 * air)
	var o := {"rot": {}, "off": {}, "hide": {}}
	if u.side == "pack":
		# The raptor: its legs stand on its point, so the body sits a little back.
		var fwd := Vector2.from_angle(ang)
		p += fwd * (lunge - 6.0 * float(d["scale"]))
		if ph == "wind":
			s *= 0.92
		if ph == "stagger" and main.u < 1.0:
			p += fwd.orthogonal() * sin(main.u * TAU * 2.0) * 1.5
		if ph == "move" and main.u < 1.0:
			var stride := sin(main.u * TAU) * 3.0
			o["off"]["leg_l"] = Vector2(stride, 0.0)
			o["off"]["leg_r"] = Vector2(-stride, 0.0)
		for node in GROWN:
			o["hide"][node] = true
	else:
		p += Vector2.from_angle(ang) * lunge
		# The sword swings through the slash's arc (its hit shape).
		var arc := float(Acts.SWORD["arc"])
		var sw := 0.5
		if ph == "wind":
			sw = -arc
		elif ph == "act" and main.u < 1.0:
			sw = lerpf(-arc, arc, clampf(main.u * 2.0, 0.0, 1.0))
		o["rot"]["sword"] = sw
		o["hide"]["sword_back"] = true
		o["recolor"] = {TEAM: u.col}
		if u.kind == "bow":
			o["hide"]["sword"] = true
	if u.flash >= 0.5:
		o["all"] = Color.WHITE
	RigArt.draw(self, d["art"], Transform2D(ang, Vector2(s, s), 0.0, _px(p)), o)
	if u.bleeding > 0:
		_drips(p)
	if u.kind == "bow":
		_bow(p, ang, ph == "wind" or (ph == "act" and main.u < 0.5), u.col)


## Bleeding: drops falling beside it.
func _drips(p: Vector2) -> void:
	for i in 2:
		var t := fmod(main.clock * 1.6 + i * 0.5, 1.0)
		var at := _px(p + Vector2(-3.0 + i * 6.0, -2.0 + t * 7.0))
		draw_rect(Rect2(at, Vector2(1, 2 if t < 0.7 else 1)), Pal.DANGER)


## The bow: an arc in front, drawn back while aiming.
func _bow(p: Vector2, ang: float, drawn: bool, col: Color) -> void:
	var f := Vector2.from_angle(ang)
	var side := f.orthogonal()
	var mid := p + f * 8.0
	for i in range(-3, 4):
		var k := float(i) / 3.0
		var q := mid + side * i * 1.2 - f * (k * k) * 2.5
		draw_rect(Rect2(_px(q), Vector2.ONE), col)
	if drawn:
		draw_line(_px(mid + side * 3.6 - f * 2.5), _px(p + f * 4.0), Pal.INK)
		draw_line(_px(mid - side * 3.6 - f * 2.5), _px(p + f * 4.0), Pal.INK)


# ---------------------------------------------------------------- helpers

func _px(p: Vector2) -> Vector2:
	return Vector2(round(p.x), round(p.y))


func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 4.0)
	for i in range(1, n):
		draw_rect(Rect2(_px(a.lerp(b, float(i) / n)), Vector2.ONE), col)


# ---------------------------------------------------------------- title

func _title() -> void:
	position = Vector2.ZERO
	var w := Pal.width("PACK", 6)
	Pal.text(self, Vector2(192 - w / 2.0, 52), "PACK", Pal.INK, 6)
	var line := "SPACE  HUNT THE HUNTERS"
	Pal.text(self, Vector2(192 - Pal.width(line) / 2.0, 120), line, Pal.DIM if fmod(main.clock, 1.0) < 0.8 else Pal.INK)
	line = "S  START SETUP"
	Pal.text(self, Vector2(192 - Pal.width(line) / 2.0, 134), line, Pal.DIM)
