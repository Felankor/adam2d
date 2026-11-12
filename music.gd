class_name Music
extends Node

# Background music in an arcade run-and-gun style (think Metal Slug), composed and synthesised in
# code, so there are no audio files to import: a distorted guitar riff, a driving bass, punchy
# drums (kick, snare, hats, crash, tom fills) and a bright lead that answers the riff.
# Every biome has its own key, tempo and riff; boss waves get a faster, heavier, double-kick version.
# Tracks are built on a background thread the first time they are needed, then cached.
# Greenland: heroic and fast   Mudland: slow, heavy stomp   Rocky Mountain: marching rock
# Hell: relentless double-kick gallop   Space: arpeggios over a steady beat

const RATE := 22050
const BARS := 8
const NONE := -99                    # a rest in a lead motif

# bpm, root note (MIDI), the riff root per two bars (semitones above the root), lead motif (16 steps,
# semitones above the riff root, NONE = rest), guitar style (0 palm-muted 8ths, 1 gallop, 2 arpeggio),
# distortion, drums (0 rock, 1 double kick, 2 half-time stomp), lead wave (1 saw, 2 square), echo seconds
const TRACKS := [
	{"bpm": 150.0, "root": 45, "prog": [0, -2, -4, -2], "lead": [12, NONE, 12, NONE, 15, NONE, 12, 10, 12, NONE, NONE, NONE, 7, NONE, 10, NONE],
		"gtr": 0, "drive": 1.0, "drums": 0, "wave": 2, "echo": 0.20},
	{"bpm": 108.0, "root": 40, "prog": [0, -4, -2, -5], "lead": [12, NONE, NONE, 10, NONE, NONE, 7, NONE, 10, NONE, NONE, 12, NONE, NONE, NONE, NONE],
		"gtr": 0, "drive": 1.6, "drums": 2, "wave": 1, "echo": 0.28},
	{"bpm": 134.0, "root": 43, "prog": [0, -2, 3, -2], "lead": [12, NONE, 15, NONE, 14, 12, NONE, 10, 12, NONE, NONE, NONE, 10, NONE, 7, NONE],
		"gtr": 0, "drive": 1.3, "drums": 0, "wave": 1, "echo": 0.18},
	{"bpm": 172.0, "root": 41, "prog": [0, 1, 0, -2], "lead": [12, 13, NONE, 12, NONE, 8, NONE, NONE, 12, 13, NONE, 15, 13, NONE, 12, NONE],
		"gtr": 1, "drive": 2.2, "drums": 1, "wave": 1, "echo": 0.14},
	{"bpm": 126.0, "root": 47, "prog": [0, 5, 3, 7], "lead": [19, NONE, NONE, NONE, 16, NONE, NONE, NONE, 14, NONE, 16, NONE, 12, NONE, NONE, NONE],
		"gtr": 2, "drive": 0.4, "drums": 0, "wave": 2, "echo": 0.36},
]
const MUSIC_DB_OFFSET := -12.0      # music sits well below the sound effects

static var _inst: Music

var _player: AudioStreamPlayer
var _cache: Dictionary = {}
var _thread: Thread = null
var _building_key: String = ""
var _want_biome: int = -1
var _want_boss: bool = false
var _current_key: String = ""
var _tween: Tween

# ---------- public API ----------

static func play(biome: int, boss: bool) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _inst == null or not is_instance_valid(_inst):
		_inst = Music.new()
		_inst.name = "Music"
		_inst.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(_inst)
	_inst._want_biome = biome
	_inst._want_boss = boss

static func stop() -> void:
	if _inst != null and is_instance_valid(_inst):
		_inst._want_biome = -1
		_inst._current_key = ""
		if _inst._tween != null:
			_inst._tween.kill()
		_inst._player.stop()

static func refresh_volume() -> void:
	if _inst != null and is_instance_valid(_inst) and _inst._player.playing:
		if _inst._tween != null:
			_inst._tween.kill()
		_inst._player.volume_db = _target_db()

static func _target_db() -> float:
	return linear_to_db(maxf(Settings.music_volume, 0.0001)) + MUSIC_DB_OFFSET

# ---------- the node that plays and crossfades ----------

func _init() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -40.0
	add_child(_player)

func _key(biome: int, boss: bool) -> String:
	return "%d_%d" % [biome, 1 if boss else 0]

