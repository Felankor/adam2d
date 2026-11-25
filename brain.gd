class_name Brain
extends RefCounted

# Shared tactical AI for Bosses, Rogue Castles and (later) the player's allies.
#
# One small object per agent. It does NOT draw or shoot; it answers four questions:
#   1. Where should I be?     -> tick(): a smooth velocity (distance band, strafing, retreat, dodging, optional anchor)
#   2. Where do I aim?        -> aim_point() / lead(): predicts a moving target, accuracy follows `skill`
#   3. What is my mood?       -> intent ("engage", "press", "retreat", "evade") picked by utility scores
#   4. Is it a good moment?   -> urgency (incoming fire), pressure (damage just taken), opening()
#
# It is built to be cheap: it only "thinks" about 7 times a second (staggered, so agents do not all think in the same
# frame), far away agents think 3x slower and skip the shot scan, the shot scan reads the shared per-frame Field
# snapshot and stops after a few shots, and there are no arrays or objects created while thinking.
#
# For an ally: pass the nearest hostile mob as `target`, call set_anchor(leader_position, leash) so it stays near its
# leader, and set `dodges` as you like. Nothing in here knows what a Boss or a Castle is.

const SENSE_RANGE := 640.0          # only shots this close are looked at
const HORIZON := 0.9                # seconds ahead that incoming shots are predicted
const MAX_SHOTS := 24               # the scan stops after this many threatening shots

# ---- personality (set once, per agent) ----
var skill: float = 0.7              # 0..1: dodge strength, aim accuracy, how much it trusts its prediction
var aggression: float = 0.5         # 0 keeps its distance and retreats when hurt, 1 presses in and never backs off
var band_min: float = 430.0         # preferred distance from the target
var band_max: float = 680.0
var turn_rate: float = 4.0          # how quickly its velocity follows what it wants
var think_interval: float = 0.14
var lod_far: float = 2600.0         # farther than this from the player: slow thinking, no shot scan
var strafe_speed: float = 0.55      # how fast it circles while inside its distance band (share of max speed)
var dodges: bool = true             # false for agents that already have their own dodge (the Bosses' dash)

# ---- state (read freely) ----
var intent: String = "engage"
var vel: Vector2 = Vector2.ZERO
var tvel: Vector2 = Vector2.ZERO    # estimated velocity of the target
var urgency: float = 0.0            # 0..1 how much incoming fire threatens it right now
var pressure: float = 0.0           # share of its max health lost over the last few seconds
var strafe: float = 1.0             # +1 / -1 circling direction

var _want: Vector2 = Vector2.ZERO
var _think_t: float = 0.0
var _intent_t: float = 0.0
var _strafe_t: float = 1.0
var _since: float = 0.0
var _last_target: Vector2 = Vector2.INF
var _dodge: Vector2 = Vector2.ZERO
var _anchor: Vector2 = Vector2.INF
var _anchor_r: float = 400.0

func _init(p_skill: float = 0.7, p_aggression: float = 0.5, p_band_min: float = 430.0, p_band_max: float = 680.0) -> void:
	skill = clampf(p_skill, 0.0, 1.0)
	aggression = clampf(p_aggression, 0.0, 1.0)
	band_min = p_band_min
	band_max = maxf(p_band_max, p_band_min + 40.0)
	strafe = 1.0 if randf() < 0.5 else -1.0
	_think_t = randf() * think_interval          # stagger: agents do not think in the same frame
	_strafe_t = randf_range(0.8, 2.0)

# An agent that follows a leader (ally) stays within `radius` of this point.
func set_anchor(point: Vector2, radius: float) -> void:
	_anchor = point
	_anchor_r = radius

func clear_anchor() -> void:
	_anchor = Vector2.INF

# Call from take_damage with the damage as a share of max health.
func note_damage(frac: float) -> void:
	pressure += frac
	if _strafe_t > 0.4 and randf() < 0.5:        # being hit: change the circling direction
		_strafe_t = 0.0

# One call per frame. Returns the velocity to move with (px/s): position += brain.tick(...) * delta.
func tick(delta: float, pos: Vector2, target: Vector2, hp_frac: float, energy_frac: float, speed: float, radius: float = 40.0, far: bool = false) -> Vector2:
	pressure *= exp(-delta / 2.5)
	_since += delta
	_think_t -= delta
	_intent_t -= delta
	_strafe_t -= delta
	if _think_t <= 0.0:
		var dt := think_interval * (3.0 if far else 1.0)
		_think_t = dt * randf_range(0.85, 1.15)
		_think(pos, target, hp_frac, energy_frac, speed, radius, far)
	vel = vel.lerp(_want, 1.0 - exp(-turn_rate * delta))
	return vel

