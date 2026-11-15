extends SceneTree

const Layout = preload("res://Scripts/MenuLayout.gd")
const Brand = preload("res://Scripts/Brand.gd")

const EXPECT_URL := "https://workinmanstrokes.github.io/test-builds/privacy/nhl94-remake.html"

func _init() -> void:
	quit(_run())

func _run() -> int:
	var url_err := _check_url()
	if url_err != "":
		return _fail(url_err)
	var scan_err := _scan_tree()
	if scan_err != "":
		return _fail(scan_err)
	var roster_err := _check_roster()
	if roster_err != "":
		return _fail(roster_err)
	var layout_err := _check_layouts()
	if layout_err != "":
		return _fail(layout_err)
	var name_err := _check_project_name()
	if name_err != "":
		return _fail(name_err)
	print("AUDIT OK")
	return 0

func _fail(msg: String) -> int:
	print("AUDIT FAIL: ", msg)
	return 1

func _check_url() -> String:
	if Brand.PRIVACY_URL != EXPECT_URL:
		return "privacy url mismatch"
	if Brand.PRODUCT_NAME != "Ice Legends '94":
		return "product name mismatch"
	return ""

func _check_project_name() -> String:
	var text := FileAccess.get_file_as_string("res://project.godot")
	if not text.contains('config/name="Ice Legends \'94"'):
		return "project name was not updated"
	if text.contains("package/unique_name") or text.contains("package="):
		return "android package must stay unset"
	return ""

func _scan_tree() -> String:
	var files: Array[String] = []
	_walk("res://", files)
	var banned := _banned_tokens()
	for path in files:
		var lower_name := path.to_lower()
		for token in banned:
			if lower_name.contains(token):
				return "banned token in path %s (%s)" % [path, token]
		if not _is_text(path):
			continue
		var raw := FileAccess.get_file_as_string(path)
		var scrubbed := raw.replace(EXPECT_URL, "").to_lower()
		for token in banned:
			if scrubbed.contains(token):
				return "banned token in %s (%s)" % [path, token]
	return ""

func _banned_tokens() -> Array[String]:
	return [
		"n" + "hl",
		"zam" + "boni",
		"shar" + "k",
		"yz" + "erman",
		"fedo" + "rov",
		"shana" + "han",
		"lid" + "strom",
		"konstan" + "tinov",
		"konst" + "ant",
		"roen" + "ick",
		"mogil" + "ny",
		"nee" + "ly",
		"bour" + "que",
		"cheli" + "os",
		"belf" + "our",
		"ir" + "be",
		"sj_sha" + "rks",
		"la_ki" + "ngs",
		"san jo" + "se",
		"los ange" + "les",
	]

func _is_text(path: String) -> bool:
	for ext in [".gd", ".json", ".tscn", ".godot", ".cfg", ".md", ".txt", ".svg"]:
		if path.ends_with(ext):
			return true
	return false

func _walk(path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		if name.ends_with(".uid") or name.ends_with(".import"):
			continue
		acc.append(path.path_join(name))
	for name in dir.get_directories():
		if name.begins_with(".") or name == "android":
			continue
		_walk(path.path_join(name), acc)

func _check_roster() -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://Data/rosters.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return "roster json"
	var order: Array = data["order"]
	if order.size() != 2:
		return "expected two clubs"
	var roles := ["C", "LW", "RW", "LD", "RD", "G"]
	for key in order:
		var team: Dictionary = data["teams"][key]
		if str(team["name"]) == "" or str(team["abbr"]) == "" or str(team["city"]) == "":
			return "club identity missing"
		var players: Array = team["players"]
		if players.size() != 6:
			return "club needs six skaters"
		for i in players.size():
			var p: Dictionary = players[i]
			if str(p["role"]) != roles[i]:
				return "role order"
			var nm := str(p["name"])
			if nm.length() < 3:
				return "name too short"
			for ch in nm:
				if ch < "A" or ch > "Z":
					return "name must be plain capitals"
			for stat in ["spd", "sht", "acc", "chk", "pas"]:
				var val := int(p[stat])
				if val < 1 or val > 5:
					return "stat out of range"
	return ""

func _check_layouts() -> String:
	var sizes: Array[Vector2] = [
		Vector2(1920, 864),
		Vector2(1920, 886),
		Vector2(2560, 1080),
		Vector2(3120, 1440),
	]
	for vp in sizes:
		var title := Layout.title(vp)
		var err := _check_rects(vp, title, ["play", "privacy"])
		if err != "":
			return err
		var word: Rect2 = title["word"]
		if word.end.y > (title["play"] as Rect2).position.y - 24.0:
			return "wordmark crowds the title buttons at %s" % vp
		var mark: Vector2 = title["mark_center"]
		var radius: float = title["mark_radius"]
		if mark.y - radius < 8.0:
			return "logo off the top at %s" % vp
		var teams := Layout.team_select(vp)
		err = _check_rects(vp, teams, ["back", "card0", "card1", "start"])
		if err != "":
			return err
		if vp.x >= 1600.0:
			var card: Rect2 = teams["card0"]
			if card.size.x < 640.0 or card.size.y < 480.0:
				return "team card too small at %s" % vp
		var pause := Layout.pause_menu(vp)
		err = _check_rects(vp, pause, ["resume", "restart", "quit", "privacy"])
		if err != "":
			return err
		var panel: Rect2 = pause["panel"]
		if not panel.encloses(_inset(pause["resume"])) or not panel.encloses(_inset(pause["privacy"])):
			return "pause actions outside the panel"
		var hud := Layout.hud(vp)
		err = _check_rects(vp, hud, ["pause", "pass", "shoot", "turbo"])
		if err != "":
			return err
		var joy: Vector2 = hud["joy_center"]
		var joy_r: float = hud["joy_radius"]
		if joy.x - joy_r < 16.0 or joy.y - joy_r < 16.0 or joy.x + joy_r > vp.x - 16.0 or joy.y + joy_r > vp.y - 16.0:
			return "joystick leaves the screen at %s" % vp
		for key in ["pause", "pass", "shoot", "turbo"]:
			if _circle_hits(joy, joy_r + 8.0, hud[key]):
				return "joystick overlaps %s at %s" % [key, vp]
	return ""

func _check_rects(vp: Vector2, rects: Dictionary, keys: Array) -> String:
	var list: Array[Rect2] = []
	for key in keys:
		var rect: Rect2 = rects[key]
		if rect.size.x < Layout.MIN_TAP or rect.size.y < Layout.MIN_TAP:
			return "%s is below 96px at %s (%s)" % [key, vp, rect.size]
		if rect.position.x < 12.0 or rect.position.y < 12.0 or rect.end.x > vp.x - 12.0 or rect.end.y > vp.y - 12.0:
			return "%s leaves the safe area at %s" % [key, vp]
		list.append(rect)
	for i in list.size():
		for j in range(i + 1, list.size()):
			if list[i].grow(-1).intersects(list[j].grow(-1)):
				return "controls overlap at %s" % vp
	return ""

func _circle_hits(center: Vector2, radius: float, rect: Rect2) -> bool:
	var x := clampf(center.x, rect.position.x, rect.end.x)
	var y := clampf(center.y, rect.position.y, rect.end.y)
	return center.distance_to(Vector2(x, y)) < radius

func _inset(rect: Rect2) -> Rect2:
	return rect.grow(-4)
