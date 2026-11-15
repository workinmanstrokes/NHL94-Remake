extends CharacterBody2D

var team_id: int = 0
var role: String = "C"
var player_name: String = "PLAYER"
var jersey_num: String = "94"
var primary_color: Color = Color("5E6EF2")
var secondary_color: Color = Color("141824")
var trim_color: Color = Color("E5F7FF")

var stat_spd: int = 4; var stat_sht: int = 4; var stat_acc: int = 4; var stat_chk: int = 4; var stat_pas: int = 4
var is_human: bool = false
var is_goalie: bool = false
var facing_dir: Vector2 = Vector2.RIGHT
var move_input: Vector2 = Vector2.ZERO
var turbo_active: bool = false
var shot_charge: float = 0.0
var is_charging_shot: bool = false
var check_timer: float = 0.0
var shoot_anim_timer: float = 0.0
var stunned_timer: float = 0.0
var pickup_cooldown: float = 0.0
var anim_phase: float = 0.0
var celebrate_phase: float = 0.0
var goalie_save_pose: int = 0
var goalie_pose_timer: float = 0.0
var game_mgr: Node2D = null

func setup_stats(data: Dictionary, t_id: int, p_col: Color, s_col: Color, tr_col: Color, mgr: Node2D) -> void:
	player_name = data.get("name", "SKATER")
	jersey_num = data.get("num", "94")
	role = data.get("role", "C")
	stat_spd = data.get("spd", 4); stat_sht = data.get("sht", 4); stat_acc = data.get("acc", 4)
	stat_chk = data.get("chk", 4); stat_pas = data.get("pas", 4)
	team_id = t_id; primary_color = p_col; secondary_color = s_col; trim_color = tr_col
	is_goalie = (role == "G"); game_mgr = mgr
	facing_dir = Vector2.RIGHT if team_id == 0 else Vector2.LEFT
	collision_layer = 2
	collision_mask = 1 | 2

func _physics_process(delta: float) -> void:
	if not game_mgr: return
	if game_mgr.paused:
		return
	if pickup_cooldown > 0.0: pickup_cooldown -= delta
	if shoot_anim_timer > 0.0: shoot_anim_timer -= delta
	if goalie_pose_timer > 0.0:
		goalie_pose_timer -= delta
		if goalie_pose_timer <= 0.0: goalie_save_pose = 0
	if game_mgr.state == game_mgr.GameState.GOAL_CELEBRATION:
		celebrate_phase += delta * 12.0
		if team_id == game_mgr.last_scoring_team and not is_goalie:
			var huddle = Vector2(550.0 if team_id == 0 else -550.0, 0.0)
			velocity = (huddle - global_position).normalized() * 140.0 if global_position.distance_to(huddle) > 65.0 else Vector2.ZERO
			move_and_slide()
		queue_redraw()
		return
	if stunned_timer > 0.0:
		stunned_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 380.0 * delta)
		move_and_slide(); queue_redraw(); return
	if check_timer > 0.0: check_timer -= delta
	if game_mgr.state != game_mgr.GameState.PLAY:
		velocity = velocity.move_toward(Vector2.ZERO, 650.0 * delta)
		move_and_slide(); queue_redraw(); return
	if is_goalie:
		_process_goalie(delta); queue_redraw(); return
	if not is_human: _process_ai_role(delta)
	var max_spd = (205.0 + stat_spd * 48.0) * (1.30 if turbo_active else 1.0)
	var accel = 520.0 + stat_spd * 75.0
	if check_timer <= 0.0:
		if move_input.length() > 0.1:
			facing_dir = move_input.normalized()
			if velocity.length() > 150.0 and velocity.normalized().dot(facing_dir) < -0.45:
				velocity = velocity.move_toward(Vector2.ZERO, 1020.0 * delta)
				game_mgr.spawn_ice_spray(global_position + Vector2(0, 8), -facing_dir)
			else:
				velocity = velocity.move_toward(facing_dir * max_spd, accel * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 175.0 * delta)
	if is_charging_shot: shot_charge = clamp(shot_charge + delta * 1.75, 0.25, 1.0)
	for other in game_mgr.get_all_skaters():
		if other != self:
			var diff = global_position - other.global_position
			var d = diff.length()
			if d > 0.01 and d < 30.0: velocity += diff.normalized() * (30.0 - d) * 32.0 * delta
	move_and_slide()
	_check_body_collisions()
	anim_phase += velocity.length() * delta * 0.052
	queue_redraw()

