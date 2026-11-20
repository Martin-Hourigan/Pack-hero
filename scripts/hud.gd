class_name Hud
extends Node2D
## Top: the leader's health. Bottom: the coming beats, the
## leader's (or what the tool under the mouse would take) over each
## hunter's, then the tools with their keys. And the result.

var main = null

const STRIP_X := 64
const STRIP_W := 10  # px a beat
const BEATS := 30
const ROW0 := 178
const ROW_H := 8


func _draw() -> void:
	var f: Battle = main.battle
	if f == null or main.mode != "run":
		return
	var l: Unit = f.leader
	draw_rect(Rect2(4, 3, 100, 4), Pal.DARK)
	draw_rect(Rect2(4, 3, round(100.0 * maxf(l.hp, 0) / l.max_hp), 4), Pal.INK)
	# Where on the bar the next stagger comes.
	var at := l.hp + l.taken - Acts.STAGGER["at"] * l.max_hp
	if at > 0.0:
		draw_rect(Rect2(4 + floor(100.0 * at / l.max_hp), 2, 1, 6), Pal.DANGER_DIM if at < l.hp else Pal.DIM)
	Pal.text(self, Vector2(356, 3), str(f.beat_n), Pal.DIM)
	_strip(f)
	_tools(f)
	if f.result != "":
		_result(f)


## Each row: its coming beats. Wind-up dim, the hit bright, recovery dark,
## moving a thin line.
func _strip(f: Battle) -> void:
	var rows := [f.leader]
	rows.append_array(f.hunters())
	for r in rows.size():
		var u: Unit = rows[r]
		var y := ROW0 + r * ROW_H
		var mine: Array = u.forecast()
		var label := String(u.cur.get("label", ""))
		var col: Color = u.col
		if u == f.leader and (u.idle() or f.reaiming()):
			var a: Dictionary = main.preview()
			if not a.is_empty():
				mine = []
				for st in a["steps"].slice(int(a.get("b", 0))):
					mine.append(String(st["ph"]))
				label = String(a["label"])
				col = col.darkened(0.3)
		if label == "":
			label = String(u.data()["label"]) if u != f.leader else ""
		Pal.text(self, Vector2(4, y), label, col if u == f.leader else u.col.darkened(0.2))
		var fire := Pal.DANGER if u.side == "hunters" else col
		for i in mini(mine.size(), BEATS):
			var bx := STRIP_X + i * STRIP_W
			var rr := Rect2(bx, y, STRIP_W - 2, 5)
			match String(mine[i]):
				"wind":
					draw_rect(rr, fire.darkened(0.6))
				"act":
					draw_rect(rr, fire)
				"rec":
					draw_rect(rr, Pal.DARK)
				_:
					draw_rect(Rect2(bx, y + 2, STRIP_W - 2, 1), col.darkened(0.5))
	draw_rect(Rect2(STRIP_X - 3, ROW0, 1, rows.size() * ROW_H - 3), Pal.DIM)


func _tools(f: Battle) -> void:
	var x := 4
	var y := 207
	for t in main.tools():
		var s := "%s %s" % [t[0], t[1]]
		var col: Color = Pal.INK if t[3] else Pal.DIM
		var left := f.cooling(t[2]) if t[2] != "" else 0
		if left > 0:
			# Still cooling down: dim, with the beats left.
			s += " %d" % left
			col = Pal.DIM.darkened(0.45)
		x += Pal.text(self, Vector2(x, y), s, col) + 8


func _result(f: Battle) -> void:
	draw_rect(Rect2(0, 80, 384, 40), Color(0, 0, 0, 0.85))
	var s := "THE HUNTERS FALL" if f.result == "win" else "THE PACK FALLS"
	var w := Pal.width(s, 2)
	Pal.text(self, Vector2(192 - w / 2.0, 88), s, Pal.INK if f.result == "win" else Pal.DANGER, 2)
	var sub := "SPACE"
	Pal.text(self, Vector2(192 - Pal.width(sub) / 2.0, 104), sub, Pal.DIM)
