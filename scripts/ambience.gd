class_name Ambience
extends Node
## 코드로 만든 환경음: 바람, 시냇물, 한강, 새, 풀벌레, 개구리, 비.
## 외부 음원 없이 파형을 직접 합성한다. 소리의 종류와 크기는 모두 설계값이다.
## 정확한 소리 사료는 없다. 다만 새벽 새소리, 밤 풀벌레와 논 개구리는 한국 자연환경의 일반적인 소리를 따랐다.

const RATE := 16000

var _wind: AudioStreamPlayer
var _stream: AudioStreamPlayer
var _river: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _frogs: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _t := 0.0

static var _tink: AudioStreamWAV


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var q := int(clampf(samples[i] / peak * 0.9, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, q)
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## 잡음에 저역/고역 통과를 걸어 만든 소리
static func _noise(seconds: float, low: float, high: float, rseed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += low * (x - lp)
		hp += high * (lp - hp)
		out[i] = lp - hp
	# 이음매를 부드럽게: 끝 0.2초를 앞 0.2초와 섞는다
	var f := int(0.2 * RATE)
	for i in f:
		var k := float(i) / float(f)
		out[i] = out[i] * k + out[n - f + i] * (1.0 - k)
	out.resize(n - f)
	return _wav(out, true)


static func _chirps(seconds: float, rseed: int, kind: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	if kind == 0:
		# 새: 높이가 오르내리는 짧은 지저귐 몇 번
		for c in 7:
			var start := int(rng.randf() * float(n - RATE / 2))
			var base := rng.randf_range(2400.0, 3800.0)
			var notes := rng.randi_range(2, 4)
			for nn in notes:
				var nlen := int(0.09 * RATE)
				var off := start + nn * int(0.13 * RATE)
				var ph := 0.0
				for i in nlen:
					if off + i >= n:
						break
					var u := float(i) / float(nlen)
					var f := base * (1.0 + 0.35 * sin(u * PI * (1.0 + float(nn))))
					ph += TAU * f / float(RATE)
					out[off + i] += sin(ph) * sin(u * PI)
	elif kind == 1:
		# 풀벌레: 4.3kHz 마디 소리를 3번씩 끊어 울린다
		var ph := 0.0
		for i in n:
			var tt := float(i) / float(RATE)
			var group := fposmod(tt, 0.7)
			var gate := 0.0
			if group < 0.36:
				gate = maxf(sin(group * TAU * 8.5), 0.0)
			ph += TAU * 4300.0 / float(RATE)
			out[i] = sin(ph) * gate * (0.6 + 0.4 * sin(tt * 0.9))
	else:
		# 개구리: 낮고 거친 소리가 짧게 이어진다
		var ph := 0.0
		for g in 4:
			var start := int(rng.randf() * float(n - RATE))
			var f0 := rng.randf_range(380.0, 560.0)
			for i in int(1.0 * RATE):
				if start + i >= n:
					break
				var tt := float(i) / float(RATE)
				var gate := maxf(sin(tt * TAU * 7.0), 0.0) * (1.0 - tt)
				ph += TAU * f0 * (1.0 - 0.1 * tt) / float(RATE)
				out[start + i] += (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.1)) * gate
	return _wav(out, true)


static func tink_stream() -> AudioStreamWAV:
	if _tink != null:
		return _tink
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var n := int(0.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var tt := float(i) / float(RATE)
		var env := exp(-tt * 28.0)
		out[i] = (sin(TAU * 1900.0 * tt) * 0.6 + sin(TAU * 3100.0 * tt) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.4) * env
	_tink = _wav(out, false)
	return _tink


func _player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p


func _ready() -> void:
	_wind = _player(_noise(4.0, 0.05, 0.004, 11))
	_stream = _player(_noise(3.0, 0.3, 0.02, 12))
	_river = _player(_noise(5.0, 0.12, 0.01, 13))
	_birds = _player(_chirps(8.0, 14, 0))
	_crickets = _player(_chirps(2.8, 15, 1))
	_frogs = _player(_chirps(6.0, 16, 2))
	_rain = _player(_noise(3.0, 0.5, 0.05, 17))


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var night: float = DayNight.night_amount
	var rain: float = DayNight.rain_amount
	var day := 1.0 - night
	var gust := 0.5 + 0.5 * sin(_t * 0.37) * sin(_t * 0.11 + 1.0)
	_wind.volume_db = -30.0 + 8.0 * gust + 6.0 * rain
	var sd := absf(p.z - HanyangMap.stream_z(p.x)) if p.x > HanyangMap.STREAM_X0 and p.x < HanyangMap.STREAM_X1 else 999.0
	_stream.volume_db = lerpf(-60.0, -16.0, clampf(1.0 - sd / 40.0, 0.0, 1.0))
	var rd := HanyangMap.river_dist(p.x, p.z) if p.z > 150.0 else 999.0
	_river.volume_db = lerpf(-60.0, -10.0, clampf(1.0 - rd / 130.0, 0.0, 1.0))
	var snowing := Season.cold > 0.55
	_birds.volume_db = lerpf(-60.0, -24.0, day * (1.0 - rain) * Season.birdsong())
	_crickets.volume_db = lerpf(-60.0, -26.0, night * (1.0 - rain * 0.7) * Season.cricket())
	var fr := clampf(1.0 - rd / 160.0, 0.0, 1.0)
	_frogs.volume_db = lerpf(-60.0, -18.0, night * fr * Season.frog())
	# 겨울에 내리는 것은 눈이라 빗소리가 나지 않는다
	_rain.volume_db = lerpf(-60.0, -12.0, 0.0 if snowing else rain)


static var _mumbles: Dictionary = {}


## 대화 중인 사람의 웅얼거림. 말뜻이 없는 모음 소리를 음절 단위로 합성한다(음높이·길이는 설계값).
## kind: 0 낮은 남성, 1 여성, 2 아이
static func mumble_stream(kind: int) -> AudioStreamWAV:
	if _mumbles.has(kind):
		return _mumbles[kind]
	var rate := 12000
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + kind
	var f0_base: float = [118.0, 215.0, 290.0][kind]
	var vowels: Array = [[700.0, 1200.0], [300.0, 2200.0], [500.0, 1500.0], [400.0, 800.0], [550.0, 1000.0]]
	var total := int(7.0 * rate)
	var out := PackedFloat32Array()
	out.resize(total)
	var cursor := int(0.2 * rate)
	while cursor < total - int(0.6 * rate):
		var syl := rng.randi_range(3, 6)
		for k in syl:
			var dur := int(rng.randf_range(0.11, 0.2) * rate)
			var vw: Array = vowels[rng.randi() % vowels.size()]
			var f0: float = f0_base * rng.randf_range(0.9, 1.2)
			var harmonics := mini(int(3600.0 / f0), 14)
			for i in dur:
				if cursor + i >= total:
					break
				var tt := float(i) / float(rate)
				var env := sin(PI * float(i) / float(dur))
				var f: float = f0 * (1.0 + 0.06 * sin(tt * 30.0))
				var v := 0.0
				for hh in range(1, harmonics + 1):
					var fr: float = f * float(hh)
					var wgt := exp(-pow((fr - float(vw[0])) / 220.0, 2.0)) + 0.6 * exp(-pow((fr - float(vw[1])) / 320.0, 2.0)) + 0.05
					v += wgt * sin(TAU * fr * tt) / float(hh) ** 0.5
				out[cursor + i] += v * env
			cursor += dur + int(rng.randf_range(0.02, 0.06) * rate)
		cursor += int(rng.randf_range(0.5, 1.0) * rate)
	var w := _wav(out, true)
	w.mix_rate = rate
	_mumbles[kind] = w
	return w
