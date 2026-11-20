class_name Shape
extends RefCounted
## Where an attack lands, with no grid: a shape on the ground in pixels.
##   disc {c, r}                    a round patch
##   fan  {c, r, a, half}           a slice of a circle: radius r, facing a, half its width either side
##   bar  {a, b, w}                 a straight strip from a to b, w wide
##   band {c, r0, r1, a, half}      a fan with its middle cut out (where a leap can land)
##   oval {c, a, rx, ry}            an oval: rx along angle a, ry across
##   box  {c, a, hx, hy}            a rectangle: hx either way along angle a, hy across
##   sweep {c, R, a0, a1, r, span}  a circle of radius r swept round c at R, from angle a0 to a1
##                                  (a side bite); span = the signed turn, for half turns and more
## A body (a circle) is hit when any of it is in the shape.


static func disc(c: Vector2, r: float) -> Dictionary:
	return {"t": "disc", "c": c, "r": r}


static func fan(c: Vector2, r: float, a: float, half: float) -> Dictionary:
	return {"t": "fan", "c": c, "r": r, "a": a, "half": half}


static func bar(a: Vector2, b: Vector2, w: float) -> Dictionary:
	return {"t": "bar", "a": a, "b": b, "w": w}


static func band(c: Vector2, r0: float, r1: float, a: float, half: float) -> Dictionary:
	return {"t": "band", "c": c, "r0": r0, "r1": r1, "a": a, "half": half}


static func oval(c: Vector2, a: float, rx: float, ry: float) -> Dictionary:
	return {"t": "oval", "c": c, "a": a, "rx": rx, "ry": ry}


static func box(c: Vector2, a: float, hx: float, hy: float) -> Dictionary:
	return {"t": "box", "c": c, "a": a, "hx": hx, "hy": hy}


static func sweep(c: Vector2, big_r: float, a0: float, a1: float, r: float, span := NAN) -> Dictionary:
	if is_nan(span):
		span = angle_difference(a0, a1)
	return {"t": "sweep", "c": c, "R": big_r, "a0": a0, "a1": a0 + span, "r": r, "span": span}


## The same shape moved by d.
static func moved(s: Dictionary, d: Vector2) -> Dictionary:
	var out := s.duplicate()
	for k in ["c", "a", "b"]:
		if out.has(k) and out[k] is Vector2:
			out[k] = out[k] + d
	return out


## Is a body of radius r at p in it?
static func hits(s: Dictionary, p: Vector2, r: float) -> bool:
	match String(s["t"]):
		"disc":
			return p.distance_to(s["c"]) <= float(s["r"]) + r
		"fan":
			var v: Vector2 = p - s["c"]
			var d := v.length()
			if d > float(s["r"]) + r:
				return false
			if d <= r:
				return true
			return absf(angle_difference(float(s["a"]), v.angle())) <= float(s["half"]) + asin(minf(r / d, 1.0))
		"bar":
			return _to_segment(p, s["a"], s["b"]) <= float(s["w"]) / 2.0 + r
		"band":
			var v: Vector2 = p - s["c"]
			var d := v.length()
			return d >= float(s["r0"]) and d <= float(s["r1"]) and absf(angle_difference(float(s["a"]), v.angle())) <= float(s["half"])
		"sweep":
			return p.distance_to(_on_sweep(s, p)) <= float(s["r"]) + r
		"box":
			var v: Vector2 = (p - s["c"]).rotated(-float(s["a"]))
			var q := Vector2(clampf(v.x, -float(s["hx"]), float(s["hx"])), clampf(v.y, -float(s["hy"]), float(s["hy"])))
			return v.distance_to(q) <= r
		"oval":
			# (A body counts as in it if it's in the oval grown by its radius.)
			var v: Vector2 = (p - s["c"]).rotated(-float(s["a"]))
			var rx := float(s["rx"]) + r
			var ry := float(s["ry"]) + r
			return (v.x * v.x) / (rx * rx) + (v.y * v.y) / (ry * ry) <= 1.0
	return false


