class_name FaceManager
extends Node
## 주변 사람들(NPC)에게 가벼운 얼굴(FaceKit lite)을 붙였다 뗀다.
## 얼굴 조각은 사람마다 메시가 열 개 남짓이라 모든 NPC에 달면 무겁다.
## 그래서 카메라에서 18 m 안의 가까운 사람 24명에게만 붙이고, 24 m 밖으로 나가면 뗀다. 멀리서는 눈코입이 보이지 않으므로 티가 나지 않는다.
## 주인공은 PlayerFace 가 따로 완전한 얼굴을 붙이므로 여기서 건너뛴다.

const NEAR := 18.0
const FAR := 24.0
const MAX_FACES := 24

var _kits: Dictionary = {}
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	# 사라졌거나 멀어진 사람의 얼굴을 뗀다
	for p in _kits.keys():
		var kit: FaceKit = _kits[p]
		if not is_instance_valid(p) or not is_instance_valid(kit):
			_kits.erase(p)
			if is_instance_valid(kit):
				kit.queue_free()
			continue
		var pn := p as Person
		if pn.global_position.distance_to(cp) > FAR or not pn.is_visible_in_tree():
			_kits.erase(p)
			kit.queue_free()
	# 가까운 순서로 모자란 자리를 채운다
	var near: Array = []
	for n in get_tree().get_nodes_in_group("person"):
		var pr := n as Person
		if pr == null or pr.kind == Person.Kind.PROTAGONIST or _kits.has(pr) or not pr.is_visible_in_tree():
			continue
		var d := pr.global_position.distance_to(cp)
		if d < NEAR:
			near.append([d, pr])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for e in near:
		if _kits.size() >= MAX_FACES:
			break
		var kit2 := FaceKit.new()
		add_child(kit2)
		kit2.setup(e[1], true)
		_kits[e[1]] = kit2