func _process_goalie(delta: float) -> void:
	var puck = game_mgr.puck
	var net_x = -982.0 if team_id == 0 else 982.0
	var out_dir = 1.0 if team_id == 0 else -1.0
	facing_dir = Vector2(out_dir, 0.0)
	var depth_x = net_x + out_dir * clamp(32.0 - abs(puck.global_position.x - net_x) * 0.03, 12.0, 32.0)
	var target_y = clamp(puck.global_position.y * 0.65, -52.0, 52.0)
	global_position = global_position.move_toward(Vector2(depth_x, target_y), (175.0 + stat_spd * 38.0) * delta)
	if puck.carrier == null and pickup_cooldown <= 0.0:
		var reach = 42.0 if puck.is_shot_on_goal else 30.0
		if global_position.distance_to(puck.global_position) < reach:
			pickup_cooldown = 0.28
			var shot_spd = puck.velocity.length()
			goalie_save_pose = (2 if shot_spd > 650.0 else 3) if abs(puck.global_position.y - global_position.y) > 22.0 else 1
			goalie_pose_timer = 0.55
			AudioManager.play_sfx("pad_save", 0.95)
			Input.vibrate_handheld(35)
			var corner_y = -280.0 if puck.global_position.y < 0.0 else 280.0
			var clear_dir = (Vector2(net_x + out_dir * 320.0, corner_y) - global_position).normalized()
			puck.launch(clear_dir, clamp(shot_spd * 0.48, 320.0, 520.0), true, team_id, false)
			game_mgr.banner_text = "GREAT SAVE BY #%s %s!" % [jersey_num, player_name]
			game_mgr.banner_timer = 1.0

func _process_ai_role(_delta: float) -> void:
	var puck = game_mgr.puck
	var attack_dir = 1.0 if team_id == 0 else -1.0
	if puck.carrier == self:
		var slot_target = Vector2(720.0 * attack_dir, clamp(global_position.y * 0.5, -140.0, 140.0))
		move_input = (slot_target - global_position).normalized()
		if abs(990.0 * attack_dir - global_position.x) < 340.0 and abs(global_position.y) < 190.0 and randf() < 0.011:
			shoot_anim_timer = 0.25; game_mgr.execute_shot(self, 0.72)
		elif randf() < 0.009:
			game_mgr.execute_pass(self)
		return
	if game_mgr.is_closest_ai_chaser(self):
		var target_pt = puck.global_position
		if puck.carrier and puck.carrier.team_id != team_id:
			target_pt = puck.carrier.global_position.lerp(Vector2(-990.0 * attack_dir, 0.0), 0.14)
			if global_position.distance_to(puck.carrier.global_position) < 48.0 and randf() < 0.06:
				start_body_check()
		move_input = (target_pt - global_position).normalized()
		return
	var px = clamp(puck.global_position.x, -720.0, 720.0)
	var zone_shift = 130.0 if (puck.carrier != null and puck.carrier.team_id == team_id) else -95.0
	var anchor = Vector2.ZERO
	match role:
		"C":  anchor = Vector2(px + (zone_shift * 0.6) * attack_dir, clamp(puck.global_position.y * 0.4, -120.0, 120.0))
		"LW": anchor = Vector2(px + (zone_shift + 70.0) * attack_dir, -225.0)
		"RW": anchor = Vector2(px + (zone_shift + 70.0) * attack_dir, 225.0)
		"LD": anchor = Vector2(px + (zone_shift - 250.0) * attack_dir, -145.0)
		"RD": anchor = Vector2(px + (zone_shift - 250.0) * attack_dir, 145.0)
	anchor.x = clamp(anchor.x, -860.0, 860.0)
	var diff = anchor - global_position
	move_input = diff.normalized() if diff.length() > 28.0 else Vector2.ZERO

