extends Node2D

enum GameState { FACEOFF, PLAY, GOAL_CELEBRATION, PENALTY_CALL, FIGHT, ZAMBONI_INTERMISSION, GAME_OVER }
var state: GameState = GameState.FACEOFF
var state_timer: float = 2.0

var home_score: int = 0; var away_score: int = 0; var home_sog: int = 0; var away_sog: int = 0
var period: int = 1; var period_clock: float = 120.0
var powerplay_team: int = -1; var powerplay_clock: float = 0.0; var last_scoring_team: int = 0
var banner_text: String = ""; var banner_timer: float = 0.0
var faceoff_pos: Vector2 = Vector2.ZERO; var faceoff_won_by: int = -1
var zamboni_pos: Vector2 = Vector2(-950, 0); var hitstop_timer: float = 0.0; var goal_flash_alpha: float = 0.0

var y_sort_layer: Node2D; var puck: CharacterBody2D; var cam: Camera2D
var home_skaters: Array = []; var away_skaters: Array = []
var active_human: CharacterBody2D = null; var pass_target_mate: CharacterBody2D = null
var auto_switch_cd: float = 0.0; var ice_sprays: Array = []; var skate_scratches: Array = []

var joy_center: Vector2 = Vector2(155, 715); var joy_knob: Vector2 = Vector2(155, 715)
var joy_touch_id: int = -1; var joy_vector: Vector2 = Vector2.ZERO

var btn_a_rect: Rect2 = Rect2(1490, 665, 138, 138)
var btn_c_rect: Rect2 = Rect2(1695, 645, 152, 152)
var btn_b_rect: Rect2 = Rect2(1660, 465, 146, 146)

var btn_b_held: bool = false; var btn_c_held: bool = false
var hud_layer: CanvasLayer; var hud_drawer: Control

func _ready() -> void:
	for i in range(55):
		skate_scratches.append({"p1": Vector2(randf_range(-940, 940), randf_range(-380, 380)), "dir": Vector2.from_angle(randf_range(0, TAU)) * randf_range(22, 55)})
	_build_rink_collision()
	y_sort_layer = Node2D.new(); y_sort_layer.y_sort_enabled = true; add_child(y_sort_layer)
	_spawn_puck_and_teams()
	cam = Camera2D.new(); cam.set_script(load("res://Scripts/OverheadCamera.gd")); cam.game_mgr = self; add_child(cam)
	_build_hud()
	_enter_faceoff(Vector2.ZERO, "TAP [WIN] WHEN GREEN RING HITS THE DOT!")

func _build_rink_collision() -> void:
	var boards = StaticBody2D.new(); boards.collision_layer = 1; boards.add_to_group("Boards"); add_child(boards)
	for r in [Rect2(-1140, -480, 2280, 40), Rect2(-1140, 440, 2280, 40), Rect2(-1140, -480, 40, 960), Rect2(1100, -480, 40, 960)]:
		var c = CollisionShape2D.new(); var s = RectangleShape2D.new(); s.size = r.size; c.shape = s; c.position = r.position + r.size * 0.5; boards.add_child(c)
	var posts = StaticBody2D.new(); posts.collision_layer = 1; posts.add_to_group("GoalPosts"); add_child(posts)
	for gp in [Vector2(-990, -54), Vector2(-990, 54), Vector2(990, -54), Vector2(990, 54)]:
		var pc = CollisionShape2D.new(); var ps = CircleShape2D.new(); ps.radius = 6.5; pc.shape = ps; pc.position = gp; posts.add_child(pc)

