class_name WaterSound
extends Ambience
## 개천과 한강 소리를 '제자리에서 나는 소리'로 바꾼 환경음. 기존 Ambience를 그대로 두고 물소리만 3D로 덮어쓴다.
## 개천은 가까이(약 7m 안)에서만 졸졸 들리고, 한강은 넓어서 약 40m까지 은은하게 들린다(크기·거리는 설계값).

var _stream3d: AudioStreamPlayer3D
var _river3d: AudioStreamPlayer3D


## 물소리 합성: 잔잔한 물결 바탕(대역 통과 잡음, 천천히 일렁임) 위에 작은 물방울이 '똑·또르르' 하고 튀는 소리를 겹친다.
## 물방울은 짧은 사인파가 빠르게 음이 올라가며 사라지는 소리다(기포가 터지는 소리의 근사). 모든 수치는 설계값.
## seconds 안에 swell_hz가 정수 번 들어가야 반복할 때 어색하지 않다.
static func _water(seconds: float, rseed: int, bed_lo: float, bed_hi: float, bed_amp: float, bubbles_per_s: float, f_lo: float, f_hi: float, swell_hz: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_lo := 1.0 - exp(-TAU * bed_lo / float(RATE))
	var a_hi := 1.0 - exp(-TAU * bed_hi / float(RATE))
	var l1 := 0.0
	var l2 := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		l1 += a_lo * (x - l1)
		l2 += a_hi * (x - l2)
		var tt := float(i) / float(RATE)
		var swell := 0.6 + 0.25 * sin(TAU * swell_hz * tt) + 0.15 * sin(TAU * swell_hz * 2.0 * tt + 1.3)
		out[i] = (l2 - l1) * bed_amp * swell
	var count := int(seconds * bubbles_per_s)
	for b in count:
		var start := rng.randi() % n
		var dur := int(rng.randf_range(0.015, 0.05) * float(RATE))
		var f0 := rng.randf_range(f_lo, f_hi)
		var amp := pow(rng.randf_range(0.2, 0.8), 2.0)
		var rise := rng.randf_range(4.0, 9.0)
		var ph := 0.0
		for k in dur:
			var t2 := float(k) / float(RATE)
			ph += TAU * f0 * (1.0 + rise * t2) / float(RATE)
			var env := (1.0 - exp(-t2 * 900.0)) * exp(-t2 * 85.0)
			out[(start + k) % n] += sin(ph) * env * amp
	return _wav(out, true)


func _make3d(stream: AudioStreamWAV, unit: float, max_d: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit
	p.max_distance = max_d
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p.volume_db = db
	add_child(p)
	p.play()
	return p


func _ready() -> void:
	super._ready()
	# 기존의 전체 재생(거리와 상관없이 깔리는) 물소리는 끈다
	_stream.stop()
	_river.stop()
	# 개천: 졸졸 흐르는 작은 물(물방울 많고 높은 소리). 한강: 낮고 느린 출렁임 위에 물방울이 드문드문.
	_stream3d = _make3d(_water(6.0, 12, 600.0, 3500.0, 0.5, 40.0, 600.0, 2400.0, 0.5), 1.2, 7.0, -22.0)
	_river3d = _make3d(_water(6.0, 13, 120.0, 1400.0, 1.2, 8.0, 250.0, 900.0, 0.3333333), 5.0, 40.0, -26.0)


func _process(delta: float) -> void:
	super._process(delta)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	# 소리 나는 자리: 카메라와 같은 x에서 가장 가까운 개천/한강 물줄기 위
	var sx := clampf(p.x, HanyangMap.STREAM_X0, HanyangMap.STREAM_X1 - 30.0)
	var sz := HanyangMap.stream_z(sx)
	_stream3d.global_position = Vector3(sx, HanyangMap.height(sx, sz) + 0.4, sz)
	_river3d.global_position = Vector3(p.x, HanyangMap.RIVER_LEVEL + 1.0, HanyangMap.river_z(p.x))
	# 겨울에는 얼음과 눈에 가려 물소리가 줄고, 비 오면 조금 커진다
	_stream3d.volume_db = -22.0 - 8.0 * Season.snow + 3.0 * DayNight.rain_amount
	_river3d.volume_db = -26.0 - 6.0 * Season.snow + 3.0 * DayNight.rain_amount
