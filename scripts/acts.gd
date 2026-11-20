class_name Acts
extends RefCounted
## Every number in the game.
## Beats: one beat = everyone's part once, the leader first.
## Distances are in pixels; the old hex was 16 px across, so 16 px here is
## "one hex" in the hex version.

## The units. hp, body: circles along its facing [ahead px, radius] (the
## raptor: head, chest, hips; the tail's tip doesn't count), and how they're
## drawn (art, scale).
const UNITS := {
	"leader": {"label": "GREAT SKREEL", "hp": 100, "body": [[12.0, 6.0], [2.0, 7.0], [-9.0, 6.0]],
		"art": "res://art/raptor.rig.json", "scale": 0.8},
	"sword": {"label": "SWORD", "hp": 60, "body": [[0.0, 4.0]], "art": "res://art/hunter.rig.json", "scale": 1.3},
	"bow": {"label": "BOW", "hp": 40, "body": [[0.0, 4.0]], "art": "res://art/hunter.rig.json", "scale": 1.3},
}

## The leader's actions. Beats each takes are in its steps (battle.gd).
## `cool`: beats after it ends before it can be used again.
## Every hit of the leader's pushes the hunter `push` px straight away from
## the part of it that hit (PUSH if the attack doesn't say).
const PUSH := 4.0
## When the damage the leader has taken since its last stagger goes over
## `at` of its health, it's staggered: pushed `push` px away from the hitter,
## what it was doing stops, and it loses its next beat.
const STAGGER := {"at": 0.6, "push": 8.0}
const LEADER := {
	"move": {"label": "MOVE", "speed": 16.0},  # px a beat, straight at the point; stops when a hunter starts a new attack
	# wind 1, bite 1: jaws of radius r, `reach` px ahead, aimed anywhere within `turn` of ahead.
	# Aimed to a side, the jaws sweep round from ahead to there, turning it.
	"bite": {"label": "BITE", "dmg": 18, "push": 4.0, "reach": 22.0, "r": 7.0, "turn": PI / 3.0},
	# ahead: wind 1, jump + slam an oval just over its body round where it lands:
	# `long` px along it by `wide` across (its body is 33 by 14).
	# behind: a hop, 1 beat. Lands min..reach px away, within `turn` of straight ahead / behind.
	"leap": {"label": "LEAP", "cool": 3, "dmg": 14, "push": 8.0, "min": 24.0, "reach": 32.0, "turn": PI / 6.0, "long": 42.0, "wide": 24.0},
	# wind 1, then a half turn on the spot: the tail sweeps round the side the
	# mouse is on, from behind to ahead (a half ring, r_in..r_out px out from
	# its legs: the hips to the tail's tip), and it ends up facing back.
	"whip": {"label": "WHIP", "dmg": 14, "r_in": 12.0, "r_out": 34.0},
	# wind 1, then a shove out to one side: it moves `move` px that way and
	# hits a box from its side `out` px out, `long` px along its body; hunters
	# hit go `push` px straight out. Aimed to the side the mouse is on,
	# turning up to `turn` from straight out.
	"hip": {"label": "HIP", "cool": 3, "dmg": 12, "push": 16.0, "move": 8.0, "out": 24.0, "long": 48.0, "side": 7.0, "turn": PI / 9.0},
	# wind 1, then two swipes straight ahead, one a beat, that can't be
	# stopped: each steps `step` px forward and hits a patch of radius r
	# `reach` px ahead of its legs, pushing hunters `step` px on ahead.
	"arms": {"label": "ARMS", "cool": 4, "dmg": 8, "step": 16.0, "reach": 22.0, "r": 8.0},
	# Unlocked by the second aspect level (any aspects). wind 1 (turning to
	# where it's aimed), then it stops: you can turn it up to `turn` more
	# either way. wind 1, then it runs `long` px straight in one beat. Its
	# path, `w` wide, hits every hunter on it once, pushing them `push` px
	# out to the side.
	"charge": {"label": "CHARGE", "cool": 4, "dmg": 16, "push": 16.0, "long": 84.0, "w": 14.0,
		"turn": PI / 6.0, "unlock": 2},
	"wait": {"label": "WAIT"},
}

## wind 2, slash, back 1. Walks `speed` px a beat. The slash is where the
## blade sweeps: from the hand (`hand`, in its body: ahead, right),
## the blade's length r (the art's 20 px x its 1.3 scale), `arc` either side
## of where it aims. The view swings the drawn sword through the same arc.
const SWORD := {"slash": 16, "wind": 2, "hand": Vector2(1.3, 3.9), "r": 26.0, "arc": 1.4, "speed": 16.0}
## wind 2, shoots a line `reach` long and `w` wide; keeps near..far away.
const BOW := {"shot": 12, "wind": 2, "reach": 96.0, "w": 5.0, "near": 32.0, "far": 80.0, "speed": 16.0}

