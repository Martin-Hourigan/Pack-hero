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
