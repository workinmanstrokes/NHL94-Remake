# 94 Ice Legends v3.2 — playtest checklists

Written for the Game Test Lab tester's v3.2 fixes. The code changes for v3.2
are in the repo; **no live session in this file has happened yet**. Fill a
table in only after the session it describes has actually run, on the live
Diddly's Arcade build, and record what failed as well as what passed.

Controls (the real map — the old title hint described keys the game does not
use): keyboard WASD/arrows move, X/K pass, hold Space/J/Z shoot, Shift/L
turbo, Esc/P pause, Enter rematch. Gamepad: left stick/D-pad move, A/B pass,
X hold-release shoot, Y/LB/RB turbo, Start pause/rematch. Touch: on-screen
stick + PASS / SHOOT / TURBO buttons.

## 1. Gamepad — live verification (tester fixes 1, 7, 13)

Session: 2–3 real players, Chrome and Firefox, at least two different pads,
on the live Arcade site. One row per player × pad × browser. Deadzone is
0.20 in `Scripts/GamepadManager.gd`; rest drift is sampled per pad and kept
in the pad profile (`max_rest_drift` — anything above ~0.05 at rest means the
stick needs a bigger deadzone or the pad is worn).

| Player | Pad (model) | Browser | Deadzone OK? | Drift at rest | Mapping (A/B pass, X shoot, Y turbo, Start) | Turbo | Restart (Start / Enter) | Notes / retest |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | Chrome | | | | | | |
| | | Firefox | | | | | | |
| | | Chrome | | | | | | |
| | | Firefox | | | | | | |

Pass bar: every pad moves cleanly with no drift at rest, every button does
what the title screen says, turbo drains and refills, Start pauses and
rematches. Anything that fails gets fixed and retested with the same players,
pads and browsers — log the retest in a new row, do not overwrite the fail.

## 2. '94 feel — keyboard checklist (tester fixes 2, 8, 14)

Run on keyboard, one item at a time, worst-feeling item first. Rate each
1–5 before tuning, tune it, rate again. Only the worst item is tuned per
round; do not tune everything at once or the before/after means nothing.

| Item | Before (1–5 + note) | Change made | After (1–5 + note) |
| --- | --- | --- | --- |
| Pass speed | | v3.2: pass base 590 → 640 | |
| Hold-release shot timing (charge 1.75/s → 2.0/s in v3.2) | | | |
| Turbo drain (v3.2: new meter, 0.45/s drain, 0.30/s refill, ~2.2 s continuous) | | | |
| Checking (stun 0.90 s, board-hit penalties/fights) | | | |
| Goalie saves (reaction, positioning, clear) | | | |
| AI pressure (chasing, backchecking, shooting) | | | |
| Skating weight (accel, turning, stop spray) | | | |
| One-timers (pass in flight + shoot) | | | |

v3.2 tuning already in the code (before → after): pass base 590 → 640;
shot charge rate 1.75/s → 2.0/s; turbo ×1.30 infinite → ×1.30 with a drain
meter. Shot speed (740 + 78 per shot rating), checking, goalie and AI are
unchanged in v3.2 — they are tuned only after this checklist says which of
them is actually the worst.

## 3. Match loop — end to end (tester fixes 4, 16)

Play it straight through, no skipping. Tick each step or write down exactly
where it sticks.

- [ ] Title shows controls (keyboard + gamepad) and the quick-match hint
- [ ] Enter on title → team select (1 input)
- [ ] Team select: arrows / tap pick a club, Enter starts; Enter with no club
  picked starts the first club (quick match, 2 inputs total)
- [ ] Faceoff: ring turns green, pressing pass/shoot on green wins it
- [ ] Period 1 plays; scoreboard shows score, period, clock, shots on goal
- [ ] Goal → goal display, horn, celebration, centre-ice faceoff
- [ ] Period ends → intermission, resurfacer, next period starts
- [ ] Pause (Esc / P / Start / pause button) shows controls; Resume, Restart
  and Quit to Title all work
- [ ] Period 3 ends → final whistle, final score shown
- [ ] Enter / Start / tap the ice → instant rematch, same clubs, scores reset
- [ ] Quit to Title → title screen, no skaters left on the ice

Dead ends / unclear steps found:

| Step | What happened | Fix |
| --- | --- | --- |
| | | |

## 4. Performance — real browser (tester fixes 5, 17)

Headless-load numbers do not count. Measure in a real browser, on the live
build, mid-range laptop and a low-end machine. Targets below are **proposed**,
not agreed — they are open question 3 from the v3.2 plan (Mike to confirm).

| Machine | Browser | Load time (first load) | FPS in play | Keyboard latency (breakaway shot) | Pass? |
| --- | --- | --- | --- | --- | --- |
| Mid-range laptop | Chrome | | | | |
| Mid-range laptop | Firefox | | | | |
| Low-end machine | Chrome | | | | |

Proposed targets: load ≤ 8 s mid-range / ≤ 15 s low-end; FPS ≥ 50
mid-range / ≥ 30 low-end during play; keyboard latency ≤ 100 ms from key
press to shot release on a fast breakaway. How to measure latency: film the
key press and the screen at 120 fps or use the browser's input-latency
tooling, and record the method used.

## The difference, for the game page (tester fix 6)

King of '94 plays the authentic 1994 ROM in a browser, online play included.
This game is an original-club arcade remix: fictional Halcyon Frost vs
Redwood Lanterns, a faceoff timing mini-game, hold-release shots with
one-timers, a turbo meter to manage, fights, penalties and power plays, and
instant pick-up-and-play (two inputs from title to puck drop, instant
rematch) on keyboard, gamepad or touch in one web build. That is the whole
pitch — the Arcade page should say it in those terms.

Cut / deferred because it does not support that difference: online play,
local 2-player, extra modes, difficulty settings, more clubs. None of those
exist in the code today; do not describe them as features anywhere.

## Open questions (from the v3.2 plan — still awaiting answers)

1. The single intended difference is the statement above; confirm it or
   replace it before the next scope decision.
2. Which two gamepads and which mid-range / low-end test machines are
   available for the live verification?
3. What are the pass/fail targets for load time, FPS and keyboard input
   latency? (Proposed targets are in section 4.)
