class_name RigArt
extends RefCounted
## Draws a puppet-editor rig (Games/tools/puppet, .rig.json) the Tell way:
## every frame, straight onto the 384x216 pixel grid, so turning, squash and
## stretch reshape the shapes instead of scaling an image. The file is
## re-read within a second of being saved, so edits show while it runs.
##
## Draw options (all optional):
##   rot   {node: radians}     extra turn about the node's joint
##   off   {node: Vector2}     extra offset, in its parent's space
##   world {node: Transform2D} place the node outright (the tail chain)
##   swap  {part: part}        wear another part (head -> head@broken)
##   hide  {node: true}        leave out (with everything under it)
##   only  [node, ...]         draw just these
##   recolor {"#hex": Color}   repaint a colour (the hunter's own colour)
##   all   Color               draw everything in one colour (hit flash, dead)
##   pose  {node: {pos, rot, part, vis}}  a clip's pose (pose() / blend()), in
##                             place of the rig's own

const RECHECK_MS := 1000

static var _cache := {}  # path -> {rig, mtime, checked, tex, px}


static func get_rig(path: String) -> Dictionary:
	var c: Dictionary = _cache.get(path, {})
	var now := Time.get_ticks_msec()
	if not c.is_empty() and now - int(c["checked"]) < RECHECK_MS:
		return c["rig"]
	var mt := FileAccess.get_modified_time(path)
	if not c.is_empty():
		c["checked"] = now
		if mt == int(c["mtime"]):
			return c["rig"]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return c.get("rig", {})
	var rig = JSON.parse_string(f.get_as_text())
	if typeof(rig) != TYPE_DICTIONARY:
		return c.get("rig", {})  # a half-written save: keep the last good one
	c = {"rig": rig, "mtime": mt, "checked": now, "tex": null, "px": {}}
	_load_sheet(c, rig)
	_cache[path] = c
	return rig


## Painted pixels on the sheet (parts can be painted as well as shaped).
static func _load_sheet(c: Dictionary, rig: Dictionary) -> void:
	var sp := String(rig.get("sheet", ""))
	if sp == "":
		return
	var img := Image.load_from_file(ProjectSettings.globalize_path(sp))
	if img == null or img.is_empty():
		return
	c["tex"] = ImageTexture.create_from_image(img)
	for k in rig.get("parts", {}):
		var r: Array = rig["parts"][k]["rect"]
		var reg := img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		c["px"][k] = not reg.is_invisible()


static func draw(ci: CanvasItem, path: String, root: Transform2D, o := {}) -> void:
	var rig := get_rig(path)
	if rig.is_empty():
		return
	var c: Dictionary = _cache[path]
	for e in _layout(rig, root, o):
		_part(ci, e["p"], e["t"], o, c, e["part"])


## Every shown node in draw order: {node, part (after swaps), p (its data),
## t (world transform), group (the part's section in the editor)}.
static func _layout(rig: Dictionary, root: Transform2D, o: Dictionary) -> Array:
	var by_name := {}
	for n in rig.get("nodes", []):
		by_name[n["name"]] = n
	var xf := {}
	var order: Array = rig.get("nodes", []).duplicate()
	order.sort_custom(func(a, b): return int(a.get("z", 0)) < int(b.get("z", 0)))
	var hide: Dictionary = o.get("hide", {})
	var only: Array = o.get("only", [])
	var out := []
	for n in order:
		var name := String(n["name"])
		if _hidden(name, by_name, hide) or not o.get("pose", {}).get(name, {}).get("vis", true):
			continue
		if not only.is_empty() and not name in only:
			continue
		var pn := String(o.get("pose", {}).get(name, {}).get("part", n.get("part", "")))
		if pn == "":
			continue
		pn = String(o.get("swap", {}).get(pn, pn))
		var p: Dictionary = rig["parts"].get(pn, {})
		if p.is_empty():
			continue
		out.append({"node": name, "part": pn, "p": p, "t": _world(name, by_name, root, o, xf),
			"group": String(p.get("group", "")).get_slice("/", 0)})
	return out


# ---------------------------------------------------------------- clips

## The rig posed at frame f of clip k (between frames it's part way, as the
## editor plays it; past the end it holds the last frame). {} = its own
## pose. {node: {pos, rot (degrees), part, vis}} for every node.
static func pose(path: String, k: String, f: float) -> Dictionary:
	var rig := get_rig(path)
	var cl: Dictionary = rig.get("clips", {}).get(k, {})
	var out := {}
	for n in rig.get("nodes", []):
		var tr: Dictionary = cl.get("tracks", {}).get(n["name"], {})
		var p := {"pos": Vector2(_track(tr.get("x", {}), f, n["pos"][0]), _track(tr.get("y", {}), f, n["pos"][1])),
			"rot": float(_track(tr.get("rot", {}), f, n.get("rot", 0.0))),
			"part": String(_track(tr.get("part", {}), f, n.get("part", ""), true)),
			"vis": bool(_track(tr.get("vis", {}), f, n.get("vis", true), true))}
		out[n["name"]] = p
	return out


