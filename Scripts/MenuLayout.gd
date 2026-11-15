extends RefCounted

const MODE_TITLE := 0
const MODE_TEAMS := 1
const MODE_MATCH := 2

const MIN_TAP := 96.0

static func title(vp: Vector2) -> Dictionary:
	var btn_w := 360.0
	var btn_h := 108.0
	var gap := 28.0
	var bottom_margin := 108.0
	var play_y := vp.y - bottom_margin - btn_h
	var total := btn_w * 2.0 + gap
	var play_x := (vp.x - total) * 0.5
	var mark_r := clampf(minf(vp.x, vp.y) * 0.132, 84.0, 128.0)
	var buttons_top := play_y
	var block_h := mark_r * 2.0 + 12.0 + 150.0
	var avail_top := 96.0
	var avail_bot := buttons_top - 24.0
	var slack := maxf(0.0, avail_bot - avail_top - block_h)
	var block_top := avail_top + slack * 0.32
	var mark_c := Vector2(vp.x * 0.5, block_top + mark_r)
	var word := Rect2(vp.x * 0.5 - 560.0, mark_c.y + mark_r + 12.0, 1120.0, 150.0)
	return {
		"play": Rect2(play_x, play_y, btn_w, btn_h),
		"privacy": Rect2(play_x + btn_w + gap, play_y, btn_w, btn_h),
		"mark_center": mark_c,
		"mark_radius": mark_r,
		"word": word,
		"hint": Rect2(60.0, play_y + btn_h + 12.0, vp.x - 120.0, 36.0),
		"ice_top": word.end.y + 8.0,
		"ice_bottom": play_y - 16.0,
	}


static func team_select(vp: Vector2) -> Dictionary:
	var margin := 40.0
	var gap := 32.0
	var back := Rect2(40.0, 22.0, 220.0, 96.0)
	var card_y := 136.0
	var footer := 156.0
	var card_w := (vp.x - margin * 2.0 - gap) * 0.5
	var card_h := vp.y - card_y - footer
	var start := Rect2((vp.x - 480.0) * 0.5, vp.y - 128.0, 480.0, 104.0)
	return {
		"back": back,
		"card0": Rect2(margin, card_y, card_w, card_h),
		"card1": Rect2(margin + card_w + gap, card_y, card_w, card_h),
		"start": start,
		"heading": Rect2(300.0, 22.0, vp.x - 600.0, 96.0),
	}


static func pause_menu(vp: Vector2) -> Dictionary:
	var btn_h := 100.0
	var gap := 14.0
	var pw := minf(720.0, vp.x - 80.0)
	var ph := 28.0 + 72.0 + 12.0 + btn_h * 4.0 + gap * 3.0 + 28.0 + 92.0
	var origin := Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	var bx := origin.x + 36.0
	var bw := pw - 72.0
	var by := origin.y + 112.0
	return {
		"panel": Rect2(origin, Vector2(pw, ph)),
		"resume": Rect2(bx, by, bw, btn_h),
		"restart": Rect2(bx, by + (btn_h + gap), bw, btn_h),
		"quit": Rect2(bx, by + (btn_h + gap) * 2.0, bw, btn_h),
		"privacy": Rect2(bx, by + (btn_h + gap) * 3.0, bw, btn_h),
		"controls": Rect2(bx, by + (btn_h + gap) * 4.0, bw, 84),
	}


static func hud(vp: Vector2) -> Dictionary:
	var edge := 48.0
	var bottom := 104.0
	var turbo_s := 156.0
	var shoot_s := 148.0
	var pass_s := 140.0
	var turbo := Rect2(vp.x - edge - turbo_s, vp.y - bottom - turbo_s, turbo_s, turbo_s)
	var shoot := Rect2(turbo.position.x - 4.0, turbo.position.y - shoot_s - 28.0, shoot_s, shoot_s)
	var pass_btn := Rect2(turbo.position.x - pass_s - 36.0, turbo.position.y + (turbo_s - pass_s) * 0.5, pass_s, pass_s)
	var joy_r := 96.0
	var joy_c := Vector2(edge + joy_r + 36.0, vp.y - bottom - joy_r)
	return {
		"pause": Rect2(24.0, 16.0, 116.0, 116.0),
		"joy_center": joy_c,
		"joy_radius": joy_r,
		"pass": pass_btn,
		"shoot": shoot,
		"turbo": turbo,
	}
