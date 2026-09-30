class_name AudioDirector
extends Node
## Procedurally synthesized dungeon audio: no external sound files are shipped.
## Cave ambience, water drips, torch crackle, footsteps, spells, chimes, hits.

signal sound_played(sound: String)

const RATE := 22050
var sounds := {}
var ambience: AudioStreamPlayer
var crackle: AudioStreamPlayer
var pool: Array[AudioStreamPlayer3D] = []
var ui_pool: Array[AudioStreamPlayer] = []
var listener_target: Node3D
var drip_clock := 2.0
var volume := 0.8

func _ready() -> void:
	add_to_group("dungeon_audio")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91357
	sounds.ambience = _loop(_ambience(rng, 8.0))
	sounds.crackle = _loop(_crackle(rng, 3.0))
	sounds.drip = _wav(_drip(rng))
	sounds.step = _wav(_noise_burst(rng, 0.11, 900.0, 0.55))
	sounds.step_run = _wav(_noise_burst(rng, 0.09, 1300.0, 0.7))
	sounds.spell = _wav(_sweep(0.55, 280.0, 1500.0, rng))
	sounds.chime = _wav(_arpeggio([1046.5, 1318.5, 1568.0], 0.11, 0.6))
	sounds.boost = _wav(_arpeggio([784.0, 1174.7, 1568.0, 2093.0], 0.06, 0.5))
	sounds.wrong = _wav(_buzz(0.42))
	sounds.hit = _wav(_thump(rng))
	sounds.trap = _wav(_clank())
	sounds.rattle = _wav(_rattle(rng))
	sounds.portal = _loop(_hum(3.0))
	ambience = AudioStreamPlayer.new()
	ambience.stream = sounds.ambience
	ambience.volume_db = -9.0
	add_child(ambience)
	crackle = AudioStreamPlayer.new()
	crackle.stream = sounds.crackle
	crackle.volume_db = -26.0
	add_child(crackle)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 5.0
		p.max_distance = 30.0
		p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p)
		pool.append(p)
	for i in 6:
		var u := AudioStreamPlayer.new()
		add_child(u)
		ui_pool.append(u)
	set_volume(volume)

func start() -> void:
	if not ambience.playing: ambience.play()
	if not crackle.playing: crackle.play()

func stop() -> void:
	ambience.stop()
	crackle.stop()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)

## Near-torch crackle loudness: 0 (far) .. 1 (right next to a torch).
func set_torch_proximity(amount: float) -> void:
	crackle.volume_db = lerpf(-34.0, -14.0, clampf(amount, 0.0, 1.0))

func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not sounds.has(name): return
	sound_played.emit(name)
	for p in ui_pool:
		if not p.playing:
			p.stream = sounds[name]
			p.pitch_scale = pitch
			p.volume_db = db
			p.play()
			return

func play_at(name: String, at: Vector3, pitch := 1.0, db := 0.0) -> void:
	if not sounds.has(name): return
	sound_played.emit(name)
	for p in pool:
		if not p.playing:
			p.stream = sounds[name]
			p.global_position = at
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.volume_db = db
			p.play()
			return

func _process(delta: float) -> void:
	if not is_instance_valid(listener_target) or not ambience.playing:
		return
	drip_clock -= delta
	if drip_clock <= 0.0:
		drip_clock = randf_range(1.6, 5.5)
		var offset := Vector3(randf_range(-9, 9), 3.6, randf_range(-9, 9))
		play_at("drip", listener_target.global_position + offset, randf_range(0.8, 1.35), -4.0)

# ---------- synthesis helpers ----------
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream

