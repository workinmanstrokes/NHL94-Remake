extends Node2D

const Layout = preload("res://Scripts/MenuLayout.gd")
const Logo = preload("res://Scripts/IceLogo.gd")
const MenuScript = preload("res://Scripts/MenuController.gd")
const GamepadScript = preload("res://Scripts/GamepadManager.gd")

# v3.2 feel tuning. Values marked "v3.1" are the shipped v3.1 numbers;
# change a value only after a live keyboard playtest and log before/after
# in docs/playtest_checklists.md (tester fixes 2, 8, 14).
const TUNING := {
	"pass_speed_base": 640.0, # v3.1: 590.0 — passes were the slowest-feeling action
	"pass_speed_per_pas": 45.0,
	"shot_speed_base": 740.0,
	"shot_speed_per_sht": 78.0,
	"turbo_multiplier": 1.30,
}

enum AppMode { TITLE = 0, TEAMS = 1, MATCH = 2 }
enum GameState { FACEOFF, PLAY, GOAL_CELEBRATION, PENALTY_CALL, FIGHT, INTERMISSION, GAME_OVER }

var app_mode: AppMode = AppMode.TITLE
var paused: bool = false
var menu: Node = null
var gamepad: RefCounted = null
var menu_time: float = 0.0

var state: GameState = GameState.FACEOFF
var state_timer: float = 2.0

var home_score: int = 0
var away_score: int = 0
var home_sog: int = 0
var away_sog: int = 0
var period: int = 1
var period_clock: float = 120.0
var powerplay_team: int = -1
var powerplay_clock: float = 0.0
var last_scoring_team: int = 0
var banner_text: String = ""
var banner_timer: float = 0.0
var faceoff_pos: Vector2 = Vector2.ZERO
var faceoff_won_by: int = -1
var resurfacer_pos: Vector2 = Vector2(-950, 0)
var hitstop_timer: float = 0.0
var goal_flash_alpha: float = 0.0

var roster: Dictionary = {}
var team_keys: Array = []
var home_key: String = ""
var away_key: String = ""
var home_info: Dictionary = {}
var away_info: Dictionary = {}

var y_sort_layer: Node2D
var puck: CharacterBody2D
var cam: Camera2D
var home_skaters: Array = []
var away_skaters: Array = []
var active_human: CharacterBody2D = null
var pass_target_mate: CharacterBody2D = null
var auto_switch_cd: float = 0.0
var ice_sprays: Array = []
var skate_scratches: Array = []

var joy_center: Vector2 = Vector2(180, 668)
var joy_knob: Vector2 = Vector2(180, 668)
var joy_radius: float = 96.0
var joy_touch_id: int = -1
var joy_vector: Vector2 = Vector2.ZERO
var keyboard_driving: bool = false

var btn_a_rect: Rect2 = Rect2()
var btn_b_rect: Rect2 = Rect2()
var btn_c_rect: Rect2 = Rect2()
var pause_rect: Rect2 = Rect2()

var btn_b_held: bool = false
var btn_c_held: bool = false
var shoot_key_down: bool = false
var b_pointer: int = -99
var c_pointer: int = -99
var hud_layer: CanvasLayer
var hud_drawer: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(55):
		skate_scratches.append({"p1": Vector2(randf_range(-940, 940), randf_range(-380, 380)), "dir": Vector2.from_angle(randf_range(0, TAU)) * randf_range(22, 55)})
	_build_rink_collision()
	y_sort_layer = Node2D.new()
	y_sort_layer.y_sort_enabled = true
	y_sort_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(y_sort_layer)
	cam = Camera2D.new()
	cam.set_script(load("res://Scripts/OverheadCamera.gd"))
	cam.game_mgr = self
	cam.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(cam)
	_build_hud()
	menu = MenuScript.new()
	add_child(menu)
	gamepad = GamepadScript.new()
	_load_roster()
	_refresh_layout()
	show_title()
	if OS.get_cmdline_user_args().has("--self-test"):
		call_deferred("_self_test")

func _load_roster() -> void:
	var raw := FileAccess.get_file_as_string("res://Data/rosters.json")
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Roster file could not be read")
		return
	roster = parsed
	team_keys = parsed.get("order", [])

func show_title() -> void:
	app_mode = AppMode.TITLE
	if menu:
		menu.prepare_title()

func show_team_select() -> void:
	app_mode = AppMode.TEAMS
	if menu:
		menu.prepare_teams()

func set_paused(on: bool) -> void:
	if on and app_mode != AppMode.MATCH:
		return
	paused = on
	Engine.time_scale = 1.0
	if on:
		hitstop_timer = 0.0
		joy_vector = Vector2.ZERO
		joy_touch_id = -1
		keyboard_driving = false
		btn_b_held = false
		btn_c_held = false
		shoot_key_down = false
		b_pointer = -99
		c_pointer = -99
		joy_knob = joy_center
		if active_human and is_instance_valid(active_human):
			active_human.turbo_active = false
			active_human.move_input = Vector2.ZERO
			active_human.is_charging_shot = false
		if menu:
			menu.prepare_pause()

