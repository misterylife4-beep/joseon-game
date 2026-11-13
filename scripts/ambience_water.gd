class_name AmbienceWater
extends Ambience
## 개천과 한강 소리를 '제자리에서 나는 소리'로 바꾼 환경음. 기존 Ambience를 그대로 두고 물소리만 3D로 덮어쓴다.
## 개천은 가까이(약 25m 안)에서만 졸졸 들리고, 한강은 넓어서 약 110m까지 은은하게 들린다(크기·거리는 설계값).

var _stream3d: AudioStreamPlayer3D
var _river3d: AudioStreamPlayer3D


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
	_stream3d = _make3d(_noise(3.0, 0.3, 0.02, 12), 3.0, 25.0, -2.0)
	_river3d = _make3d(_noise(5.0, 0.12, 0.01, 13), 14.0, 110.0, 0.0)


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
