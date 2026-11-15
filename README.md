# Ice Legends '94 — v3.2

'94-style arcade hockey for the web, live on Diddly's Arcade. Godot 4.7.2.
Two fictional clubs, three 2-minute periods, and pick-up-and-play controls on
keyboard, gamepad, or touch.

v3.2 applies the Game Test Lab tester's six fixes (VEX scored v3.1 5.0/10,
grade C — "a promising shell, not a proven '94") in priority order. What
changed, what is still only a checklist, and what was cut is all listed below
— nothing here claims a live test that has not happened yet.

## What v3.2 changed

- **Real gamepad support (fixes 1, 7, 13).** v3.1 shipped a gamepad control
  map with no gamepad code in the repo at all — only the touch joystick.
  New `Scripts/GamepadManager.gd` is the first real pad input in the project:
  0.20 deadzone with rescaling, rest-drift sampling per pad, left stick /
  D-pad movement, A/B pass, X hold-release shoot, Y/LB/RB turbo, Start
  pause / rematch. It is wired into `GameManager` (`_input`, `_poll_gamepad`,
  `_poll_shoot_key`, `_turbo_held`) and into the menus, and the built-in
  self-test checks the manager is present and the deadzone is 0.20. The live
  session itself — 2–3 real players, Chrome and Firefox, at least two
  different pads — still has to happen; the log table is in
  `docs/playtest_checklists.md`.
- **'94 feel tuning (fixes 2, 8, 14).** Pass speed, shot speed, charge rate
  and turbo are now named `TUNING` values in `Scripts/GameManager.gd`
  (charge rate and turbo constants live in `Scripts/Skater.gd`) instead of
  magic numbers scattered through the code. One item was tuned first:
  passes were the slowest-feeling action, so pass base speed went 590 → 640.
  Shot charge winds up faster (1.75/s → 2.0/s). Turbo is no longer infinite:
  it drains at 0.45/s (~2.2 s continuous) and refills at 0.30/s, with a meter
  drawn under the active skater. Shot speed, checking, goalie behaviour and
  AI pressure are unchanged — there was no evidence they were the worst
  item, so they are tuned only after the written feel checklist is run live.
  Before/after table: see `docs/playtest_checklists.md`.
- **Controls on screen + quick start (fix 3).** The title screen now shows
  the real keyboard and gamepad maps (the old hint line described keys the
  game does not use). The pause screen shows the same controls plus the
  rematch hint. A first match is two inputs: Enter on the title, then Enter
  again on team select picks the first club and drops the puck. The final
  whistle now says so: "PRESS ENTER OR START FOR A REMATCH".
- **Match loop documented (fix 4).** Title → team select → faceoff timing
  (press on green) → 3 periods → intermission resurfacer → goal / score
  display → final whistle → instant rematch. No dead ends: every screen has
  a way forward and a way back (Esc / B / Start). Full step list in
  `docs/playtest_checklists.md`.
- **Performance (fix 5).** A Web export preset was added
  (`export_presets.cfg`, preset 1, exports to `build/web/index.html`) — the
  repo previously had an Android preset only, so there was no repeatable web
  build to measure. Real-browser load time, FPS and keyboard latency still
  have to be measured on real machines; the checklist and the proposed
  pass/fail targets are in `docs/playtest_checklists.md`.
- **The difference, stated (fix 6).** See below. Online play, local
  2-player, extra modes and difficulty settings were cut / deferred — they do
  not support the difference.

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move | WASD / arrows | Left stick / D-pad | On-screen stick |
| Pass / switch skater | X or K | A or B | PASS button |
| Shoot (hold to charge, release) | Space, J, or Z | X | SHOOT button |
| Turbo (drains, then refills) | Shift or L | Y, LB, or RB | TURBO button |
| Pause | Esc or P | Start | Pause button |
| Rematch after the final whistle | Enter | Start | Tap the ice |
| Faceoff: win it | Press pass / shoot when the ring turns green | A / B / X on green | Tap on green |

One-timers: press shoot while a pass is in flight and your skater is close
to the puck.

## The match

Pick a club — Halcyon Frost (HCF, Halcyon Bay) or Redwood Lanterns (RWL,
Redwood Reach). Six skaters each (C, LW, RW, LD, RD, G) with 1–5 ratings for
speed, shot, accuracy, checking and passing. Win the faceoff, then three
2-minute periods. Goals, shots on goal and power plays are on the scoreboard;
hard board hits can draw a penalty or drop the gloves. Between periods the
resurfacer crosses the ice. After the third period the final score shows and
Enter / Start / tap starts an instant rematch with the same clubs.

Presentation as it exists today: top-down rink with centre-ice crest, goal
lamps, hit-stop and camera shake, goal horn and organ stings, skate spray and
ice scratches, and a shot-charge bar with an aim guide. No tutorial beyond the
on-screen controls; no modes, difficulty, local 2-player, or online play.

## What this does that King of '94 does not

King of '94 plays the authentic 1994 ROM in a browser, online play included.
Ice Legends '94 is not that. It is an original-club arcade remix: fictional
Halcyon Frost vs Redwood Lanterns (no licensed teams or players), built
around a faceoff timing mini-game, hold-release shots with one-timers, a
turbo meter you have to manage, fights, penalties and power plays, and
instant pick-up-and-play — two inputs from title to puck drop, instant
rematch — on keyboard, gamepad or touch in one web build. Everything that
does not support that difference was cut or deferred: online play, local
2-player, extra modes, difficulty settings, more clubs.

## Run it / export it

- Godot 4.7.2. Open `project.godot` and run the main scene
  (`Scenes/MainRink.tscn`).
- Self-test: run with the `--self-test` user argument. It boots on the
  title, starts matches, pauses, restarts, quits, checks the gamepad manager
  and tuning values, and exercises the two-input quick match.
- Layout/trademark audit: `Tests/audit.gd` (run as a Godot script).
- Web export: preset "Web" in `export_presets.cfg` → `build/web/index.html`
  (gitignored). Copy the export into the Diddly's Arcade site to redeploy.
- Android export: preset "Android" (`com.diddlerrr.icelegends`).

## Still to do live (not claimed as done)

- Gamepad session: 2–3 players, Chrome + Firefox, ≥ 2 different pads —
  deadzone, drift, mapping, turbo, restart logged per pad.
- '94 feel checklist on keyboard, worst item tuned first, before/after
  recorded.
- Full-loop playtest and real-browser load / FPS / latency measurements.
- All three checklists, log tables and proposed targets:
  `docs/playtest_checklists.md`. Open questions: which two pads and which
  mid-range / low-end machines are available, and the pass/fail targets for
  load time, FPS and input latency (proposed targets are in the checklist).