func start_match(team_index: int) -> void:
	if team_keys.is_empty():
		return
	_clear_match()
	set_paused(false)
	var count := team_keys.size()
	var home_i := clampi(team_index, 0, count - 1)
	var away_i := (home_i + 1) % count
	home_key = str(team_keys[home_i])
	away_key = str(team_keys[away_i])
	home_info = roster["teams"][home_key]
	away_info = roster["teams"][away_key]
	_spawn_puck_and_teams()
	home_score = 0
	away_score = 0
	home_sog = 0
	away_sog = 0
	period = 1
	period_clock = 120.0
	powerplay_team = -1
	powerplay_clock = 0.0
	goal_flash_alpha = 0.0
	last_scoring_team = 0
	resurfacer_pos = Vector2(-1050, 0)
	app_mode = AppMode.MATCH
	_enter_faceoff(Vector2.ZERO, "TAP WIN OR PRESS SPACE WHEN THE RING TURNS GREEN")

func restart_match() -> void:
	if app_mode != AppMode.MATCH or home_skaters.is_empty():
		return
	set_paused(false)
	home_score = 0
	away_score = 0
	home_sog = 0
	away_sog = 0
	period = 1
	period_clock = 120.0
	powerplay_team = -1
	powerplay_clock = 0.0
	goal_flash_alpha = 0.0
	resurfacer_pos = Vector2(-1050, 0)
	_enter_faceoff(Vector2.ZERO, "NEW GAME — TAP WIN OR PRESS SPACE ON GREEN")

func quit_to_title() -> void:
	set_paused(false)
	_clear_match()
	banner_text = ""
	banner_timer = 0.0
	show_title()

func _clear_match() -> void:
	for s in home_skaters:
		_discard(s)
	for s in away_skaters:
		_discard(s)
	home_skaters.clear()
	away_skaters.clear()
	active_human = null
	pass_target_mate = null
	_discard(puck)
	puck = null
	hitstop_timer = 0.0
	Engine.time_scale = 1.0

func _discard(node: Node) -> void:
	if node and is_instance_valid(node):
		if node.get_parent():
			node.get_parent().remove_child(node)
		node.queue_free()

func _build_rink_collision() -> void:
	var boards = StaticBody2D.new(); boards.collision_layer = 1; boards.add_to_group("Boards"); add_child(boards)
	for r in [Rect2(-1140, -480, 2280, 40), Rect2(-1140, 440, 2280, 40), Rect2(-1140, -480, 40, 960), Rect2(1100, -480, 40, 960)]:
		var c = CollisionShape2D.new(); var s = RectangleShape2D.new(); s.size = r.size; c.shape = s; c.position = r.position + r.size * 0.5; boards.add_child(c)
	var posts = StaticBody2D.new(); posts.collision_layer = 1; posts.add_to_group("GoalPosts"); add_child(posts)
	for gp in [Vector2(-990, -54), Vector2(-990, 54), Vector2(990, -54), Vector2(990, 54)]:
		var pc = CollisionShape2D.new(); var ps = CircleShape2D.new(); ps.radius = 6.5; pc.shape = ps; pc.position = gp; posts.add_child(pc)

func _spawn_puck_and_teams() -> void:
	puck = CharacterBody2D.new()
	puck.set_script(load("res://Scripts/Puck.gd"))
	puck.game_mgr = self
	var pc = CollisionShape2D.new(); var ps = CircleShape2D.new(); ps.radius = 6.0; pc.shape = ps; puck.add_child(pc); y_sort_layer.add_child(puck)
	for p in home_info["players"]:
		home_skaters.append(_create_skater(p, 0, Color(home_info["primary"]), Color(home_info["secondary"]), Color(home_info["trim"])))
	for p in away_info["players"]:
		away_skaters.append(_create_skater(p, 1, Color(away_info["primary"]), Color(away_info["secondary"]), Color(away_info["trim"])))
	_set_active_human(home_skaters[0])

func _create_skater(p_data: Dictionary, t_id: int, p_col: Color, s_col: Color, tr_col: Color) -> CharacterBody2D:
	var s = CharacterBody2D.new(); s.set_script(load("res://Scripts/Skater.gd")); s.setup_stats(p_data, t_id, p_col, s_col, tr_col, self)
	var c = CollisionShape2D.new(); var sh = CircleShape2D.new(); sh.radius = 13.0; c.shape = sh; s.add_child(c); y_sort_layer.add_child(s)
	return s

func _set_active_human(skater: CharacterBody2D) -> void:
	if not skater or skater.is_goalie: return
	for s in home_skaters: s.is_human = false; s.is_charging_shot = false; s.turbo_active = false
	skater.is_human = true; active_human = skater

func trigger_hit_feedback(freeze_sec: float, shake: float) -> void:
	if paused:
		return
	hitstop_timer = freeze_sec; Engine.time_scale = 0.08
	if cam: cam.add_shake(shake)

func spawn_ice_spray(pos: Vector2, dir: Vector2) -> void:
	if ice_sprays.size() > 24: return
	ice_sprays.append({"pos": pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), "vel": dir * randf_range(35, 95), "life": 0.28})

