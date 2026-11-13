class_name PlayerSurvivor
extends PlayerExplorer
## 생존 모드 주인공. 지형 충돌과 눈에 보이는 지형이 어긋나 몸이 땅에 묻히면 지면 위로 끌어올리고,
## 카메라가 너무 가파르게 내려다보지 않게 제한한다. 막힘 진단 로그는 끈다.

const SINK_MARGIN := 0.12


func _physics_process(delta: float) -> void:
	super(delta)
	var g := HanyangMap.height(global_position.x, global_position.z)
	if global_position.y < g - SINK_MARGIN:
		global_position.y = g + 0.05
		if velocity.y < 0.0:
			velocity.y = 0.0


func _process(delta: float) -> void:
	super(delta)
	_pitch = clampf(_pitch, -0.8, 0.35)


func _log_blocker(_delta: float) -> void:
	pass