func _spawn_puck_and_teams() -> void:
	puck = CharacterBody2D.new(); puck.set_script(load("res://Scripts/Puck.gd"))
	var pc = CollisionShape2D.new(); var ps = CircleShape2D.new(); ps.radius = 6.0; pc.shape = ps; puck.add_child(pc); y_sort_layer.add_child(puck)
	var roster_file = FileAccess.open("res://Data/rosters.json", FileAccess.READ)
	var r_json = JSON.parse_string(roster_file.get_as_text())
	var home_data = r_json["teams"]["SJ_SHARKS"]; var away_data = r_json["teams"]["LA_KINGS"]
	for p in home_data["players"]: home_skaters.append(_create_skater(p, 0, Color(home_data["primary"]), Color(home_data["secondary"]), Color(home_data["trim"])))
	for p in away_data["players"]: away_skaters.append(_create_skater(p, 1, Color(away_data["primary"]), Color(away_data["secondary"]), Color(away_data["trim"])))
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
	for s in home_skaters: s.global_position = pos + h_off.get(s.role, Vector2(-100, 0)); s.velocity = Vector2.ZERO; s.stunned_timer = 0.0; s.facing_dir = Vector2.RIGHT
	for s in away_skaters: s.global_position = pos + a_off.get(s.role, Vector2(100, 0)); s.velocity = Vector2.ZERO; s.stunned_timer = 0.0; s.facing_dir = Vector2.LEFT
	_set_active_human(home_skaters[0])

func _process(delta: float) -> void:
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
		active_human.move_input = joy_vector; active_human.turbo_active = btn_c_held
		pass_target_mate = _find_best_pass_target(active_human) if puck.carrier == active_human else null
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
			if (puck.carrier == null or puck.carrier.team_id != 0) and auto_switch_cd <= 0.0:
				var best = _find_nearest_home_skater(puck.global_position)
				if best and best != active_human and best.global_position.distance_to(puck.global_position) + 55.0 < active_human.global_position.distance_to(puck.global_position):
					_set_active_human(best); auto_switch_cd = 0.50
			if period_clock <= 0.0: _end_period()
		GameState.GOAL_CELEBRATION:
			state_timer -= delta
			if state_timer <= 0.0: _enter_faceoff(Vector2.ZERO, "CENTER ICE FACEOFF - TAP [WIN] ON GREEN!")
		GameState.PENALTY_CALL, GameState.FIGHT:
			state_timer -= delta
			if state_timer <= 0.0: _enter_faceoff(faceoff_pos, "POWER PLAY FACEOFF!")
		GameState.ZAMBONI_INTERMISSION:
			state_timer -= delta; zamboni_pos.x += 580.0 * delta
			if state_timer <= 0.0: period += 1; period_clock = 120.0; _enter_faceoff(Vector2.ZERO, "PERIOD %d FACEOFF!" % period)
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
			home_score += 1; _trigger_goal_celebration("GOAL! PACIFIC TEAL SHARKS SCORE!", 0)
		elif puck.global_position.x < -990.0 and puck.global_position.x > -1048.0:
			away_score += 1; _trigger_goal_celebration("GOAL! ROYAL GOLD KINGS SCORE!", 1)

func _trigger_goal_celebration(msg: String, scoring_team: int) -> void:
	state = GameState.GOAL_CELEBRATION; state_timer = 3.8; last_scoring_team = scoring_team
	goal_flash_alpha = 0.65; banner_text = msg; banner_timer = 3.8; puck.carrier = null; puck.velocity = Vector2.ZERO
	if cam: cam.add_shake(16.0)
	if powerplay_team == scoring_team: powerplay_team = -1; powerplay_clock = 0.0
	AudioManager.play_sfx("goal_horn", 1.0); Input.vibrate_handheld(260)

func _end_period() -> void:
	if period < 3:
		state = GameState.ZAMBONI_INTERMISSION; state_timer = 3.8; zamboni_pos = Vector2(-1050, 0)
		banner_text = "END OF PERIOD %d - ZAMBONI ICE RESURFACING" % period; banner_timer = 3.8
		AudioManager.play_sfx("organ_charge", 0.9)
	else:
		state = GameState.GAME_OVER; banner_text = "FINAL: PTS %d - %d RGK (TAP TO PLAY AGAIN)" % [home_score, away_score]; banner_timer = 999.0

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
		banner_text = "2:00 POWER PLAY! BOARDING ON #%s %s" % [hitter.jersey_num, hitter.player_name]; banner_timer = 2.2
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
	puck.launch(pass_dir, 590.0 + sender.stat_pas * 45.0, true, sender.team_id, false)
	AudioManager.play_sfx("pass", 0.85)
	if best_mate and sender.team_id == 0: _set_active_human(best_mate)
	Input.vibrate_handheld(20)

