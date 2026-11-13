class_name PalaceSite
extends HanyangSite
## 경복궁 터. 아직 안 지어진 전각은 충돌도 끄고, 광화문 바로 안쪽 전각은 통로를 비켜 양옆으로 나눠 세운다.
## (hanyang_site.gd 는 편집기에 열려 있어 덮어써지므로 새 파일에서 고친다.)


var _pillars: Array[Node] = []
var _complete := false
var _throne: Hanok


func is_complete() -> bool:
	return _complete


## 정전 기둥을 기록해 둔다 (완공되면 근정전으로 바뀐다)
func _build_pillars() -> void:
	var n0 := get_child_count()
	super()
	for i in range(n0, get_child_count()):
		_pillars.append(get_child(i))


## 1막을 마치면 궁궐이 끝까지 지어진다: 궁성과 전각이 모두 서고 기둥 자리에 정전(근정전)이 선다.
## 근정전 7칸×4칸은 압축한 설계값이다(실제는 정면 5칸·측면 5칸 2층, 1395년 준공 당시 정전의 존재는 [사료]).
func complete() -> void:
	if _complete:
		return
	_complete = true
	set_progress(1.0)
	for pl in _pillars:
		(pl as Node3D).visible = false
		WalkGuard.set_collide(pl, false)
	if _throne == null:
		_throne = Hanok.new()
		_throne.setup(Hanok.Style.TILE, 7, 4, Vector3(0.0, 0.6, 0.0), 0.0, true)
		add_child(_throne)
		var label := Label3D.new()
		label.text = "근정전"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0.0, 9.5, 0.0)
		label.font_size = 56
		label.pixel_size = 0.012
		label.outline_size = 12
		label.visibility_range_end = 90.0
		_throne.add_child(label)


func _build_halls() -> void:
	super()
	for st in _stages.duplicate():
		var n := st[1] as Node3D
		if absf(n.position.x) < 0.1 and absf(n.position.z - 17.0) < 0.1:
			var y := n.position.y
			var when: float = st[0]
			_stages.erase(st)
			n.queue_free()
			for sx in [-11.0, 11.0]:
				var hk := Hanok.new()
				hk.setup(Hanok.Style.TILE, 3, 1, Vector3(sx, y, 17.0), 0.0, true)
				hk.visible = false
				add_child(hk)
				_stages.append([when, hk])


func set_progress(p: float) -> void:
	if _complete:
		p = 1.0
	super(p)
	for st in _stages:
		_set_collision(st[1] as Node, p >= float(st[0]))


func _set_collision(n: Node, on: bool) -> void:
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 1 if on else 0
	for c in n.get_children():
		_set_collision(c, on)
