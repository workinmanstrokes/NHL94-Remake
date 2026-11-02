extends Node

var sfx_player: AudioStreamPlayer

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

func play_sfx(sfx_name: String, vol: float = 1.0) -> void:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.4
	sfx_player.stream = gen
	sfx_player.volume_db = linear_to_db(clamp(vol, 0.05, 1.0))
	sfx_player.play()
	var pb = sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb: return
	var dur = 0.14; var f1 = 220.0; var f2 = 330.0; var noise_mix = 0.0
	match sfx_name:
		"pass": f1 = 320.0; f2 = 190.0; dur = 0.06; noise_mix = 0.25
		"slapshot": f1 = 175.0; f2 = 85.0; dur = 0.15; noise_mix = 0.60
		"onetimer": f1 = 260.0; f2 = 110.0; dur = 0.19; noise_mix = 0.68
		"pad_save": f1 = 140.0; f2 = 95.0; dur = 0.11; noise_mix = 0.45
		"board_crack": f1 = 90.0; f2 = 52.0; dur = 0.22; noise_mix = 0.72
		"post_ping": f1 = 1520.0; f2 = 2280.0; dur = 0.22; noise_mix = 0.04
		"whistle": f1 = 2820.0; f2 = 2960.0; dur = 0.28; noise_mix = 0.14
		"goal_horn": f1 = 138.6; f2 = 207.6; dur = 0.38; noise_mix = 0.18
		"organ_charge": f1 = 261.6; f2 = 392.0; dur = 0.28; noise_mix = 0.0
	var frames = int(gen.mix_rate * dur)
	for i in range(frames):
		var t = float(i) / gen.mix_rate
		var env = 1.0 - (float(i) / frames)
		var wave = (sin(TAU * f1 * t) * 0.6 + sin(TAU * f2 * t) * 0.4)
		var sq = 1.0 if wave >= 0.0 else -1.0
		var n = randf_range(-1.0, 1.0) * noise_mix
		var sample = ((wave * 0.6 + sq * 0.4) * (1.0 - noise_mix) + n) * env * 0.38
		pb.push_frame(Vector2(sample, sample))
