extends Node

const Layout = preload("res://Scripts/MenuLayout.gd")
const Logo = preload("res://Scripts/IceLogo.gd")
const Brand = preload("res://Scripts/Brand.gd")

var focus := "play"
var hover := ""
var pressed := ""
var selected_team := -1
var show_focus := false

func prepare_title() -> void:
	focus = "play"
	hover = ""
	pressed = ""
	show_focus = false

func prepare_teams() -> void:
	focus = "card0"
	hover = ""
	pressed = ""
	selected_team = -1
	show_focus = false

func prepare_pause() -> void:
	focus = "resume"
	hover = ""
	pressed = ""
	show_focus = false

func handle_event(event: InputEvent, gm) -> void:
	var vp: Vector2 = gm.get_viewport().get_visible_rect().size
	var rects := _rects_for(gm, vp)
	if event is InputEventMouseMotion:
		show_focus = true
		hover = _hit(rects, event.position)
		if hover != "":
			focus = hover
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed = _hit(rects, event.position)
			if pressed != "":
				focus = pressed
				show_focus = true
		else:
			var released := _hit(rects, event.position)
			if released != "" and released == pressed:
				_activate(released, gm)
			pressed = ""
	elif event is InputEventScreenTouch:
		if event.pressed:
			show_focus = false
			pressed = _hit(rects, event.position)
		else:
			var released := _hit(rects, event.position)
			if released != "" and released == pressed:
				_activate(released, gm)
			pressed = ""
	elif event is InputEventKey and event.pressed and not event.echo:
		show_focus = true
		_menu_key(event.keycode, gm)
	elif event is InputEventJoypadButton and event.pressed:
		show_focus = true
		_menu_pad(event.button_index, gm)

func draw_on(canvas: CanvasItem, vp: Vector2, gm, t: float) -> void:
	var font := ThemeDB.fallback_font
	if gm.app_mode == Layout.MODE_TITLE:
		_draw_title(canvas, vp, font, t)
	elif gm.app_mode == Layout.MODE_TEAMS:
		_draw_teams(canvas, vp, font, t, gm)
	elif gm.paused:
		_draw_pause(canvas, vp, font, t)

func _rects_for(gm, vp: Vector2) -> Dictionary:
	if gm.app_mode == Layout.MODE_TITLE:
		return Layout.title(vp)
	if gm.app_mode == Layout.MODE_TEAMS:
		return Layout.team_select(vp)
	if gm.paused:
		return Layout.pause_menu(vp)
	return {}

func _hit(rects: Dictionary, pos: Vector2) -> String:
	var order := ["privacy", "play", "start", "back", "quit", "restart", "resume", "card1", "card0"]
	for key in order:
		if rects.has(key) and rects[key] is Rect2 and (rects[key] as Rect2).has_point(pos):
			return key
	return ""

func _menu_key(key: Key, gm) -> void:
	if gm.app_mode == Layout.MODE_TITLE:
		if key == KEY_RIGHT or key == KEY_D:
			focus = "privacy"
		elif key == KEY_LEFT or key == KEY_A:
			focus = "play"
		elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
			_activate(focus, gm)
	elif gm.app_mode == Layout.MODE_TEAMS:
		if key == KEY_ESCAPE or key == KEY_BACKSPACE:
			_activate("back", gm)
		elif key == KEY_LEFT or key == KEY_A:
			selected_team = 0
			focus = "card0"
		elif key == KEY_RIGHT or key == KEY_D:
			selected_team = 1
			focus = "card1"
		elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
			if focus == "back":
				_activate("back", gm)
			elif selected_team >= 0:
				_activate("start", gm)
			else:
				# Quick match: Enter with no club picked starts the first
				# club, so title -> teams -> match is two inputs (v3.2 fix 3).
				selected_team = 0 if focus != "card1" else 1
				_activate("start", gm)
	elif gm.paused:
		var order: Array[String] = ["resume", "restart", "quit", "privacy"]
		var idx := order.find(focus)
		if idx < 0:
			idx = 0
		if key == KEY_ESCAPE:
			_activate("resume", gm)
		elif key == KEY_DOWN or key == KEY_S:
			focus = order[mini(idx + 1, order.size() - 1)]
		elif key == KEY_UP or key == KEY_W:
			focus = order[maxi(idx - 1, 0)]
		elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
			_activate(focus if focus in order else "resume", gm)

