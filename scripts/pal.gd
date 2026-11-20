class_name Pal
extends RefCounted
## Colours and the 3x5 pixel font. Black ground, bone white, one muted
## orange for danger, a muted colour per hunter.

const BG := Color("#000000")
const INK := Color("#e8e2d0")
const DIM := Color("#6a655c")
const DARK := Color("#2a2826")
const DANGER := Color("#d9784a")
const DANGER_DIM := Color("#5c3424")
const POISON := Color("#8e5c8e")
const HUNTERS := [Color("#6fb7a8"), Color("#d8c27a"), Color("#a89bd0"), Color("#8fb46a")]

# 3x5 glyphs, rows top to bottom, "#" = lit.
const FONT := {
	"A": ".#.#.#####.##.#", "B": "##.#.###.#.###.", "C": ".###..#..#...##", "D": "##.#.##.##.###.",
	"E": "####..##.#..###", "F": "####..##.#..#..", "G": ".###..#.##.#.##", "H": "#.##.#####.##.#",
	"I": "###.#..#..#.###", "J": "..#..#..##.#.#.", "K": "#.##.###.#.##.#", "L": "#..#..#..#..###",
	"M": "#.########.##.#", "N": "##.#.##.##.##.#", "O": ".#.#.##.##.#.#.", "P": "##.#.###.#..#..",
	"Q": ".#.#.##.###..##", "R": "##.#.###.#.##.#", "S": ".###...#...###.", "T": "###.#..#..#..#.",
	"U": "#.##.##.##.####", "V": "#.##.##.##.#.#.", "W": "#.##.########.#", "X": "#.##.#.#.#.##.#",
	"Y": "#.##.#.#..#..#.", "Z": "###..#.#.#..###", "0": "####.##.##.####", "1": ".#.##..#..#.###",
	"2": "##...#.#.#..###", "3": "##...#.#...###.", "4": "#.##.####..#..#", "5": "####..##...###.",
	"6": ".###..####.####", "7": "###..#.#..#..#.", "8": "####.#####.####", "9": "####.####..###.",
	".": ".............#.", ":": "....#.....#....", "-": "......###......", "/": "..#..#.#.#..#..",
	"?": "##...#.#.....#.", ">": "#...#...#.#.#..", "<": "..#.#.#...#...#", "+": "....#.###.#....", " ": "...............",
}


# M and W don't read at 3 wide, so they're 5.
const WIDE := {"M": "#...###.###.#.##...##...#", "W": "#...##...##.#.###.###...#"}


## Draws text in the pixel font (4 px a letter, 6 for M and W). Returns the
## width.
static func text(ci: CanvasItem, at: Vector2, s: String, col: Color, scale := 1) -> int:
	var x := int(at.x)
	var y := int(at.y)
	for ch in s.to_upper():
		var w := 5 if WIDE.has(ch) else 3
		var g: String = WIDE[ch] if WIDE.has(ch) else _glyph(ch)
		for i in w * 5:
			if g[i] == "#":
				ci.draw_rect(Rect2(x + (i % w) * scale, y + (i / w) * scale, scale, scale), col)
		x += (w + 1) * scale
	return x - int(at.x)


static func width(s: String, scale := 1) -> int:
	var n := 0
	for ch in s.to_upper():
		n += 6 if WIDE.has(ch) else 4
	return n * scale


static func _glyph(ch: String) -> String:
	return FONT.get(ch, FONT["?"])
