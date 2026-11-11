class_name Sfx
extends RefCounted

# All sound effects are generated in code, so there are no audio files to import.
const RATE := 22050

static var _cache: Dictionary = {}
static var _players: Array[AudioStreamPlayer] = []
static var _host: Node
static var _next: int = 0

static func play(sound: String, volume_db: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _host == null or not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "SfxHost"
		_host.process_mode = Node.PROCESS_MODE_ALWAYS
		_players.clear()
		for i in 12:
			var np := AudioStreamPlayer.new()
			_host.add_child(np)
			_players.append(np)
		tree.root.add_child.call_deferred(_host)
	var stream := _stream_for(sound)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	if not player.is_inside_tree():
		return
	player.stream = stream
	player.volume_db = volume_db + linear_to_db(maxf(Settings.sfx_volume, 0.0001))
	player.play()

static func _stream_for(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _build(sound)
	return _cache[sound] as AudioStreamWAV

# ---------- synthesis helpers ----------

static func _tone(f0: float, f1: float, dur: float, vol: float, wave: int = 0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var v := sin(TAU * phase)
		if wave == 1:
			v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var env := pow(1.0 - t, 2.0)
		if i < 40:
			env *= float(i) / 40.0
		out[i] = v * env * vol
	return out

static func _noise(dur: float, vol: float, smooth: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		last = last * smooth + (randf() * 2.0 - 1.0) * (1.0 - smooth)
		out[i] = last * pow(1.0 - t, 2.0) * vol
	return out

static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		out[i] = v
	return out

static func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part in parts:
		out.append_array(part)
	return out

static func _notes(freqs: Array, dur: float, vol: float, wave: int) -> PackedFloat32Array:
	var parts: Array = []
	for f in freqs:
		parts.append(_tone(float(f), float(f), dur, vol, wave))
	return _cat(parts)

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s

static func _build(sound: String) -> AudioStreamWAV:
	var d := PackedFloat32Array()
	match sound:
		"shoot":
			d = _mix(_tone(620.0, 140.0, 0.13, 0.45, 1), _noise(0.06, 0.3, 0.3))
		"auto":
			d = _mix(_tone(480.0, 160.0, 0.10, 0.28, 1), _noise(0.04, 0.15, 0.4))
		"hit":
			d = _mix(_noise(0.06, 0.4, 0.5), _tone(220.0, 110.0, 0.06, 0.3, 0))
		"block":
			d = _mix(_tone(1200.0, 900.0, 0.08, 0.3, 1), _tone(1800.0, 1400.0, 0.06, 0.2, 0))
		"kill":
			d = _mix(_tone(300.0, 50.0, 0.22, 0.45, 0), _noise(0.18, 0.35, 0.35))
		"explode":
			d = _mix(_noise(0.6, 0.7, 0.8), _tone(100.0, 28.0, 0.6, 0.6, 0))
		"base_hit":
			d = _mix(_tone(150.0, 45.0, 0.3, 0.7, 1), _noise(0.18, 0.4, 0.6))
		"win":
			d = _notes([523.0, 659.0, 784.0, 1047.0], 0.12, 0.35, 0)
		"fail":
			d = _notes([392.0, 330.0, 262.0, 196.0], 0.2, 0.3, 1)
		"biome_win":
			var run := _notes([392.0, 523.0, 659.0, 784.0, 659.0, 784.0], 0.12, 0.35, 0)
			var chord := _mix(_tone(1047.0, 1047.0, 0.6, 0.3, 0), _tone(784.0, 784.0, 0.6, 0.25, 0))
			d = _cat([run, chord])
		"coin":
			d = _cat([_tone(988.0, 988.0, 0.06, 0.3, 0), _tone(1319.0, 1319.0, 0.2, 0.3, 0)])
		"barrier":
			d = _mix(_tone(250.0, 900.0, 0.45, 0.4, 0), _tone(500.0, 1800.0, 0.45, 0.18, 0))
		"barrier_end":
			d = _tone(700.0, 200.0, 0.25, 0.3, 0)
		"click":
			d = _tone(800.0, 600.0, 0.04, 0.3, 1)
		"boss_hit":
			d = _mix(_tone(190.0, 90.0, 0.09, 0.5, 1), _noise(0.06, 0.3, 0.5))
		"boss_die":
			d = _mix(_noise(1.1, 0.8, 0.85), _tone(120.0, 20.0, 1.1, 0.6, 0))
		"boss_spawn":
			d = _tone(90.0, 55.0, 0.9, 0.5, 1)
		"bolt":
			d = _tone(300.0, 750.0, 0.22, 0.28, 0)
		"mg":
			d = _mix(_tone(1100.0, 350.0, 0.05, 0.3, 1), _noise(0.03, 0.2, 0.2))
		"rocket":
			d = _mix(_noise(0.3, 0.45, 0.75), _tone(220.0, 90.0, 0.3, 0.3, 0))
		"rocket_boom":
			d = _mix(_noise(0.45, 0.65, 0.8), _tone(130.0, 35.0, 0.45, 0.5, 0))
		"laser":
			d = _mix(_tone(900.0, 350.0, 0.15, 0.2, 0), _tone(1300.0, 500.0, 0.1, 0.07, 0))
		"laser_hit":
			d = _tone(420.0, 260.0, 0.05, 0.1, 0)      # a soft, low tick (the old hit sound was harsh)
		"tank_fire":
			d = _mix(_tone(160.0, 60.0, 0.22, 0.5, 1), _noise(0.15, 0.4, 0.6))
		"beam_charge":
			d = _mix(_tone(200.0, 1400.0, 1.4, 0.3, 0), _tone(100.0, 700.0, 1.4, 0.2, 1))
		"beam":
			d = _mix(_tone(110.0, 50.0, 0.7, 0.7, 1), _noise(0.6, 0.5, 0.85))
		"weapon_up":
			d = _notes([392.0, 523.0, 659.0, 784.0, 1047.0], 0.08, 0.35, 1)
		"dodge":
			d = _tone(500.0, 1100.0, 0.08, 0.18, 0)
		"toast":
			d = _tone(900.0, 900.0, 0.04, 0.12, 0)
		"powerup":
			d = _notes([523.0, 659.0, 784.0], 0.09, 0.3, 0)
		_:
			d = _tone(440.0, 440.0, 0.1, 0.3, 0)
	return _wav(d)