func execute_shot(shooter: CharacterBody2D, charge_ratio: float, is_one_timer: bool = false) -> void:
	if puck.carrier != shooter and not is_one_timer: return
	var target_x = 990.0 if shooter.team_id == 0 else -990.0
	var corner_y = clamp(shooter.facing_dir.y * 48.0, -42.0, 42.0)
	var spread = (5 - shooter.stat_acc) * 6.0
	var shot_dir = (Vector2(target_x, corner_y + randf_range(-spread, spread)) - puck.global_position).normalized()
	var final_spd = (740.0 + shooter.stat_sht * 78.0) * clamp(charge_ratio, 0.58, 1.0) * (1.28 if is_one_timer else 1.0)
	shooter.pickup_cooldown = 0.35; shooter.is_charging_shot = false; shooter.shot_charge = 0.0; shooter.shoot_anim_timer = 0.26
	puck.launch(shot_dir, final_spd, false, shooter.team_id, true)
	if shooter.team_id == 0: home_sog += 1
	else: away_sog += 1
	if is_one_timer or charge_ratio > 0.8: trigger_hit_feedback(0.04, 8.5)
	AudioManager.play_sfx("onetimer" if is_one_timer else "slapshot", 1.0); Input.vibrate_handheld(65 if is_one_timer else 40)

func _input(event: InputEvent) -> void:
	if state == GameState.GAME_OVER and event is InputEventScreenTouch and event.pressed:
		home_score = 0; away_score = 0; home_sog = 0; away_sog = 0; period = 1; period_clock = 120.0
		_enter_faceoff(Vector2.ZERO, "NEW GAME FACEOFF!"); return
	if event is InputEventScreenTouch:
		var pos = event.position
		if event.pressed:
			if pos.distance_to(joy_center) < 195.0: joy_touch_id = event.index; _update_joystick(pos)
			elif btn_a_rect.has_point(pos): _on_button_a_pressed()
			elif btn_b_rect.has_point(pos): btn_b_held = true; _on_button_b_pressed()
			elif btn_c_rect.has_point(pos): btn_c_held = true; Input.vibrate_handheld(15)
		else:
			if event.index == joy_touch_id: joy_touch_id = -1; joy_knob = joy_center; joy_vector = Vector2.ZERO
			if btn_b_held and not btn_a_rect.has_point(pos) and not btn_c_rect.has_point(pos): btn_b_held = false; _on_button_b_released()
			if btn_c_held and btn_c_rect.has_point(pos): btn_c_held = false
	elif event is InputEventScreenDrag and event.index == joy_touch_id:
		_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var delta = touch_pos - joy_center; var max_r = 82.0
	if delta.length() > max_r: delta = delta.normalized() * max_r
	joy_knob = joy_center + delta
	joy_vector = (delta / max_r) if delta.length() > 12.0 else Vector2.ZERO

func _on_button_a_pressed() -> void:
	if state == GameState.FACEOFF: _attempt_faceoff_timing_win(); return
	if not active_human: return
	if puck.carrier == active_human: execute_pass(active_human)
	else:
		var nearest = _find_nearest_home_skater(puck.global_position)
		if nearest: _set_active_human(nearest)
		Input.vibrate_handheld(20)

func _on_button_b_pressed() -> void:
	if state == GameState.FACEOFF: _attempt_faceoff_timing_win(); return
	if not active_human: return
	if puck.pass_in_flight and puck.last_team == 0 and active_human.global_position.distance_to(puck.global_position) < 105.0:
		puck.global_position = active_human.global_position + active_human.facing_dir * 22.0
		execute_shot(active_human, 1.0, true); banner_text = "BOOM! ONE-TIMER BLAST!"; banner_timer = 1.1; return
	if puck.carrier == active_human: active_human.is_charging_shot = true; active_human.shot_charge = 0.32; Input.vibrate_handheld(20)
	else: active_human.start_body_check()