## The number of frames in clip k (0 = no such clip).
static func frames(path: String, k: String) -> int:
	return int(get_rig(path).get("clips", {}).get(k, {}).get("frames", 0))


## Part way (t) from pose a to pose b. Parts and visibility switch half way.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for k in b:
		if not a.has(k):
			out[k] = b[k]
			continue
		var pa: Dictionary = a[k]
		var pb: Dictionary = b[k]
		out[k] = {"pos": pa["pos"].lerp(pb["pos"], t), "rot": lerpf(pa["rot"], pb["rot"], t),
			"part": pb["part"] if t >= 0.5 else pa["part"], "vis": pb["vis"] if t >= 0.5 else pa["vis"]}
	return out


## A track's value at frame f (keys are frame numbers); def without keys.
static func _track(tr: Dictionary, f: float, def: Variant, stepped := false) -> Variant:
	if tr.is_empty():
		return def
	var ks: Array = tr.keys().map(func(x): return int(x))
	ks.sort()
	if f <= ks[0]:
		return tr[str(ks[0])]
	for i in range(ks.size() - 1, -1, -1):
		if ks[i] <= f:
			if i == ks.size() - 1 or stepped:
				return tr[str(ks[i])]
			var a = tr[str(ks[i])]
			var b = tr[str(ks[i + 1])]
			return lerpf(float(a), float(b), (f - ks[i]) / float(ks[i + 1] - ks[i]))
	return def


## The parts shown in this pose (after swaps and hiding).
static func shown(path: String, o := {}) -> Array:
	var rig := get_rig(path)
	var out := []
	if rig.is_empty():
		return out
	for e in _layout(rig, Transform2D(), o):
		out.append(e["part"])
	return out


## The rig's outlines in the world, posed as it would be drawn: what the
## game hits. [{node, part, group, polys: [PackedVector2Array]}]; cut-outs
## don't count, they're only looks.
static func geometry(path: String, root: Transform2D, o := {}) -> Array:
	var rig := get_rig(path)
	var out := []
	if rig.is_empty():
		return out
	for e in _layout(rig, root, o):
		var p: Dictionary = e["p"]
		var pivot := Vector2(p["pivot"][0], p["pivot"][1])
		var polys := []
		for sh in p.get("shapes", []):
			if String(sh.get("mode", "fill")) == "cut":
				continue
			var pts := PackedVector2Array()
			for q in _base(sh):
				var lp: Vector2 = q - pivot
				if p.get("flip", false):
					lp.x = -lp.x
				pts.append(e["t"] * lp)
			if pts.size() >= 3:
				polys.append(pts)
		if p.get("shapes", []).is_empty():
			# Painted only: its rect stands in.
			var r: Array = p["rect"]
			var a := -pivot
			polys.append(PackedVector2Array([e["t"] * a, e["t"] * (a + Vector2(r[2], 0)), e["t"] * (a + Vector2(r[2], r[3])),
				e["t"] * (a + Vector2(0, r[3]))]))
		out.append({"node": e["node"], "part": e["part"], "group": e["group"], "polys": polys})
	return out


## How far a part's shapes reach from its joint (a hunter's body size).
static func reach(path: String, part: String) -> float:
	var rig := get_rig(path)
	var p: Dictionary = rig.get("parts", {}).get(part, {})
	if p.is_empty():
		return 0.0
	var pivot := Vector2(p["pivot"][0], p["pivot"][1])
	var r := 0.0
	for sh in p.get("shapes", []):
		for q in _base(sh):
			r = maxf(r, (q - pivot).length())
	return r


## The nearest edge of these outlines to p: [distance, point, inside any].
static func edge(p: Vector2, polys: Array) -> Array:
	var best := INF
	var at := p
	var inside := false
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			inside = true
		for i in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			var d := p.distance_to(q)
			if d < best:
				best = d
				at = q
	return [best, at, inside]


## Distance from p to the nearest of these outlines (0 inside one), and
## that nearest point.
static func gap(p: Vector2, polys: Array) -> Array:
	var best := INF
	var at := p
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return [0.0, p]
		for i in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			var d := p.distance_to(q)
			if d < best:
				best = d
				at = q
	return [best, at]


static func _hidden(name: String, by_name: Dictionary, hide: Dictionary) -> bool:
	var n = by_name.get(name)
	while n != null:
		if hide.has(n["name"]) or not n.get("vis", true):
			return true
		var par = n.get("parent")
		n = by_name.get(par) if par != null else null
	return false


