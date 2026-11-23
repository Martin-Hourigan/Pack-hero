# Pack-hero: the plan

A copy of Pack-free (2026-11-20) where you are a HERO, like in GrimTactics,
against a big KNIGHT with a greatsword. The raptor fight is kept as it was
(title: R), for a boss or a drake/dragon later; it isn't worked on for now.

Nothing new goes in until it's agreed here. One thing at a time, each
finished before the next. Labels as below (DECIDED / PLACEHOLDER / LATER /
OPEN).

## The duel

DECIDED (Martin, 2026-11-20)
- Free movement, as Pack-free.
- Every character is a top-down PUPPET (the puppet editor's rigs).
- The swings are SIMULATED: the weapon's hit is the puppet's actual blade,
  its real size, so dodges can be planned against it.
- Attacks and movement go in set STEPS. A swing is several steps (about 5),
  not one a frame.
- The big knight is the enemy; the hero has health, stamina and flasks as
  in GrimTactics.
- Every weapon has a light and a heavy attack.

BUILT (2026-11-20), all numbers PLACEHOLDER (scripts/acts.gd, DUEL_UNITS,
HERO, KNIGHT)
- Each attack is a clip on its puppet with one frame a step: frame 0 the
  rest pose, frame n the pose at the end of step n. Wind-up, swing, way back.
- The blade (the puppet's "blade" node) hits a body it passes over. Between
  two steps it's checked 6 times, both bodies moving as they go, so a fast
  blade can't skip past. A swing hits a body once.
- Only some swing steps hit (the overhead only on its last 2, once the blade
  is low; raised, the blade is drawn short, as seen from above).
- Knight: SWEEP (wind 3, swing 5, back 2), BACKHAND (only straight after a
  sweep, 60%; swing 5, back 3), OVERHEAD (wind 4, swing 5 hitting on the
  last 2, back 3; steps forward 2 px a swing step). Chops when you're
  nearly straight ahead and not too close; otherwise sweeps. Turns 25
  degrees a wind-up step toward you, then is locked. Walks 3 px a step.
  600 health; hits 50 / 40 / 80. Greatsword blade 36 px.
- Hero: 1 MOVE (4 px a step), 2 ROLL (4 steps of 8 px; hits miss on the
  first 2), LIGHT (wind 1, swing 4), HEAVY (wind 3, swing 5 hitting on
  the last 2, steps in), 5 FLASK (2, heal 100, 5 steps), SPACE wait a
  step. 200 health, stamina 100 (light 20, heavy 35, roll 25; 4 back a
  step when not attacking, rolling or drinking). A hit pushes you 6 px back
  and you lose 2 steps. Longsword blade 15 px.
- The knight's swing still to come is drawn: the ground its hitting steps
  sweep (the next one brightest), the blade's ghost at each step, and the
  steps left at each blade tip. The hero's tool shows the same at the mouse.
- The knight pushes the hero aside; the hero stops at the knight.
- Turn by turn: steps play until your action ends, then wait for you. A
  walk stops when the knight starts an attack.

PLACEHOLDER
- The puppets and swings were made by a script (from the sketch); open them
  in the puppet editor (art/knight.rig.json, art/hero.rig.json) to change.
- The hero's facing turns straight to where you aim.
- The knight has no stagger / poise; the hero only the 2 lost steps.
- The ghosts show the whole swing from his current facing; the wind-up's
  turning can still move it.

HANDS (2026-11-20)
DECIDED (Martin)
- Both hands can hold something. The bottom row has a left hand and a right
  hand button, named for the item in it (LONGSWORD, KITE SHIELD, WOODEN
  STAFF; shortened if too long). Tapping one opens a menu of what the item
  can do: a weapon its light and heavy, a shield BLOCK, a wand or staff its
  spells.
- Kite shield BLOCK: a hit from the front does no damage. A block is a step
  facing the way you pick; the tool stays picked until you pick another, so
  you keep blocking a step at a time.
BUILT: left hand kite shield (BLOCK), right hand longsword (LIGHT, HEAVY).
A hand's button shows its picked option underneath. PC: 3 and 4 open the
left and right hand's menus.
PLACEHOLDER
- "The front" = the half in front of where he faces (180 degrees). Where
  the blade first touches him decides it.
- A block costs no stamina, and stamina comes back while blocking.
- A blocked swing is spent: it can't come round and hit from the side.
- On the phone a block is one tap (no second tap to confirm).
- The hero now holds the longsword in one hand; the shield and the block
  pose were added to art/hero.rig.json by a script.
- No wand / staff / spells yet; the menu is ready to list them.

GEAR (2026-11-20)
DECIDED (Martin)
- New items: two-handed claymore and bow, one-handed crossbow, a staff.
- Bow: ARROW, FIRE ARROW and HEAVY SHOT (its special, a heavier shot); it
  draws back first (wind-up).
- Crossbow: BOLT and POISON BOLT, no real wind-up, but it must be loaded
  (RELOAD) before it shoots.
- Staff: BOLT and HEAVY BOLT. Spells use stamina and have a cast limit per
  rest; 20 for now.
BUILT
- Gear screen after THE KNIGHT: tap a hand to go through the items; a
  two-handed item fills both hands. One-handed items go in either hand (the
  left hand plays the clips mirrored).
- Shots fly a set distance a step and hit the first body they reach. The
  preview shows a mark where it'll be each step and the steps until it hits.
- RELOAD from the menu happens at once (no aiming); a spell's casts left
  show in its menu; empty crossbow or no casts: the hand's button wiggles.
PLACEHOLDER
- All the numbers (Acts.ITEMS, Acts.SHOTS, Acts.BURNS). Fire: 6 a step for
  5 steps. Poison: 3 a step for 12 steps. Hit again: back to full.
- Casts are per spell (20 each), for the whole fight (there's no rest yet).
- The crossbow starts loaded; reload takes 4 steps; it can't be loaded with
  one kind of bolt: you pick BOLT or POISON BOLT when you shoot.
- Arrows and bolts are unlimited.
- The heavy shot uses a normal arrow.
- A shot in the air only moves when steps play (like his swings), so after
  shooting you wait (or act) for it to arrive.
- Items' looks and clips (made by a script, scratchpad make_hero.py; the
  hero rig was rebuilt for this).

STAGGER (2026-11-20)
DECIDED (Martin): "we need a stagger mechanic".
BUILT, PLACEHOLDER: the knight has 100 poise. Your hits' damage adds up
(burns don't); at 100 he staggers: what he was doing stops, 4 steps reeling.
8 steps without a hit and it's back to 0. A thin line under his health bar
shows it filling. The hero's own stagger is still the 2 lost steps.

TWO ITEMS A HAND, TWO-HANDING, TRICK WEAPONS (2026-11-20)
DECIDED (Martin; "yes for all assumptions for now")
- Two items in each hand. The gear screen has two slots a hand; in the
  fight a hand's menu has SWAP, to its other item (1 step).
- Two-handing: a one-handed melee weapon's menu has TWO HANDS (back with
  ONE HAND). The other hand's item is put away and its button goes until
  you let go. Two-handed, a melee weapon can BLOCK (aimed like the
  shield's); a weapon block stops half the damage. Two-handing does
  nothing else.
- The claymore can be held in one hand: more stamina, less damage than
  two-handed. The bow stays two-handed only.
- Trick weapons, like Bloodborne's: TRANSFORM in the menu switches form
  (1 step); no transform attacks yet.
  - QUARTERSTAFF (two-handed): LIGHT a quick strike, HEAVY a wide sweep;
    turns into a BOW (ARROW, FIRE ARROW, HEAVY SHOT).
  - GREATSPEAR (two-handed): LIGHT a long thrust, HEAVY a lunging thrust;
    separates into a SPEAR STAFF (left hand: BOLT, HEAVY BOLT) and a
    SHORTSWORD (right hand: LIGHT a fast stab, HEAVY a slash, shorter and
    cheaper than the longsword). The halves stay together; TRANSFORM joins
    them back.
PLACEHOLDER
- All the new numbers. One-handed claymore: about 1.5x the stamina, 0.7x
  the damage.
- Going to two hands and back takes 1 step too.
- A two-handed-only weapon (bow, quarterstaff, greatspear) can BLOCK too.
- A weapon-blocked hit does half damage but doesn't knock you back.
- A weapon keeps its form when swapped away and back.
- Casts are counted per item (two staffs would share them); a crossbow's
  loaded or not per slot.
- Swapping to a two-handed item takes both hands; swapping away from it,
  if the other hand's item is two-handed too, that one takes both.
- The shortsword can't be two-handed (the spear staff is in the other hand).
- SWAP, while the greatspear is split, is in the menu of the hand whose
  slot it's in (the SHORTSWORD's, when it's in the right hand).
- New items' looks and clips made by the script (scratchpad make_hero.py).
BUILT: all of the above. Gear screen: two slots a hand, the top one held
first (the second dimmer). Starting gear: kite shield / staff, longsword /
claymore.

TOGGLES: LOCK, 2H, GUARD (2026-11-20)
DECIDED (Martin)
- A two-handed toggle and a lock-on toggle; shielding is a toggle too.
- The block lasts until you dodge (roll). Attacks don't cancel it for now;
  when there are weighted attacks, the heavy ones could.
- While shielding, stamina comes back slower.
- 2026-11-21: attacks DO cancel it (the longsword's should). Some don't:
  standard spear attacks keep the shield up while attacking; if hit, fine,
  they keep attacking while getting hit. A one-handed PIKE added for it.
- Everything drops it except certain attacks for certain weapons, and
  walking ("easier that way than list everything that does"). Waiting
  doesn't cancel it either. Holding WAIT goes through steps slowly.
BUILT
- Three toggles above the bottom right, lit when on: LOCK (Q), 2H (E),
  GUARD (F). BLOCK, TWO HANDS and ONE HAND left the menus.
- LOCK: tap it, then tap (click) an enemy to lock on to it (Martin: the
  cursor turns into a reticle, and it needs an enemy picked to go ahead).
  Until then LOCK blinks and other taps on the arena do nothing; LOCK again
  stops picking. Locked: corner marks on that enemy; the hero faces it
  while walking, waiting, drinking; shots (arrows, bolts, spells) aim
  themselves at it (on the phone, one tap does them). Melee swings are
  still aimed (Martin: their reach shows, so it makes sense not to have
  them auto), and so are MOVE and ROLL. LOCK while locked lets go; it lets go when that enemy dies.
  On the phone (no cursor) every enemy pulses with a reticle while picking.
- 2H: the right hand's item in two hands, else the left's; again lets go.
  1 step.
- GUARD: the shield's (or the two-handed weapon's) block is up whatever
  the hero does, in front of where he faces (a faint arc shows it), until
  anything but walking, waiting or a "keeps guard" attack (roll, attacks,
  FLASK, SWAP, 2H, TRANSFORM all drop it).
- Holding WAIT (or Space) waits a step every 0.3 s (PLACEHOLDER) until let
  go. Nothing to block with: GUARD
  wiggles.
- PIKE (either hand): its LIGHT ("keeps guard") leaves GUARD on, and the
  shield blocks while it thrusts; its HEAVY drops GUARD.
PLACEHOLDER
- Starts with LOCK and GUARD off. Turning LOCK or GUARD on or off takes no
  step.
- Guarding: stamina back 2 a step instead of 4. Walking with it up isn't
  slower.
- Pike LIGHT keeps the guard, HEAVY drops it. Pike numbers: LIGHT wind 1,
  swing 2, back 1, dmg 25, st 15; HEAVY wind 2, swing 3, back 2, lunge 3,
  dmg 50, st 30. Its look: shaft 20 px with a small steel head.
- Swapping or transforming to something with no block turns GUARD off.

GEAR GRID (2026-11-20)
DECIDED (Martin): the gear screen is a grid of icons; hovering shows the
name (it used to cycle through them all).
BUILT: two slots a hand down each side (top held first), the items in a
grid 5 across between. Tap a slot (it lights), then an item to put it there;
the item in the picked slot lights in the grid. The name of what the mouse
is over shows under the grid; on the phone (no hover), what was last
tapped.
PLACEHOLDER: icons are the puppet's own item art (long ones diagonal, as
big as whole pixels fit). The kite shield is seen from above, so its icon
looks like a thin curve (like a bow); a face-on icon would need drawing.

TUNING (2026-11-20, Martin)
- Quarterstaff 20% longer (more range). Claymore: bigger crossguard, blade
  20% shorter.
- Bow and staff attacks need a bigger wind-up. PLACEHOLDER: 2 more steps
  each: ARROW / FIRE ARROW 5, HEAVY SHOT 7, BOLT 3, HEAVY BOLT 5 (the
  quarterstaff's bow and the spear staff too). The draw / raise is spread
  over the longer wind-up.

ROOMS AND ENEMIES (2026-11-20; the run became ONE MAP 2026-11-21)
DECIDED (Martin: "go with your picks"): a short run of rooms (4), the knight
in the last; doorways always open; pillars in some rooms; enemies stay in
their room; dying = back to room 1, no refills between rooms (a rest spot
later). Basic enemies: SOLDIER (short sword, quick, weak, staggers easily),
SPEARMAN (keeps a bit of distance, thrusts), ARCHER (keeps away, shoots);
2, 3, 4 a room. Enemies can't hurt each other.
Also (Martin): line of sight: never seen = blank, seen before = greyed (you
see the room, not the enemies), remembered after dying. Pan as far as the
hero being at the edge of the screen. The menus down the sides so the view
is more square. Ranged attacks have limits; a GREATBOW reaches the
farthest. Agreed: rooms up to 2x the screen, the camera follows, drag to
look; enemies notice you once they see you; lock only what you can see;
ranges staff 100, crossbow 120, bow 160, greatbow 240 px; greatbow
two-handed ARROW + HEAVY SHOT, longer wind-up, harder hits, no fire arrow.
BUILT (step 3-4): the run (Acts.ROOMS): 4 rooms, doorways in the right
wall, pillars in rooms 2 and 3, the knight in room 4; dying starts again
in room 1, the hero's seen squares kept. Sight in 4 px squares (Acts.FOG):
the floor in sight is very dark grey, seen before is greyed back toward
black, never seen is black (walls too); enemies, their swings and shots
only show where you can see. The view is a 216 px square in the middle;
the left column has health, stamina, flasks, MOVE, ROLL, the left hand,
LOCK, back; the right column the knight's health (in his room), FLASK,
WAIT, the right hand, 2H, GUARD. A hand's menu opens on the view beside
its button. Drag the view (right mouse on PC) to look around; doing
anything puts it back. On the phone a tap on the view is done when you let
go (so a drag can look around instead). Shots stop at their range; the
aim preview too.
BUILT (step 1-2): any number of enemies in a fight (Acts.FOES), each
choosing its own attacks; the hero's swing hits every enemy it sweeps; a
walk stops when any enemy starts an attack; won when all are dead. Their
swings show as ghosts like the knight's; the smaller ones get a small
health bar over them once hurt. Puppets by scratchpad make_foes.py.
PLACEHOLDER: all their numbers (Acts.SOLDIER / SPEARMAN / ARCHER), looks,
and AI; an archer waits 3 steps after each shot. The rooms' sizes, pillars
and who's where. Sight has no distance limit (a room with no pillars is
all seen at once). Pillars don't stop blades. The camera can look past the
room's edge (blank). Greatbow numbers and look. Dev: --foes=..., --room=N.


ONE MAP, DOORS, AGGRO (2026-11-21)
DECIDED (Martin): rooms were very hard to get between (the doorway too
close to the wall); one connected map instead. Doors separate the rooms
for now; the boss has a door that closes behind you when you enter.
Enemies only come for you once they see you AND you're within aggro range.
Agreed: the four rooms become areas of one map, snaking (1 top left, 2 to
its right, 3 below 2, the knight's left of 3), joined by halls; anything
not floor is wall (blocks walking, shots, sight); fog over the whole map;
dying: back to the start of area 1, everything reset, seen kept.
BUILT: Acts.MAP (areas, halls, doors, pillars, foes). Walking into a closed
door opens it (that step), and the walk goes on through. The boss door
(dull red) shuts once you're fully in the knight's area and won't open
while he lives. Won when the knight dies. Enemies wake on sight within
Acts.AGGRO (or when hit), then keep after you; out of a straight line
they find the way round walls and pillars (a closed door stops them).
Tapping somewhere out of a straight line, the hero walks the way round
too (the dots show it). Walking into a wall at a slant slides along it.
Archers walk until they can see you before shooting.
PLACEHOLDER: halls 40 px wide, 60/60/40 long; doors 8 px thick, mid-hall;
aggro 100 px for every enemy (the knight too); enemies can't open doors;
enemies hit before they've seen you still wake; once awake they never give
up; the walls are thin lines on the edge of the wall squares. Dev:
--room=N starts in area N.

HIDDEN (2026-11-21)
DECIDED (Martin): like a D&D thief, attacking from hiding for a sneak
attack; make a status for not spotted / hidden first. The sneak attack
itself will be a skill on a weapon or a catalyst (maybe a thief catalyst),
thought about later.
BUILT: Duel.hidden_from(enemy): the hero is HIDDEN from an enemy until it
spots him (sees him within aggro, or is hit). A shut eye over each enemy
he's hidden from. It does nothing yet.
PLACEHOLDER: hidden is per enemy (as in D&D, hidden from a creature); the
shut eye; once spotted there's no hiding again (they never give up).

SHRUBS, LOW WALLS, CONES, TURNING (2026-11-21)
DECIDED (Martin): shrubs and low walls to hide behind or within. Arrows
and spells pass over both. You can look out of a shrub you're in, but
your vision range in one is much lower. Enemies have a cone of vision;
turn speed applies to all their turning. Enemies can hide in shrubs and
behind low walls too (none do it on purpose yet; later maybe ambushes).
An enemy that's lost sight of you stays alerted (not built: they still
just keep after you). Put some walls and shrubs around and see.
BUILT: Acts.MAP shrubs and low walls. Shrubs: walk through, nobody sees
through one; in one you see Acts.SHRUB_SIGHT px; someone in a shrub is
seen only by someone in it or touching it. Low walls: block walking; you
see over them; someone within Acts.LOW_HIDE px of one is hidden from
the far side. Shots go through and over both. Enemies spot you only in
Acts.CONE ahead of them. Each enemy's `turn` (degrees a step) now limits
all its turning. The hero only sees and locks on to enemies he can see
by these rules too.
PLACEHOLDER: cone 120 degrees; shrub sight 40 px; low wall hide 8 px;
turn speeds are the old wind-up ones (knight 25, soldier 40, spearman and
archer 30); where the shrubs and walls are; their look (muted green,
lighter-edged block).
OPEN: ALERTED status: later.

CROUCH (2026-11-21)
DECIDED (Martin): crouching behind a low wall, you can't see anything
past the wall. Standing next to a low wall, you can't see anything
crouching right next to the far side, and that grows the further you are
from the wall. Crouching: slower walking, less sound. Besides that (and
sound) it doesn't help at all. Anything but moving and waiting takes you
out of crouch (you can get a ranged attack off, but not stay crouched;
maybe a special weapon could, or staying crouched after a crouching melee
kill, later). The rules are the same for everyone. The start of the
enemies' cones shows while crouching.
BUILT: a CROUCH toggle (C, left side). Unit.crouch; Acts.HERO crouch_walk;
low walls as above (Acts.LOW_HIDE, LOW_SHADOW, LOW_SPREAD); standing next
to a low wall no longer hides you. Dev: --crouch starts crouched.
PLACEHOLDER: crouch walk 2 px a step (half); seeing nothing past a low
wall when crouching within 8 px of it; the shadow 8 px + 1 px for every
4 px the viewer is from the wall; the cone starts are two dotted lines
16 px long; no crouching pose; being hit doesn't stand you up; crouching
mid-walk only slows the next walk.

SEEING OVER (2026-11-22; replaces the low-wall shadow above)
DECIDED (Martin): standing, only a short distance past a shrub or low wall
is hidden, and only to someone crouching or something low (a dog, a rat,
a spider); crouching, shrubs and low walls block vision like a full wall
(the fog too). A small sketch of an enemy where it was last seen before
it disappeared or became hidden.
BUILT: standing, you see over shrubs and low walls; someone crouching (or
an enemy with "low") within Acts.LOW_SHADOW of one, past it, is hidden;
in a shrub is still hidden unless you touch it or are in it; from in a
shrub, still only Acts.SHRUB_SIGHT. Crouching, shrubs and low walls stop
sight and the fog. Unit.sketch: an enemy out of sight is drawn flat
grey where last seen, until seen again, dead, or you see the spot and
it's gone.
PLACEHOLDER: the short distance 8 px (the same however far away you
are); the sketch colour; no low enemies exist yet.

MOVE'S WAYS OF WALKING (2026-11-22)
DECIDED (Martin): with MOVE selected, tap/click it again for its
settings: click and that's where you'll go (as before); hold the button
down and the hero walks straight toward the cursor, adjusting as it
moves, and letting go just stops him (not on to that point); and one
step's worth in that direction at a time, good for combat.
BUILT: main.walk "to" / "hold" / "step" (WALK TO, HOLD, 1 STEP; shown
under MOVE). Duel "steer": one step straight toward a point (slides along
walls; no way round). HOLD steps every HOLD_T while held. The preview
shows the one step for HOLD and 1 STEP. main.STEER_T.
PLACEHOLDER: the names; HOLD's pace 0.12 s a step, one straight after
another with no gap (Martin: 0.3 with a pause was jarring, too stilted); an
enemy starting an attack stops HOLD until you press again; on the phone
1 STEP is aim then tap again, like the other tools, and HOLD steers
where your finger is (dragging steers rather than moving the view);
WALK TO is the default.

THE VIEW (2026-11-22)
Tried: the view leaning toward the mouse. Martin: "i actually hate the
auto scroll around": taken out.
Moved off with the right button (or a drag), the view no longer snaps
back when you do something: it scrolls back (main.HOME_RATE, eased).
PLACEHOLDER: the scroll back takes about a second.

SOUND (2026-11-22)
DECIDED (Martin): weapons and armour make noise; noise is linear, every
item's noise added up. It goes out from you in rings: the outer 30 is
low (an enemy turns, not suspicious), the 30 inside that medium (turns
and comes to look), anything nearer loud (turns and is alerted). 40
noise: 10 medium, then the full 30 low; low-noise gear never gets past
low; past 60 the loud just grows. Plate mail in a shrub: the enemy
comes to look and finds you. The ring shows only while crouching, and
so does whether you've been spotted (the shut eyes); standing, noise
still works, you just don't see it.
BUILT: ITEMS noise; Duel.noise() (held items added up, halved
crouching); anything but waiting makes it, each step; Acts.NOISE_BAND.
Low: the enemy turns to where it heard you. Medium: it walks there and
stays, facing it. Loud: it spots you. Walls and closed doors stop sound.
Dotted rings while crouching; the shut eyes now only while crouching.
PLACEHOLDER: bands 30 px; crouching halves noise; waiting is silent;
attacks no louder than walking; loud = spotted (there's no ALERTED yet);
after looking it stays there; pillars, shrubs and low walls don't stop
sound; item noise: claymore, greatspear 30; greatbow 20; longsword,
kite shield, pike, quarterstaff, crossbow 15; staff, bow 5; no armour yet.

SPOTTED FROM OFF THE VIEW (2026-11-23)
DECIDED (Martin): an enemy off the screen that spots you: a little ! in
a circle flips up at the side, then a dot on the edge of the screen says
where it is, while it knows of you.
BUILT: DuelHud._alerts: the ! flips up on the view's edge on the line
from the hero toward it, then a 3 px dot there; gone once it's on the
view, dead, or doesn't know of him. Enemies that know of him from the
start don't flip up.
PLACEHOLDER: flips up in 0.12 s, stays 1.2 s; 6 px in from the edge;
the danger orange; shows standing or crouching; an enemy on the view but
out of sight (behind a wall) gets no mark; a dot, no arrow.
ON THE VIEW (2026-11-23), DECIDED (Martin): an enemy on the screen that
spots you gets a smaller ! too (like Metal Gear Solid).
BUILT: a smaller ! in a circle (3 px) flips up over its head, the same
timing. PLACEHOLDER: only if you can see it; 7 px over its body.
VIEW RANGE (2026-11-23), DECIDED (Martin): enemies see further.
PLACEHOLDER: Acts.AGGRO 100 -> 160 px.

LIGHT (2026-11-23)
DECIDED (Martin): lighting and shadows, for stealth. Light sources like a
campfire or a torch: a torch either side of each door, a lantern on every
enemy, a campfire somewhere to see what one looks like. Later, outside or
an overworld: a sun, all the light from one direction, or overhead with
no shadows except from trees; a few places it could be.
DECIDED (my suggestions, not objected to): fixed lights first; walls,
pillars and closed doors throw shadows, low walls and shrubs don't;
three steps, lit / dim / dark; less light, seen from less far, the same
for everyone.
BUILT: each square lit, dim or dark (Duel.light, light_at); MAP dark
(lit only by its lights; maps without it are all lit, like the knight's
arena); MAP lights; Acts.LIGHTS torch / campfire / lantern; Acts.SUNS
noon / morning / evening (MAP sun; dev --sun=morning shows the map
outside). Spotting: someone dim is seen only within DIM_SIGHT, dark
within DARK_SIGHT, lit as far as the one looking sees (an enemy: AGGRO;
the hero: what's in sight). Dim and dark squares in sight drawn darker
(puppets aren't); torch, campfire and lantern drawn small.
PLACEHOLDER: torch lit 24 / dim 56 px, campfire 40 / 88, lantern 12 /
32; DIM_SIGHT 80, DARK_SIGHT 40; shading 0.4 dim, 0.7 dark; the sun's
shadows 24 px (morning from the east, evening from the west), shadow =
dim; torches on the side you come to each door from; the campfire at
(700, 140) in the second area; lights don't flicker (only the flames);
no trees yet; the hero carries no light; crouching doesn't change it.
IN THE DARK (2026-11-23), DECIDED (Martin): anyone in the dark (the
hero too) is drawn as a light grey outline, not in colour; dim is full
colour. BUILT: DuelView._unit. PLACEHOLDER: outline #a29d92, 1 px, filled
#070606; enemies carry lanterns, so it's mostly the hero.
DITHERED EDGES (2026-11-23), DECIDED (Martin): the light dithers out
instead of hard lines, still with lit and dim areas. BUILT:
shaders/shade.gdshader (the fog and the light; the light smoothed and
dithered 4x4 between lit / dim / dark, on the world's pixels). Only the
look: who's seen still goes by the square's own lit / dim / dark.
PLACEHOLDER: smoothed over about 3 squares (12 px) each way.
Into the dark, too (2026-11-23), DECIDED (Martin): going into the dark
dithers into the outline the same way; half in, half of you is outline.
BUILT: the outlines drawn over everyone, shown only on the pixels that
are dark (shaders/dark.gdshader; shaders/light.gdshaderinc shared with
the floor).

BOW TIMING (2026-11-23)
DECIDED (Martin): drawing a bow takes longer, and so does the end of the
shot (not a cooldown), so you can't loose two arrows before the enemy
knows of the first.
BUILT: wind and recovery longer; the bow clips stretched to fit.
PLACEHOLDER: bow and quarterstaff bow arrow / fire arrow wind 5 -> 7,
rec 1 -> 3; heavy shot wind 7 -> 9, rec 1 -> 3; greatbow arrow wind
7 -> 9, rec 1 -> 3; heavy shot wind 9 -> 11, rec 2 -> 4. Crossbow and
staff unchanged.

LIGHT ATTACKS STEP FORWARD (2026-11-23)
DECIDED (Martin): the melee LIGHT attacks carry you forward a little, as
in Dark Souls, not slashing on the spot. The pike's LIGHT with the
shield's GUARD up stays put; without GUARD it steps forward too.
BUILT: on the swing steps only (like the heavies).
PLACEHOLDER ("fine for now"): about 4 px in all: longsword 1 px a swing
step (4), claymore 1 (5), quarterstaff / greatspear / pike / shortsword
2 (4).

SOUND, YELLS, PATROLS, SIGHT, BACK ATTACKS, DAGGER (2026-11-23)
DECIDED (Martin):
- Hearing never spots you; only sight does. A low sound: it turns to
  where it was. Medium: it walks over at half speed to look. Loud: it
  goes over at full speed. Finding nothing, it goes back to its post or
  patrol.
- An enemy yells when it spots you, or when you hit it from hiding; the
  yell reaches further than other sound and alerts anyone who hears it,
  so a fight in a room pulls in most of the room.
- Patrols: some enemies walk a route; others stand (a guard at a fire).
- Enemies see further; walking round to their back mustn't be trivial.
- BACK ATTACKS, and you can be heard first: heavy gear (and later armour)
  gets you caught. A DAGGER.
BUILT:
- Sound as above. After reaching the spot (or just turning, for a low
  sound) it looks LOOK_STEPS, then walks back at half speed.
- Yell: hears it within YELL px, not through walls or closed doors; those
  that hear it come for you (and get the "!"). They don't yell on in turn.
  One killed in a single blow doesn't yell.
- Patrol: a list of points on the map's foe, walked round at half speed,
  waiting PATROL_WAIT at each. The test map: the two soldiers in the big
  lower-right area patrol; the rest stand.
- Sight: a wider cone, further, and a sense all round when you're near
  and standing (not crouching).
- (Replaced, same day, by FROM BEHIND and BACKSTAB below.)
- DAGGER: one-handed, quiet, fastest light; its BACKSTAB does more.
  Its art is a short shortsword; its clips are the shortsword's, quicker.
  On the gear screen (now 6 across).
PLACEHOLDER: AGGRO 160 -> 200, CONE 120 -> 180 degrees, NEAR_SENSE 24,
YELL 160, CALM_WALK half, LOOK_STEPS 6, PATROL_WAIT 4; BACK_ATTACK reach
16, behind 45 degrees, 3x damage (dagger 5x), hold 4 (now BACKSTAB's). Dagger: noise 5;
light wind 1 / swing 1 / rec 1, 12 dmg, 10 st, 2 px forward; heavy 2/2/2,
24 dmg, 20 st, 2 px forward each swing step. Patrol routes.

FROM BEHIND AND BACKSTAB (2026-11-23)
DECIDED (Martin): special attacks appear when their conditions are met.
A normal attack from behind gets a bonus, mid-fight too; if the enemy
hadn't noticed you, the sneak bonus as well. Close enough behind an
enemy, you can BACKSTAB: humanoids only; that's the one with the big
damage.
BUILT:
- FROM BEHIND: any melee hit (LIGHT or HEAVY) landing within 45 degrees
  of straight behind: +50%; it hadn't noticed you: +50% more (x2).
  The knight too. Not shots.
- BACKSTAB: first in a melee hand's menu while you're within reach of a
  humanoid enemy, behind it, that hasn't noticed you; the hand's button
  flickers. Once started it can't fail: the enemy's held from the start.
  Wind (the LIGHT's), the stab (3x the LIGHT's damage; dagger 5x), both
  held still, then the LIGHT's recovery. Its stamina is the LIGHT's.
  Gone from the menu: back to the LIGHT.
- "humanoid" on the soldier, spearman, archer and knight; the knight
  can't be backstabbed (Claude's default, Martin didn't say).
- A melee attack (or BACKSTAB) started crouching keeps you crouched
  (Claude's call: otherwise standing up within NEAR_SENSE always gets
  you noticed, so the sneak bonus could never land in melee).
PLACEHOLDER: +50% / +50%, 45 degrees, BACKSTAB reach 16 / 3x / hold 4,
its art (the LIGHT's swing, held on its last frame).

OPEN
- Martin played v0.1 on his phone (2026-11-20).

---

# The raptor fight (kept from Pack-free)

Nothing new goes into the game until it's agreed here. One thing at a time,
each finished (works, nothing half-built, Martin has played it and is happy)
before the next starts.

Labels:
- **DECIDED**: Martin's call.
- **PLACEHOLDER**: mine, standing in until Martin decides.
- **LATER**: an idea written down so it isn't lost. Not for now.
- **OPEN**: a question still to answer.

Order: the fight, then levelling, then the run.

---

## 1. The fight (in the game)

DECIDED
- (2026-11-04) We work on THIS version, Pack-free: free movement and free
  aim, no grid. Games/Pack (hexes) is set aside; if this is ever dropped,
  small hexes are the next thing to try.
- Turn-based with BEATS (confirmed 2026-11-04).
- Attacks can have directional options. Hovering shows what that way hits.
- BITE: aimed in front of you. Aimed to a side, the jaws sweep round from
  ahead to there (2026-11-03).
- LEAP is one action: a forward jump attack or a back hop. The jump slams
  an oval just over the size of the body where it lands (2026-11-04).
- The hunters' hits follow their swing (the sword's hit is where the blade
  sweeps). They may get different attacks later; these do for now.
- You start with one Skreel ally. HOWL only calls it back once it's down.
- MARK takes a beat and marks a hunter for the ally to go for.
- Raptor body only for now.
- Reach rule: anything that changes an attack's distance adds choices. It
  never replaces them (leap 24-32 px, with more reach 24-40).
- (2026-11-04) The base moves designed on hexes (tail whip, hip check, arm
  combo, below) carry over as they are.
- (2026-11-04) The monster PUSHES hunters: with attacks (the arm combo), and
  with movement too.
- (2026-11-04) Walking into a hunter just moves it as you move: your body
  pushes against its circle, no shove. It does NOT stop its attack (maybe
  for a bigger monster, later). BUILT.
- (2026-11-04) The attacks stay where they were in the plan below.
- (2026-11-06) AIMING shows which way an attack goes: stripey chevrons
  moving through the hit area in its direction (round a sweep's arc, out to
  the side for the hip check, ahead for the arm combo); a burst (the leap
  slam, later a fireball) shows rings spreading from the middle. Only in
  your own aim preview, NOT on the hunters' warnings. BUILT.
- (2026-11-06) BODIES ARE SOLID THINGS that push each other out of the way,
  like circles in a physics sim. The monster is the big one: hunters never
  stop it. NOTHING a hunter does stops a monster move or attack from
  happening (a whip turning its head to where a hunter stands, a leap
  landing on one, a walk into one pinned at the edge): the hunter is pushed
  aside. Don't fuss over walls for now: a hunter pinned against one squeezes
  out along it. BUILT.

PLACEHOLDER
- Beats: your step first, then the pack's, then the hunters'.
- All numbers (health, damage, wind-ups, sizes in px). See NOTES.md.
- The hunters: SWORD and BOW, and how they choose.
- Bodies are circles (the raptor three, head / chest / hips; the tail tip
  doesn't count); attacks are shapes on the ground.

NOT IN PACK-FREE YET (decided, to bring over)
- The Skreel ally, HOWL and MARK.

OPEN
- Martin hasn't played it yet. Is it fun as it is?

### Choosing a move: branching menus (2026-11-01)

DECIDED
- Moves are picked through branching menus, starting from the number keys.
  ATTACK opens the parts (head, body, tail, ...), and each part lists its
  moves. Mutations add moves to their part's list.
- The pack moves (HOWL, MARK) go under SPECIAL.

PLACEHOLDER (to try)
```
1 MOVE   2 ATTACK   3 SPECIAL   SPC WAIT
2 ATTACK  -> 1 HEAD  2 BODY  3 TAIL  4 LEGS
3 SPECIAL -> 1 HOWL  2 MARK
```
- A part with only one move skips its menu.
- The last move used stays picked, so repeating it is just a click.

### Base moves for each part (2026-11-01)

DECIDED
- TAIL: a 180-degree spin tail whip. It repositions you (you end up facing
  the other way) and it's an attack.
- BODY: a hip check. One beat of wind-up, then it hits an area 3 cells wide
  and 2 cells deep. (On hexes: only the four side directions. Now: to the
  sides, adjustable a little; see 2026-11-05 below.)

- ARMS: a two-swipe combo. You move two spaces as it goes, pushing the
  hunters (or monsters) back. Straight ahead only. A wind-up, then the two
  swipes one straight after the other. Each swipe hits just the hex in
  front. It's a special attack: once started it always does both swipes,
  no cancelling. A hunter at the edge just stays put and isn't pushed.
  (2026-11-01)
- Attacks will have COOLDOWNS, counted in beats. (2026-11-01)
- HIP CHECK pushes the hunters it hits back, and the monster moves half
  that distance the same way. (2026-11-05)
- The hip check hits along the whole way: from your side, over the distance
  you move, out to as far as the hunters get pushed to. (2026-11-05)
- The hip check aims mostly to the sides: straight out to your left or
  right, adjustable a little either way. (2026-11-05)
- TAIL WHIP: the mouse picks the side; the tail sweeps that side from behind
  to front (a half ring, hips to tail tip) and you turn round on the spot.
  The area in the picture is right. (2026-11-05) BUILT (key 4 for now,
  until the menus).
- Hip check numbers: hunters pushed 16 px, you move 8, the area reaches
  24 px out from your side; the aim turns up to 20 degrees either way from
  straight out. (2026-11-05)
- Body spikes are replaced by an aspect perk. (2026-11-05)
- Every monster attack has a wind-up of at least 1 beat (the tail whip
  too). (2026-11-06)
- Every hit pushes the enemy back some amount; some attacks have higher
  knockback (the hip check: 16 px). (2026-11-06)
- Knockback, to try: 4 px normally, the leap slam 8, the hip check 16, the
  arm combo as far as you step. Straight away from the attack's origin
  (the part of the raptor that hit). Hunters' hits don't push the raptor.
  (2026-11-06) BUILT for
  the bite and leap; its swing / shot moves with it.
- The MONSTER gets a STAGGER: after enough hits it's pushed back and
  staggered. (2026-11-06)
- The stagger goes by DAMAGE: when the damage it has taken goes over 60% of
  its health, it's staggered. To try for now. (2026-11-06)
- Stagger details: pushed 8 px away from the hit; it stops what it's doing
  and loses its next beat; the count starts again from 0; a mark on the
  health bar shows where the next one comes. (2026-11-06) BUILT.

- (2026-11-06, Martin agreed to the obvious answers:)
  - Arm combo: the edge question is gone (bodies are solid: a hunter at the
    edge squeezes out). In px: 16 px a swipe, 32 in all; each swipe hits a
    small patch just in front of the head.
  - Cooldowns only on the bigger attacks (leap, hip check, arm combo). The
    tool dims with the beats left on it.
  - LEAP goes on the top level next to MOVE.
  - Nothing else under SPECIAL for now.
  - The throat is part of the head.

PLACEHOLDER
- Cooldown lengths (beats): leap 3, hip check 3, arm combo 4.
- Arm combo damage and patch size; hip check damage.
- Menu keys: 1 MOVE  2 LEAP  3 ATTACK (1 HEAD bite, 2 BODY hip check,
  3 TAIL whip, 4 ARMS combo)  SPC WAIT. SPECIAL comes back with the ally.
  Esc / right click backs out of a menu.

Build order: hip check, arm combo, cooldowns, menus. Then aspects.
ALL BUILT (2026-11-06).
- (2026-11-07) A stagger stops any attack, combos too (the arm combo's
  "no cancelling" is only about you choosing to stop it). DECIDED, BUILT.

## 2. Levelling (in the game)

(2026-11-11) Brought over from Games/Pack with the run, and switched ON:
a stat every level; every third level, then an aspect pick (BLADES or
BLUNT). Taking an aspect level only records it so far: what each level
does is the next thing to build.
- (2026-11-11) A START SETUP (S on the title): pick the stats and aspect
  levels a run starts with, then Enter for the run or F straight into a
  fight. BUILT. (Layout and keys mine.)

DECIDED
- Every level you pick a stat: STRENGTH, SPEED or DEFENSE.
- Every third level you get a bigger choice: a mutation.
- No named forms for now.
- Every third level you get BOTH: the stat increase and the perk (a
  mutation). (2026-11-01)

- ASPECTS (2026-11-01, replaces "a type put on an area": picking what gets
  upgraded was getting too messy). You pick an ASPECT, not a part. Each
  level of an aspect gives a benefit AND adds a new attack or enhances one
  or more of your attacks. The aspect decides which; you don't pick parts.
- Aspects are things like BLADES, BLUNT, FIRE, POISON.
- On screen, choices are single-colour ICONS, not names: one icon per
  aspect. The code keeps its own names. What an aspect grows shows on the
  creature itself. (2026-11-01)

SUPERSEDED (kept so we know why)
- Type on an area (spikes on the head = horns, etc.), areas picked per
  mutation, and the spikes / blades / plating x area grid below. The areas
  (head, body, tail, legs, arms) still matter for the attack menus.

- (2026-11-07) The stat picks stay: a stat every level, and an aspect level
  every third level.
- (2026-11-07) Aspects start with RULES: how many attacks each level of an
  aspect adds or alters. Each level changes at least 2 attacks:
  - level 1: 2 enhancements (to existing attacks)
  - level 2: 1 enhancement + 1 new attack
  - level 3: 1 enhancement + 2 new attacks
  So a full aspect = 4 enhancements + 3 new attacks.
- (2026-11-07) Each aspect is a SET LIST: you don't choose what goes where.
  BLADES 1 always enhances the same two attacks in the same way, every run.

BLADES (2026-11-07)
- BLADES itself (on every level): any attack BLADES affects builds BLEED,
  on the bladed part of it.
- BLADES 1, enhancement 1: the arm combo becomes a THREE-slash combo. Its
  range goes up slightly and the last slash is a bigger hit (and it bleeds).
- BLADES 1, enhancement 2: the tail whip gets an arm CLAW sweeping the side
  opposite the tail, with less reach than the tail. The claw half bleeds;
  the tail half doesn't.
- BLEED (new status, on hunters): small damage as they walk around, bigger
  damage when they attack or dodge. It lasts a set time, or until they use
  something to heal.
  - It starts after 2 bleeding hits.
  - 1 damage for a beat they move, 2 for an attack (dodges too, once the
    hunters have them).
  - Lasts 8 beats.
  - Triggering it again (another 2 hits) puts the timer back to 8; a single
    hit doesn't.
  - Hunter healing and dodges come later, with other hunter additions.
PLACEHOLDER (BLADES 1 combo): slash reach 22 -> 26 px; the third slash's
patch 8 -> 12 px and damage 8 -> 14; still 16 px a step, 48 px in all.
PLACEHOLDER (BLADES 1 claw): 8-20 px out from the legs, 8 damage, the
normal 4 px push.
- BLADES 1 and bleed: BUILT (2026-11-12). A bleeding hunter shows drops
  falling beside it.
- BLADES 2, enhancement: the CHARGE's area is a bit wider, and it bleeds.
  BUILT (2026-11-12). PLACEHOLDER: 8 px wider.
  (2026-11-12) BLADES 2's new attack: OPEN.
- BLADES 3: OPEN.

CHARGE (2026-11-11): a standard move, unlocked by your second aspect level.
- 2 wind-up beats. After the first, it stops and you can turn the aim a
  little more (placeholder: up to 30 degrees either way); the hunters'
  warning turns with it.
- Distance: 1.5x the 56 px first proposed, at least, to start with (84 px).
- Hits every hunter on its path once each; bodies are solid, so they're
  pushed aside off the path.
- PLACEHOLDER: 16 damage, 16 px knockback, 4-beat cooldown, the run itself
  in one beat; under BODY in the menu.
- (2026-11-11) Unlocked by your SECOND aspect level, whichever aspects they
  are (BLADES + BLADES or BLADES + BLUNT both unlock it).
- (2026-11-11) A set distance: always the full 84 px.
- BUILT (2026-11-12). With it, BODY in the ATTACK menu opens 1 HIP 2 CHARGE.
  After the first wind-up it stops: click to aim it again, Space to keep
  it. PLACEHOLDER: its path is 14 px wide (the body's width), run from the
  head.

OPEN (aspects)
- How many levels does an aspect have? (Proposed: 3, so a run can max one
  and dip into another.)
- Which aspects to start with? (Proposed: just BLADES and BLUNT, the two
  non-elemental ones, worked out fully before fire and poison.)
- What each level of each aspect gives (the benefit + the attack). To fill
  in per aspect once the above is settled.
- Is the old SPIKES and PLATING folded into these (spikes into BLADES,
  plating into BLUNT), or are they aspects of their own?

OPEN (icons)
- Are icons used everywhere you choose: the top menu (MOVE / ATTACK /
  SPECIAL), the parts, the moves, the level-up cards?
- One colour for every icon, or a colour for each type (spikes, fire,
  poison...)?
- Who draws them? (Proposed: I draw placeholder pixel icons; Martin redraws
  them in the puppet tool's Paint tab.)

PLACEHOLDER
- A won fight is one level.
- What each stat point gives: STRENGTH bite +3, other attacks +2; SPEED
  walk +2 px a beat; DEFENSE every hit on you -2.
- Aspect cards show just the name and level (BLADES 0>1); icons are still
  OPEN.
- (The old elements and parts from the hex version were not brought over.)

SUPERSEDED PROPOSAL (type on area, no longer the plan): each type has one job, and the area
says which move and which side it works on.
- SPIKES = hurt: that part's move hits harder, and hunters who hit that
  part get hurt back.
- BLADES = reach: that part's move hits more cells.
- PLATING = guard: hits on that part do less, and that part's move knocks
  hunters back.
- Which part a hunter's hit lands on comes from where it came from: front =
  head, sides = body, behind = tail.

|        | SPIKES                        | BLADES                       | PLATING                         |
|--------|-------------------------------|------------------------------|---------------------------------|
| HEAD   | bite harder; front hits hurt back | bite hits all 3 cells ahead | less from the front; bite knocks back |
| BODY   | charge harder; side hits hurt back | charge band wider           | less from the sides; charge shoves further |
| TAIL   | whip harder; hits from behind hurt back | whip sweeps more cells | less from behind; whip knocks back |
| LEGS   | leap landing harder           | landing hits all round you   | can't be knocked back / staggered |
| ARMS   | swipes harder                 | each swipe hits 3 cells wide | pushes them further             |

(Its open questions on type-then-area picking are dropped with it.)

## 3. The run (in the game; brought over from Games/Pack 2026-11-11)

DECIDED
- A route map like Slay the Spire (layout 1).

PLACEHOLDER
- 7 columns of hunts, prey and nests, ending in a big fight.
- How much healing prey and nests give.
- Which hunters each column has.

## LATER
- Follow-up attacks: some attacks can chain into a special follow-up if
  you want, e.g. a bite to the right, then back across to the left.
- Endgame body plans: raptor, wyvern, snake, beast.
- An element combining with a part (fire + vocal cords = fire breath).
- Stacking an element to grow it (two fires lets you shoot a fireball).
- Named monster forms.
- A territory-of-zones mode, if the route map's balance works.
- Rival monsters.
