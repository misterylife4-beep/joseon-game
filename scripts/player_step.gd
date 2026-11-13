class_name PlayerStep
extends Player
## 주인공. 걷다가 낮은 턱(계단, 기단, 지형 단차)에 막히면 점프 없이 자동으로 올라선다.
## 최대 높이와 탐지 거리는 설계값이다.

const STEP_MAX := 1.0
const PROBE := 0.5


func _physics_process(delta: float) -> void:
	_try_step_up()
	super(delta)


func _try_step_up() -> void:
	if not is_on_floor():
		return
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if h.length() < 0.5:
		return
	var motion := h.normalized() * PROBE
	var xf := global_transform
	if not test_move(xf, motion):
		return
	var up := Vector3.UP * STEP_MAX
	if test_move(xf, up):
		return
	var raised := xf.translated(up)
	if test_move(raised, motion):
		return
	var over := raised.translated(motion)
	var res := PhysicsTestMotionResult3D.new()
	if test_move(over, Vector3.DOWN * (STEP_MAX + 0.05), res):
		var land := over.translated(res.get_travel())
		global_transform = land