static func _world(name: String, by_name: Dictionary, root: Transform2D, o: Dictionary, xf: Dictionary) -> Transform2D:
	if xf.has(name):
		return xf[name]
	var t: Transform2D
	if o.get("world", {}).has(name):
		t = o["world"][name]
	else:
		var n: Dictionary = by_name[name]
		var pz: Dictionary = o.get("pose", {}).get(name, {})
		var pos: Vector2 = pz.get("pos", Vector2(n["pos"][0], n["pos"][1])) + Vector2(o.get("off", {}).get(name, Vector2.ZERO))
		var rot := deg_to_rad(float(pz.get("rot", n.get("rot", 0.0)))) + float(o.get("rot", {}).get(name, 0.0))
		var local := Transform2D(rot, pos)
		var parent = n.get("parent")
		var base := root if parent == null or not by_name.has(parent) else _world(String(parent), by_name, root, o, xf)
		t = base * local
	xf[name] = t
	return t


static func _part(ci: CanvasItem, p: Dictionary, t: Transform2D, o: Dictionary, c: Dictionary, pn: String) -> void:
	var pivot := Vector2(p["pivot"][0], p["pivot"][1])
	var flip: bool = p.get("flip", false)
	# Pixels painted on the sheet, if any (drawn under the shapes).
	if c["tex"] != null and c["px"].get(pn, false):
		var r: Array = p["rect"]
		ci.draw_set_transform_matrix(t * Transform2D(0.0, Vector2(-1 if flip else 1, 1), 0.0, Vector2.ZERO))
		var col := Color.WHITE if not o.has("all") else Color(o["all"])
		ci.draw_texture_rect_region(c["tex"], Rect2(-pivot, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]), col)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	for sh in p.get("shapes", []):
		_shape(ci, sh, t, pivot, flip, o)


static func _shape(ci: CanvasItem, sh: Dictionary, t: Transform2D, pivot: Vector2, flip: bool, o: Dictionary) -> void:
	var mode := String(sh.get("mode", "fill"))
	var col := _colour(sh, o)
	if mode == "cut":
		col = Pal.BG  # the ground shows through (the ground is black)
	var raw := _base(sh)
	var pts := PackedVector2Array()
	for q in raw:
		var lp: Vector2 = q - pivot
		if flip:
			lp.x = -lp.x
		pts.append(t * lp)
	if pts.size() < 2:
		return
	if mode == "outline" and String(sh["type"]) != "line":
		var w := float(sh.get("ow", 1.0))
		var inset := Geometry2D.offset_polygon(pts, -w * 0.5)
		if inset.is_empty():
			return
		var ring: PackedVector2Array = inset[0]
		ring.append(ring[0])
		ci.draw_polyline(ring, col, w)
		return
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return  # self-crossing or flat: nothing to fill
	ci.draw_colored_polygon(pts, col)


## The shape as a polygon in part pixels, as the editor builds it.
static func _base(sh: Dictionary) -> Array:
	var p: Array = sh.get("pts", [])
	match String(sh.get("type", "poly")):
		"ellipse":
			var cx := float(p[0][0])
			var cy := float(p[0][1])
			var out := []
			for i in 40:
				var a := TAU * i / 40.0
				out.append(Vector2(cx + cos(a) * float(sh["rx"]), cy + sin(a) * float(sh["ry"])))
			return out
		"rect":
			var a := Vector2(p[0][0], p[0][1])
			var b := Vector2(p[1][0], p[1][1])
			return [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]
		"line":
			var a := Vector2(p[0][0], p[0][1])
			var b := Vector2(p[p.size() - 1][0], p[p.size() - 1][1])
			var n := (b - a).normalized().orthogonal() * float(sh.get("w", 1.0)) * 0.5
			return [a + n, b + n, b - n, a - n]
	var pts := []
	for q in p:
		pts.append(Vector2(q[0], q[1]))
	for k in mini(3, int(sh.get("smooth", 0))):  # Chaikin corner cutting
		var nx := []
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			nx.append(a * 0.75 + b * 0.25)
			nx.append(a * 0.25 + b * 0.75)
		pts = nx
	return pts


static func _colour(sh: Dictionary, o: Dictionary) -> Color:
	var hex := String(sh.get("color", "#ede4d3")).to_lower()
	var col := Color(hex)
	var rc: Dictionary = o.get("recolor", {})
	if rc.has(hex):
		col = rc[hex]
	if o.has("all") and String(sh.get("mode", "fill")) != "cut":
		col = o["all"]
	col.a *= float(sh.get("op", 1.0))
	return col