func _menu_pad(button: JoyButton, gm) -> void:
	if gm.app_mode == Layout.MODE_TITLE:
		if button == JOY_BUTTON_DPAD_LEFT:
			focus = "play"
		elif button == JOY_BUTTON_DPAD_RIGHT:
			focus = "privacy"
		elif button == JOY_BUTTON_A or button == JOY_BUTTON_START:
			_activate(focus, gm)
	elif gm.app_mode == Layout.MODE_TEAMS:
		if button == JOY_BUTTON_B:
			_activate("back", gm)
		elif button == JOY_BUTTON_DPAD_LEFT:
			selected_team = 0
			focus = "card0"
		elif button == JOY_BUTTON_DPAD_RIGHT:
			selected_team = 1
			focus = "card1"
		elif button == JOY_BUTTON_A or button == JOY_BUTTON_START:
			if selected_team < 0:
				selected_team = 0 if focus != "card1" else 1
			_activate("start", gm)
	elif gm.paused:
		var order: Array[String] = ["resume", "restart", "quit", "privacy"]
		var idx := order.find(focus)
		if idx < 0:
			idx = 0
		if button == JOY_BUTTON_B or button == JOY_BUTTON_START:
			_activate("resume", gm)
		elif button == JOY_BUTTON_DPAD_DOWN:
			focus = order[mini(idx + 1, order.size() - 1)]
		elif button == JOY_BUTTON_DPAD_UP:
			focus = order[maxi(idx - 1, 0)]
		elif button == JOY_BUTTON_A:
			_activate(focus if focus in order else "resume", gm)

func _activate(id: String, gm) -> void:
	match id:
		"play":
			gm.show_team_select()
		"privacy":
			Brand.open_privacy()
		"back":
			gm.show_title()
		"card0":
			selected_team = 0
			focus = "card0"
		"card1":
			selected_team = 1
			focus = "card1"
		"start":
			if selected_team >= 0:
				gm.start_match(selected_team)
		"resume":
			gm.set_paused(false)
		"restart":
			gm.restart_match()
		"quit":
			gm.quit_to_title()

func _draw_title(canvas: CanvasItem, vp: Vector2, font: Font, t: float) -> void:
	var ui := Layout.title(vp)
	_draw_arena(canvas, vp, t)
	Logo.draw_mark(canvas, ui["mark_center"], ui["mark_radius"], t)
	var banner := (ui["word"] as Rect2).grow_individual(0, 8, 0, 6)
	canvas.draw_rect(Rect2(0, banner.position.y, vp.x, banner.size.y), Color(0.03, 0.05, 0.09, 0.42), true)
	Logo.draw_wordmark(canvas, font, ui["word"])
	_draw_ice_band(canvas, vp, ui["ice_top"], ui["ice_bottom"])
	var ice_mid := (float(ui["ice_top"]) + float(ui["ice_bottom"])) * 0.5
	Logo.draw_mark(canvas, Vector2(vp.x * 0.5, ice_mid), clampf((float(ui["ice_bottom"]) - float(ui["ice_top"])) * 0.18, 18.0, 36.0), t)
	_draw_button(canvas, font, ui["play"], "PLAY", "primary", _hot("play"), pressed == "play", "")
	_draw_button(canvas, font, ui["privacy"], "PRIVACY", "ghost", _hot("privacy"), pressed == "privacy", "link")
	Logo.draw_centered(canvas, font, ui["hint"], "WASD / ARROWS MOVE  ·  X OR K PASS  ·  HOLD SPACE OR J SHOOT  ·  SHIFT OR L TURBO  ·  ESC PAUSE", 18, Color("#D5E8F8"))
	var pad_hint := Rect2(ui["hint"].position + Vector2(0, 32), ui["hint"].size)
	Logo.draw_centered(canvas, font, pad_hint, "PAD: LEFT STICK MOVE  ·  A / B PASS  ·  X SHOOT  ·  Y TURBO  ·  START PAUSE  —  ENTER, ENTER FOR A QUICK MATCH", 16, Color("#D5E8F8"))

