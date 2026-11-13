class_name PlayerExplorer
extends Player
## 주인공. 걷다가 낮은 턱(최대 STEP_MAX)에 막히면 높이만 올려서 넘는다(앞으로 순간이동하지 않는다).
## 걷는데 막히면 막은 물체를 로그에 남긴다(godot.log 의 BLOCK 줄).

const STEP_MAX := 0.9
const PROBE := 0.12

var _log_cd := 0.0


func _physics_process(delta: float) -> void:
	_try_step_up()
	super(delta)
	_log_blocker(delta)


func _try_step_up() -> void:
	if not is_on_floor():
		return
	var h := Vector3(velocity.x, 0.0, velocity.z)
	if h.length() < 0.5:
		return
	var dir := h.normalized()
	var xf := global_transform
	var hit := KinematicCollision3D.new()
	if not test_move(xf, dir * PROBE, hit):
		return
	# 벽(거의 수직 면)에 막힌 경우만: 완만한 오르막은 move_and_slide 가 처리한다
	if absf(hit.get_normal().y) > 0.3:
		return
	var up := Vector3.UP * STEP_MAX
	if test_move(xf, up):
		return
	var raised := xf.translated(up)
	if test_move(raised, dir * (PROBE + 0.3)):
		return
	var over := raised.translated(dir * (PROBE + 0.3))
	var res := KinematicCollision3D.new()
	if not test_move(over, Vector3.DOWN * (STEP_MAX + 0.05), res):
		return
	var rise := STEP_MAX - res.get_travel().length()
	if rise > 0.02 and rise <= STEP_MAX:
		global_position.y += rise + 0.02


func _log_blocker(delta: float) -> void:
	_log_cd -= delta
	if _log_cd > 0.0 or input_locked:
		return
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if inp.length() < 0.1 or get_real_velocity().length() > 1.0:
		return
	_log_cd = 0.7
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider() as Node
		if col == null:
			continue
		var info := ""
		for ch in col.get_children():
			if ch is CollisionShape3D and (ch as CollisionShape3D).shape is BoxShape3D:
				info += " box=%s" % str(((ch as CollisionShape3D).shape as BoxShape3D).size)
		var par := col.get_parent()
		print("BLOCK player=%s collider=%s class=%s parent=%s(%s) pos=%s normal=%s%s" % [
			str(global_position), col.name, col.get_class(),
			par.name if par else "-", par.get_class() if par else "-",
			str((col as Node3D).global_position) if col is Node3D else "-",
			str(c.get_normal()), info])