func _enter_faceoff(pos: Vector2, msg: String) -> void:
	state = GameState.FACEOFF; state_timer = 1.65; faceoff_pos = pos; faceoff_won_by = -1
	banner_text = msg; banner_timer = 1.65; puck.carrier = null; puck.velocity = Vector2.ZERO; puck.global_position = pos
	AudioManager.play_sfx("whistle", 0.78)
	var h_off = {"C": Vector2(-36, 0), "LW": Vector2(-105, -145), "RW": Vector2(-105, 145), "LD": Vector2(-245, -105), "RD": Vector2(-245, 105), "G": Vector2(-978 - pos.x, -pos.y)}
	var a_off = {"C": Vector2(36, 0),  "LW": Vector2(105, -145),  "RW": Vector2(105, 145),  "LD": Vector2(245, -105),  "RD": Vector2(245, 105),  "G": Vector2(978 - pos.x, -pos.y)}
	for s in home_skaters:
		s.global_position = pos + h_off.get(s.role, Vector2(-100, 0)); s.velocity = Vector2.ZERO; s.stunned_timer = 0.0; s.facing_dir = Vector2.RIGHT
		s.is_charging_shot = false; s.shot_charge = 0.0; s.turbo_active = false; s.turbo_meter = 1.0
	for s in away_skaters:
		s.global_position = pos + a_off.get(s.role, Vector2(100, 0)); s.velocity = Vector2.ZERO; s.stunned_timer = 0.0; s.facing_dir = Vector2.LEFT
		s.is_charging_shot = false; s.shot_charge = 0.0; s.turbo_active = false; s.turbo_meter = 1.0
	_set_active_human(home_skaters[0])

func _process(delta: float) -> void:
	menu_time += delta
	_refresh_layout()
	if app_mode != AppMode.MATCH or paused:
		queue_redraw()
		if hud_drawer:
			hud_drawer.queue_redraw()
		return
	_poll_keyboard()
	_poll_shoot_key()
	_poll_gamepad()
	if hitstop_timer > 0.0:
		hitstop_timer -= delta / max(0.01, Engine.time_scale)
		if hitstop_timer <= 0.0: Engine.time_scale = 1.0
	if goal_flash_alpha > 0.0: goal_flash_alpha = move_toward(goal_flash_alpha, 0.0, 1.8 * delta)
	if banner_timer > 0.0: banner_timer -= delta
	if auto_switch_cd > 0.0: auto_switch_cd -= delta
	for i in range(ice_sprays.size() - 1, -1, -1):
		ice_sprays[i]["pos"] += ice_sprays[i]["vel"] * delta; ice_sprays[i]["life"] -= delta
		if ice_sprays[i]["life"] <= 0.0: ice_sprays.remove_at(i)
	if active_human and is_instance_valid(active_human):
		active_human.move_input = joy_vector
		active_human.turbo_active = _turbo_held()
		pass_target_mate = _find_best_pass_target(active_human) if puck and puck.carrier == active_human else null
	match state:
		GameState.FACEOFF:
			state_timer -= delta
			if state_timer <= 0.0: _resolve_faceoff_drop()
		GameState.PLAY:
			period_clock -= delta
			if powerplay_clock > 0.0:
				powerplay_clock -= delta
				if powerplay_clock <= 0.0: powerplay_team = -1
			_handle_puck_pickups_and_rules()
			_check_single_goal_scored()
			if active_human and (puck.carrier == null or puck.carrier.team_id != 0) and auto_switch_cd <= 0.0:
				var best = _find_nearest_home_skater(puck.global_position)
				if best and best != active_human and best.global_position.distance_to(puck.global_position) + 55.0 < active_human.global_position.distance_to(puck.global_position):
					_set_active_human(best); auto_switch_cd = 0.50
			if period_clock <= 0.0: _end_period()
		GameState.GOAL_CELEBRATION:
			state_timer -= delta
			if state_timer <= 0.0: _enter_faceoff(Vector2.ZERO, "CENTER ICE — TAP WIN OR PRESS SPACE ON GREEN")
		GameState.PENALTY_CALL, GameState.FIGHT:
			state_timer -= delta
			if state_timer <= 0.0: _enter_faceoff(faceoff_pos, "POWER PLAY FACEOFF")
		GameState.INTERMISSION:
			state_timer -= delta; resurfacer_pos.x += 580.0 * delta
			if state_timer <= 0.0: period += 1; period_clock = 120.0; _enter_faceoff(Vector2.ZERO, "PERIOD %d — FACEOFF" % period)
	queue_redraw()
	if hud_drawer: hud_drawer.queue_redraw()

func _resolve_faceoff_drop() -> void:
	state = GameState.PLAY; AudioManager.play_sfx("organ_charge", 0.55)
	var winner_team = faceoff_won_by if faceoff_won_by != -1 else (0 if randf() < 0.52 else 1)
	if winner_team == 0:
		var tm = home_skaters[1] if randf() < 0.5 else home_skaters[3]
		puck.launch((tm.global_position - faceoff_pos).normalized(), 460.0, true, 0, false); _set_active_human(tm)
	else:
		var ta = away_skaters[1] if randf() < 0.5 else away_skaters[3]
		puck.launch((ta.global_position - faceoff_pos).normalized(), 440.0, true, 1, false)

func _handle_puck_pickups_and_rules() -> void:
	if puck.carrier != null: return
	for s in get_all_skaters():
		if not s.is_goalie and s.pickup_cooldown <= 0.0 and s.stunned_timer <= 0.0:
			if s.global_position.distance_to(puck.global_position) < 28.0:
				puck.carrier = s; puck.is_shot_on_goal = false
				if s.team_id == 0: _set_active_human(s)
				return

func _check_single_goal_scored() -> void:
	if abs(puck.global_position.y) < 52.0:
		if puck.global_position.x > 990.0 and puck.global_position.x < 1048.0:
			home_score += 1; _trigger_goal_celebration("GOAL! %s SCORES!" % home_info["name"], 0)
		elif puck.global_position.x < -990.0 and puck.global_position.x > -1048.0:
			away_score += 1; _trigger_goal_celebration("GOAL! %s SCORES!" % away_info["name"], 1)

