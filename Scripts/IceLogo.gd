extends RefCounted

const GOLD := Color("#E6C36A")
const GOLD_DEEP := Color("#8A5A22")
const INK := Color("#10151F")
const ICE := Color("#D9F4FF")
const ICE_DEEP := Color("#7EC8EA")

static func draw_mark(canvas: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var w := maxf(2.0, r * 0.045)
	canvas.draw_circle(c, r * 1.08, Color(ICE_DEEP.r, ICE_DEEP.g, ICE_DEEP.b, 0.12))
	canvas.draw_circle(c, r, GOLD_DEEP)
	canvas.draw_circle(c, r - w * 1.35, GOLD)
	canvas.draw_circle(c, r * 0.86, INK)
	canvas.draw_arc(c, r * 0.78, 0.0, TAU, 48, Color(ICE.r, ICE.g, ICE.b, 0.92), w, true)
	for i in 6:
		var a := -PI * 0.5 + t * 0.12 + float(i) * TAU / 6.0
		var tip := c + Vector2.from_angle(a) * r * 0.60
		var left := c + Vector2.from_angle(a - 0.26) * r * 0.18
		var right := c + Vector2.from_angle(a + 0.26) * r * 0.18
		var col := ICE if i % 2 == 0 else Color("#F5FBFF")
		canvas.draw_colored_polygon(PackedVector2Array([c, left, tip, right]), col)
	canvas.draw_circle(c, r * 0.30, INK)
	canvas.draw_arc(c, r * 0.30, 0.0, TAU, 32, GOLD, w, true)
	if r >= 72.0:
		_monogram(canvas, c, r)
	else:
		canvas.draw_circle(c + Vector2(-r * 0.05, -r * 0.05), r * 0.07, ICE)
	for i in 12:
		var a2 := float(i) * TAU / 12.0
		canvas.draw_line(
			c + Vector2.from_angle(a2) * r * 0.88,
			c + Vector2.from_angle(a2) * r * 0.96,
			GOLD_DEEP,
			maxf(1.5, w * 0.75),
			true
		)


static func draw_wordmark(canvas: CanvasItem, font: Font, rect: Rect2) -> void:
	var title_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.56))
	var sub_rect := Rect2(rect.position.x, rect.position.y + rect.size.y * 0.58, rect.size.x, rect.size.y * 0.22)
	var credit_rect := Rect2(rect.position.x, rect.position.y + rect.size.y * 0.82, rect.size.x, rect.size.y * 0.16)
	var title := "ICE LEGENDS"
	var size := 68
	var title_pos := _baseline(font, title_rect, size)
	canvas.draw_string(font, title_pos + Vector2(0, 5), title, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, size, Color(0, 0, 0, 0.55))
	canvas.draw_string_outline(font, title_pos, title, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, size, 10, GOLD_DEEP)
	canvas.draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_CENTER, title_rect.size.x, size, Color("#F4FBFF"))
	var measured := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var title_right := title_rect.position.x + title_rect.size.x * 0.5 + measured.x * 0.5
	var plate := Rect2(title_right + 10.0, title_rect.position.y + title_rect.size.y * 0.16, 96.0, 62.0)
	canvas.draw_rect(plate, GOLD, true)
	canvas.draw_rect(plate.grow(-4.0), INK, false, 3.0)
	draw_centered(canvas, font, plate, "'94", 34, INK)
	var sub := "RETRO ARCADE HOCKEY"
	var sub_size := 22
	var sub_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
	var mid_x := rect.position.x + rect.size.x * 0.5
	var rule_y := sub_rect.position.y + sub_rect.size.y * 0.55
	canvas.draw_line(Vector2(mid_x - sub_w * 0.5 - 92.0, rule_y), Vector2(mid_x - sub_w * 0.5 - 14.0, rule_y), GOLD, 2.0, true)
	canvas.draw_line(Vector2(mid_x + sub_w * 0.5 + 14.0, rule_y), Vector2(mid_x + sub_w * 0.5 + 92.0, rule_y), GOLD, 2.0, true)
	draw_centered(canvas, font, sub_rect, sub, sub_size, GOLD)
	draw_centered(canvas, font, credit_rect, "DIDDLERRR", 16, Color(GOLD.r, GOLD.g, GOLD.b, 0.8))


static func draw_centered(canvas: CanvasItem, font: Font, rect: Rect2, text: String, size: int, color: Color) -> void:
	canvas.draw_string(font, _baseline(font, rect, size), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, color)


static func _baseline(font: Font, rect: Rect2, size: int) -> Vector2:
	var ascent := font.get_ascent(size)
	var descent := font.get_descent(size)
	var baseline := rect.position.y + (rect.size.y - (ascent + descent)) * 0.5 + ascent
	return Vector2(rect.position.x, baseline)


static func _monogram(canvas: CanvasItem, c: Vector2, r: float) -> void:
	var h := r * 0.16
	var thick := maxf(2.0, r * 0.035)
	var col := Color("#F4FBFF")
	var ix := c.x - r * 0.075
	canvas.draw_rect(Rect2(ix - thick * 1.15, c.y - h, thick * 2.3, thick), col, true)
	canvas.draw_rect(Rect2(ix - thick * 0.5, c.y - h, thick, h * 2.0), col, true)
	canvas.draw_rect(Rect2(ix - thick * 1.15, c.y + h - thick, thick * 2.3, thick), col, true)
	var lx := c.x + r * 0.02
	canvas.draw_rect(Rect2(lx, c.y - h, thick, h * 2.0), col, true)
	canvas.draw_rect(Rect2(lx, c.y + h - thick, r * 0.11, thick), col, true)