func _attempt_faceoff_timing_win() -> void:
	if faceoff_won_by != -1: return
	if state_timer < 0.62:
		faceoff_won_by = 0; state_timer = 0.05; banner_text = "FACEOFF WON CLEANLY!"; banner_timer = 0.9; Input.vibrate_handheld(35)
	else:
		faceoff_won_by = 1; banner_text = "JUMPED EARLY - FACEOFF LOST!"; banner_timer = 0.9

func _on_button_b_released() -> void:
	if active_human and active_human.is_charging_shot:
		if puck.carrier == active_human: execute_shot(active_human, active_human.shot_charge, false)
		else: active_human.is_charging_shot = false

func _find_nearest_home_skater(pos: Vector2) -> CharacterBody2D:
	var best: CharacterBody2D = null; var best_d: float = 999999.0
	for s in home_skaters:
		if not s.is_goalie:
			var d = s.global_position.distance_to(pos)
			if d < best_d: best_d = d; best = s
	return best

func is_closest_ai_chaser(skater: CharacterBody2D) -> bool:
	var team_list = home_skaters if skater.team_id == 0 else away_skaters
	var my_d = skater.global_position.distance_to(puck.global_position)
	for s in team_list:
		if s != skater and not s.is_goalie and not s.is_human:
			if s.global_position.distance_to(puck.global_position) < my_d - 8.0: return false
	return true

func get_all_skaters() -> Array:
	return home_skaters + away_skaters

func _build_hud() -> void:
	hud_layer = CanvasLayer.new(); add_child(hud_layer)
	hud_drawer = Control.new(); hud_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_drawer.draw.connect(_draw_hud); hud_layer.add_child(hud_drawer)