func _trigger_goal_celebration(msg: String, scoring_team: int) -> void:
	state = GameState.GOAL_CELEBRATION; state_timer = 3.8; last_scoring_team = scoring_team
	goal_flash_alpha = 0.65; banner_text = msg; banner_timer = 3.8; puck.carrier = null; puck.velocity = Vector2.ZERO
	if cam: cam.add_shake(16.0)
	if powerplay_team == scoring_team: powerplay_team = -1; powerplay_clock = 0.0
	AudioManager.play_sfx("goal_horn", 1.0); Input.vibrate_handheld(260)

func _end_period() -> void:
	if period < 3:
		state = GameState.INTERMISSION; state_timer = 3.8; resurfacer_pos = Vector2(-1050, 0)
		banner_text = "END OF PERIOD %d — RESURFACING THE ICE" % period; banner_timer = 3.8
		AudioManager.play_sfx("organ_charge", 0.9)
	else:
		state = GameState.GAME_OVER
		banner_text = "FINAL   %s %d  –  %d %s" % [home_info["abbr"], home_score, away_score, away_info["abbr"]]
		banner_timer = 999.0

func on_crushing_board_hit(hitter: CharacterBody2D, victim: CharacterBody2D) -> void:
	if state != GameState.PLAY: return
	var roll = randf()
	if roll < 0.16:
		state = GameState.FIGHT; state_timer = 2.6; faceoff_pos = Vector2.ZERO
		banner_text = "GLOVES DROPPED! #%s %s vs #%s %s!" % [hitter.jersey_num, hitter.player_name, victim.jersey_num, victim.player_name]; banner_timer = 2.6
		AudioManager.play_sfx("whistle", 0.9)
	elif roll < 0.32:
		state = GameState.PENALTY_CALL; state_timer = 2.2; powerplay_team = victim.team_id; powerplay_clock = 30.0
		faceoff_pos = Vector2(580 if victim.team_id == 0 else -580, -180)
		banner_text = "PENALTY! BOARDING ON #%s %s" % [hitter.jersey_num, hitter.player_name]; banner_timer = 2.2
		AudioManager.play_sfx("whistle", 0.9)

func _find_best_pass_target(sender: CharacterBody2D) -> CharacterBody2D:
	var mates = home_skaters if sender.team_id == 0 else away_skaters
	var best_mate: CharacterBody2D = null; var best_score: float = -999.0
	for m in mates:
		if m != sender and not m.is_goalie:
			var to_m = m.global_position - sender.global_position
			var dist = to_m.length()
			if dist < 760.0:
				var score = sender.facing_dir.dot(to_m.normalized()) * 2.6 - (dist / 520.0)
				if score > best_score: best_score = score; best_mate = m
	return best_mate

func execute_pass(sender: CharacterBody2D) -> void:
	if puck.carrier != sender: return
	var best_mate = _find_best_pass_target(sender)
	var pass_dir = (best_mate.global_position + best_mate.velocity * 0.24 - sender.global_position).normalized() if best_mate else sender.facing_dir
	sender.pickup_cooldown = 0.32
	puck.launch(pass_dir, TUNING["pass_speed_base"] + sender.stat_pas * TUNING["pass_speed_per_pas"], true, sender.team_id, false)
	AudioManager.play_sfx("pass", 0.85)
	if best_mate and sender.team_id == 0: _set_active_human(best_mate)
	Input.vibrate_handheld(20)

func execute_shot(shooter: CharacterBody2D, charge_ratio: float, is_one_timer: bool = false) -> void:
	if puck.carrier != shooter and not is_one_timer: return
	var target_x = 990.0 if shooter.team_id == 0 else -990.0
	var corner_y = clamp(shooter.facing_dir.y * 48.0, -42.0, 42.0)
	var spread = (5 - shooter.stat_acc) * 6.0
	var shot_dir = (Vector2(target_x, corner_y + randf_range(-spread, spread)) - puck.global_position).normalized()
	var final_spd = (TUNING["shot_speed_base"] + shooter.stat_sht * TUNING["shot_speed_per_sht"]) * clamp(charge_ratio, 0.58, 1.0) * (1.28 if is_one_timer else 1.0)
	shooter.pickup_cooldown = 0.35; shooter.is_charging_shot = false; shooter.shot_charge = 0.0; shooter.shoot_anim_timer = 0.26
	puck.launch(shot_dir, final_spd, false, shooter.team_id, true)
	if shooter.team_id == 0: home_sog += 1
	else: away_sog += 1
	if is_one_timer or charge_ratio > 0.8: trigger_hit_feedback(0.04, 8.5)
	AudioManager.play_sfx("onetimer" if is_one_timer else "slapshot", 1.0); Input.vibrate_handheld(65 if is_one_timer else 40)

func _input(event: InputEvent) -> void:
	_refresh_layout()
	if app_mode != AppMode.MATCH or paused:
		if menu:
			menu.handle_event(event, self)
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if app_mode != AppMode.MATCH or paused:
			if menu:
				menu.handle_event(event, self)
			return
		if gamepad:
			gamepad.handle_event(event, self)
		return
	if event is InputEventKey:
		_game_key(event)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.position, event.index)
		else:
			_pointer_up(event.position, event.index)
	elif event is InputEventScreenDrag and event.index == joy_touch_id:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down(event.position, -2)
		else:
			_pointer_up(event.position, -2)
	elif event is InputEventMouseMotion and joy_touch_id == -2:
		_update_joystick(event.position)

