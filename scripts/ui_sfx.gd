class_name UiSfx
extends RefCounted
## 화면 효과음 모음. 파일 없이 코드로 합성한 소리이며, 쓰임새마다 다른 악기·재료를 흉내 낸다.
##   tok 목탁(고르기·누르기), tick 가벼운 나무 두드림(손 올림·슬라이더), toggle 켜고 끄기,
##   page 종이 한 장 넘김(대화 다음 줄), scroll 두루마리 펼침(지도·대화창), cloth 보따리 푸는 소리(가방),
##   gong 징(큰 일의 완료), drum 북(위험·피해), pluck/pluck_up/pluck_down 가야금 줄 튕김(얻음·성공·경고),
##   flint 부싯돌과 불붙는 소리, munch 먹는 소리, pick 짚·풀 줍는 소리, pop 밤 터지는 소리,
##   sizzle 지글거림(반복), bubble 끓는 소리(반복), done 맑은 작은 종(요리 완료), deny 막힘(둔탁한 두 번),
##   brush 붓, paper 종이, stamp 도장.
##   몸 소리: shiver 찬바람에 몸이 떨리는 소리, chatter 이가 딱딱 부딪는 소리, stomach 배에서 나는 꼬르륵,
##   gasp 숨이 차 몰아쉬는 소리. 발소리: step_dirt 흙, step_snow 눈, step_plank 나무 널(다리·잔교).
##   crackle 모닥불 장작 타는 소리(반복).
##   chwita 임금 행차의 대취타(징 → 용고·나발·자바라 → 태평소 가락, 약 22초). 가락은 실제 곡이 아닌 근사한 창작이다.
## 음 높이, 길이, 소리 세기는 모두 설계값이다. 실제 악기 녹음이 아니라 근사한 합성음이다.

const RATE := 32000
const LOOPING := ["sizzle", "bubble", "crackle"]
const MAX_VOICES := 12

static var _cache: Dictionary = {}
static var _hooked := false
static var _voices := 0
static var _last_tick := 0.0


## 소리를 낸다. owner 가 사라져도 끊기지 않게 최상위 노드에 붙인다.
static func play(owner: Node, kind: String, volume_db := -12.0, pitch := 1.0) -> AudioStreamPlayer:
	if owner == null or not owner.is_inside_tree() or _voices >= MAX_VOICES:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream(kind)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	_voices += 1
	p.finished.connect(func() -> void:
		_voices = maxi(_voices - 1, 0)
		p.queue_free())
	# 부모가 아이를 붙이는 중일 때(_ready)도 안전하도록 한 틈 미루고, 붙으면 저절로 재생한다
	p.autoplay = true
	owner.get_tree().root.add_child.call_deferred(p)
	return p


static func stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var buf := _synth(kind)
	var w := _to_wav(buf, 0.9)
	if LOOPING.has(kind):
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	_cache[kind] = w
	return w


# --- 알림 글에 맞는 소리 고르기 ---

const HURT_WORDS := ["물렸", "들이받", "쓰러", "삼켰", "막힌다!", "다쳤"]
const WARN_WORDS := ["기운이 없", "위험", "으스스", "기척", "울음", "조용하다", "씩씩거"]
const DENY_WORDS := ["수 없다", "없다.", "닫혔", "닫혀", "고개를 젓는다", "부족", "두 단이 있어야"]
const GAIN_WORDS := ["주웠다", "피웠다", "구웠다", "먹었다", "끓였다", "수집", "완료", "완공", "건넜다", "올랐다", "내렸다", "얻었다"]


static func toast_kind(text: String) -> String:
	# 몸 상태는 그 상태에 맞는 소리로
	for w in ["얼어붙", "춥", "얼어"]:
		if text.contains(w):
			return "shiver"
	for w in ["배고", "허기", "배가 너무"]:
		if text.contains(w):
			return "stomach"
	if text.contains("숨이 차") or text.contains("숨이 가"):
		return "gasp"
	for w in HURT_WORDS:
		if text.contains(w):
			return "drum"
	for w in WARN_WORDS:
		if text.contains(w):
			return "pluck_down"
	for w in DENY_WORDS:
		if text.contains(w):
			return "deny"
	for w in GAIN_WORDS:
		if text.contains(w):
			return "pluck_up"
	return "brush"


