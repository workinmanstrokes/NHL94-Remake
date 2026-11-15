extends SceneTree

const Logo = preload("res://Scripts/IceLogo.gd")

var jobs: Array = []
var job_index := 0
var frames_on_job := 0
var viewport: SubViewport

func _init() -> void:
	jobs = [
		{"file": "res://Icons/adaptive_foreground.png", "size": 432, "mode": "fg"},
		{"file": "res://Icons/adaptive_background.png", "size": 432, "mode": "bg"},
		{"file": "res://Icons/adaptive_monochrome.png", "size": 432, "mode": "mono"},
		{"file": "res://Icons/legacy_192.png", "size": 192, "mode": "legacy"},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Icons"))
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if viewport == null:
		_mount(job_index)
		return
	frames_on_job += 1
	if frames_on_job < 3:
		return
	var image := viewport.get_texture().get_image()
	var job: Dictionary = jobs[job_index]
	if image == null or image.get_width() != int(job.size):
		push_error("Icon render failed for %s" % job.file)
		quit(1)
		return
	if job.mode == "mono":
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(1, 1, 1, pixel.a))
	var out_path := ProjectSettings.globalize_path(job.file)
	var err := image.save_png(out_path)
	if err != OK:
		push_error("Could not save %s" % out_path)
		quit(1)
		return
	print("ICON ", out_path, " ", image.get_width(), "x", image.get_height())
	job_index += 1
	if job_index >= jobs.size():
		quit(0)
		return
	_mount(job_index)

func _mount(index: int) -> void:
	if viewport != null:
		root.remove_child(viewport)
		viewport.free()
	frames_on_job = 0
	var job: Dictionary = jobs[index]
	var side := int(job.size)
	viewport = SubViewport.new()
	viewport.size = Vector2i(side, side)
	viewport.transparent_bg = job.mode == "fg" or job.mode == "mono"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_2d = Viewport.MSAA_8X
	var drawer := IconDrawer.new()
	drawer.mode = job.mode
	drawer.canvas_size = Vector2(side, side)
	drawer.size = Vector2(side, side)
	viewport.add_child(drawer)
	root.add_child(viewport)
	drawer.queue_redraw()

class IconDrawer extends Control:
	var mode := "fg"
	var canvas_size := Vector2(432, 432)

	func _draw() -> void:
		var side := canvas_size
		if mode == "bg" or mode == "legacy":
			_draw_arena(side)
		if mode == "fg" or mode == "mono" or mode == "legacy":
			var radius := side.x * (0.255 if mode != "legacy" else 0.38)
			Logo.draw_mark(self, side * 0.5, radius, 0.4)

	func _draw_arena(side: Vector2) -> void:
		var steps := 64
		for i in steps:
			var u := float(i) / float(steps)
			var col := Color("#070B14").lerp(Color("#1A3E5C"), clampf(u * 1.15, 0.0, 1.0))
			col = col.lerp(Color("#102033"), smoothstep(0.45, 1.0, u))
			draw_rect(Rect2(0, side.y * u, side.x, side.y / float(steps) + 1.5), col, true)
		var center := side * 0.5
		draw_circle(center, side.x * 0.46, Color(0.35, 0.62, 0.82, 0.16))
		draw_circle(center, side.x * 0.28, Color(0.90, 0.75, 0.38, 0.12))
		draw_arc(center, side.x * 0.34, 0, TAU, 96, Color(0.90, 0.76, 0.42, 0.35), maxf(2.0, side.x * 0.008), true)
		var cols := 18
		for i in cols:
			var hue := fmod(float(i) * 0.17, 1.0)
			draw_rect(Rect2(side.x * (0.08 + float(i) * 0.046), side.y * 0.06, side.x * 0.028, side.y * 0.018), Color.from_hsv(hue, 0.45, 0.72), true)