func _game_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var key := event.keycode
	if key == KEY_ESCAPE or key == KEY_P:
		set_paused(true)
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER:
		if state == GameState.GAME_OVER:
			restart_match()
		else:
			_on_button_a_pressed()
		return
	if key == KEY_X or key == KEY_K:
		_on_button_a_pressed()

func _pointer_down(pos: Vector2, pointer_id: int) -> void:
	if pause_rect.has_point(pos):
		set_paused(true)
		return
	if state == GameState.GAME_OVER and not _controls_hit(pos):
		restart_match()
		return
	if pos.distance_to(joy_center) <= joy_radius + 28.0:
		joy_touch_id = pointer_id
		keyboard_driving = false
		_update_joystick(pos)
		return
	if btn_a_rect.has_point(pos):
		_on_button_a_pressed()
	elif btn_b_rect.has_point(pos):
		btn_b_held = true
		b_pointer = pointer_id
		_on_button_b_pressed()
	elif btn_c_rect.has_point(pos):
		btn_c_held = true
		c_pointer = pointer_id
		Input.vibrate_handheld(15)

func _pointer_up(pos: Vector2, pointer_id: int) -> void:
	if pointer_id == joy_touch_id:
		joy_touch_id = -1
		joy_knob = joy_center
		joy_vector = Vector2.ZERO
	if pointer_id == b_pointer:
		btn_b_held = false
		b_pointer = -99
		_on_button_b_released()
	if pointer_id == c_pointer:
		btn_c_held = false
		c_pointer = -99

func _controls_hit(pos: Vector2) -> bool:
	if pause_rect.has_point(pos):
		return true
	if pos.distance_to(joy_center) <= joy_radius + 28.0:
		return true
	return btn_a_rect.has_point(pos) or btn_b_rect.has_point(pos) or btn_c_rect.has_point(pos)

func _update_joystick(touch_pos: Vector2) -> void:
	var delta := touch_pos - joy_center
	var max_r := joy_radius * 0.86
	if delta.length() > max_r:
		delta = delta.normalized() * max_r
	joy_knob = joy_center + delta
	joy_vector = (delta / max_r) if delta.length() > 12.0 else Vector2.ZERO

func _poll_keyboard() -> void:
	if joy_touch_id != -1:
		return
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	if v.length() > 0.1:
		joy_vector = v.normalized()
		joy_knob = joy_center + joy_vector * (joy_radius * 0.72)
		keyboard_driving = true
	elif keyboard_driving:
		joy_vector = Vector2.ZERO
		joy_knob = joy_center
		keyboard_driving = false

func _poll_shoot_key() -> void:
	var down: bool = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_Z) or (gamepad != null and gamepad.is_shoot_held())
	if not btn_b_held:
		if down and not shoot_key_down:
			_on_button_b_pressed()
		elif not down and shoot_key_down:
			_on_button_b_released()
	shoot_key_down = down

func _poll_gamepad() -> void:
	if not gamepad or joy_touch_id != -1:
		return
	var pad_move: Vector2 = gamepad.poll_move()
	if pad_move.length() > 0.05:
		joy_vector = pad_move
		joy_knob = joy_center + pad_move * (joy_radius * 0.72)
		keyboard_driving = false
	elif not keyboard_driving:
		joy_vector = Vector2.ZERO
		joy_knob = joy_center

func _turbo_held() -> bool:
	return btn_c_held or Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_L) or (gamepad != null and gamepad.is_turbo_held())

func _on_button_a_pressed() -> void:
	if state == GameState.FACEOFF:
		_attempt_faceoff_timing_win()
		return
	if not active_human:
		return
	if puck.carrier == active_human:
		execute_pass(active_human)
	else:
		var nearest = _find_nearest_home_skater(puck.global_position)
		if nearest:
			_set_active_human(nearest)
		Input.vibrate_handheld(20)

func _on_button_b_pressed() -> void:
	if state == GameState.FACEOFF:
		_attempt_faceoff_timing_win()
		return
	if not active_human:
		return
	if puck.pass_in_flight and puck.last_team == 0 and active_human.global_position.distance_to(puck.global_position) < 105.0:
		puck.global_position = active_human.global_position + active_human.facing_dir * 22.0
		execute_shot(active_human, 1.0, true)
		banner_text = "ONE-TIMER!"
		banner_timer = 1.1
		return
	if puck.carrier == active_human:
		active_human.is_charging_shot = true
		active_human.shot_charge = 0.32
		Input.vibrate_handheld(20)
	else:
		active_human.start_body_check()

func _attempt_faceoff_timing_win() -> void:
	if faceoff_won_by != -1:
		return
	if state_timer < 0.62:
		faceoff_won_by = 0
		state_timer = 0.05
		banner_text = "FACEOFF WON CLEANLY!"
		banner_timer = 0.9
		Input.vibrate_handheld(35)
	else:
		faceoff_won_by = 1
		banner_text = "JUMPED EARLY — FACEOFF LOST"
		banner_timer = 0.9

func _on_button_b_released() -> void:
	if active_human and active_human.is_charging_shot:
		if puck.carrier == active_human:
			execute_shot(active_human, active_human.shot_charge, false)
		else:
			active_human.is_charging_shot = false

func _find_nearest_home_skater(pos: Vector2) -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_d: float = 999999.0
	for s in home_skaters:
		if not s.is_goalie:
			var d = s.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = s
	return best

