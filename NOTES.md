# Pack-hero

A copy of Pack-free (2026-11-20): the HERO against the big KNIGHT (see
PLAN.md). Starts on a title: Space the knight, R the raptor fight (Pack-free
as it was; its notes are below).

Run: `play.bat`. Tests: `godot --headless --path . --script res://tests/smoke.gd`
(the raptor's checks, then the duel's, tests/duel_checks.gd).

Files: scripts/duel.gd (the rules), duel_view.gd (drawing), duel_main.gd
(title + input, scenes/duel.tscn, the main scene); rig_art.gd can now pose a
rig from a clip (pose / blend / frames, draw option `pose`).

Duel dev flags (after `--`): --duel (straight in), --seed=N, --at=x,y (the
hero there), --knight=sweep / backhand / overhead (he starts it now),
--steps=N (play N steps first), --tool=light with --mouse=x,y (aimed there).
Screenshots: `--shot path@secs` goes BEFORE the `--`.

---

# Pack-free (the raptor fight)

The free-movement test of Pack (Martin, 2026-11-03): the same fight with no
hex grid, to compare against Games/Pack. Hexes are too coarse to grow
attacks in small steps (1 hex of reach can only become 2). If this one is
dropped, the next thing to try is smaller hexes (see Pack/PLAN.md).

The Great Skreel against parties of SWORDs and BOWs along a route map, as
in Pack: title, map, fights, a level after each won fight (a stat; every
third level an aspect pick), the last fight. No ally yet. Turn-based with
beats, as in Pack.

Title: Space a run, S the START SETUP: pick the stats and aspect levels to
start with (up/down a row, left/right or click - / +), Enter the run, F
straight into a fight, Esc back.

Dev flags (after `--`): --setup, --start (skip the title), --fight (straight into a
fight), --evolve (a level-up), --big (the aspect pick), --seed=N,
--pose=sword / bow.

Run: `play.bat`. Tests: `godot --headless --path . --script res://tests/smoke.gd`.

## Controls
1 MOVE, 2 LEAP, 3 ATTACK. ATTACK opens the parts: 1 HEAD (bite), 2 BODY
(hip check), 3 TAIL (whip), 4 ARMS (combo); Esc or right click backs out.
The mouse aims; left click does it; the tool stays picked. Space WAIT.
After the fight, Space goes on (a level-up, or back to the map). Map: click
a lit stop (H hunters, P prey, N nest, B the last fight). A tool still cooling down is dim with
the beats left on it.

## What changed from the hex version (all mine: placeholders)
- Everyone stands at a point (pixels) and faces any angle. Bodies are
  circles: the raptor is three along its facing (head, chest, hips; the
  tail tip doesn't count), a hunter is one.
- Attacks land on shapes on the ground (a disc, a slice of a circle, a
  strip), drawn pixel by pixel. Anyone with any of their body in it is hit.
- MOVE: walks straight at the point, 16 px a beat (the old hex). Still
  stops when a hunter starts an attack.
- Walking into a hunter MOVES it (Martin, 2026-11-04): the raptor's body
  circles slide its circle along, just clear, as you go; not a shove. Its
  attack carries on, from where it now stands.
- Bodies are solid (Martin, 2026-11-06): the raptor is never stopped by a
  hunter. Any hunter it overlaps (walking, whipping round, landing a leap,
  being staggered) is pushed out of the way; one pinned at the arena's edge
  squeezes out along it. Hunters pushed into each other both give way.
  Hunters walking still stop at the raptor (they don't push it).
- BITE: aim anywhere up to 60 degrees either side of ahead (further and it
  bites as far round as it can). Jaws 14 px across, 22 px ahead of its
  legs. Aimed to a side, the jaws SWEEP round from ahead to there (Martin,
  2026-11-03; to tweak later).
- LEAP: aim ahead (up to 30 degrees off) to jump 24 to 32 px and slam an
  OVAL just over its body where it lands (Martin, 2026-11-04; 42 x 24 px is
  mine, its body is 33 x 14); aim behind to
  hop back the same distances. Any distance in between is a choice.
- WHIP (Martin, 2026-11-05): 1 beat wind-up, then a half turn on the spot
  round its legs. The tail sweeps the side the mouse is on, behind to
  ahead: a half ring 12 to 34 px out (hips to tail tip). Damage 14 is mine.
- Every hit of yours pushes the hunter straight away from where the hit
  came from (Martin, 2026-11-06): 4 px, the leap slam 8. Its attack moves
  with it.
- STAGGER (Martin, 2026-11-06): once the raptor has taken more than 60% of
  its health since its last stagger, it's pushed 8 px away from the hunter
  that hit it, stops what it was doing and loses its next beat. A mark on
  the health bar shows where the next one comes.
- HIP CHECK (Martin, 2026-11-05/06): 1 beat wind-up, then it shoves out to
  the side the mouse is on (turning up to 20 degrees off straight out),
  moving 8 px, hitting a box from its side 24 px out and 48 px along its
  body; hunters hit go 16 px straight out. Damage 12 is mine.
- ARM COMBO (Martin, 2026-11-01/06): 1 beat wind-up, then two swipes
  straight ahead, a beat each, can't be stopped (only a stagger stops it).
  Each steps 16 px and hits a patch 16 px across 22 px ahead of its legs,
  pushing hunters 16 px on. Damage 8 a swipe and the patch are mine.
- COOLDOWNS (Martin: the bigger attacks only): leap 3, hip check 3, arm
  combo 4 beats, counted from when it ends. The numbers are mine.
- SWORD walks up and slashes, aimed at the raptor's nearest part. The hit
  is where the blade SWEEPS (Martin): 26 px from the hand (the art's
  length), 80 degrees either side; the drawn sword swings the same arc.
  Martin: the hunters may get different attacks later; these do for now.
- BOW keeps 32 to 80 px away and shoots a strip at it, from any angle.
- The ground has a faint dot every 16 px so movement reads.
- Aiming (Martin, 2026-11-06): chevrons scroll through the hit area the way
  the attack goes; the leap slam has rings spreading out. Only when you
  aim. Stripe gap 6 px, 2 px wide, 10 px a second (mine).

## Aspects
- BLADES 1: the arm combo is three slashes (reach 26 px; the last a 12 px
  patch for 14) and the tail whip has a claw sweeping the other side
  (8-20 px out, 8 damage). The slashes and the claw bleed; the tail
  doesn't.
- Bleed: 2 bleeding hits start it (2 more put it back to the top); 8
  beats; 1 damage a beat the hunter moves, 2 for each attack. Drops fall
  beside a bleeding hunter.
- BLUNT does nothing yet.
- CHARGE (comes with the second aspect level, any aspects): under BODY. Aim
  it anywhere; one wind-up, then it stops: click to aim it again (up to 30
  degrees either way) or Space to keep it; a second wind-up, then it runs
  84 px in one beat. Its path (14 px wide) hits every hunter on it once
  for 16 and knocks them 16 px out to the side. Cooldown 4. BLADES 2: the
  path is 8 px wider and it bleeds.
