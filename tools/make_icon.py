import sys
from PIL import Image

import os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/'
N = 32
BG = (0x2a, 0x28, 0x26, 255)
BLADE = (0xe8, 0xe2, 0xd0, 255)
BLADE_D = (0xa8, 0xa2, 0x94, 255)
STEEL = (0x8a, 0x84, 0x78, 255)
HILT = (0x5a, 0x46, 0x32, 255)
WOOD = (0x7a, 0x5a, 0x3e, 255)
WOOD_D = (0x5e, 0x45, 0x2f, 255)
ORB = (0xa8, 0x9b, 0xd0, 255)
ORB_L = (0xd6, 0xcf, 0xec, 255)
OUT = (0x12, 0x11, 0x10, 255)

px = {}


def put(x, y, c):
    if 0 <= x < N and 0 <= y < N:
        px[(x, y)] = c


# Staff: bottom right to top left, orb at the top.
for i in range(24):
    x, y = 27 - i, 28 - i
    put(x, y, WOOD)
    put(x + 1, y, WOOD_D)
for x, y in [(4, 3), (5, 3), (3, 4), (4, 4), (5, 4), (6, 4), (3, 5), (4, 5), (5, 5), (6, 5), (4, 6), (5, 6)]:
    put(x, y, ORB)
put(4, 4, ORB_L)

# Sword: pommel bottom left, tip top right.
for i in range(18):
    x, y = 10 + i, 21 - i
    put(x, y, BLADE)
    put(x + 1, y, BLADE_D)
put(28, 3, BLADE)
for i in range(4):
    put(5 + i, 26 - i, HILT)
put(4, 27, STEEL)
put(3, 28, STEEL)
put(4, 28, STEEL)
# Crossguard across the blade, running down-right.
for i in range(-2, 3):
    put(9 + i, 22 + i, STEEL)
    put(10 + i, 22 + i, STEEL)

# Kite shield in front.
shield = []
for y in range(8, 28):
    if y < 11:
        half = 6 + (y - 8) // 2
    elif y < 16:
        half = 7
    else:
        half = max(0, 7 - (y - 15) * 7 // 12)
    for x in range(16 - half, 16 + half):
        shield.append((x, y))
ss = set(shield)
for (x, y) in shield:
    edge = any((x + dx, y + dy) not in ss for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])
    put(x, y, STEEL if edge else WOOD)
# Ridge down the middle.
for y in range(10, 26):
    put(15, y, WOOD_D)
    put(16, y, WOOD_D)
# Outline around everything.
solid = set(px)
for (x, y) in list(solid):
    for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
        q = (x + dx, y + dy)
        if q not in solid:
            put(*q, OUT)


def art(bg):
    im = Image.new('RGBA', (N, N), BG if bg else (0, 0, 0, 0))
    for (x, y), c in px.items():
        im.putpixel((x, y), c)
    return im


def scaled(size, k, bg, back=None):
    im = Image.new('RGBA', (size, size), back or (0, 0, 0, 0))
    a = art(bg).resize((N * k, N * k), Image.NEAREST)
    o = (size - N * k) // 2
    im.alpha_composite(a, (o, o))
    return im


scaled(192, 6, True).save(R + 'icon.png')
scaled(432, 8, False).save(R + 'icon_fg.png')
Image.new('RGBA', (432, 432), BG).save(R + 'icon_bg.png')
scaled(384, 12, True).save(sys.argv[1])
print('ok')
