extends RefCounted

## 94 Ice Legends v3.2 — physical gamepad support.
## Tester fixes 1, 7 and 13: the v3.1 pad map existed only on paper. No gamepad
## code was in the repo at all (only the touch joystick), so the headline
## feature was unproven. This manager is the first real gamepad input here:
## deadzone, rest-drift sampling, stick + D-pad movement, and the A / B / X /
## Y / LB / RB / Start map. Shooting (X) is polled, not event-driven, so the
## hold-release timing matches the keyboard path exactly.
##
## Mapping (matches the on-screen buttons and the keyboard map):
##   Left stick / D-pad .... move
##   A / B ................. pass / switch skater (in-game button A)
##   X ..................... shoot — hold to charge, release to shoot
##   Y / LB / RB ........... turbo
##   Start ................. pause / resume, or rematch on the final whistle

const DEADZONE := 0.20
const BUTTON_PASS := JOY_BUTTON_A
const BUTTON_PASS_ALT := JOY_BUTTON_B
const BUTTON_SHOOT := JOY_BUTTON_X
const BUTTON_TURBO_1 := JOY_BUTTON_Y
const BUTTON_TURBO_2 := JOY_BUTTON_LEFT_SHOULDER
const BUTTON_TURBO_3 := JOY_BUTTON_RIGHT_SHOULDER
const BUTTON_PAUSE := JOY_BUTTON_START

var connected_pads: Array = []
var profiles: Dictionary = {}
var rest_drift: Dictionary = {}

func _init() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	refresh_pads()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	refresh_pads()

func refresh_pads() -> void:
	connected_pads = Input.get_connected_joypads()
	for device in connected_pads:
		if not profiles.has(device):
			profiles[device] = {
				"name": Input.get_joy_name(device),
				"deadzone": DEADZONE,
				"max_rest_drift": 0.0,
				"mapping_ok": false,
				"turbo_ok": false,
				"restart_ok": false,
			}
			rest_drift[device] = 0.0

func connected_count() -> int:
	return connected_pads.size()

func first_pad_id() -> int:
	if connected_pads.is_empty():
		return -1
	return int(connected_pads[0])

func pad_name(device: int) -> String:
	if profiles.has(device):
		return str(profiles[device]["name"])
	return Input.get_joy_name(device)

func apply_deadzone(v: Vector2) -> Vector2:
	var mag := v.length()
	if mag < DEADZONE:
		return Vector2.ZERO
	return v.normalized() * clampf((mag - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)

func poll_move(device: int = -1) -> Vector2:
	var dev := _resolve_device(device)
	if dev < 0:
		return Vector2.ZERO
	var stick := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	var dpad := Vector2.ZERO
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT):
		dpad.x -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT):
		dpad.x += 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP):
		dpad.y -= 1.0
	if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN):
		dpad.y += 1.0
	_sample_rest_drift(dev, stick)
	var raw := stick if stick.length() > dpad.length() else dpad
	return apply_deadzone(raw)

func is_turbo_held(device: int = -1) -> bool:
	var dev := _resolve_device(device)
	if dev < 0:
		return false
	return Input.is_joy_button_pressed(dev, BUTTON_TURBO_1) or Input.is_joy_button_pressed(dev, BUTTON_TURBO_2) or Input.is_joy_button_pressed(dev, BUTTON_TURBO_3)

func is_shoot_held(device: int = -1) -> bool:
	var dev := _resolve_device(device)
	if dev < 0:
		return false
	return Input.is_joy_button_pressed(dev, BUTTON_SHOOT)

func handle_event(event: InputEvent, gm) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			BUTTON_PASS, BUTTON_PASS_ALT:
				if gm.state == gm.GameState.GAME_OVER:
					gm.restart_match()
				else:
					gm._on_button_a_pressed()
				return true
			BUTTON_PAUSE:
				if gm.app_mode == gm.AppMode.MATCH:
					if gm.state == gm.GameState.GAME_OVER:
						gm.restart_match()
					else:
						gm.set_paused(not gm.paused)
				return true
	return false

func record_test(device: int, field: String, ok: bool) -> void:
	if profiles.has(device):
		profiles[device][field] = ok

func profile_summary(device: int) -> String:
	if not profiles.has(device):
		return "pad %d: not seen" % device
	var p: Dictionary = profiles[device]
	return "pad %d (%s): deadzone %.2f, max rest drift %.3f, mapping %s, turbo %s, restart %s" % [device, str(p["name"]), float(p["deadzone"]), float(p["max_rest_drift"]), str(p["mapping_ok"]), str(p["turbo_ok"]), str(p["restart_ok"])]

func _resolve_device(device: int) -> int:
	if device >= 0 and connected_pads.has(device):
		return device
	if connected_pads.is_empty():
		return -1
	return int(connected_pads[0])

func _sample_rest_drift(device: int, stick: Vector2) -> void:
	if stick.length() < DEADZONE:
		var drift := maxf(float(rest_drift.get(device, 0.0)), stick.length())
		rest_drift[device] = drift
		if profiles.has(device):
			profiles[device]["max_rest_drift"] = drift