func _loop(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := _wav(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream

func _ambience(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var low := 0.0
	for i in n:
		brown = clampf(brown + rng.randf_range(-0.02, 0.02), -1.0, 1.0)
		low += (brown - low) * 0.02
		var t := float(i) / RATE
		var wind := 0.5 + 0.5 * sin(TAU * t / seconds) # seamless swell
		var drone := sin(TAU * 55.0 * t) * 0.05 + sin(TAU * 82.5 * t) * 0.03
		out[i] = low * (0.55 + wind * 0.35) + drone * (0.6 + 0.4 * sin(TAU * 2.0 * t / seconds))
	return out

func _crackle(rng: RandomNumberGenerator, seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var i := 0
	while i < n:
		i += rng.randi_range(600, 4200)
		var length := rng.randi_range(40, 260)
		var amp := rng.randf_range(0.2, 0.9)
		for k in length:
			if i + k >= n: break
			out[i + k] += rng.randf_range(-1, 1) * amp * exp(-float(k) / (length * 0.3))
	var hiss := 0.0
	for j in n:
		hiss += (rng.randf_range(-1, 1) - hiss) * 0.3
		out[j] = out[j] * 0.6 + hiss * 0.05
	return out

func _drip(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.32 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := rng.randf_range(900.0, 1400.0)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (f0 + 1400.0 * exp(-t * 30.0)) / RATE
		out[i] = sin(phase) * exp(-t * 16.0) * 0.6
	return out

func _noise_burst(rng: RandomNumberGenerator, seconds: float, cutoff: float, amp: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var a := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	for i in n:
		var t := float(i) / RATE
		y += (rng.randf_range(-1, 1) - y) * a
		out[i] = y * amp * 3.0 * exp(-t * 38.0) + sin(TAU * 70.0 * t) * 0.25 * exp(-t * 45.0)
	return out

func _sweep(seconds: float, from_hz: float, to_hz: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(from_hz, to_hz, t * t) / RATE
		var env := sin(PI * t) * (1.0 - t * 0.3)
		out[i] = (sin(phase) * 0.35 + sin(phase * 2.01) * 0.12 + rng.randf_range(-1, 1) * 0.08 * t) * env
	return out

func _arpeggio(notes: Array, gap: float, tail: float) -> PackedFloat32Array:
	var n := int((gap * notes.size() + tail) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in notes.size():
		var start := int(gap * k * RATE)
		for i in range(start, n):
			var t := float(i - start) / RATE
			out[i] += (sin(TAU * notes[k] * t) + 0.3 * sin(TAU * notes[k] * 2.0 * t)) * exp(-t * 6.0) * 0.22
	return out

func _buzz(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var saw := fmod(t * 110.0, 1.0) * 2.0 - 1.0
		var saw2 := fmod(t * 116.5, 1.0) * 2.0 - 1.0
		out[i] = (saw + saw2) * 0.16 * minf(1.0, t * 40.0) * exp(-t * 4.0)
	return out

func _thump(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.35 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (140.0 * exp(-t * 18.0) + 45.0) / RATE
		out[i] = sin(phase) * exp(-t * 11.0) * 0.8 + rng.randf_range(-1, 1) * exp(-t * 60.0) * 0.4
	return out

func _clank() -> PackedFloat32Array:
	var n := int(0.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[523.0, 1.0], [1307.0, 0.6], [2211.0, 0.4], [3109.0, 0.25]]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p in partials:
			s += sin(TAU * p[0] * t) * p[1] * exp(-t * (5.0 + p[0] * 0.002))
		out[i] = s * 0.18
	return out

func _rattle(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var i := 0
	while i < n:
		i += rng.randi_range(500, 1700)
		var f := rng.randf_range(1800.0, 3200.0)
		for k in 500:
			if i + k >= n: break
			var t := float(k) / RATE
			out[i + k] += sin(TAU * f * t) * exp(-t * 90.0) * 0.5
	return out

func _hum(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * 110.0 * t) * 0.2 + sin(TAU * 165.0 * t) * 0.12 + sin(TAU * 220.0 * t) * 0.05) * (0.7 + 0.3 * sin(TAU * t / seconds))
	return out
