class_name Tink
extends AudioStreamPlayer3D
## 공사장의 정 쪼는 소리. 해 뜰 무렵부터 해 질 무렵까지 불규칙하게 울린다. 간격과 음색은 설계값이다.

var base_pitch := 1.0
var _wait := 0.5


func _ready() -> void:
	stream = Ambience.tink_stream()
	unit_size = 8.0
	max_distance = 90.0
	volume_db = -9.0
	_wait = randf_range(0.5, 8.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var h: float = DayNight.hour_now
	if h < 5.5 or h >= 19.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		play()
		pitch_scale = base_pitch * randf_range(0.85, 1.2)
		_wait = randf_range(0.55, 1.3)