func _draw_teams(canvas: CanvasItem, vp: Vector2, font: Font, t: float, gm) -> void:
	var ui := Layout.team_select(vp)
	_draw_arena(canvas, vp, t)
	canvas.draw_rect(Rect2(0, 0, vp.x, 128), Color(0.03, 0.05, 0.09, 0.55), true)
	_draw_button(canvas, font, ui["back"], "BACK", "ghost", _hot("back"), pressed == "back", "")
	Logo.draw_centered(canvas, font, ui["heading"], "CHOOSE YOUR CLUB", 40, Color("#F4FBFF"))
	var keys: Array = gm.team_keys
	for i in mini(2, keys.size()):
		var key := str(keys[i])
		var info: Dictionary = gm.roster["teams"][key]
		var rect: Rect2 = ui["card%d" % i]
		_draw_team_card(canvas, font, rect, info, i == selected_team, _hot("card%d" % i) or pressed == "card%d" % i)
	var start_kind := "primary" if selected_team >= 0 else "disabled"
	var start_label := "DROP THE PUCK" if selected_team >= 0 else "SELECT A CLUB"
	_draw_button(canvas, font, ui["start"], start_label, start_kind, _hot("start") and selected_team >= 0, pressed == "start", "")
	Logo.draw_centered(
		canvas,
		font,
		Rect2(vp.x * 0.5 + 270.0, ui["start"].position.y, vp.x * 0.5 - 310.0, ui["start"].size.y),
		"ARROWS CHOOSE  ·  ENTER STARTS  ·  ESC BACK  ·  ENTER ALONE = QUICK MATCH",
		16,
		Color("#D5E8F8")
	)

func _draw_pause(canvas: CanvasItem, vp: Vector2, font: Font, _t: float) -> void:
	var ui := Layout.pause_menu(vp)
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.06, 0.62), true)
	var panel: Rect2 = ui["panel"]
	canvas.draw_rect(panel, Color("#101722"), true)
	canvas.draw_rect(Rect2(panel.position, Vector2(panel.size.x, 8)), Logo.GOLD, true)
	canvas.draw_rect(panel, Logo.GOLD, false, 3.0)
	var title_rect := Rect2(panel.position.x, panel.position.y + 20.0, panel.size.x, 64.0)
	Logo.draw_centered(canvas, font, title_rect, "PAUSED", 42, Color("#F4FBFF"))
	_draw_button(canvas, font, ui["resume"], "RESUME", "primary", _hot("resume"), pressed == "resume", "")
	_draw_button(canvas, font, ui["restart"], "RESTART", "ghost", _hot("restart"), pressed == "restart", "")
	_draw_button(canvas, font, ui["quit"], "QUIT TO TITLE", "ghost", _hot("quit"), pressed == "quit", "")
	_draw_button(canvas, font, ui["privacy"], "PRIVACY", "ghost", _hot("privacy"), pressed == "privacy", "link")
	var ctl: Rect2 = ui["controls"]
	Logo.draw_centered(canvas, font, Rect2(ctl.position, Vector2(ctl.size.x, 26)), "KEYBOARD: WASD MOVE  ·  X / K PASS  ·  SPACE / J SHOOT  ·  SHIFT / L TURBO", 16, Color("#D5E8F8"))
	Logo.draw_centered(canvas, font, Rect2(ctl.position + Vector2(0, 28), Vector2(ctl.size.x, 26)), "PAD: LEFT STICK MOVE  ·  A / B PASS  ·  X SHOOT  ·  Y TURBO  ·  START RESUME", 16, Color("#D5E8F8"))
	Logo.draw_centered(canvas, font, Rect2(ctl.position + Vector2(0, 56), Vector2(ctl.size.x, 26)), "ENTER OR START ON THE FINAL WHISTLE = INSTANT REMATCH", 16, Color("#F4FBFF"))