func start_body_check() -> void:
	if check_timer > 0.0 or stunned_timer > 0.0: return
	check_timer = 0.28
	velocity = facing_dir * (460.0 + stat_chk * 45.0)
	AudioManager.play_sfx("pass", 0.65)
	if is_human: Input.vibrate_handheld(30)

func _check_body_collisions() -> void:
	if check_timer <= 0.0: return
	for s in game_mgr.get_all_skaters():
		if s != self and s.team_id != team_id and not s.is_goalie and s.stunned_timer <= 0.0:
			if global_position.distance_to(s.global_position) < 34.0:
				s.stunned_timer = 0.90; s.velocity = facing_dir * 540.0
				AudioManager.play_sfx("board_crack", 1.0)
				game_mgr.trigger_hit_feedback(0.055, 11.0)
				Input.vibrate_handheld(80)
				if game_mgr.puck.carrier == s:
					game_mgr.puck.carrier = self; s.pickup_cooldown = 0.70
				if abs(s.global_position.y) > 365.0 or abs(s.global_position.x) > 940.0:
					game_mgr.on_crushing_board_hit(self, s)

func _draw() -> void:
	var font = ThemeDB.fallback_font
	draw_set_transform(Vector2(0, 11), 0.0, Vector2(1.45, 0.58))
	draw_circle(Vector2.ZERO, 11.5, Color(0, 0, 0, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_human:
		var ring_col = Color(1.0, 0.92, 0.15, 0.92) if game_mgr.puck.carrier == self else Color(0.15, 0.95, 1.0, 0.80)
		draw_arc(Vector2(0, 10), 19.0, 0, TAU, 24, ring_col, 2.8)
		var nameplate := "#%s %s" % [jersey_num, player_name]
		draw_rect(Rect2(-64, 16, 128, 16), Color(0.05, 0.07, 0.12, 0.78), true)
		draw_string(font, Vector2(-64, 28), nameplate, HORIZONTAL_ALIGNMENT_CENTER, 128, 12, Color(0.95, 0.97, 1.0))
		if is_charging_shot:
			draw_rect(Rect2(-18, -33, 36, 6), Color(0.1, 0.1, 0.1, 0.85), true)
			draw_rect(Rect2(-17, -32, 34.0 * shot_charge, 4), Color(1.0, 0.3, 0.1), true)
			var aim_dir = Vector2(1.0 if team_id == 0 else -1.0, clamp(facing_dir.y * 0.45, -0.4, 0.4)).normalized()
			draw_dashed_line(Vector2.ZERO, aim_dir * 165.0, Color(1.0, 0.25, 0.15, 0.75), 2.5, 8.0)
	if is_goalie:
		_draw_goalie_sprite(); return
	if stunned_timer > 0.0:
		draw_rect(Rect2(-16, -4, 30, 13), primary_color, true)
		draw_rect(Rect2(-6, -4, 10, 13), secondary_color, true)
		draw_circle(Vector2(14, 2), 5.5, Color(0.95, 0.78, 0.64))
		return
	var spd_ratio = clamp(velocity.length() / 360.0, 0.0, 1.0)
	var stride_l = sin(anim_phase) * 6.5 * spd_ratio
	var stride_r = -sin(anim_phase) * 6.5 * spd_ratio
	var body_bob = abs(cos(anim_phase)) * 2.0 * spd_ratio
	draw_rect(Rect2(-9 + stride_l * 0.3, 6 + stride_l, 6, 5), Color(0.12, 0.12, 0.15), true)
	draw_rect(Rect2(3 + stride_r * 0.3, 6 + stride_r, 6, 5), Color(0.12, 0.12, 0.15), true)
	draw_rect(Rect2(-9, 0 - body_bob, 18, 7), secondary_color, true)
	draw_rect(Rect2(-10, -13 - body_bob, 20, 14), primary_color, true)
	draw_rect(Rect2(-10, -3 - body_bob, 20, 3), trim_color, true)
	draw_rect(Rect2(-11, -13 - body_bob, 22, 4), secondary_color, true)
	draw_string(font, Vector2(-10, -4 - body_bob), jersey_num, HORIZONTAL_ALIGNMENT_CENTER, 20, 9, trim_color)
	draw_rect(Rect2(-6, -21 - body_bob, 12, 8), primary_color, true)
	draw_rect(Rect2(-4 + facing_dir.x * 1.5, -18 - body_bob, 8, 5), Color(0.96, 0.80, 0.64), true)
	if game_mgr.state == game_mgr.GameState.GOAL_CELEBRATION and team_id == game_mgr.last_scoring_team:
		draw_line(Vector2(-8, -12), Vector2(12, -26.0 + sin(celebrate_phase) * 5.0), Color(0.86, 0.72, 0.42), 3.2)
		return
	var stick_angle = facing_dir.angle()
	if is_charging_shot: stick_angle -= 1.15 * sign(facing_dir.x if facing_dir.x != 0 else 1.0)
	elif shoot_anim_timer > 0.0: stick_angle += 0.95 * sign(facing_dir.x if facing_dir.x != 0 else 1.0)
	var stick_dir = Vector2.from_angle(stick_angle)
	var stick_end = stick_dir * (25.0 + (11.0 if check_timer > 0.0 else 0.0)) + Vector2(0, 5)
	draw_line(Vector2(0, -3 - body_bob), stick_end, Color(0.86, 0.72, 0.42), 3.2)
	draw_line(stick_end, stick_end + stick_dir.rotated(0.45) * 7.5, trim_color, 3.8)

func _draw_goalie_sprite() -> void:
	var out = facing_dir.x
	if goalie_save_pose == 1:
		draw_rect(Rect2(-18, 2, 17, 8), trim_color, true)
		draw_rect(Rect2(1, 2, 17, 8), trim_color, true)
		draw_rect(Rect2(-16, 4, 32, 4), primary_color, true)
	elif goalie_save_pose == 2:
		draw_rect(Rect2(-18, -4, 28, 7), trim_color, true)
		draw_rect(Rect2(-18, 4, 28, 7), trim_color, true)
	else:
		draw_rect(Rect2(-11, -1, 9, 13), trim_color, true)
		draw_rect(Rect2(2, -1, 9, 13), trim_color, true)
		draw_rect(Rect2(-9, 1, 5, 9), primary_color, true)
		draw_rect(Rect2(4, 1, 5, 9), primary_color, true)
	draw_rect(Rect2(-12, -14, 24, 14), primary_color, true)
	draw_rect(Rect2(-12, -5, 24, 3), secondary_color, true)
	var glove_y = -18.0 if goalie_save_pose == 3 else -8.0
	draw_rect(Rect2(-16, -9, 6, 8), trim_color, true)
	draw_circle(Vector2(14, glove_y), 5.5, secondary_color)
	draw_arc(Vector2(14, glove_y), 5.5, 0, TAU, 12, trim_color, 1.8)
	draw_rect(Rect2(-6, -22, 12, 9), trim_color, true)
	draw_rect(Rect2(-4 + out * 1.5, -20, 8, 6), Color(0.25, 0.28, 0.32), true)
	var g_stick = Vector2(out * 18.0, 10.0)
	draw_line(Vector2(-6, -4), g_stick, Color(0.9, 0.76, 0.45), 4.2)
	draw_line(g_stick, g_stick + Vector2(out * 9.0, 0), primary_color, 4.5)
