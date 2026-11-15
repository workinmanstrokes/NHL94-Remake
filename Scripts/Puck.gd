extends CharacterBody2D

var carrier: Node2D = null
var last_team: int = -1
var pass_in_flight: bool = false
var one_timer_window: float = 0.0
var is_shot_on_goal: bool = false
var start_x_launch: float = 0.0
var trail_points: Array = []
var game_mgr: Node2D = null

const ICE_FRICTION: float = 175.0
const BOUNCE_RESTITUTION: float = 0.76

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if game_mgr and game_mgr.paused:
		return
	if one_timer_window > 0.0:
		one_timer_window -= delta
		if one_timer_window <= 0.0: pass_in_flight = false
	if carrier and is_instance_valid(carrier):
		var stick_pos = carrier.global_position + carrier.facing_dir * 24.0 + Vector2(0, 6)
		global_position = global_position.lerp(stick_pos, 0.62)
		velocity = carrier.velocity
		trail_points.clear()
	else:
		if velocity.length() > 380.0:
			trail_points.push_front(global_position)
			if trail_points.size() > 7: trail_points.pop_back()
		elif trail_points.size() > 0:
			trail_points.pop_back()
		velocity = velocity.move_toward(Vector2.ZERO, ICE_FRICTION * delta)
		var col = move_and_collide(velocity * delta)
		if col:
			velocity = velocity.bounce(col.get_normal()) * BOUNCE_RESTITUTION
			is_shot_on_goal = false
			var collider = col.get_collider()
			if collider and collider.is_in_group("GoalPosts"):
				AudioManager.play_sfx("post_ping", 1.0)
				Input.vibrate_handheld(65)
			else:
				AudioManager.play_sfx("board_crack", clamp(velocity.length() / 900.0, 0.15, 0.9))
	queue_redraw()

func launch(dir: Vector2, speed: float, is_pass: bool, from_team: int, shot_on_net: bool = false) -> void:
	carrier = null
	last_team = from_team
	start_x_launch = global_position.x
	velocity = dir.normalized() * speed
	pass_in_flight = is_pass
	one_timer_window = 0.60 if is_pass else 0.0
	is_shot_on_goal = shot_on_net

func _draw() -> void:
	for i in range(trail_points.size()):
		var local_pt = trail_points[i] - global_position
		var alpha = (1.0 - float(i) / max(1, trail_points.size())) * 0.42
		draw_circle(local_pt, 6.0 * (1.0 - float(i) * 0.1), Color(0.75, 0.92, 1.0, alpha))
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.3, 0.75))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 6.2, Color(0.06, 0.06, 0.08))
	draw_circle(Vector2(-1.5, -1.5), 2.0, Color(0.38, 0.38, 0.45))