func _draw_team_card(canvas: CanvasItem, font: Font, rect: Rect2, info: Dictionary, selected: bool, hot: bool) -> void:
	var primary := Color(str(info["primary"]))
	var secondary := Color(str(info["secondary"]))
	var trim := Color(str(info["trim"]))
	canvas.draw_rect(rect, secondary, true)
	var band := Rect2(rect.position, Vector2(rect.size.x, 168))
	canvas.draw_rect(band, primary, true)
	canvas.draw_rect(Rect2(rect.position.x, band.end.y - 8, rect.size.x, 8), trim, true)
	var badge_c := rect.position + Vector2(96, 78)
	canvas.draw_circle(badge_c, 52, secondary)
	canvas.draw_arc(badge_c, 52, 0, TAU, 36, trim, 5, true)
	canvas.draw_circle(badge_c, 30, primary)
	Logo.draw_centered(canvas, font, Rect2(badge_c.x - 40, badge_c.y - 22, 80, 44), str(info["abbr"]), 22, _ink_on(primary))
	var name_rect := Rect2(rect.position.x + 166, rect.position.y + 36, rect.size.x - 190, 58)
	var city_rect := Rect2(rect.position.x + 166, rect.position.y + 96, rect.size.x - 190, 32)
	Logo.draw_centered(canvas, font, name_rect, str(info["name"]), 34, _ink_on(primary))
	Logo.draw_centered(canvas, font, city_rect, str(info.get("city", "")).to_upper(), 18, _ink_on(primary))
	var players: Array = info["players"]
	var list_top := band.end.y + 14.0
	var list_bot := rect.end.y - 52.0
	var row_h := (list_bot - list_top) / maxf(1.0, float(players.size()))
	var stat_keys := ["spd", "sht", "acc", "chk", "pas"]
	var stat_labels := ["SPD", "SHT", "ACC", "CHK", "PAS"]
	for i in players.size():
		var row := Rect2(rect.position.x + 12, list_top + row_h * i, rect.size.x - 24, row_h - 4)
		if i % 2 == 0:
			canvas.draw_rect(row, Color(1, 1, 1, 0.045), true)
		var p: Dictionary = players[i]
		Logo.draw_centered(canvas, font, Rect2(row.position.x + 8, row.position.y, 58, row.size.y), str(p["role"]), 20, Logo.GOLD)
		Logo.draw_centered(canvas, font, Rect2(row.position.x + 66, row.position.y, 72, row.size.y), "#" + str(p["num"]), 20, trim)
		Logo.draw_centered(canvas, font, Rect2(row.position.x + 140, row.position.y, 210, row.size.y), str(p["name"]), 22, Color("#F7FBFF"))
		var block_w := 52.0
		var start_x := row.end.x - 16.0 - block_w * 5.0
		for s in 5:
			var val := int(p[stat_keys[s]])
			if i == 0:
				var label_rect := Rect2(start_x + block_w * s, row.position.y + 2, 44, row.size.y * 0.38)
				Logo.draw_centered(canvas, font, label_rect, stat_labels[s], 12, Color(trim.r, trim.g, trim.b, 0.8))
			var bar_y := row.position.y + (row.size.y * 0.62 if i == 0 else row.size.y * 0.38)
			var bar := Rect2(start_x + block_w * s, bar_y, 40, 8)
			canvas.draw_rect(bar, Color(1, 1, 1, 0.12), true)
			canvas.draw_rect(Rect2(bar.position, Vector2(40.0 * float(val) / 5.0, 8)), primary, true)
	var foot := Rect2(rect.position.x, rect.end.y - 46, rect.size.x, 40)
	Logo.draw_centered(canvas, font, foot, "YOUR CLUB" if selected else "TAP TO SELECT", 18, Logo.GOLD if selected else Color("#D5E8F8"))
	var border := Logo.GOLD if selected else (Color("#F4FBFF") if hot else Color(1, 1, 1, 0.18))
	canvas.draw_rect(rect, border, false, 6.0 if selected else 2.0)

func _draw_arena(canvas: CanvasItem, vp: Vector2, t: float) -> void:
	var steps := 32
	for i in steps:
		var u := float(i) / float(steps)
		var col := Color("#070B14").lerp(Color("#14324A"), clampf(u * 1.2, 0.0, 1.0))
		col = col.lerp(Color("#0C1422"), smoothstep(0.5, 1.0, u))
		canvas.draw_rect(Rect2(0, vp.y * u, vp.x, vp.y / float(steps) + 1.0), col, true)
	for i in 3:
		var sx := vp.x * (0.18 + float(i) * 0.32)
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(sx, 0),
			Vector2(sx - 240.0, vp.y * 0.82),
			Vector2(sx + 240.0, vp.y * 0.82),
		]), Color(0.78, 0.9, 1.0, 0.05))
	var cols := int(vp.x / 26.0)
	for row in 4:
		for i in cols:
			var hue := fmod(float(i) * 0.137 + float(row) * 0.11, 1.0)
			var tw := 0.55 + 0.45 * absf(sin(t * 1.7 + float(i) * 0.65 + float(row)))
			canvas.draw_rect(Rect2(10 + i * 26, 14 + row * 16, 12, 8), Color.from_hsv(hue, 0.45, 0.32 + 0.58 * tw), true)