func _draw() -> void:
	var font = ThemeDB.fallback_font
	draw_rect(Rect2(-1320, -640, 2640, 1280), Color(0.10, 0.11, 0.16), true)
	for cx in range(-1140, 1140, 32):
		draw_rect(Rect2(cx, -520, 14, 14), Color.from_hsv(abs(cx * 0.013) - floor(abs(cx * 0.013)), 0.55, 0.78))
		draw_rect(Rect2(cx, 488, 14, 14), Color.from_hsv(abs(cx * 0.019) - floor(abs(cx * 0.019)), 0.55, 0.78))
	draw_rect(Rect2(-1100, -440, 2200, 880), Color(0.89, 0.95, 0.99), true)
	for sc in skate_scratches: draw_line(sc["p1"], sc["p1"] + sc["dir"], Color(0.76, 0.87, 0.95, 0.55), 1.6)
	for sp in ice_sprays: draw_circle(sp["pos"], 3.2, Color(1.0, 1.0, 1.0, sp["life"] * 2.5))
	draw_line(Vector2(-990, -440), Vector2(-990, 440), Color(0.82, 0.15, 0.15, 0.75), 4.0)
	draw_line(Vector2(990, -440), Vector2(990, 440), Color(0.82, 0.15, 0.15, 0.75), 4.0)
	draw_line(Vector2(-330, -440), Vector2(-330, 440), Color(0.12, 0.38, 0.86, 0.82), 11.0)
	draw_line(Vector2(330, -440), Vector2(330, 440), Color(0.12, 0.38, 0.86, 0.82), 11.0)
	draw_line(Vector2(0, -440), Vector2(0, 440), Color(0.84, 0.12, 0.14, 0.82), 10.0)
	draw_dashed_line(Vector2(0, -440), Vector2(0, 440), Color(0.92, 0.96, 1.0, 0.9), 6.0, 18.0)
	draw_circle(Vector2.ZERO, 118.0, Color(0.0, 0.55, 0.55, 0.18))
	draw_arc(Vector2.ZERO, 118.0, 0, TAU, 48, Color(0.12, 0.38, 0.86, 0.85), 5.0)
	draw_rect(Rect2(-46, -28, 92, 56), Color(0.08, 0.15, 0.32, 0.85), true)
	draw_rect(Rect2(-46, -28, 92, 56), Color(0.95, 0.78, 0.15), false, 3.0)
	draw_string(font, Vector2(-44, 9), "NHL '94", HORIZONTAL_ALIGNMENT_CENTER, 88, 22, Color(0.95, 0.82, 0.2))
	for dot in [Vector2(-640, -200), Vector2(-640, 200), Vector2(640, -200), Vector2(640, 200)]:
		draw_arc(dot, 92.0, 0, TAU, 36, Color(0.84, 0.12, 0.14, 0.72), 3.5); draw_circle(dot, 8.0, Color(0.84, 0.12, 0.14))
	_draw_pro_goal_net(Vector2(-990, 0), -1.0); _draw_pro_goal_net(Vector2(990, 0), 1.0)
	if state == GameState.GOAL_CELEBRATION:
		var lamp_x = 1068.0 if last_scoring_team == 0 else -1068.0
		var pulse = abs(sin(state_timer * 14.0))
		draw_circle(Vector2(lamp_x, 0), 26.0 + pulse * 18.0, Color(1.0, 0.1, 0.1, 0.55 * pulse)); draw_circle(Vector2(lamp_x, 0), 10.0, Color(1.0, 0.25, 0.2))
	if state == GameState.PLAY and pass_target_mate and is_instance_valid(pass_target_mate):
		draw_arc(pass_target_mate.global_position + Vector2(0, 10), 22.0, 0, TAU, 20, Color(0.15, 0.95, 0.35, 0.88), 2.8)
	if state == GameState.FACEOFF:
		var ring_r = clamp((state_timer / 1.65) * 85.0, 8.0, 85.0)
		var ring_col = Color(0.15, 0.95, 0.35, 0.95) if state_timer < 0.62 else Color(1.0, 0.85, 0.15, 0.85)
		draw_arc(faceoff_pos, ring_r, 0, TAU, 28, ring_col, 4.0)
	draw_rect(Rect2(-1100, -440, 2200, 880), Color(0.95, 0.80, 0.15), false, 8.0)
	draw_rect(Rect2(-1112, -452, 2224, 904), Color(0.95, 0.96, 0.98), false, 14.0)
	draw_rect(Rect2(-1120, -460, 2240, 920), Color(0.85, 0.14, 0.14), false, 5.0)
	for gx in range(-1000, 1050, 200):
		draw_line(Vector2(gx, -444), Vector2(gx, -468), Color(0.7, 0.85, 0.95, 0.65), 3.0)
		draw_line(Vector2(gx, 444), Vector2(gx, 468), Color(0.7, 0.85, 0.95, 0.65), 3.0)
	if state == GameState.ZAMBONI_INTERMISSION:
		draw_rect(Rect2(zamboni_pos.x - 60, zamboni_pos.y - 35, 120, 70), Color(0.95, 0.95, 0.98), true)
		draw_rect(Rect2(zamboni_pos.x - 10, zamboni_pos.y - 30, 65, 60), Color(0.0, 0.55, 0.55), true)