## The arena: where bodies can stand (px).
const ARENA := Rect2(12, 12, 360, 158)

# ---------------------------------------------------------------- levels
## A won fight is a level. Every level you pick a stat; every third level,
## an aspect level too. What a stat point gives is a placeholder.
const STATS := {
	"strength": {"label": "STRENGTH", "say": "BITE +3  OTHER ATTACKS +2"},
	"speed": {"label": "SPEED", "say": "WALK +2 PX A BEAT"},
	"defense": {"label": "DEFENSE", "say": "EVERY HIT ON YOU -2"},
}
const STR_BITE := 3
const STR_OTHER := 2
const SPEED_PX := 2.0
const DEF_CUT := 2
const ASPECT_EVERY := 3  # levels between aspect picks
const ASPECT_MAX := 3  # levels an aspect has
## The aspects. What each level does comes later (PLAN.md).
const ASPECTS := {
	"blades": {"label": "BLADES", "col": "#b9c4c9"},
	"blunt": {"label": "BLUNT", "col": "#b39a72"},
}

## BLADES, level by level (PLAN.md). Every attack it changes bleeds, on its
## bladed part. Numbers are placeholders.
## 1: the arm combo is three slashes, each reaching `reach` px, the last a
## patch of radius `last_r` for `last_dmg`; the tail whip gets a CLAW on the
## other side, sweeping a half ring r_in..r_out px out from its legs.
## 2: the charge's path is `charge_w` px wider, and it bleeds.
const BLADES := {"reach": 26.0, "last_r": 12.0, "last_dmg": 14, "charge_w": 8.0,
	"claw": {"dmg": 8, "r_in": 8.0, "r_out": 20.0}}
## Bleed: `hits` bleeding hits start it (and start it again, from the top);
## it lasts `beats` beats, `move` damage a beat the hunter moves and `attack`
## for each attack it makes.
const BLEED := {"hits": 2, "beats": 8, "move": 1, "attack": 2}

# ---------------------------------------------------------------- the hero and the knight
## The duel (duel.gd): you are the HERO against the big KNIGHT. Time goes in
## STEPS, everyone together; an attack is a clip on its puppet, one frame a
## step: a wind-up, the swing, then a way back. The blade hits where the
## puppet's blade actually is, swept between steps. All numbers PLACEHOLDER.
const DUEL_UNITS := {
	"hero": {"label": "HERO", "hp": 200, "body": [[0.0, 4.0]], "art": "res://art/hero.rig.json", "scale": 1.0},
	"knight": {"label": "KNIGHT", "hp": 600, "body": [[0.0, 8.0]], "art": "res://art/knight.rig.json", "scale": 1.0},
}
## Checks between one step and the next, so a fast blade can't skip past.
const SWEEP_CHECKS := 6
## An attack: its clip, steps of wind-up, swing and way back; `live`: the
## swing's steps (from 1) the blade hits on (the overhead only once it's
## low); `lunge`: px forward each swing step; `st`: the hero's stamina cost.
const HERO := {
	"walk": 4.0,  # px a step
	"stamina": 100,
	"stamina_back": 4,  # a step, when not attacking, rolling or drinking
	"flasks": 2,
	"heal": 100,
	"drink": 5,  # steps a flask takes
	"hurt": 2,  # steps lost when hit
	"hurt_push": 6.0,  # px pushed away from the knight when hit
	"light": {"clip": "light", "wind": 1, "swing": 4, "rec": 2, "live": [1, 2, 3, 4], "dmg": 30, "st": 20},
	"heavy": {"clip": "heavy", "wind": 3, "swing": 5, "rec": 3, "live": [4, 5], "lunge": 2.0, "dmg": 55, "st": 35},
	# 4 steps of `px`; hits miss on the first `safe` steps.
	"roll": {"clip": "roll", "steps": 4, "px": 8.0, "safe": 2, "st": 25},
}
const KNIGHT := {
	"walk": 3.0,  # px a step
	"reach": 40.0,  # px from him to the hero: he attacks from here
	"turn": 25.0,  # degrees a wind-up step turns him toward the hero
	"overhead_cone": 30.0,  # degrees: the hero this near straight ahead
	"overhead_near": 22.0,  # px: and further than this, he'll chop
	"backhand_odds": 0.6,  # after a sweep
	"sweep": {"clip": "sweep", "wind": 3, "swing": 5, "rec": 2, "live": [1, 2, 3, 4, 5], "dmg": 50},
	"backhand": {"clip": "backhand", "wind": 0, "swing": 5, "rec": 3, "live": [1, 2, 3, 4, 5], "dmg": 40},
	"overhead": {"clip": "overhead", "wind": 4, "swing": 5, "rec": 3, "live": [4, 5], "lunge": 2.0, "dmg": 80},
}
