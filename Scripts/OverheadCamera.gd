extends Camera2D

var game_mgr: Node2D = null
var shake_amount: float = 0.0

func _ready() -> void:
	zoom = Vector2(1.50, 1.50)

func add_shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)

func _process(delta: float) -> void:
	if not game_mgr or not game_mgr.puck: return
	var puck = game_mgr.puck
	var human = game_mgr.active_human
	var focus = puck.global_position
	if human and is_instance_valid(human):
		focus = puck.global_position.lerp(human.global_position, 0.28)
	var lead = Vector2.ZERO
	if puck.carrier and is_instance_valid(puck.carrier):
		var attack_dir = 1.0 if puck.carrier.team_id == 0 else -1.0
		lead = puck.carrier.velocity * 0.42 + Vector2(attack_dir * 135.0, puck.carrier.facing_dir.y * 55.0)
	else:
		lead = puck.velocity * 0.32
	var target = focus + lead
	target.x = clamp(target.x, -490.0, 490.0)
	target.y = clamp(target.y, -155.0, 155.0)
	global_position = global_position.lerp(target, 7.2 * delta)
	if shake_amount > 0.1:
		offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		shake_amount = move_toward(shake_amount, 0.0, 48.0 * delta)
	else:
		offset = Vector2.ZERO
