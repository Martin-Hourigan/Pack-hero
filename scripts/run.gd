class_name Run
extends RefCounted
## One run: a route map of stops from left to right, Slay-the-Spire style,
## ending in a big fight. You pick the next stop from the ones joined to
## where you are. The leader's health carries over from stop to stop.
## A won fight is a level (a stat; every third level an aspect level too).
## The stop mix and its numbers are placeholders.

const COLS := 7  # stops before the last fight
const LANES := 4  # rows a stop can be on
const PATHS := 4  # routes drawn through the map (where they cross, they join)
const KINDS := [["hunt", 60], ["prey", 25], ["nest", 15]]
const PREY_HEAL := 30
const NEST_HEAL := 0.5  # of max health

## Hunting parties by how far in (column).
const PARTIES := [
	[["sword"]],
	[["sword"], ["bow"]],
	[["sword", "bow"]],
	[["sword", "bow"], ["sword", "sword"]],
	[["sword", "sword"], ["sword", "bow"], ["bow", "bow"]],
	[["sword", "sword", "bow"], ["sword", "bow", "bow"]],
	[["sword", "sword", "bow"]],
]
const BOSS := ["sword", "sword", "bow", "bow"]

var nodes: Array = []  # {id, col, lane, kind, next: [ids], party}
var at := -1  # the stop you're on (-1 = not started)
var hp := 100
var max_hp := 100
var result := ""  # "", "win", "lose"
var level := 1
var stats := {"strength": 0, "speed": 0, "defense": 0}
var aspects := {}  # aspect -> its level
var offer: Array = []  # the cards to pick from now: [{kind: stat / aspect, id}]
var rng := RandomNumberGenerator.new()


func _init(seed_ := 0) -> void:
	rng.seed = seed_ if seed_ != 0 else int(Time.get_ticks_usec())
	max_hp = int(Acts.UNITS["leader"]["hp"])
	hp = max_hp
	_make()


func _make() -> void:
	var by := {}  # Vector2i(col, lane) -> id
	var boss := {"id": 0, "col": COLS, "lane": -1, "kind": "boss", "next": [], "party": BOSS}
	nodes.append(boss)
	for p in PATHS:
		var lane := rng.randi() % LANES
		var prev := -1
		for c in COLS:
			if c > 0:
				lane = clampi(lane + rng.randi_range(-1, 1), 0, LANES - 1)
			var key := Vector2i(c, lane)
			if not by.has(key):
				var n := {"id": nodes.size(), "col": c, "lane": lane, "kind": _kind(c), "next": [], "party": []}
				if n["kind"] == "hunt":
					var opts: Array = PARTIES[mini(c, PARTIES.size() - 1)]
					n["party"] = opts[rng.randi() % opts.size()]
				nodes.append(n)
				by[key] = n["id"]
			var id: int = by[key]
			if prev >= 0 and not id in nodes[prev]["next"]:
				nodes[prev]["next"].append(id)
			prev = id
		if not 0 in nodes[prev]["next"]:
			nodes[prev]["next"].append(0)


func _kind(c: int) -> String:
	if c == 0:
		return "hunt"
	if c == COLS - 1:
		return "nest"  # a rest before the last fight
	var total := 0.0
	for k in KINDS:
		total += float(k[1])
	var r := rng.randf() * total
	for k in KINDS:
		r -= float(k[1])
		if r <= 0.0:
			return String(k[0])
	return "hunt"


## The stops you can go to next.
func choices() -> Array:
	if result != "":
		return []
	if at < 0:
		return nodes.filter(func(n): return n["col"] == 0).map(func(n): return n["id"])
	return nodes[at]["next"]


## Goes to stop id. Prey and nests happen at once; fights return the party
## to fight (then call won() or lost()).
func go(id: int) -> Array:
	if not id in choices():
		return []
	at = id
	var n: Dictionary = nodes[id]
	match String(n["kind"]):
		"prey":
			hp = mini(hp + PREY_HEAL, max_hp)
		"nest":
			hp = mini(hp + int(max_hp * NEST_HEAL), max_hp)
	return n["party"]


func is_fight(id: int) -> bool:
	return String(nodes[id]["kind"]) in ["hunt", "boss"]


## A won fight is a level: pick a stat (then, every third level, an aspect).
func won(hp_left: int) -> void:
	hp = hp_left
	if String(nodes[at]["kind"]) == "boss":
		result = "win"
	else:
		level += 1
		offer = stat_offer()


func lost() -> void:
	hp = 0
	result = "lose"


# ---------------------------------------------------------------- levels

## What the fight needs to know about the leader.
func build() -> Dictionary:
	return {"stats": stats.duplicate(), "aspects": aspects.duplicate(), "max_hp": max_hp}


## Every level: the three stats.
func stat_offer() -> Array:
	return Acts.STATS.keys().map(func(k): return {"kind": "stat", "id": k})


## Every third level: each aspect that isn't at its top level yet.
func aspect_offer() -> Array:
	return Acts.ASPECTS.keys().filter(func(k): return int(aspects.get(k, 0)) < Acts.ASPECT_MAX) \
		.map(func(k): return {"kind": "aspect", "id": k})


## Is the choice up now an aspect?
func big() -> bool:
	return not offer.is_empty() and offer[0]["kind"] == "aspect"


## Aspect levels taken, of every aspect together.
func aspect_levels() -> int:
	var n := 0
	for k in aspects:
		n += int(aspects[k])
	return n


## Takes card i of the offer. After the stat on every third level, the
## aspects come up (empty = back to the map).
func take(i: int) -> void:
	if i < 0 or i >= offer.size():
		return
	var o: Dictionary = offer[i]
	offer = []
	if o["kind"] == "stat":
		stats[o["id"]] = int(stats[o["id"]]) + 1
		if level % Acts.ASPECT_EVERY == 0:
			offer = aspect_offer()
	else:
		aspects[o["id"]] = int(aspects.get(o["id"], 0)) + 1