func _draw_pro_goal_net(post_center: Vector2, dir_sign: float) -> void:
	draw_circle(post_center, 54.0, Color(0.32, 0.72, 0.96, 0.55))
	draw_arc(post_center, 54.0, -PI*0.5 if dir_sign < 0 else PI*0.5, PI*0.5 if dir_sign < 0 else PI*1.5, 24, Color(0.84, 0.12, 0.14, 0.85), 3.0)
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
	if goal_flash_alpha > 0.01:
		hud_drawer.draw_rect(Rect2(0, 0, 1920, 864), Color(1.0, 0.2, 0.2, goal_flash_alpha * 0.45), true)
	hud_drawer.draw_rect(Rect2(490, 14, 940, 82), Color(0.05, 0.07, 0.12, 0.84), true)
	hud_drawer.draw_rect(Rect2(494, 18, 250, 74), Color(0.0, 0.55, 0.55, 0.85), true)
	hud_drawer.draw_rect(Rect2(1176, 18, 250, 74), Color(0.96, 0.72, 0.0, 0.85), true)
	hud_drawer.draw_rect(Rect2(490, 14, 940, 82), Color(0.95, 0.82, 0.2, 0.9), false, 3.0)
	hud_drawer.draw_string(font, Vector2(505, 58), "PTS  %d" % home_score, HORIZONTAL_ALIGNMENT_CENTER, 230, 36, Color.WHITE)
	hud_drawer.draw_string(font, Vector2(1185, 58), "%d  RGK" % away_score, HORIZONTAL_ALIGNMENT_CENTER, 230, 36, Color(0.12, 0.08, 0.25))
	hud_drawer.draw_string(font, Vector2(750, 52), "P%d   %02d:%02d" % [period, int(period_clock) / 60, int(period_clock) % 60], HORIZONTAL_ALIGNMENT_CENTER, 420, 32, Color(1.0, 0.94, 0.25))
	var sub_str = "SHOTS ON GOAL:  %d  -  %d" % [home_sog, away_sog]
	if powerplay_team != -1: sub_str = "POWER PLAY (%s): %02ds  |  SHOTS: %d-%d" % ["PTS" if powerplay_team == 0 else "RGK", int(powerplay_clock), home_sog, away_sog]
	hud_drawer.draw_string(font, Vector2(750, 84), sub_str, HORIZONTAL_ALIGNMENT_CENTER, 420, 20, Color(0.82, 0.94, 1.0))
	if banner_timer > 0.0 and banner_text != "":
		hud_drawer.draw_rect(Rect2(580, 104, 760, 38), Color(0.04, 0.05, 0.09, 0.68), true)
		hud_drawer.draw_rect(Rect2(580, 104, 760, 38), Color(1.0, 0.85, 0.2, 0.75), false, 2.0)
		hud_drawer.draw_string(font, Vector2(590, 130), banner_text, HORIZONTAL_ALIGNMENT_CENTER, 740, 21, Color.WHITE)
	hud_drawer.draw_circle(joy_center, 86.0, Color(0.08, 0.1, 0.15, 0.34))
	hud_drawer.draw_arc(joy_center, 86.0, 0, TAU, 32, Color(0.9, 0.95, 1.0, 0.42), 3.0)
	hud_drawer.draw_circle(joy_knob, 36.0, Color(0.95, 0.82, 0.15, 0.48))
	var on_offense = (puck and puck.carrier != null and puck.carrier.team_id == 0)
	var lbl_a = "WIN!" if state == GameState.FACEOFF else ("PASS" if on_offense else "SWITCH")
	var lbl_b = "WIN!" if state == GameState.FACEOFF else ("SHOOT" if on_offense else ("1-TIMER!" if (puck and puck.pass_in_flight) else "CHECK"))
	_draw_arcade_btn(btn_a_rect, Color(0.1, 0.78, 0.32, 0.38), lbl_a, font)
	_draw_arcade_btn(btn_b_rect, Color(0.92, 0.22, 0.18, 0.38), lbl_b, font)
	_draw_arcade_btn(btn_c_rect, Color(0.15, 0.58, 0.96, 0.42), "TURBO", font)

func _draw_arcade_btn(r: Rect2, col: Color, text: String, font: Font) -> void:
	var c = r.position + r.size * 0.5
	hud_drawer.draw_circle(c, r.size.x * 0.47, col)
	hud_drawer.draw_arc(c, r.size.x * 0.47, 0, TAU, 28, Color(1.0, 1.0, 1.0, 0.45), 3.5)
	hud_drawer.draw_string(font, Vector2(r.position.x, c.y + 8), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1.0, 1.0, 1.0, 0.82))
