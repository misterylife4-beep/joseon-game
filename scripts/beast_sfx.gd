class_name BeastSfx
extends RefCounted
## 들짐승 소리: 사슴(경계 울음·콧김), 멧돼지(꿀꿀·꽥·콧김), 늑대(울부짖음·으르렁·낑), 호랑이(포효·으르렁·숨),
## 발소리(종류마다 무게가 다름), 풀 스치는 소리, 심장 박동, 물리는 소리, 맞아서 나는 신음.
## 파일 없이 코드로 합성한 근사음이며 실제 동물 소리가 아니다. 높이·길이·세기는 설계값이다. (고증_근거.md 47장)

const R := 22050
const KINDS: Array[String] = [
	"step_deer", "step_boar", "step_wolf", "step_tiger", "rustle", "heart", "bite", "slash", "hurt", "thud",
	"deer_bark", "deer_snort", "boar_grunt", "boar_squeal", "boar_snort",
	"wolf_howl", "wolf_snarl", "wolf_yelp", "tiger_roar", "tiger_growl", "tiger_huff",
]

static var _cache: Dictionary = {}


static func has(kind: String) -> bool:
	return _cache.has(kind)


## 소리 스트림. 처음 부를 때 합성한다 (warm 으로 미리 만들어 두면 끊김이 없다).
static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var w := _to_wav(_synth(kind))
	_cache[kind] = w
	return w


## 한 프레임에 하나씩 미리 합성한다. 게임이 시작할 때 부르고 기다리지 않는다.
static func warm(tree: SceneTree) -> void:
	for k in KINDS:
		if not _cache.has(k):
			stream(k)
		await tree.process_frame


## 평면 소리 한 번 재생(화면 효과). 끝나면 스스로 사라진다.
static func play2d(owner: Node, kind: String, db := -6.0, pitch := 1.0) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream(kind)
	p.volume_db = db
	p.pitch_scale = pitch
	p.autoplay = true
	p.finished.connect(p.queue_free)
	owner.get_tree().root.add_child.call_deferred(p)


# --- 합성 재료 ---

static func _to_wav(b: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] / peak * 0.9, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = R
	w.stereo = false
	w.data = data
	return w


static func _buf(secs: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(float(R) * secs))
	return b


## 목소리 한 마디: 높이가 f0 에서 f1 로 변하고, 배음이 쌓이며, 떨림·끊김·숨소리를 섞는다.
## form 이 0보다 크면 그 주파수 근처 배음이 두드러진다(입 모양에 따른 소리 색).
static func _voice(b: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, f0: float, f1: float, gain: float, harm := 6, roll := 1.0, form := 0.0, vib := 0.0, pulse := 0.0, noise := 0.0) -> void:
	var s0 := int(t0 * float(R))
	var n := int(dur * float(R))
	var amps: Array[float] = []
	var fm := (f0 + f1) * 0.5
	for h in range(1, harm + 1):
		var a := pow(float(h), -roll)
		if form > 0.0:
			a *= 1.0 + 2.0 * exp(-pow((fm * float(h) - form) / (form * 0.5), 2.0))
		amps.append(a)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var j := s0 + i
		if j >= b.size():
			break
		var u := float(i) / float(n)
		var t := float(i) / float(R)
		var f := lerpf(f0, f1, u) * (1.0 + vib * sin(TAU * 5.5 * t))
		ph += TAU * f / float(R)
		var s := 0.0
		for h in amps.size():
			s += amps[h] * sin(ph * float(h + 1))
		var env := smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.55, 1.0, u))
		if pulse > 0.0:
			env *= 1.0 - pulse + pulse * (0.5 + 0.5 * sin(TAU * 22.0 * t))
		var nz := 0.0
		if noise > 0.0:
			lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.2
			nz = lp * noise
		b[j] += (s * 0.3 + nz) * env * gain


## 잡음 덩어리(높낮이 필터와 감쇠 모양)
static func _noise(b: PackedFloat32Array, rng: RandomNumberGenerator, t0: float, dur: float, gain: float, lp: float, hp := 0.0, curve := 1.0, attack := 0.01) -> void:
	var s0 := int(t0 * float(R))
	var n := int(dur * float(R))
	var l1 := 0.0
	var l2 := 0.0
	for i in n:
		var j := s0 + i
		if j >= b.size():
			break
		var u := float(i) / float(n)
		l1 += lp * (rng.randf_range(-1.0, 1.0) - l1)
		l2 += hp * (l1 - l2)
		var v := l1 - l2 if hp > 0.0 else l1
		var env := pow(1.0 - u, curve) * minf(float(i) / (attack * float(R)), 1.0)
		b[j] += v * gain * env


## 둔탁한 쿵: 낮은 사인이 빠르게 가라앉는다
static func _thump(b: PackedFloat32Array, t0: float, f: float, gain: float, decay: float) -> void:
	var s0 := int(t0 * float(R))
	var ph := 0.0
	for i in range(s0, b.size()):
		var t := float(i - s0) / float(R)
		var env := exp(-t * decay)
		if env < 0.002:
			break
		ph += TAU * (f * (1.0 + 0.8 * exp(-t * 40.0))) / float(R)
		b[i] += sin(ph) * env * gain * minf(t * 600.0, 1.0)


