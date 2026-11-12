class_name Music
extends Node

# Background music, composed and synthesised in code (like the sound effects, so there are no audio
# files to import). Every biome has its own looping track, and boss waves get a faster, darker version.
# Tracks are built on a background thread the first time they are needed, then cached.
# Greenland: bright and pastoral   Mudland: slow and swampy   Rocky Mountain: heavy, with a beat
# Hell: fast, distorted, relentless   Space: wide, slow and echoing

const RATE := 11025

# bpm, root note (MIDI), four chords (semitones above the root), echo time/feedback,
# pad detune, distortion drive, drum style (0 none, 1 kick, 2 kick + hats)
const TRACKS := [
	{"bpm": 84.0, "root": 48, "chords": [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]], "echo": 0.28, "fb": 0.30, "detune": 0.0, "drive": 0.0, "drums": 0},
	{"bpm": 68.0, "root": 50, "chords": [[0, 3, 7], [-2, 2, 5], [-4, 0, 3], [-2, 2, 5]], "echo": 0.40, "fb": 0.35, "detune": 0.006, "drive": 0.0, "drums": 0},
	{"bpm": 90.0, "root": 48, "chords": [[0, 3, 7], [-4, 0, 3], [-2, 2, 5], [-5, -1, 2]], "echo": 0.20, "fb": 0.25, "detune": 0.0, "drive": 0.4, "drums": 1},
	{"bpm": 104.0, "root": 52, "chords": [[0, 3, 7], [1, 5, 8], [0, 3, 7], [-2, 2, 5]], "echo": 0.18, "fb": 0.25, "detune": 0.003, "drive": 1.2, "drums": 2},
	{"bpm": 60.0, "root": 45, "chords": [[0, 4, 7], [2, 6, 9], [7, 11, 14], [-3, 1, 4]], "echo": 0.50, "fb": 0.45, "detune": 0.004, "drive": 0.0, "drums": 0},
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
	var bpm := float(t["bpm"]) * (1.3 if boss else 1.0)
	var beat := 60.0 / bpm
	var n := int(beat * 16.0 * float(RATE))          # 4 chords x 4 beats
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chords: Array = t["chords"]
	var root := int(t["root"])
	var detune := float(t["detune"])
	var drums := int(t["drums"])
	if boss:
		drums = maxi(drums, 1)
	for c in 4:
		var ch: Array = chords[c]
		var cstart := int(beat * 4.0 * float(c) * float(RATE))
		var clen := int(beat * 4.0 * float(RATE))
		var tones: Array[float] = []
		for k in 3:
			var semis := int(ch[k])
			if boss and k == 1 and semis - int(ch[0]) == 4:
				semis -= 1                           # boss waves: darker, minor chords
			tones.append(_hz(root + semis))
		for f in tones:
			_sustain(buf, cstart, clen, f, 0.10, 1, 0.3, 0.35)
			if detune > 0.0:
				_sustain(buf, cstart, clen, f * (1.0 + detune), 0.07, 0, 0.3, 0.35)
		var bass_f := tones[0] * 0.5
		for b in 4:
			_pluck(buf, cstart + int(beat * float(b) * float(RATE)), int(beat * 0.9 * float(RATE)), bass_f, 0.24, 7.0)
		var steps := 16 if (boss or drums == 2) else 8
		var step_len := beat * 4.0 / float(steps)
		var pattern := [0, 1, 2, 1]
		for s in steps:
			if biome == 4 and s % 2 == 1 and not boss:
				continue                              # space: a sparse, floating arpeggio
			var f2: float = tones[int(pattern[s % 4])] * 2.0
			_pluck(buf, cstart + int(step_len * float(s) * float(RATE)), int(step_len * 3.0 * float(RATE)), f2, 0.07, 5.0)
	if drums >= 1:
		for b in 16:
			_kick(buf, int(beat * float(b) * float(RATE)))
	if drums >= 2 or boss:
		for b in 16:
			_hat(buf, int(beat * (float(b) + 0.5) * float(RATE)))
	var drive := float(t["drive"]) + (0.5 if boss else 0.0)
	if drive > 0.0:
		for i in n:
			buf[i] = tanh(buf[i] * (1.0 + drive * 2.5))
	var d := int(float(t["echo"]) * float(RATE))
	var fb := float(t["fb"])
	if d > 0 and d < n:
		for i in n:
			buf[i] += buf[(i - d + n) % n] * fb
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var gain := 0.8 / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32000.0))
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

# A held tone with a linear attack and release (pads). Writes wrap around the loop end.
static func _sustain(buf: PackedFloat32Array, start: int, length: int, freq: float, amp: float, shape: int, atk: float, rel: float) -> void:
	var n := buf.size()
	var ph := 0.0
	var inc := freq / float(RATE)
	for i in length:
		var x := float(i) / float(length)
		var env := minf(x / atk, 1.0) * minf((1.0 - x) / rel, 1.0)
		var s := sin(TAU * ph)
		if shape == 1:
			s += 0.35 * sin(TAU * ph * 2.0) + 0.15 * sin(TAU * ph * 3.0)
		buf[(start + i) % n] += s * env * amp
		ph += inc

# A plucked note: quick attack, exponential decay (bass and arpeggio).
static func _pluck(buf: PackedFloat32Array, start: int, length: int, freq: float, amp: float, decay: float) -> void:
	var n := buf.size()
	var ph := 0.0
	var inc := freq / float(RATE)
	var atk := 0.004 * float(RATE)
	for i in length:
		var t := float(i) / float(RATE)
		var env := minf(float(i) / atk, 1.0) * exp(-decay * t)
		var s := sin(TAU * ph) + 0.4 * sin(TAU * ph * 2.0) + 0.15 * sin(TAU * ph * 3.0)
		buf[(start + i) % n] += s * env * amp
		ph += inc

static func _kick(buf: PackedFloat32Array, start: int) -> void:
	var n := buf.size()
	var ph := 0.0
	for i in int(0.2 * float(RATE)):
		var t := float(i) / float(RATE)
		ph += (45.0 + 90.0 * exp(-t * 25.0)) / float(RATE)
		buf[(start + i) % n] += sin(TAU * ph) * exp(-t * 14.0) * 0.4

static func _hat(buf: PackedFloat32Array, start: int) -> void:
	var n := buf.size()
	for i in int(0.04 * float(RATE)):
		var t := float(i) / float(RATE)
		buf[(start + i) % n] += (randf() * 2.0 - 1.0) * exp(-t * 90.0) * 0.06
