class_name BodySfx
extends Node
## 몸이 느끼는 것에 맞는 소리: 추우면 몸 떠는 소리와 이 부딪는 소리, 배고프면 꼬르륵,
## 숨이 차면 몰아쉬는 숨, 걸으면 밟은 곳(흙·눈·나무 널)에 맞는 발소리.
## 기준 수치와 간격은 설계값이다. (고증_근거.md 40장)

var _player: Player
var _sv: Survival
var _shiver_t := 4.0
var _hunger_t := 8.0
var _step_t := 0.0
var _was_exh := false


func setup(player: Player, sv: Survival) -> void:
	_player = player
	_sv = sv


func _process(delta: float) -> void:
	if _player == null or _sv == null or not is_instance_valid(_player):
		return
	_cold(delta)
	_hunger(delta)
	_breath()
	_steps(delta)


## 체온이 50 아래로 내려가면 찬바람에 몸이 떠는 소리, 35 아래면 이 부딪는 소리도 함께. 불 곁에서는 멈춘다.
func _cold(delta: float) -> void:
	var w := _sv.warmth
	if w >= 50.0 or _sv.near_fire():
		_shiver_t = maxf(_shiver_t, 3.0)
		return
	var k := clampf((50.0 - w) / 50.0, 0.0, 1.0)
	_shiver_t -= delta
	if _shiver_t > 0.0:
		return
	_shiver_t = lerpf(14.0, 6.0, k)
	UiSfx.play(self, "shiver", -26.0 + 10.0 * k, randf_range(0.92, 1.08))
	if w < 35.0:
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			UiSfx.play(self, "chatter", -22.0 + 6.0 * k, randf_range(0.95, 1.1)))


## 허기가 25 아래면 배에서 꼬르륵. 더 굶을수록 자주.
func _hunger(delta: float) -> void:
	var h := _sv.hunger
	if h >= 25.0:
		_hunger_t = maxf(_hunger_t, 6.0)
		return
	_hunger_t -= delta
	if _hunger_t > 0.0:
		return
	_hunger_t = lerpf(8.0, 22.0, h / 25.0)
	UiSfx.play(self, "stomach", -17.0, randf_range(0.9, 1.1))


## 기력이 바닥나 더는 달릴 수 없게 된 순간 숨을 몰아쉰다.
func _breath() -> void:
	var exh: bool = _sv._exhausted
	if exh and not _was_exh:
		UiSfx.play(self, "gasp", -10.0)
	_was_exh = exh


## 발소리: 걸음 폭 2.6 m마다 한 번. 밟은 곳을 아래로 쏜 선으로 알아본다.
func _steps(delta: float) -> void:
	if _player.swimming or _player.riding != null or _player.input_locked or not _player.is_on_floor() or _player.wade_depth > 0.05:
		_step_t = 0.0
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 1.2:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t > 0.0:
		return
	_step_t = 2.6 / speed
	var kind := "step_dirt"
	var from := _player.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.6)
	q.collision_mask = 1
	q.exclude = [_player.get_rid()]
	var r := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r["collider"] is Node and (r["collider"] as Node).has_meta("surface"):
		kind = "step_" + String((r["collider"] as Node).get_meta("surface"))
	elif Season.snow > 0.12:
		kind = "step_snow"
	var sprint := speed > 6.2
	UiSfx.play(self, kind, -23.0 if sprint else -28.0, randf_range(0.94, 1.06))