static func _synth(kind: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + kind.hash() % 1000
	var b := _buf(0.3)
	match kind:
		"step_deer":
			b = _buf(0.14)
			_thump(b, 0.0, 150.0, 0.7, 45.0)
			_noise(b, rng, 0.0, 0.05, 0.4, 0.25, 0.0, 2.0)
		"step_boar":
			b = _buf(0.18)
			_thump(b, 0.0, 105.0, 0.9, 38.0)
			_noise(b, rng, 0.0, 0.08, 0.5, 0.2, 0.0, 2.0)
		"step_wolf":
			b = _buf(0.14)
			_thump(b, 0.0, 130.0, 0.6, 50.0)
			_noise(b, rng, 0.0, 0.05, 0.35, 0.3, 0.0, 2.0)
		"step_tiger":
			b = _buf(0.22)
			_thump(b, 0.0, 78.0, 1.0, 30.0)
			_noise(b, rng, 0.0, 0.1, 0.4, 0.15, 0.0, 2.0)
		"rustle":
			b = _buf(0.45)
			for k in 4:
				_noise(b, rng, 0.03 + 0.09 * float(k), 0.14, 0.35, 0.55, 0.25, 1.5, 0.02)
		"heart":
			b = _buf(0.75)
			_thump(b, 0.0, 52.0, 1.0, 16.0)
			_thump(b, 0.24, 46.0, 0.75, 18.0)
		"bite":
			b = _buf(0.5)
			_noise(b, rng, 0.0, 0.18, 0.7, 0.5, 0.3, 2.0, 0.004)
			_thump(b, 0.0, 90.0, 0.9, 22.0)
			_noise(b, rng, 0.08, 0.2, 0.35, 0.35, 0.2, 1.5, 0.01)
		"slash":
			b = _buf(0.4)
			_noise(b, rng, 0.0, 0.22, 0.6, 0.7, 0.5, 1.6, 0.03)
			_thump(b, 0.12, 100.0, 0.7, 24.0)
		"thud":
			b = _buf(0.45)
			_thump(b, 0.0, 70.0, 1.0, 14.0)
			_noise(b, rng, 0.0, 0.1, 0.5, 0.3, 0.0, 2.0)
		"hurt":
			# 맞아서 내뱉는 "윽" 소리
			b = _buf(0.5)
			_voice(b, rng, 0.0, 0.32, 150.0, 105.0, 0.9, 8, 0.7, 650.0, 0.02, 0.0, 0.05)
		"deer_bark":
			# 사슴의 날카로운 경계 울음
			b = _buf(0.5)
			_voice(b, rng, 0.0, 0.26, 430.0, 360.0, 0.9, 9, 0.6, 1400.0, 0.0, 0.5, 0.18)
			_noise(b, rng, 0.0, 0.1, 0.4, 0.6, 0.3, 2.0, 0.005)
		"deer_snort":
			b = _buf(0.5)
			_noise(b, rng, 0.0, 0.35, 0.7, 0.55, 0.4, 2.2, 0.02)
		"boar_grunt":
			b = _buf(0.7)
			_voice(b, rng, 0.0, 0.5, 85.0, 70.0, 0.9, 7, 0.8, 300.0, 0.03, 0.8, 0.3)
		"boar_squeal":
			b = _buf(1.0)
			_voice(b, rng, 0.0, 0.8, 620.0, 1050.0, 0.8, 8, 0.7, 1500.0, 0.06, 0.2, 0.15)
		"boar_snort":
			b = _buf(0.5)
			_noise(b, rng, 0.0, 0.22, 0.8, 0.3, 0.0, 1.8, 0.02)
			_noise(b, rng, 0.2, 0.12, 0.6, 0.3, 0.0, 1.8, 0.01)
		"wolf_howl":
			# 길게 올라갔다 내려오는 울부짖음: 숨소리가 섞이고 끝에서 떨린다
			var tmp := _buf(3.8)
			var n := tmp.size()
			var ph := 0.0
			for i in n:
				var t := float(i) / float(R)
				var u := t / 3.6
				var f := 300.0 + 230.0 * sin(clampf(u, 0.0, 1.0) * PI * 0.9) + 6.0 * sin(t * 33.0) * smoothstep(0.5, 1.0, u) * 3.0
				ph += TAU * f / float(R)
				var env := smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(2.7, 3.7, t))
				tmp[i] = (sin(ph) * 0.65 + sin(ph * 2.0) * 0.28 + sin(ph * 3.0) * 0.09) * env
			b = tmp
			_noise(b, rng, 0.2, 3.2, 0.05, 0.3, 0.2, 0.6, 0.3)
		"wolf_snarl":
			b = _buf(1.1)
			_voice(b, rng, 0.0, 1.0, 115.0, 95.0, 0.9, 7, 0.9, 700.0, 0.03, 0.7, 0.35)
		"wolf_yelp":
			b = _buf(0.4)
			_voice(b, rng, 0.0, 0.26, 700.0, 1200.0, 0.9, 5, 1.0, 1800.0, 0.02, 0.0, 0.03)
		"tiger_roar":
			# 호랑이 포효: 낮고 굵은 목울림이 부풀었다가 떨며 가라앉는다
			b = _buf(2.4)
			_voice(b, rng, 0.0, 2.2, 68.0, 125.0, 1.0, 9, 0.75, 420.0, 0.015, 0.75, 0.25)
			_voice(b, rng, 0.2, 1.6, 135.0, 210.0, 0.45, 7, 0.9, 1100.0, 0.02, 0.6, 0.15)
			_noise(b, rng, 0.0, 1.6, 0.18, 0.18, 0.0, 0.9, 0.2)
		"tiger_growl":
			b = _buf(1.7)
			_voice(b, rng, 0.0, 1.6, 58.0, 52.0, 0.9, 8, 0.8, 300.0, 0.02, 0.8, 0.3)
		"tiger_huff":
			b = _buf(0.6)
			_noise(b, rng, 0.0, 0.4, 0.8, 0.2, 0.0, 1.6, 0.05)
		_:
			_thump(b, 0.0, 100.0, 1.0, 30.0)
	return b