func is_closest_ai_chaser(skater: CharacterBody2D) -> bool:
	var team_list = home_skaters if skater.team_id == 0 else away_skaters
	var my_d = skater.global_position.distance_to(puck.global_position)
	for s in team_list:
		if s != skater and not s.is_goalie and not s.is_human:
			if s.global_position.distance_to(puck.global_position) < my_d - 8.0:
				return false
	return true

func get_all_skaters() -> Array:
	return home_skaters + away_skaters

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud_layer)
	hud_drawer = Control.new()
	hud_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_drawer.draw.connect(_draw_hud)
	hud_layer.add_child(hud_drawer)

func _refresh_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 100.0 or vp.y < 100.0:
		vp = Vector2(1920, 864)
	var hud: Dictionary = Layout.hud(vp)
	pause_rect = hud["pause"]
	joy_center = hud["joy_center"]
	joy_radius = hud["joy_radius"]
	btn_a_rect = hud["pass"]
	btn_b_rect = hud["shoot"]
	btn_c_rect = hud["turbo"]
	if joy_touch_id == -1 and not keyboard_driving:
		joy_knob = joy_center

func _draw() -> void:
	var font = ThemeDB.fallback_font
	draw_rect(Rect2(-1320, -640, 2640, 1280), Color(0.10, 0.11, 0.16), true)
	for cx in range(-1140, 1140, 32):
		draw_rect(Rect2(cx, -520, 14, 14), Color.from_hsv(abs(cx * 0.013) - floor(abs(cx * 0.013)), 0.55, 0.78))
		draw_rect(Rect2(cx, 488, 14, 14), Color.from_hsv(abs(cx * 0.019) - floor(abs(cx * 0.019)), 0.55, 0.78))
	draw_rect(Rect2(-1100, -440, 2200, 880), Color(0.89, 0.95, 0.99), true)
	for sc in skate_scratches:
		draw_line(sc["p1"], sc["p1"] + sc["dir"], Color(0.76, 0.87, 0.95, 0.55), 1.6)
	for sp in ice_sprays:
		draw_circle(sp["pos"], 3.2, Color(1.0, 1.0, 1.0, sp["life"] * 2.5))
	draw_line(Vector2(-990, -440), Vector2(-990, 440), Color(0.82, 0.15, 0.15, 0.75), 4.0)
	draw_line(Vector2(990, -440), Vector2(990, 440), Color(0.82, 0.15, 0.15, 0.75), 4.0)
	draw_line(Vector2(-330, -440), Vector2(-330, 440), Color(0.12, 0.38, 0.86, 0.82), 11.0)
	draw_line(Vector2(330, -440), Vector2(330, 440), Color(0.12, 0.38, 0.86, 0.82), 11.0)
	draw_line(Vector2(0, -440), Vector2(0, 440), Color(0.84, 0.12, 0.14, 0.82), 10.0)
	draw_dashed_line(Vector2(0, -440), Vector2(0, 440), Color(0.92, 0.96, 1.0, 0.9), 6.0, 18.0)
	draw_circle(Vector2.ZERO, 118.0, Color(0.75, 0.88, 1.0, 0.16))
	draw_arc(Vector2.ZERO, 118.0, 0, TAU, 48, Color(0.12, 0.38, 0.86, 0.85), 5.0)
	Logo.draw_mark(self, Vector2.ZERO, 44.0, menu_time)
	for dot in [Vector2(-640, -200), Vector2(-640, 200), Vector2(640, -200), Vector2(640, 200)]:
		draw_arc(dot, 92.0, 0, TAU, 36, Color(0.84, 0.12, 0.14, 0.72), 3.5)
		draw_circle(dot, 8.0, Color(0.84, 0.12, 0.14))
	_draw_pro_goal_net(Vector2(-990, 0), -1.0)
	_draw_pro_goal_net(Vector2(990, 0), 1.0)
	if app_mode == AppMode.MATCH and state == GameState.GOAL_CELEBRATION:
		var lamp_x = 1068.0 if last_scoring_team == 0 else -1068.0
		var pulse = abs(sin(state_timer * 14.0))
		draw_circle(Vector2(lamp_x, 0), 26.0 + pulse * 18.0, Color(1.0, 0.1, 0.1, 0.55 * pulse))
		draw_circle(Vector2(lamp_x, 0), 10.0, Color(1.0, 0.25, 0.2))
	if app_mode == AppMode.MATCH and not paused and state == GameState.PLAY and pass_target_mate and is_instance_valid(pass_target_mate):
		draw_arc(pass_target_mate.global_position + Vector2(0, 10), 22.0, 0, TAU, 20, Color(0.15, 0.95, 0.35, 0.88), 2.8)
	if app_mode == AppMode.MATCH and state == GameState.FACEOFF:
		var ring_r = clamp((state_timer / 1.65) * 85.0, 8.0, 85.0)
		var ring_col = Color(0.15, 0.95, 0.35, 0.95) if state_timer < 0.62 else Color(1.0, 0.85, 0.15, 0.85)
		draw_arc(faceoff_pos, ring_r, 0, TAU, 28, ring_col, 4.0)
	draw_rect(Rect2(-1100, -440, 2200, 880), Color(0.95, 0.80, 0.15), false, 8.0)
	draw_rect(Rect2(-1112, -452, 2224, 904), Color(0.95, 0.96, 0.98), false, 14.0)
	draw_rect(Rect2(-1120, -460, 2240, 920), Color(0.85, 0.14, 0.14), false, 5.0)
	for gx in range(-1000, 1050, 200):
		draw_line(Vector2(gx, -444), Vector2(gx, -468), Color(0.7, 0.85, 0.95, 0.65), 3.0)
		draw_line(Vector2(gx, 444), Vector2(gx, 468), Color(0.7, 0.85, 0.95, 0.65), 3.0)
	if app_mode == AppMode.MATCH and state == GameState.INTERMISSION:
		draw_rect(Rect2(resurfacer_pos.x - 70, resurfacer_pos.y - 28, 150, 56), Color("#E7E1D6"), true)
		draw_rect(Rect2(resurfacer_pos.x - 8, resurfacer_pos.y - 36, 84, 42), Color("#C4553A"), true)
		draw_rect(Rect2(resurfacer_pos.x - 78, resurfacer_pos.y + 8, 30, 16), Color("#5C6B7A"), true)
		draw_string(font, Vector2(resurfacer_pos.x - 28, resurfacer_pos.y + 4), "ICE", HORIZONTAL_ALIGNMENT_LEFT, 80, 16, Color("#1A140C"))