# --- 단추·슬라이더에 자동으로 소리 붙이기 ---

static func hook(tree: SceneTree) -> void:
	if _hooked:
		return
	_hooked = true
	tree.node_added.connect(_attach)
	_walk(tree.root)


static func _walk(n: Node) -> void:
	_attach(n)
	for c in n.get_children():
		_walk(c)


static func _attach(n: Node) -> void:
	if n.has_meta("sfx"):
		return
	if n is OptionButton:
		n.set_meta("sfx", true)
		(n as OptionButton).item_selected.connect(func(_i: int) -> void: play(n, "tok", -12.0, 1.25))
		(n as Control).mouse_entered.connect(func() -> void: play(n, "tick", -30.0))
	elif n is CheckBox or n is CheckButton:
		n.set_meta("sfx", true)
		(n as BaseButton).toggled.connect(func(_on: bool) -> void: play(n, "toggle", -14.0))
		(n as Control).mouse_entered.connect(func() -> void: play(n, "tick", -30.0))
	elif n is BaseButton:
		n.set_meta("sfx", true)
		(n as BaseButton).pressed.connect(func() -> void: play(n, "tok", -11.0))
		(n as Control).mouse_entered.connect(func() -> void:
			if not (n as BaseButton).disabled:
				play(n, "tick", -30.0))
	elif n is Slider:
		n.set_meta("sfx", true)
		(n as Slider).value_changed.connect(func(_v: float) -> void:
			var now := Time.get_ticks_msec() * 0.001
			if now - _last_tick > 0.06:
				_last_tick = now
				play(n, "tick", -22.0, 0.9 + 0.2 * (n as Slider).ratio))


# --- 합성 ---

static func _to_wav(buf: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] / peak * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


static func _buf(secs: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(float(RATE) * secs))
	return b


## 감쇠하는 사인파(모드) 더하기. modes: [주파수, 세기, 감쇠(1/초)]
static func _add_modes(b: PackedFloat32Array, modes: Array, start := 0.0, gain := 1.0, f_scale := 1.0) -> void:
	var s0 := int(start * float(RATE))
	for m in modes:
		var f: float = float(m[0]) * f_scale
		var a: float = float(m[1]) * gain
		var d: float = float(m[2])
		var ph := 0.0
		for i in range(s0, b.size()):
			var t := float(i - s0) / float(RATE)
			var env := exp(-t * d)
			if env < 0.001:
				break
			ph += TAU * f / float(RATE)
			b[i] += sin(ph) * a * env * minf(t * 900.0, 1.0)


## 잡음 덩어리: 높낮이 통과 필터와 모양(attack 빠르게, 감쇠)
static func _add_noise(b: PackedFloat32Array, rng: RandomNumberGenerator, start: float, dur: float, gain: float, lp: float, hp := 0.0, curve := 1.0) -> void:
	var s0 := int(start * float(RATE))
	var n := int(dur * float(RATE))
	var l1 := 0.0
	var l2 := 0.0
	for i in n:
		if s0 + i >= b.size():
			break
		var t := float(i) / float(n)
		var x := rng.randf_range(-1.0, 1.0)
		l1 += lp * (x - l1)
		l2 += hp * (l1 - l2)
		var v := l1 - l2 if hp > 0.0 else l1
		var env := pow(1.0 - t, curve) * minf(float(i) / 40.0, 1.0)
		b[s0 + i] += v * gain * env


## 가야금 줄 튕김(카플러스-스트롱): 줄 길이만큼의 지연선에 잡음을 넣고 평균으로 걸러 낸다.
static func _add_pluck(b: PackedFloat32Array, rng: RandomNumberGenerator, start: float, freq: float, gain: float, decay := 0.996) -> void:
	var s0 := int(start * float(RATE))
	var n := maxi(int(float(RATE) / freq), 2)
	var line := PackedFloat32Array()
	line.resize(n)
	var lp := 0.0
	for i in n:
		lp += 0.5 * (rng.randf_range(-1.0, 1.0) - lp)
		line[i] = lp * 1.6
	var idx := 0
	for i in range(s0, b.size()):
		var nx := (idx + 1) % n
		var v := line[idx]
		line[idx] = (line[idx] + line[nx]) * 0.5 * decay
		idx = nx
		b[i] += v * gain


