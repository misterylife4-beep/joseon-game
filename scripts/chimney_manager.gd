class_name ChimneyManager
extends Node
## 카메라 가까이 있는 민가에만 굴뚝과 연기를 세운다(수백 채에 한꺼번에 입자를 두지 않기 위한 설계).
## 집 뒤편 위치는 house_points(집 앞마당 점)에서 뒤로 7.5m, 옆으로 2m 옮긴 설계값이다.

const NEAR := 80.0
const FAR := 115.0
const MAX_ACTIVE := 28

var _active: Dictionary = {}  # 인덱스 -> ChimneySmoke
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.5
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var hp := HanyangCity.house_points

	# 멀어진 굴뚝은 치운다
	for k in _active.keys():
		var node: ChimneySmoke = _active[k]
		var d := Vector2(node.global_position.x - cp.x, node.global_position.z - cp.z).length()
		if d > FAR:
			node.queue_free()
			_active.erase(k)

	# 가까운 집에 굴뚝을 세운다
	for i in hp.size():
		if _active.size() >= MAX_ACTIVE:
			break
		if _active.has(i):
			continue
		var p := hp[i]
		var cx := p.x + 2.0
		var cz := p.y - 7.5
		if Vector2(cx - cp.x, cz - cp.z).length() > NEAR:
			continue
		var s := ChimneySmoke.new()
		s.position = Vector3(cx, HanyangMap.height(cx, cz), cz)
		get_parent().add_child(s)
		_active[i] = s

	# 추운 철과 아침저녁(밥 짓는 때)에 더 많이 난다
	var h: float = DayNight.hour_now
	var meal := 1.0 if (h >= 5.0 and h < 9.0) or (h >= 17.0 and h < 22.0) else 0.6
	var level := clampf(0.25 + Season.cold * 0.75, 0.15, 1.0) * meal
	for k in _active.keys():
		(_active[k] as ChimneySmoke).set_strength(level)