## The point on a sweep's path nearest p.
static func _on_sweep(s: Dictionary, p: Vector2) -> Vector2:
	var a0 := float(s["a0"])
	var span := float(s["span"])
	var t := angle_difference(a0, (p - s["c"]).angle()) if p != s["c"] else 0.0
	# Measured the way it turns, so a half turn or more still works.
	if span > 0.0 and t < 0.0:
		t += TAU
	elif span < 0.0 and t > 0.0:
		t -= TAU
	if absf(t) > absf(span):
		# Past its end: the nearer of the two ends.
		var e0: Vector2 = s["c"] + Vector2.from_angle(a0) * float(s["R"])
		var e1: Vector2 = s["c"] + Vector2.from_angle(a0 + span) * float(s["R"])
		return e0 if p.distance_to(e0) < p.distance_to(e1) else e1
	return s["c"] + Vector2.from_angle(a0 + t) * float(s["R"])


## Which way an attack moves through it, at p: Vector2(how far along,
## how far off the middle line). A sweep goes round its arc, a box along its
## angle, an oval spreads out from its middle (along = the distance, 0
## across); anything else goes the way `fwd` points.
static func flow(s: Dictionary, p: Vector2, fwd: float) -> Vector2:
	var c: Vector2 = s["a"] if s["t"] == "bar" else s["c"]
	var dir := Vector2.from_angle(fwd)
	match String(s["t"]):
		"sweep":
			var span := float(s["span"])
			if absf(span) > 0.01:
				var t := angle_difference(float(s["a0"]), (p - c).angle()) * signf(span)
				if t < -0.5:
					t += TAU
				return Vector2(t * float(s["R"]), (p - c).length() - float(s["R"]))
			dir = Vector2.from_angle(float(s["a0"]))
		"box":
			dir = Vector2.from_angle(float(s["a"]))
		"oval":
			return Vector2((p - c).length(), 0.0)
		"bar":
			dir = (Vector2(s["b"]) - c).normalized()
	var v := p - c
	return Vector2(v.dot(dir), v.cross(dir))


## Is the point p in it?
static func has_point(s: Dictionary, p: Vector2) -> bool:
	return hits(s, p, 0.0)


## The point of it nearest `to` (where its beat count goes).
static func near_point(s: Dictionary, to: Vector2) -> Vector2:
	match String(s["t"]):
		"bar":
			return Geometry2D.get_closest_point_to_segment(to, s["a"], s["b"])
		"fan", "band":
			var c: Vector2 = s["c"]
			return c + Vector2.from_angle(float(s["a"])) * float(s.get("r", s.get("r1", 0.0))) * 0.6
		"sweep":
			return _on_sweep(s, to)
	return s["c"]


## The pixels it covers: {rows: [[y, x0, x1], ...], edge: [Vector2i, ...]}.
## Pixel (x, y) is in it if its middle is.
static func raster(s: Dictionary) -> Dictionary:
	var box := _box(s)
	var inside := {}
	var rows := []
	for y in range(box.position.y, box.end.y + 1):
		var start := -1
		for x in range(box.position.x, box.end.x + 2):
			var on := x <= box.end.x and has_point(s, Vector2(x + 0.5, y + 0.5))
			if on:
				inside[Vector2i(x, y)] = true
				if start < 0:
					start = x
			elif start >= 0:
				rows.append([y, start, x - 1])
				start = -1
	var edge := []
	for q in inside:
		for n in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not inside.has(q + n):
				edge.append(q)
				break
	return {"rows": rows, "edge": edge}


static func _box(s: Dictionary) -> Rect2i:
	var lo: Vector2
	var hi: Vector2
	match String(s["t"]):
		"bar":
			var w := float(s["w"])
			lo = Vector2(minf(s["a"].x, s["b"].x), minf(s["a"].y, s["b"].y)) - Vector2(w, w)
			hi = Vector2(maxf(s["a"].x, s["b"].x), maxf(s["a"].y, s["b"].y)) + Vector2(w, w)
		"sweep":
			var r := float(s["R"]) + float(s["r"])
			lo = s["c"] - Vector2(r, r)
			hi = s["c"] + Vector2(r, r)
		"box":
			var r := Vector2(float(s["hx"]), float(s["hy"])).length()
			lo = s["c"] - Vector2(r, r)
			hi = s["c"] + Vector2(r, r)
		"oval":
			var r := maxf(float(s["rx"]), float(s["ry"]))
			lo = s["c"] - Vector2(r, r)
			hi = s["c"] + Vector2(r, r)
		_:
			var r := float(s.get("r", s.get("r1", 0.0)))
			lo = s["c"] - Vector2(r, r)
			hi = s["c"] + Vector2(r, r)
	return Rect2i(Vector2i(floori(lo.x), floori(lo.y)), Vector2i(ceili(hi.x - lo.x), ceili(hi.y - lo.y)))


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