## 관악기 한 음. kind 0 은 태평소(겹서 소리: 코가 막힌 듯 배음이 많고 1,100 Hz 근처가 두드러지며 떨림과 미끄러짐이 있음),
## kind 1 은 나발(낮고 굵은 금관 소리: 천천히 일어나 길게 남음).
static func _add_wind(b: PackedFloat32Array, start: float, dur: float, f: float, gain: float, kind := 0) -> void:
	var tab := PackedFloat32Array()
	tab.resize(256)
	var hmax := 10 if kind == 0 else 7
	for i in 256:
		var x := TAU * float(i) / 256.0
		var v := 0.0
		for h in range(1, hmax):
			var fh := f * float(h)
			var a := pow(float(h), -0.8 if kind == 0 else -1.2)
			if kind == 0:
				a *= 1.0 + 1.6 * exp(-pow((fh - 1100.0) / 450.0, 2.0))
			v += a * sin(x * float(h))
		tab[i] = v * 0.35
	var n0 := int(start * float(RATE))
	var n1 := mini(int((start + dur) * float(RATE)), b.size())
	var ph := 0.0
	var att := 0.04 if kind == 0 else 0.3
	var rel := 0.1 if kind == 0 else 0.5
	for i in range(n0, n1):
		var t := float(i - n0) / float(RATE)
		var vib := 0.012 * sin(TAU * 5.2 * t) * smoothstep(0.0, 0.4, t) if kind == 0 else 0.004 * sin(TAU * 4.0 * t)
		var fm := f * (1.0 + vib) * (0.94 + 0.06 * smoothstep(0.0, 0.08 if kind == 0 else 0.25, t))
		ph += fm / float(RATE)
		ph -= floorf(ph)
		var env := smoothstep(0.0, att, t) * (1.0 - smoothstep(dur - rel, dur, t))
		var idx := ph * 256.0
		var i0 := int(idx) & 255
		var i1 := (i0 + 1) & 255
		var fr := idx - floorf(idx)
		b[i] += gain * env * lerpf(tab[i0], tab[i1], fr)


## 용고(큰 북) 한 번 치기
static func _add_drum_hit(b: PackedFloat32Array, rng: RandomNumberGenerator, start: float, gain: float) -> void:
	var s0 := int(start * float(RATE))
	var ph := 0.0
	for i in range(s0, mini(s0 + int(0.5 * float(RATE)), b.size())):
		var t := float(i - s0) / float(RATE)
		ph += TAU * (62.0 + 90.0 * exp(-t * 18.0)) / float(RATE)
		b[i] += sin(ph) * exp(-t * 7.0) * gain
	_add_noise(b, rng, start, 0.04, 0.4 * gain, 0.25)


