class_name TownNav
extends RefCounted
## 사람이 집에 오갈 때 돌아 지나갈 문. 곧장 가면 담과 성벽에 막히므로 막히지 않은 문을 거친다.
##  - 집 마당: 담 남쪽 가운데의 틈(문)으로 드나든다 (hanyang_city.gd 의 _yard_wall: 집 앞마당 점에서 남쪽으로 1.5 m).
##  - 경복궁 궁성: 남쪽·북쪽 문 자리(틈)로 드나든다.
##  - 도성 성벽: 성문으로만 드나들고, 성문이 닫힌 밤(22시~4시)에는 건너지 않는다.
## 문 앞 접근 거리와 안쪽 거리는 설계값이다.

const YARD_GATE := 1.5
const YARD_OUT := 5.0
const PALACE_IN := Vector2(33.0, 21.0)
const GATE_REACH := 5.0
const WALL_REACH := 9.0


static func gates_open() -> bool:
	var h: float = DayNight.hour_now
	return not (h >= 22.0 or h < 4.0)


## a에서 b까지 거쳐 갈 점들(b 포함). 건널 수 없으면 null.
static func route(a: Vector2, b: Vector2) -> Variant:
	var seq: Array[Vector2] = [a, b]
	# 1) 경복궁 궁성
	var s1: Array[Vector2] = [a]
	for i in range(1, seq.size()):
		s1.append_array(_palace_via(seq[i - 1], seq[i]))
		s1.append(seq[i])
	# 2) 도성 성벽
	var s2: Array[Vector2] = [s1[0]]
	for i in range(1, s1.size()):
		var via = _city_via(s1[i - 1], s1[i])
		if via == null:
			return null
		s2.append_array(via)
		s2.append(s1[i])
	s2.remove_at(0)
	return s2


static func _in_palace(p: Vector2) -> bool:
	var c := HanyangMap.PALACE_C
	return absf(p.x - c.x) < PALACE_IN.x and absf(p.y - c.y) < PALACE_IN.y


static func _palace_via(p: Vector2, q: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var ip := _in_palace(p)
	if ip == _in_palace(q):
		return out
	var c := HanyangMap.PALACE_C
	var inner := p if ip else q
	var outer := q if ip else p
	var best := 1.0e9
	var bs := 1.0
	for sgn in [-1.0, 1.0]:
		var s: float = sgn
		var gi := Vector2(c.x, c.y + s * (HanyangSite.HALF_Z - GATE_REACH))
		var go := Vector2(c.x, c.y + s * (HanyangSite.HALF_Z + GATE_REACH))
		var d := inner.distance_to(gi) + outer.distance_to(go)
		if d < best:
			best = d
			bs = s
	var g_in := Vector2(c.x, c.y + bs * (HanyangSite.HALF_Z - GATE_REACH))
	var g_mid := Vector2(c.x, c.y + bs * HanyangSite.HALF_Z)
	var g_out := Vector2(c.x, c.y + bs * (HanyangSite.HALF_Z + GATE_REACH))
	if ip:
		out.append_array([g_in, g_mid, g_out])
	else:
		out.append_array([g_out, g_mid, g_in])
	return out


## 도성 안과 밖에 걸치면 가장 가까운 성문을 지나게 한다. 성문이 닫혔으면 null.
static func _city_via(p: Vector2, q: Vector2):
	var ip := HanyangMap.u_of(p.x, p.y) < 1.0
	var iq := HanyangMap.u_of(q.x, q.y) < 1.0
	var out: Array[Vector2] = []
	if ip == iq:
		return out
	if not gates_open():
		return null
	var best := 1.0e9
	var bg := ""
	for g in HanyangMap.GATES:
		var gp := HanyangMap.gate_pos(String(g["name"]))
		var d := p.distance_to(gp) + gp.distance_to(q)
		if d < best:
			best = d
			bg = String(g["name"])
	var phi := HanyangMap.gate_phi(bg)
	var gpos := HanyangMap.crest_point(phi)
	var t := HanyangMap.crest_point(phi + 0.01) - HanyangMap.crest_point(phi - 0.01)
	var nrm := Vector2(t.y, -t.x).normalized()
	if nrm.dot(gpos) < 0.0:
		nrm = -nrm
	var g_in := gpos - nrm * WALL_REACH
	var g_out := gpos + nrm * WALL_REACH
	if ip:
		out.append_array([g_in, gpos, g_out])
	else:
		out.append_array([g_out, gpos, g_in])
	return out


## 집 마당 문 앞(바깥)과 문 자리. home은 집 앞마당 점이다.
static func yard_approach(home: Vector2) -> Vector2:
	return home + Vector2(0.0, YARD_OUT)


static func yard_gate(home: Vector2) -> Vector2:
	return home + Vector2(0.0, YARD_GATE)