func _draw_ice_band(canvas: CanvasItem, vp: Vector2, top: float, bottom: float) -> void:
	if bottom - top < 24.0:
		return
	var mid_y := (top + bottom) * 0.5
	var rx := vp.x * 0.34
	var ry := (bottom - top) * 0.42
	var c := Vector2(vp.x * 0.5, mid_y)
	canvas.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	canvas.draw_circle(Vector2.ZERO, rx, Color(0.86, 0.95, 1.0, 0.14))
	canvas.draw_arc(Vector2.ZERO, rx, 0, TAU, 72, Color(0.93, 0.97, 1.0, 0.55), 5.0, true)
	canvas.draw_arc(Vector2.ZERO, rx * 0.55, 0, TAU, 48, Color(Logo.GOLD.r, Logo.GOLD.g, Logo.GOLD.b, 0.45), 3.0, true)
	canvas.draw_line(Vector2(-rx * 0.92, 0), Vector2(rx * 0.92, 0), Color(0.82, 0.16, 0.16, 0.45), 4.0, true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_button(canvas: CanvasItem, font: Font, rect: Rect2, label: String, kind: String, hot: bool, down: bool, icon: String) -> void:
	var fill := Color("#141C2C")
	var edge := Color(Logo.GOLD.r, Logo.GOLD.g, Logo.GOLD.b, 0.85)
	var text := Color("#F4FBFF")
	if kind == "primary":
		fill = Color("#C9A24A") if down else Logo.GOLD
		text = Color("#1A140C")
		edge = Color("#FFF6D8") if hot else Color("#8A5A22")
	elif kind == "disabled":
		fill = Color(0.08, 0.1, 0.14, 0.72)
		edge = Color(1, 1, 1, 0.18)
		text = Color(1, 1, 1, 0.38)
	else:
		fill = Color("#1A2436") if down else Color(0.07, 0.1, 0.16, 0.88)
		if hot:
			edge = Color("#FFF6D8")
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, edge, false, 4.0 if hot or kind == "primary" else 2.0)
	if kind == "primary":
		canvas.draw_rect(Rect2(rect.position, Vector2(8, rect.size.y)), Color("#8A5A22"), true)
	elif kind != "disabled":
		canvas.draw_rect(Rect2(rect.position, Vector2(8, rect.size.y)), Color("#7EC8EA"), true)
	var text_rect := rect
	if icon == "link":
		text_rect = Rect2(rect.position.x, rect.position.y, rect.size.x - 36.0, rect.size.y)
		_draw_link_arrow(canvas, rect.end - Vector2(48, rect.size.y * 0.5 + 8), 16.0, text)
	Logo.draw_centered(canvas, font, text_rect, label, 28, text)
	if icon == "link" and kind != "disabled":
		var underline_y := rect.position.y + rect.size.y * 0.72
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var mid := text_rect.position.x + text_rect.size.x * 0.5
		canvas.draw_line(Vector2(mid - text_w * 0.5, underline_y), Vector2(mid + text_w * 0.5, underline_y), text, 2.0, true)

func _draw_link_arrow(canvas: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	canvas.draw_rect(Rect2(at, Vector2(s, s)), col, false, 2.0)
	var tip := at + Vector2(s + 6.0, -6.0)
	canvas.draw_line(at + Vector2(s * 0.35, s * 0.65), tip, col, 2.0, true)
	canvas.draw_line(tip + Vector2(-8, 0), tip, col, 2.0, true)
	canvas.draw_line(tip + Vector2(0, 8), tip, col, 2.0, true)

func _hot(id: String) -> bool:
	if pressed == id:
		return true
	if not show_focus:
		return false
	return hover == id or focus == id

func _ink_on(c: Color) -> Color:
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	return Color("#1A140C") if lum > 0.62 else Color("#F7FBFF")