## 대취타: 집사의 "명금일하"에 징을 두 번 치고 시작한다(사료). 이어 용고가 걸음 박자를 잡고 나발이 길게 불며
## 자바라가 마디마다 부딪고 태평소가 가락을 이끈다. 마디 길이(3.6초)·음높이(레 음계)·가락은 설계값이다.
static func _synth_chwita(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(23.0)
	var gong := [[170.0, 1.0, 1.5], [176.0, 0.7, 1.7], [255.0, 0.55, 1.9], [344.0, 0.5, 2.2], [468.0, 0.3, 2.8]]
	_add_modes(b, gong, 0.0, 0.9)
	_add_modes(b, gong, 1.0, 1.0)
	# 용고: 마디마다 강-약-중-약
	for bar in range(1, 6):
		var t0 := 3.6 * float(bar)
		for k in 4:
			_add_drum_hit(b, rng, t0 + 0.9 * float(k), [1.0, 0.45, 0.7, 0.45][k] * 0.8)
	_add_drum_hit(b, rng, 2.6, 0.5)
	_add_drum_hit(b, rng, 3.1, 0.5)
	# 자바라와 징
	for bar in [1, 3, 5]:
		var tc := 3.6 * float(bar)
		_add_modes(b, [[3100.0, 0.5, 9.0], [4300.0, 0.4, 11.0], [5600.0, 0.3, 13.0]], tc, 0.5)
		_add_noise(b, rng, tc, 0.5, 0.35, 0.9, 0.3, 2.0)
	_add_modes(b, gong, 7.2, 0.5)
	_add_modes(b, gong, 14.4, 0.5)
	# 나발
	_add_wind(b, 3.6, 3.3, 146.83, 0.8, 1)
	_add_wind(b, 10.8, 3.3, 110.0, 0.8, 1)
	_add_wind(b, 18.0, 3.8, 146.83, 0.8, 1)
	# 태평소 가락 [시작, 길이, 높이]
	var d4 := 293.66
	var e4 := 329.63
	var g4 := 392.0
	var a4 := 440.0
	var b4 := 493.88
	var d5 := 587.33
	var mel := [
		[5.4, 1.2, a4], [6.6, 0.45, b4], [7.05, 0.45, a4], [7.5, 1.3, g4], [8.8, 0.45, e4],
		[9.25, 0.45, g4], [9.7, 1.7, a4], [11.4, 1.2, d5], [12.6, 0.45, b4], [13.05, 0.45, a4],
		[13.5, 0.9, g4], [14.4, 0.45, a4], [14.85, 0.45, g4], [15.3, 1.8, e4], [17.1, 3.0, d4],
	]
	for n in mel:
		_add_wind(b, float(n[0]), float(n[1]) * 0.96, float(n[2]), 0.9, 0)
	return b


static func _synth(kind: String) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + kind.hash() % 1000
	var b := _buf(0.3)
	match kind:
		"tok":
			# 목탁: 속이 빈 나무가 울리는 소리 (낮은 울림 + 높은 배음)
			b = _buf(0.22)
			_add_modes(b, [[720.0, 1.0, 34.0], [1190.0, 0.5, 52.0], [1960.0, 0.22, 80.0]])
			_add_noise(b, rng, 0.0, 0.006, 0.5, 0.6, 0.2)
		"bow_creak":
			# 활을 당길 때 나무가 삐걱이는 소리 (낮은 울림 두 개와 작은 마찰)
			b = _buf(0.55)
			_add_modes(b, [[170.0, 0.7, 5.0], [255.0, 0.45, 7.0], [410.0, 0.2, 10.0]])
			_add_noise(b, rng, 0.0, 0.4, 0.18, 0.5, 0.2, 2.0)
		"bow_twang":
			# 시위를 놓는 소리: 팽팽한 줄이 한 번 울린다
			b = _buf(0.6)
			_add_modes(b, [[210.0, 1.0, 9.0], [420.0, 0.55, 13.0], [630.0, 0.3, 19.0], [840.0, 0.16, 26.0]])
			_add_noise(b, rng, 0.0, 0.012, 0.6, 0.7, 0.3)
		"arrow_hit":
			# 화살이 몸이나 땅에 박히는 짧은 퍽 소리
			b = _buf(0.16)
			_add_modes(b, [[150.0, 1.0, 38.0], [320.0, 0.5, 60.0]])
			_add_noise(b, rng, 0.0, 0.015, 0.7, 0.6, 0.1)
		"tick":
			# 가볍게 톡: 작은 나무토막
			b = _buf(0.07)
			_add_modes(b, [[2300.0, 1.0, 130.0], [3600.0, 0.35, 190.0]])
		"toggle":
			b = _buf(0.16)
			_add_modes(b, [[1500.0, 1.0, 90.0], [2400.0, 0.3, 130.0]], 0.0)
			_add_modes(b, [[2000.0, 1.0, 90.0], [3100.0, 0.3, 130.0]], 0.07)
		"page":
			# 한 장 넘김: 맑은 나무 한 번 딱 (목탁 쪽 가볍게)
			b = _buf(0.14)
			_add_modes(b, [[1320.0, 1.0, 60.0], [2100.0, 0.3, 90.0]])
		"scroll":
			# 펼침: 가야금 세 음이 오음 음계로 부드럽게 올라간다 (레-솔-레)
			b = _buf(1.3)
			_add_pluck(b, rng, 0.0, 293.66, 0.8, 0.997)
			_add_pluck(b, rng, 0.1, 392.0, 0.8, 0.997)
			_add_pluck(b, rng, 0.2, 587.33, 0.9, 0.997)
		"cloth":
			# 가방 열기: 낮은 가야금 두 음(5도), 묵직하고 단정하게
			b = _buf(0.9)
			_add_pluck(b, rng, 0.0, 196.0, 0.9, 0.996)
			_add_pluck(b, rng, 0.09, 293.66, 0.8, 0.996)
		"cloth_close":
			# 가방 닫기: 낮은 한 음이 짧게 가라앉는다
			b = _buf(0.5)
			_add_pluck(b, rng, 0.0, 220.0, 0.9, 0.99)
		"gong":
			# 징: 낮은 소리에 어긋난 배음이 길게 남는다
			b = _buf(2.4)
			_add_modes(b, [[170.0, 1.0, 1.5], [176.0, 0.7, 1.7], [255.0, 0.55, 1.9], [344.0, 0.5, 2.2], [468.0, 0.3, 2.8], [660.0, 0.18, 3.6]])
			_add_noise(b, rng, 0.0, 0.05, 0.4, 0.3)
		"drum":
			# 북: 내려앉는 낮은 소리와 가죽 두드리는 울림
			b = _buf(0.55)
			var ph := 0.0
			for i in b.size():
				var t := float(i) / float(RATE)
				ph += TAU * (62.0 + 90.0 * exp(-t * 18.0)) / float(RATE)
				b[i] = sin(ph) * exp(-t * 7.0)
			_add_noise(b, rng, 0.0, 0.05, 0.5, 0.25)
		"pluck":
			b = _buf(1.0)
			_add_pluck(b, rng, 0.0, 392.0, 1.0)
		"pluck_up":
			b = _buf(1.1)
			_add_pluck(b, rng, 0.0, 293.66, 0.9)
			_add_pluck(b, rng, 0.11, 440.0, 1.0)
		"pluck_down":
			b = _buf(1.0)
			_add_pluck(b, rng, 0.0, 440.0, 0.9)
			_add_pluck(b, rng, 0.12, 293.66, 1.0)
		"flint":
			# 부싯돌 치는 소리 셋, 이어서 불이 확 붙는 소리
			b = _buf(0.9)
			for k in 3:
				_add_modes(b, [[3800.0, 1.0, 400.0], [5200.0, 0.4, 500.0]], 0.0 + 0.09 * float(k), 0.7)
				_add_noise(b, rng, 0.09 * float(k), 0.01, 0.6, 0.8, 0.4)
			var l := 0.0
			var s0 := int(0.32 * float(RATE))
			for i in range(s0, b.size()):
				var t := float(i - s0) / float(b.size() - s0)
				l += 0.2 * (rng.randf_range(-1.0, 1.0) - l)
				b[i] += l * sin(t * PI) * 0.9
		"munch":
			# 우적우적: 바삭한 덩어리를 세 번 씹는 소리
			b = _buf(0.55)
			for k in 3:
				var st := 0.02 + 0.16 * float(k)
				_add_noise(b, rng, st, 0.07, 1.0, 0.5, 0.15, 1.5)
				_add_modes(b, [[190.0, 0.8, 50.0]], st, 0.8)
		"pick":
			# 풀·짚을 훑어 줍는 소리와 톡
			b = _buf(0.2)
			_add_noise(b, rng, 0.0, 0.14, 0.9, 0.5, 0.2, 1.1)
			_add_modes(b, [[880.0, 0.6, 60.0]], 0.12)
		"pop":
			# 밤이 탁 터지는 소리
			b = _buf(0.18)
			_add_noise(b, rng, 0.0, 0.015, 1.0, 0.9, 0.5)
			var ph2 := 0.0
			for i in b.size():
				var t := float(i) / float(RATE)
				ph2 += TAU * (520.0 - 3000.0 * t) / float(RATE)
				b[i] += sin(ph2) * exp(-t * 40.0) * 0.8
		"sizzle":
			# 지글지글(반복): 높은 잡음 바탕에 톡톡 튀는 소리
			b = _buf(1.6)
			_add_noise(b, rng, 0.0, 1.6, 0.25, 0.7, 0.35, 0.0)
			for k in 40:
				_add_noise(b, rng, rng.randf() * 1.55, 0.012, rng.randf_range(0.5, 1.0), 0.8, 0.3)
		"bubble":
			# 보글보글(반복): 작은 기포가 올라오다 터지는 소리
			b = _buf(2.0)
			_add_noise(b, rng, 0.0, 2.0, 0.12, 0.12, 0.02, 0.0)
			for k in 22:
				var f0 := rng.randf_range(260.0, 700.0)
				var st := rng.randf() * 1.9
				var ph3 := 0.0
				var dn := int(rng.randf_range(0.03, 0.07) * float(RATE))
				for i in dn:
					var t := float(i) / float(RATE)
					ph3 += TAU * f0 * (1.0 + 7.0 * t) / float(RATE)
					var idx := int(st * float(RATE)) + i
					if idx < b.size():
						b[idx] += sin(ph3) * (1.0 - float(i) / float(dn)) * rng.randf_range(0.2, 0.6)
		"done":
			# 맑은 작은 종소리: 요리가 다 되었다는 신호
			b = _buf(1.5)
			_add_modes(b, [[1568.0, 1.0, 3.2], [2350.0, 0.45, 4.5], [3136.0, 0.25, 6.0], [4180.0, 0.12, 8.0]])
			_add_modes(b, [[2093.0, 0.8, 3.4], [3140.0, 0.3, 5.0]], 0.16)
		"deny":
			# 막힘: 둔탁한 소리 두 번
			b = _buf(0.28)
			_add_modes(b, [[150.0, 1.0, 26.0], [230.0, 0.4, 40.0]], 0.0)
			_add_modes(b, [[135.0, 1.0, 26.0], [210.0, 0.4, 40.0]], 0.09)
		"brush":
			# 일반 알림: 가야금 한 음 (소리가 깨끗하고 짧다)
			b = _buf(0.7)
			_add_pluck(b, rng, 0.0, 329.63, 0.9, 0.993)
		"paper":
			# 부드러운 나무 톡 (낮은 쪽)
			b = _buf(0.16)
			_add_modes(b, [[880.0, 1.0, 55.0], [1500.0, 0.25, 85.0]])
		"stamp":
			# 도장: 둔탁한 낮은 울림에 나무 부딪는 소리
			b = _buf(0.3)
			_add_modes(b, [[95.0, 1.0, 14.0], [190.0, 0.5, 22.0]])
			_add_noise(b, rng, 0.0, 0.02, 0.8, 0.3)
		"shiver":
			# 찬바람: 낮은 바람이 부풀었다 사그라지며 가는 휘파람이 섞인다
			b = _buf(1.5)
			var lp3 := 0.0
			var ph4 := 0.0
			for i in b.size():
				var t := float(i) / float(b.size())
				var sw := pow(sin(t * PI), 1.6)
				lp3 += lerpf(0.08, 0.2, sw) * (rng.randf_range(-1.0, 1.0) - lp3)
				ph4 += TAU * (620.0 + 260.0 * sw + 30.0 * sin(t * 40.0)) / float(RATE)
				b[i] = (lp3 * 0.9 + sin(ph4) * 0.07) * sw
		"chatter":
			# 이가 딱딱 부딪는 소리: 작고 단단한 소리가 불규칙한 떨림으로 이어진다
			b = _buf(0.95)
			var tt := 0.0
			for k in 11:
				var g := rng.randf_range(0.5, 1.0)
				_add_modes(b, [[2400.0 + rng.randf() * 500.0, 1.0, 230.0], [3900.0, 0.4, 300.0]], tt, g)
				_add_noise(b, rng, tt, 0.004, 0.6 * g, 0.9, 0.4)
				tt += rng.randf_range(0.055, 0.085)
				if k == 5:
					tt += 0.12
		"stomach":
			# 배 속에서 나는 꼬르륵: 낮은 소리가 떨리며 오르내린다
			b = _buf(1.2)
			var ph5 := 0.0
			var lp4 := 0.0
			for i in b.size():
				var t := float(i) / float(b.size())
				var f := 80.0 + 70.0 * sin(t * PI) - 25.0 * t
				ph5 += TAU * f / float(RATE)
				lp4 += 0.04 * (rng.randf_range(-1.0, 1.0) - lp4)
				var trem := 0.55 + 0.45 * sin(t * 90.0 + sin(t * 11.0) * 2.0)
				b[i] = (sin(ph5) * 0.7 + lp4 * 2.2) * trem * sin(t * PI)
		"gasp":
			# 숨이 차 크게 들이쉬고 내쉬는 소리
			b = _buf(0.85)
			var lp5 := 0.0
			var hp5 := 0.0
			for i in b.size():
				var t := float(i) / float(b.size())
				var env := (smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.3, 0.42, t))) * 0.8 + (smoothstep(0.45, 0.55, t) * (1.0 - smoothstep(0.55, 1.0, t))) * 0.55
				lp5 += 0.45 * (rng.randf_range(-1.0, 1.0) - lp5)
				hp5 += 0.12 * (lp5 - hp5)
				b[i] = (lp5 - hp5) * env
		"step_dirt":
			# 흙 밟는 소리(아주 부드럽게): 둔하고 낮은 눌림. 모서리 없이 천천히 일어났다 사라진다
			b = _buf(0.2)
			var lpd := 0.0
			for i in b.size():
				var t := float(i) / float(b.size())
				var env := pow(sin(PI * pow(t, 0.55)), 2.0)
				lpd += 0.07 * (rng.randf_range(-1.0, 1.0) - lpd)
				b[i] = lpd * env * 1.6 + sin(TAU * 78.0 * t * 0.2) * env * 0.25
		"step_snow":
			# 눈 밟는 소리: 뽀드득. 눈이 눌리며 가는 마찰음이 두 번 올라갔다 가라앉는다 (살짝, 부드럽게)
			b = _buf(0.3)
			var lps := 0.0
			var hps := 0.0
			var phs := 0.0
			for i in b.size():
				var t := float(i) / float(b.size())
				var e1 := pow(sin(PI * clampf(t / 0.42, 0.0, 1.0)), 2.0)
				var e2 := pow(sin(PI * clampf((t - 0.38) / 0.5, 0.0, 1.0)), 2.0) * 0.8
				var env := maxf(e1, e2)
				lps += 0.30 * (rng.randf_range(-1.0, 1.0) - lps)
				hps += 0.10 * (lps - hps)
				phs += TAU * (1500.0 + 900.0 * t + 120.0 * sin(t * 70.0)) / float(RATE)
				b[i] = ((lps - hps) * 1.1 + sin(phs) * 0.16) * env
		"step_plank":
			# 나무 널 밟는 소리(부드럽게): 속 빈 나무가 낮고 짧게 울린다
			b = _buf(0.24)
			_add_modes(b, [[160.0, 1.0, 22.0], [330.0, 0.35, 38.0]], 0.0, 0.8)
			for i in b.size():
				b[i] *= minf(float(i) / 260.0, 1.0)
		"crackle":
			# 모닥불 장작 타는 소리(반복): 낮은 불길 위로 톡톡 튀는 불똥
			b = _buf(2.4)
			_add_noise(b, rng, 0.0, 2.4, 0.18, 0.05, 0.01, 0.0)
			for k in 34:
				_add_noise(b, rng, rng.randf() * 2.35, rng.randf_range(0.004, 0.012), rng.randf_range(0.5, 1.2), 0.85, 0.35)
			for k in 4:
				_add_modes(b, [[rng.randf_range(120.0, 200.0), 0.5, 50.0]], rng.randf() * 2.2)
		"chwita":
			b = _synth_chwita(rng)
		_:
			_add_modes(b, [[800.0, 1.0, 40.0]])
	return b
