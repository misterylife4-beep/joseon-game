class_name WalkGuard
extends RefCounted
## 걷는 사람이 건물·울타리·자재·나무를 뚫고 지나가지 않게 한다.
## 허리 높이에서 앞으로 짧은 광선을 쏘아 막혔는지 보고, 막히면 좌우로 비스듬히 틀어 비켜 간다.
## 땅(윗면이 위를 보는 면)과 플레이어는 장애물로 보지 않는다. 거리와 각도는 설계값이다.

const LOOK := 1.3
const WAIST := 0.9
const ANGLES: Array[float] = [0.0, 0.55, -0.55, 1.1, -1.1, 1.7, -1.7, 2.4, -2.4]


static func clear(node: Node3D, from: Vector2, dir: Vector2, base_y: float) -> bool:
	var space := node.get_world_3d().direct_space_state
	var a := Vector3(from.x, base_y + WAIST, from.y)
	var b := a + Vector3(dir.x, 0.0, dir.y) * LOOK
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var ex: Array[RID] = []
	for i in 3:
		q.exclude = ex
		var r := space.intersect_ray(q)
		if r.is_empty():
			return true
		var col: Object = r["collider"]
		var up: float = (r["normal"] as Vector3).y
		if col is CharacterBody3D or up > 0.6:
			ex.append((col as CollisionObject3D).get_rid())
			continue
		return false
	return true


## 가려는 방향에서 얼마나 틀어야 하는지(라디안). 갈 수 있는 곳이 없으면 INF.
static func steer(node: Node3D, from: Vector2, dir: Vector2, base_y: float) -> float:
	for ang in ANGLES:
		if clear(node, from, dir.rotated(ang), base_y):
			return ang
	return INF


## 상자 모양 충돌체를 붙인다 (자재 더미, 비계 같은 소품용)
static func add_box(parent: Node3D, center: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	body.position = center
	body.rotation.y = yaw
	parent.add_child(body)
	return body


## 켜고 끄기: 숨겨진 소품이 보이지 않는 벽으로 남지 않게 한다.
static func set_collide(n: Node, on: bool) -> void:
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 1 if on else 0
	for c in n.get_children():
		set_collide(c, on)