func _process(_delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		var res: Variant = _thread.wait_to_finish()
		_thread = null
		if res is AudioStreamWAV:
			_cache[_building_key] = res
		_building_key = ""
	if _want_biome < 0:
		return
	var key := _key(_want_biome, _want_boss)
	if _cache.has(key):
		if key != _current_key:
			_switch_to(key)
	elif _thread == null:
		_building_key = key
		_thread = Thread.new()
		_thread.start(_job.bind(_want_biome, _want_boss))

func _job(biome: int, boss: bool) -> AudioStreamWAV:
	return Music.build(biome, boss)

func _switch_to(key: String) -> void:
	_current_key = key
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if _player.playing:
		_tween.tween_property(_player, "volume_db", -40.0, 0.6)
	else:
		_player.volume_db = -40.0
	_tween.tween_callback(func() -> void:
		_player.stream = _cache[key] as AudioStreamWAV
		_player.play())
	_tween.tween_property(_player, "volume_db", _target_db(), 1.4)

# ---------- composing ----------

static func build(biome: int, boss: bool) -> AudioStreamWAV:
	var t: Dictionary = TRACKS[clampi(biome, 0, TRACKS.size() - 1)]
	var bpm := float(t["bpm"]) * (1.15 if boss else 1.0)
	var step := 60.0 / bpm / 4.0                      # one sixteenth note, in seconds
	var n := int(step * 16.0 * float(BARS) * float(RATE))
	var gtr := PackedFloat32Array()
	var bass := PackedFloat32Array()
	var lead := PackedFloat32Array()
	var drum := PackedFloat32Array()
	gtr.resize(n)
	bass.resize(n)
	lead.resize(n)
	drum.resize(n)
	var root := int(t["root"])
	var prog: Array = t["prog"]
	var motif: Array = t["lead"]
	var style := int(t["gtr"])
	var kit := 1 if boss else int(t["drums"])
	var hat16 := boss or biome == 3
	var wave := int(t["wave"])
	var sl := int(step * float(RATE))                 # samples per step
	for bar in BARS:
		var r := root + int(prog[(bar >> 1) % 4])
		for s in 16:
			var at := (bar * 16 + s) * sl
			var last_bar := bar == BARS - 1
			var in_fill := last_bar and s >= 12
			# --- guitar ---
			if style == 2:
				var arp := [0, 7, 12, 7]
				_voice(gtr, at, int(sl * 1.6), _hz(r + 12 + int(arp[s % 4])), 0.30, 2, 9.0, 0.0)
			else:
				var hit := false
				var accent := false
				if style == 1:
					hit = s % 4 != 1
					accent = s == 0 or s == 8
				else:
					hit = s % 2 == 0
					accent = s == 0 or s == 6 or s == 10
				if hit and not in_fill:
					var nlen := int(sl * (3.2 if accent else 1.5))
					var dec := 6.0 if accent else 22.0
					for k in [0, 7, 12]:
						_voice(gtr, at, nlen, _hz(r + int(k)), 0.26, 1, dec, 0.0)
			# --- bass ---
			if s % 2 == 0 and not in_fill:
				var bm := r - 12
				if style != 2 and (s == 6 or s == 14):
					bm += 12
				_voice(bass, at, int(sl * 1.9), _hz(bm), 0.30, 2, 8.0, 0.0)
				_voice(bass, at, int(sl * 1.9), _hz(bm), 0.22, 0, 8.0, 0.0)
			# --- lead ---
			var v := int(motif[s])
			if v != NONE and not in_fill:
				var note := r + 12 + v + (12 if (bar >= 4 or boss) else 0)
				var gap := 1
				while s + gap < 16 and int(motif[s + gap]) == NONE:
					gap += 1
				_voice(lead, at, int(sl * minf(float(gap), 3.0) * 0.95), _hz(note), 0.15, wave, 3.0, 0.004)
			# --- drums ---
			var kick := false
			var snare := false
			match kit:
				1:
					kick = s == 0 or s == 2 or s == 6 or s == 8 or s == 10 or s == 14
					snare = s == 4 or s == 12
				2:
					kick = s == 0 or s == 10 or (s == 6 and bar % 2 == 1)
					snare = s == 8
				_:
					kick = s == 0 or s == 8 or (s == 10 and bar % 2 == 1)
					snare = s == 4 or s == 12
			if in_fill:
				snare = true
				kick = false
				_snare(drum, at, 0.30 + 0.07 * float(s - 12))
				_tom(drum, at, 150.0 - 18.0 * float(s - 12))
			elif snare:
				_snare(drum, at, 0.45)
			if kick:
				_kick(drum, at)
			if hat16:
				_hat(drum, at, 0.10 if s % 2 == 0 else 0.05)
			elif s % 2 == 0:
				_hat(drum, at, 0.11)
			if s == 0 and (bar % 4 == 0 or boss):
				_crash(drum, at)
	# --- mix ---
	var drive := float(t["drive"]) + (0.8 if boss else 0.0)
	for i in n:
		gtr[i] = tanh(gtr[i] * (2.0 + drive * 3.0)) * 0.5      # the crunch
	var d := int(float(t["echo"]) * float(RATE))
	if d > 0 and d < n:
		for i in n:
			lead[i] += lead[(i - d + n) % n] * 0.30
	var peak := 0.001
	for i in n:
		var x := tanh((gtr[i] * 0.9 + bass[i] + lead[i] + drum[i]) * 1.4)
		gtr[i] = x                                            # reuse the guitar buffer as the mix
		peak = maxf(peak, absf(x))
	var gain := 0.85 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(gtr[i] * gain, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)

static func _osc(ph: float, wave: int) -> float:
	var f := ph - floorf(ph)
	if wave == 1:
		return 2.0 * f - 1.0                    # saw
	if wave == 2:
		return 1.0 if f < 0.5 else -1.0         # square
	return sin(TAU * ph)

# One synth note: quick attack, exponential decay, short release. Writes wrap around the loop end.
static func _voice(buf: PackedFloat32Array, start: int, length: int, freq: float, amp: float, wave: int, decay: float, vib: float) -> void:
	var n := buf.size()
	var ph := 0.0
	var atk := 0.003 * float(RATE)
	var rel := 0.012 * float(RATE)
	for i in length:
		var tt := float(i) / float(RATE)
		var env := minf(float(i) / atk, 1.0) * minf(float(length - i) / rel, 1.0) * exp(-decay * tt)
		var f := freq
		if vib > 0.0:
			f = freq * (1.0 + vib * sin(tt * 38.0))
		ph += f / float(RATE)
		buf[(start + i) % n] += _osc(ph, wave) * env * amp

static func _kick(buf: PackedFloat32Array, start: int) -> void:
	var n := buf.size()
	var ph := 0.0
	for i in int(0.22 * float(RATE)):
		var tt := float(i) / float(RATE)
		ph += (48.0 + 110.0 * exp(-tt * 30.0)) / float(RATE)
		buf[(start + i) % n] += sin(TAU * ph) * exp(-tt * 13.0) * 0.55

static func _snare(buf: PackedFloat32Array, start: int, amp: float) -> void:
	var n := buf.size()
	for i in int(0.2 * float(RATE)):
		var tt := float(i) / float(RATE)
		var noise := randf() * 2.0 - 1.0
		var tone := sin(TAU * 190.0 * tt) * exp(-tt * 32.0)
		buf[(start + i) % n] += (noise * exp(-tt * 20.0) * 0.55 + tone * 0.45) * amp

static func _tom(buf: PackedFloat32Array, start: int, freq: float) -> void:
	var n := buf.size()
	var ph := 0.0
	for i in int(0.16 * float(RATE)):
		var tt := float(i) / float(RATE)
		ph += (freq * (1.0 + 0.5 * exp(-tt * 18.0))) / float(RATE)
		buf[(start + i) % n] += sin(TAU * ph) * exp(-tt * 16.0) * 0.30

static func _hat(buf: PackedFloat32Array, start: int, amp: float) -> void:
	var n := buf.size()
	var prev := 0.0
	for i in int(0.05 * float(RATE)):
		var tt := float(i) / float(RATE)
		var x := randf() * 2.0 - 1.0
		buf[(start + i) % n] += (x - prev) * 0.5 * exp(-tt * 85.0) * amp * 2.0
		prev = x

static func _crash(buf: PackedFloat32Array, start: int) -> void:
	var n := buf.size()
	var prev := 0.0
	for i in int(0.9 * float(RATE)):
		var tt := float(i) / float(RATE)
		var x := randf() * 2.0 - 1.0
		buf[(start + i) % n] += (x - prev) * 0.5 * exp(-tt * 4.5) * 0.28
		prev = x
