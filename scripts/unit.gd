class_name Unit
extends RefCounted
## One body: the leader (you) or a hunter. It stands at a point (pixels)
## facing any angle, and takes up a few circles along its facing (body()). It does one action
## at a time: a list of steps, one a beat, that can't be stopped once
## started (only the leader's walk stops, when a hunter starts an attack).
## A step: {ph: wind / act / rec / move / wait, to: point, face: angle,
## hit: [shapes], dmg, air, hop}.

var kind := "leader"
var side := "pack"  # pack or hunters
var pos := Vector2.ZERO
var ang := 0.0
var hp := 1
var max_hp := 1
var taken := 0  # damage since its last stagger
var bleed_hits := 0  # bleeding hits toward the next bleed
var bleeding := 0  # beats of bleed left
var cur := {}  # {k, label, steps, b} or empty: free to choose
var played := {}  # the beat just played, for drawing: {from_ang, trail, step, k}
var flash := 0.0
var col := Color.WHITE


## The duel's: its pose now (RigArt.pose) and where it was when the step began.
var pose := {}
var was := {}  # {pos, ang, pose}
var burns := {}  # Acts.BURNS kind -> steps left
var calm := 0  # steps since it was last hit (its poise comes back)
var last := ""  # its last attack
var aware := false  # an enemy that has seen the hero (it acts once it has)
var heard := Vector2.INF  # where an enemy last heard the hero (INF: never)
var inspect := false  # going to look where it heard him
var rush := false  # (going there at its full walk: it was loud)
var looking := 0  # steps it's looked where it heard him
var post := Vector2.ZERO  # an enemy: where it stands...
var post_ang := 0.0  # ...and faces when it's nothing else to do
var patrol: Array = []  # points it walks round instead (none: it stands)
var patrol_i := 0  # the point it's going to
var waited := 0  # steps it's waited at that point
var crouch := false  # CROUCH: low (slower walking; hidden behind low walls and shrubs)
var sketch := {}  # an enemy: {pos, ang, pose} where the hero last saw it ({}: none)


func _init(k: String, at: Vector2, a: float) -> void:
	kind = k
	side = "hunters" if k in ["sword", "bow"] else "pack"
	pos = at
	ang = a
	max_hp = int(data()["hp"])
	hp = max_hp
	played = {"from_ang": a, "trail": [at]}


func alive() -> bool:
	return hp > 0


func idle() -> bool:
	return cur.is_empty()


func data() -> Dictionary:
	return Acts.UNITS[kind] if Acts.UNITS.has(kind) else Acts.DUEL_UNITS[kind]


## Its body if it stood at p facing a: [[centre, radius], ...].
func body(p := pos, a := ang) -> Array:
	var f := Vector2.from_angle(a)
	var out := []
	for c in data()["body"]:
		out.append([p + f * float(c[0]), float(c[1])])
	return out


## How far its body is from q (0 or less = touching).
func gap(q: Vector2, r := 0.0) -> float:
	var best := INF
	for c in body():
		best = minf(best, q.distance_to(c[0]) - c[1] - r)
	return best


## Its body's circle nearest q.
func near(q: Vector2) -> Vector2:
	var best: Vector2 = pos
	var bd := INF
	for c in body():
		var d: float = q.distance_to(c[0]) - c[1]
		if d < bd:
			bd = d
			best = c[0]
	return best


## Is any of its body in shape s?
func in_shape(s: Dictionary) -> bool:
	for c in body():
		if Shape.hits(s, c[0], c[1]):
			return true
	return false


## The step it does next beat ({} if none).
func next_step() -> Dictionary:
	if cur.is_empty():
		return {}
	return cur["steps"][int(cur["b"])]


## Its coming beats, as phases (for the strip at the bottom).
func forecast() -> Array:
	var out := []
	if cur.is_empty():
		return out
	for i in range(int(cur["b"]), cur["steps"].size()):
		out.append(String(cur["steps"][i]["ph"]))
	return out


## Beats until each of its coming hits lands: [[n, shapes], ...].
func coming_hits() -> Array:
	var out := []
	if cur.is_empty():
		return out
	var b: int = cur["b"]
	for i in range(b, cur["steps"].size()):
		var st: Dictionary = cur["steps"][i]
		for h in Battle.hits_of(st):
			out.append([i - b + 1, h["hit"]])
	return out
