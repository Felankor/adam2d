class_name Sfx
extends RefCounted

# All sound effects are generated in code, so there are no audio files to import.
const RATE := 22050

static var _cache: Dictionary = {}
static var _players: Array[AudioStreamPlayer] = []
static var _host: Node
static var _next: int = 0

# Rapid fire can start dozens of sounds a second. To keep it clean: a big pool of voices, a minimum gap and a voice cap per
# sound (name -> [min gap in ms, max voices at once]), and when every voice is busy the one that is nearly finished is
# reused, so a fresh shot never cuts off a long sound in the middle.
const LIMITS := {
	"rifle": [30, 6], "carbine": [30, 6], "gatling": [25, 6], "mg": [30, 6], "shoot": [30, 5], "auto": [25, 5],
	"laser": [35, 5], "void": [40, 5], "rocket": [60, 4],
	"hit": [22, 5], "hit_heavy": [28, 5], "shield_hit": [30, 3], "laser_hit": [22, 4], "block": [30, 3], "crit": [40, 3], "kill": [45, 5], "boss_hit": [60, 3],
	"explode": [70, 4], "rocket_boom": [70, 4], "void_boom": [80, 3], "base_hit": [90, 2],
}
const POOL := 32
static var _last_ms: Dictionary = {}

static func play(sound: String, volume_db: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _host == null or not is_instance_valid(_host):
		_host = Node.new()
		_host.name = "SfxHost"
		_host.process_mode = Node.PROCESS_MODE_ALWAYS
		_players.clear()
		for i in POOL:
			var np := AudioStreamPlayer.new()
			_host.add_child(np)
			_players.append(np)
		tree.root.add_child.call_deferred(_host)
	var now := Time.get_ticks_msec()
	var lim: Array = LIMITS.get(sound, [])
	if not lim.is_empty():
		if now - int(_last_ms.get(sound, -1000)) < int(lim[0]):
			return
		var same := 0
		for p in _players:
			if p.playing and p.has_meta("snd") and p.get_meta("snd") == sound:
				same += 1
		if same >= int(lim[1]):
			return
	var stream := _stream_for(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	var best := -1.0
	for p in _players:
		if not p.is_inside_tree():
			continue
		if not p.playing:
			player = p
			break
		var len_s := p.stream.get_length() if p.stream != null else 0.0
		var prog := p.get_playback_position() / maxf(len_s, 0.05)
		if prog > best:
			best = prog
			player = p
	if player == null:
		return
	_last_ms[sound] = now
	player.set_meta("snd", sound)
	player.stream = stream
	# weapons and impacts get a little random pitch and loudness, so fast repeats never form a buzzing tone
	var jit: float = float(JITTER.get(sound, 0.0))
	player.pitch_scale = 1.0 + randf_range(-jit, jit) if jit > 0.0 else 1.0
	player.volume_db = volume_db + linear_to_db(maxf(Settings.sfx_volume, 0.0001)) + (randf_range(-1.5, 1.0) if jit > 0.0 else 0.0)
	player.play()

# The finished sounds live in res://audio/sfx/ (rendered offline). Gunshots, hits and explosions have a few
# recorded-style variants (name_1, name_2, ...) and one is picked at random, so rapid fire does not sound like a loop.
# If a file is missing, the sound is generated in code below instead, so the game always has sound.
const JITTER := {"rifle": 0.05, "carbine": 0.04, "gatling": 0.06, "mg": 0.06, "shoot": 0.05, "auto": 0.06, "laser": 0.05, "void": 0.05, "rocket": 0.04,
	"hit": 0.07, "hit_heavy": 0.05, "shield_hit": 0.05, "kill": 0.06, "block": 0.05, "crit": 0.03, "laser_hit": 0.08, "boss_hit": 0.04, "explode": 0.05, "rocket_boom": 0.05, "tank_fire": 0.04, "base_hit": 0.04}
const VARIANTS := {"rifle": 3, "carbine": 3, "gatling": 3, "mg": 2, "hit": 4, "hit_heavy": 3, "shield_hit": 2, "kill": 3, "laser": 4, "laser_hit": 3, "void": 3, "block": 3, "explode": 2, "rocket_boom": 2}

static func _stream_for(sound: String) -> AudioStreamWAV:
	var key := sound
	if VARIANTS.has(sound):
		key = "%s_%d" % [sound, 1 + randi() % int(VARIANTS[sound])]
	if not _cache.has(key):
		var path := "res://audio/sfx/%s.wav" % key
		var res: Variant = load(path) if ResourceLoader.exists(path) else null
		_cache[key] = res if res is AudioStreamWAV else _build(sound)
	return _cache[key] as AudioStreamWAV

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
		"rifle":
			# MP5-style: a snappy, fairly light crack with a short thump under it
			d = _mix(_mix(_noise(0.05, 0.55, 0.25), _tone(1500.0, 320.0, 0.035, 0.28, 1)), _tone(170.0, 85.0, 0.07, 0.3, 0))
		"carbine":
			# M4-style: a harder, louder crack, a deep boom and a short rumbling tail
			d = _mix(_mix(_noise(0.09, 0.8, 0.35), _tone(2200.0, 450.0, 0.03, 0.3, 1)), _mix(_tone(120.0, 42.0, 0.13, 0.55, 0), _noise(0.2, 0.22, 0.85)))
		"gatling":
			# very short and fast, so a stream of them sounds like a buzzing whir
			d = _mix(_noise(0.03, 0.32, 0.15), _tone(950.0, 480.0, 0.03, 0.22, 1))
		"mg":
			d = _mix(_tone(1100.0, 350.0, 0.05, 0.3, 1), _noise(0.03, 0.2, 0.2))
		"rocket":
			d = _mix(_noise(0.3, 0.45, 0.75), _tone(220.0, 90.0, 0.3, 0.3, 0))
		"rocket_boom":
			d = _mix(_noise(0.45, 0.65, 0.8), _tone(130.0, 35.0, 0.45, 0.5, 0))
		"laser":
			d = _mix(_tone(900.0, 350.0, 0.15, 0.2, 0), _tone(1300.0, 500.0, 0.1, 0.07, 0))
		"boss_summon":
			d = _mix(_tone(110.0, 190.0, 0.5, 0.45, 1), _tone(220.0, 380.0, 0.4, 0.2, 0))
		"boss_split":
			d = _mix(_tone(900.0, 80.0, 0.55, 0.35, 0), _noise(0.35, 0.3, 0.7))
		"boss_phase":
			d = _mix(_tone(60.0, 220.0, 0.9, 0.6, 1), _noise(0.6, 0.45, 0.85))
		"boss_warn":
			d = _notes([523.0, 392.0, 523.0, 392.0], 0.12, 0.3, 1)
		"crit":
			d = _mix(_tone(1500.0, 400.0, 0.14, 0.4, 1), _noise(0.12, 0.4, 0.15))
		"void":
			d = _mix(_tone(260.0, 70.0, 0.25, 0.4, 0), _tone(130.0, 55.0, 0.3, 0.3, 1))
		"void_boom":
			d = _mix(_noise(0.55, 0.55, 0.85), _tone(85.0, 24.0, 0.6, 0.65, 0))
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