func _draw_pro_goal_net(post_center: Vector2, dir_sign: float) -> void:
	draw_circle(post_center, 54.0, Color(0.32, 0.72, 0.96, 0.55))
	draw_arc(post_center, 54.0, -PI * 0.5 if dir_sign < 0 else PI * 0.5, PI * 0.5 if dir_sign < 0 else PI * 1.5, 24, Color(0.84, 0.12, 0.14, 0.85), 3.0)
	var p_top = post_center + Vector2(0, -54); var p_bot = post_center + Vector2(0, 54)
	var b_top = post_center + Vector2(dir_sign * 46.0, -42); var b_bot = post_center + Vector2(dir_sign * 46.0, 42)
	draw_colored_polygon(PackedVector2Array([p_top, b_top, b_bot, p_bot]), Color(0.92, 0.95, 0.98, 0.65))
	for m in range(1, 6):
		var t = float(m) / 6.0
		draw_line(p_top.lerp(p_bot, t), b_top.lerp(b_bot, t), Color(0.65, 0.7, 0.75, 0.7), 1.5)
		draw_line(p_top.lerp(b_top, t), p_bot.lerp(b_bot, t), Color(0.65, 0.7, 0.75, 0.7), 1.5)
	draw_polyline(PackedVector2Array([p_top, b_top, b_bot, p_bot]), Color(0.86, 0.12, 0.14), 5.0)
	draw_circle(p_top, 5.5, Color(0.9, 0.15, 0.15)); draw_circle(p_bot, 5.5, Color(0.9, 0.15, 0.15))

func _draw_hud() -> void:
	var font = ThemeDB.fallback_font
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 100.0:
		vp = Vector2(1920, 864)
	if app_mode != AppMode.MATCH:
		if menu:
			menu.draw_on(hud_drawer, vp, self, menu_time)
		return
	if goal_flash_alpha > 0.01:
		hud_drawer.draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.2, 0.2, goal_flash_alpha * 0.45), true)
	var board := Rect2((vp.x - 940.0) * 0.5, 14, 940, 82)
	var home_col := Color(str(home_info.get("primary", "#5E6EF2")))
	var away_col := Color(str(away_info.get("primary", "#D4653E")))
	hud_drawer.draw_rect(board, Color(0.05, 0.07, 0.12, 0.84), true)
	hud_drawer.draw_rect(Rect2(board.position.x + 4, 18, 250, 74), home_col, true)
	hud_drawer.draw_rect(Rect2(board.end.x - 254, 18, 250, 74), away_col, true)
	hud_drawer.draw_rect(board, Color(0.95, 0.82, 0.2, 0.9), false, 3.0)
	Logo.draw_centered(hud_drawer, font, Rect2(board.position.x + 4, 18, 250, 74), "%s  %d" % [home_info.get("abbr", "HCF"), home_score], 34, _ink_on(home_col))
	Logo.draw_centered(hud_drawer, font, Rect2(board.end.x - 254, 18, 250, 74), "%d  %s" % [away_score, away_info.get("abbr", "RWL")], 34, _ink_on(away_col))
	Logo.draw_centered(hud_drawer, font, Rect2(board.position.x + 260, 18, 420, 46), "P%d   %02d:%02d" % [period, int(period_clock) / 60, int(period_clock) % 60], 30, Color(1.0, 0.94, 0.25))
	var sub_str = "SHOTS ON GOAL    %d  –  %d" % [home_sog, away_sog]
	if powerplay_team != -1:
		var pp: String = str(home_info.get("abbr", "HCF")) if powerplay_team == 0 else str(away_info.get("abbr", "RWL"))
		sub_str = "POWER PLAY %s  %02ds    SHOTS %d–%d" % [pp, int(powerplay_clock), home_sog, away_sog]
	Logo.draw_centered(hud_drawer, font, Rect2(board.position.x + 260, 58, 420, 32), sub_str, 16, Color(0.82, 0.94, 1.0))
	if banner_timer > 0.0 and banner_text != "":
		var banner := Rect2(board.position.x + 70, board.end.y + 8, 800, 40)
		hud_drawer.draw_rect(banner, Color(0.04, 0.05, 0.09, 0.72), true)
		hud_drawer.draw_rect(banner, Color(1.0, 0.85, 0.2, 0.75), false, 2.0)
		Logo.draw_centered(hud_drawer, font, banner, banner_text, 20, Color.WHITE)
	if state == GameState.GAME_OVER:
		Logo.draw_centered(hud_drawer, font, Rect2(board.position.x, board.end.y + 54, board.size.x, 32), "PRESS ENTER OR START FOR A REMATCH     ·     TAP THE ICE     ·     PAUSE TO QUIT", 18, Color("#E7F6FF"))
	_draw_pause_button()
	hud_drawer.draw_circle(joy_center, joy_radius, Color(0.08, 0.1, 0.15, 0.34))
	hud_drawer.draw_arc(joy_center, joy_radius, 0, TAU, 40, Color(0.9, 0.95, 1.0, 0.55), 3.0, true)
	hud_drawer.draw_circle(joy_knob, 38.0, Color(0.95, 0.82, 0.15, 0.72))
	var on_offense = (puck and puck.carrier != null and puck.carrier.team_id == 0)
	var lbl_a = "WIN" if state == GameState.FACEOFF else ("PASS" if on_offense else "SWITCH")
	var lbl_b = "WIN" if state == GameState.FACEOFF else ("SHOOT" if on_offense else ("1-TIMER" if (puck and puck.pass_in_flight) else "CHECK"))
	_draw_arcade_btn(btn_a_rect, Color(0.1, 0.78, 0.32, 0.5), lbl_a, font, false)
	_draw_arcade_btn(btn_b_rect, Color(0.92, 0.22, 0.18, 0.5), lbl_b, font, btn_b_held or shoot_key_down)
	_draw_arcade_btn(btn_c_rect, Color(0.15, 0.58, 0.96, 0.55), "TURBO", font, _turbo_held())
	if paused and menu:
		menu.draw_on(hud_drawer, vp, self, menu_time)