func _think(pos: Vector2, target: Vector2, hp_frac: float, energy_frac: float, speed: float, radius: float, far: bool) -> void:
	# 1. perception: how fast is the target moving, and is fire heading our way?
	if _last_target != Vector2.INF and _since > 0.0:
		tvel = tvel.lerp((target - _last_target) / _since, 0.5)
	_last_target = target
	_since = 0.0
	_dodge = Vector2.ZERO
	urgency = 0.0
	if dodges and not far:
		_scan_shots(pos, radius)
	var to_t := target - pos
	var dist := maxf(to_t.length(), 1.0)
	# 2. utility scores: each mood scores 0..~1, the highest wins, and it is kept for a moment so it does not flicker
	var s_engage := 0.45
	var s_evade := urgency * (0.4 + 0.9 * skill)
	var s_retreat := (clampf(0.45 - hp_frac, 0.0, 1.0) * 2.2 + clampf(0.2 - energy_frac, 0.0, 1.0) * 2.0) * (1.0 - aggression)
	var s_press := aggression * hp_frac * (0.65 if dist > band_max else 0.35)
	if _intent_t <= 0.0 or s_evade > 0.8:
		var pick := "engage"
		var best := s_engage
		if s_press > best:
			best = s_press
			pick = "press"
		if s_retreat > best:
			best = s_retreat
			pick = "retreat"
		if s_evade > best:
			best = s_evade
			pick = "evade"
		if pick != intent:
			intent = pick
		_intent_t = 0.3 if pick == "evade" else randf_range(0.6, 1.3)
	# 3. steering: a distance band to hold, a circling tangent, a push away from incoming shots
	var radial := to_t / dist
	var lo := band_min
	var hi := band_max
	if intent == "press":
		lo *= 0.7
		hi *= 0.75
	elif intent == "retreat":
		lo *= 1.35
		hi *= 1.6
	var rad_w := 0.0
	if dist > hi:
		rad_w = clampf((dist - hi) / 250.0, 0.2, 1.0)
	elif dist < lo:
		rad_w = -clampf((lo - dist) / 250.0, 0.2, 1.0)
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 3.0)
		if randf() < 0.55:
			strafe = -strafe
	var strafe_w := strafe_speed * (0.45 if intent == "retreat" else 1.0)
	var dir := radial * rad_w + radial.orthogonal() * strafe * strafe_w * (1.0 - absf(rad_w) * 0.5)
	if intent == "retreat":
		dir -= radial * 0.4
	if _dodge.length_squared() > 0.0001:
		dir += _dodge.normalized() * (1.6 * urgency * (0.5 + skill))
	if _anchor != Vector2.INF:
		var to_a := _anchor - pos
		var over := to_a.length() - _anchor_r
		if over > 0.0:
			dir += to_a.normalized() * clampf(over / 300.0, 0.0, 1.0) * 1.2
	if dir.length_squared() < 0.0004:
		_want = Vector2.ZERO
	else:
		_want = dir.normalized() * speed * minf(dir.length(), 1.0)

# Looks at our side's shots in flight (Field keeps one snapshot per frame). For each one that will pass close to us in
# the next HORIZON seconds, note how dangerous it is and which way is out of its path.
func _scan_shots(pos: Vector2, radius: float) -> void:
	var reach := radius + 40.0
	var n := 0
	for s in Field.shots():
		var p := s.position - pos
		if p.length_squared() > SENSE_RANGE * SENSE_RANGE:
			continue
		var v := s.velocity
		var vv := v.length_squared()
		if vv < 1.0:
			continue
		var tc := clampf(-p.dot(v) / vv, 0.0, HORIZON)
		var cp := p + v * tc                      # where the shot is, relative to us, at its closest
		var miss := cp.length()
		if miss > reach:
			continue
		var u := (1.0 - miss / reach) * (1.0 - tc / HORIZON * 0.6)
		var side := v.orthogonal().normalized()
		if miss < 4.0:
			side *= strafe                        # dead centre: keep circling the way we were
		elif side.dot(-cp) < 0.0:
			side = -side                          # step away from the line the shot will take
		_dodge += side * u
		urgency = maxf(urgency, u)
		n += 1
		if n >= MAX_SHOTS:
			break

# Where to aim to hit a target that keeps moving. Accuracy and trust in the prediction follow `skill`.
func aim_point(from: Vector2, target: Vector2, proj_speed: float, spread: float = -1.0) -> Vector2:
	var rel := target - from
	var v := tvel * (0.35 + 0.65 * skill)
	var a := v.dot(v) - proj_speed * proj_speed
	var b := 2.0 * rel.dot(v)
	var c := rel.dot(rel)
	var t := 0.0
	if absf(a) < 0.001:
		if absf(b) > 0.001:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var sq := sqrt(disc)
			var t1 := (-b - sq) / (2.0 * a)
			var t2 := (-b + sq) / (2.0 * a)
			if t1 > 0.0 and t2 > 0.0:
				t = minf(t1, t2)
			elif t1 > 0.0 or t2 > 0.0:
				t = maxf(t1, t2)
	t = clampf(t, 0.0, 1.6)
	var err := (1.0 - skill) * 70.0 if spread < 0.0 else spread
	return target + v * t + Vector2(randf_range(-err, err), randf_range(-err, err))

# Where the target will be in `secs` seconds (for slow, locked shots like a charging beam).
func lead(target: Vector2, secs: float) -> Vector2:
	return target + tvel * secs * (0.35 + 0.65 * skill)

# A good moment for a burst of damage: calm (nothing about to hit us) and not running away.
func opening() -> bool:
	return urgency < 0.5 and intent != "retreat"