func _draw_pause_button() -> void:
	var c := pause_rect.position + pause_rect.size * 0.5
	var rad := pause_rect.size.x * 0.42
	hud_drawer.draw_circle(c, rad, Color(0.05, 0.07, 0.12, 0.78))
	hud_drawer.draw_arc(c, rad, 0, TAU, 32, Logo.GOLD, 3.0, true)
	hud_drawer.draw_rect(Rect2(c.x - 16, c.y - 18, 8, 36), Color("#F4FBFF"), true)
	hud_drawer.draw_rect(Rect2(c.x + 8, c.y - 18, 8, 36), Color("#F4FBFF"), true)

func _ink_on(c: Color) -> Color:
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return Color("#1A140C") if lum > 0.62 else Color("#F7FBFF")

func _draw_arcade_btn(r: Rect2, col: Color, text: String, font: Font, held: bool) -> void:
	var c = r.position + r.size * 0.5
	var fill := col
	if held:
		fill.a = minf(col.a + 0.35, 0.92)
	hud_drawer.draw_circle(c, r.size.x * 0.47, fill)
	hud_drawer.draw_arc(c, r.size.x * 0.47, 0, TAU, 32, Color(1, 1, 1, 0.7 if held else 0.5), 3.5, true)
	Logo.draw_centered(hud_drawer, font, r, text, 20, Color(1, 1, 1, 0.95))

func _self_test() -> void:
	if not _ok(app_mode == AppMode.TITLE, "boot on title"):
		return
	if not _ok(home_skaters.is_empty(), "no skaters before a match"):
		return
	if not _ok(gamepad != null, "gamepad manager present"):
		return
	if not _ok(GamepadScript.DEADZONE == 0.2, "gamepad deadzone 0.20"):
		return
	if not _ok(float(TUNING["pass_speed_base"]) == 640.0, "tuning pass speed 640"):
		return
	start_match(0)
	if not _ok(app_mode == AppMode.MATCH, "match started"):
		return
	if not _ok(str(home_info.get("abbr", "")) == "HCF", "home abbr"):
		return
	if not _ok(str(away_info.get("abbr", "")) == "RWL", "away abbr"):
		return
	if not _ok(home_skaters.size() == 6 and away_skaters.size() == 6, "roster size"):
		return
	if not _ok(home_skaters[0].player_name == "VOSS" and str(home_skaters[0].jersey_num) == "21", "home center"):
		return
	if not _ok(away_skaters[0].player_name == "MARLOW", "away center"):
		return
	set_paused(true)
	if not _ok(paused, "paused"):
		return
	home_score = 4
	period = 3
	restart_match()
	if not _ok(not paused and home_score == 0 and period == 1, "restart reset"):
		return
	if not _ok(home_skaters[0].player_name == "VOSS", "restart keeps club"):
		return
	quit_to_title()
	if not _ok(app_mode == AppMode.TITLE and home_skaters.is_empty() and puck == null, "quit to title"):
		return
	start_match(1)
	if not _ok(str(home_info.get("abbr", "")) == "RWL" and str(away_info.get("abbr", "")) == "HCF", "swapped clubs"):
		return
	if not _ok(home_skaters[0].player_name == "MARLOW", "player club is home"):
		return
	quit_to_title()
	if not _ok(app_mode == AppMode.TITLE, "quit to title again"):
		return
	show_team_select()
	var quick_key := InputEventKey.new()
	quick_key.keycode = KEY_ENTER
	quick_key.pressed = true
	menu.handle_event(quick_key, self)
	if not _ok(app_mode == AppMode.MATCH and str(home_info.get("abbr", "")) == "HCF", "quick match starts first club"):
		return
	print("SELF-TEST OK")
	get_tree().quit(0)

func _ok(cond: bool, msg: String) -> bool:
	if cond:
		return true
	print("SELF-TEST FAIL: ", msg)
	push_error("SELF-TEST FAIL: " + msg)
	get_tree().quit(1)
	return false
