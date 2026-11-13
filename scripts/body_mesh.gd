class_name BodyMesh
extends RefCounted
## 사람 모델의 몸 조각을 만드는 도우미. 모든 함수는 SurfaceTool에 삼각형을 더한다.
## 정점 색의 알파: 0이면 피부·나무(매끈), 1이면 천(셰이더가 직조 무늬를 그린다).


## 삼각형 하나. 꼭짓점 법선 합쪽이 앞면이 되도록 감는 방향을 맞춘다.
static func tri(
	st: SurfaceTool,
	a: Vector3, b: Vector3, c: Vector3,
	na: Vector3, nb: Vector3, nc: Vector3,
	ca: Color, cb: Color, cc: Color
) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 0.00000001:
		return
	if cr.dot(na + nb + nc) > 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_color(cb)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_color(cc)
	st.set_normal(nc)
	st.add_vertex(c)


## 단면을 위로(또는 아래로) 이어 붙인 통. rings의 각 항목은 [y, rx, rz] 또는 [y, rx, rz, cx, cz].
## 색은 첫 단면의 col_a에서 마지막 단면의 col_b로 이어진다.
static func loft(
	st: SurfaceTool, rings: Array, sides: int,
	col_a: Color, col_b: Color,
	cap_first := false, cap_last := false
) -> void:
	var n := rings.size()
	if n < 2:
		return
	var pts: Array = []
	var nrm: Array = []
	var cols: Array = []
	for j in n:
		var r: Array = rings[j]
		var y: float = r[0]
		var rx: float = r[1]
		var rz: float = r[2]
		var cx: float = 0.0
		var cz: float = 0.0
		if r.size() > 3:
			cx = r[3]
			cz = r[4]
		var ra: Array = rings[maxi(j - 1, 0)]
		var rb: Array = rings[mini(j + 1, n - 1)]
		var dy: float = float(rb[0]) - float(ra[0])
		var dr: float = ((float(rb[1]) + float(rb[2])) - (float(ra[1]) + float(ra[2]))) * 0.5
		var slope := 0.0
		if absf(dy) > 0.0001:
			slope = dr / dy
		var row_p: Array = []
		var row_n: Array = []
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var ca := cos(a)
			var sa := sin(a)
			row_p.append(Vector3(cx + ca * rx, y, cz + sa * rz))
			var hn := Vector2(ca / maxf(rx, 0.001), sa / maxf(rz, 0.001)).normalized()
			row_n.append(Vector3(hn.x, -slope, hn.y).normalized())
		pts.append(row_p)
		nrm.append(row_n)
		cols.append(col_a.lerp(col_b, float(j) / float(n - 1)))

	for j in n - 1:
		var c0: Color = cols[j]
		var c1: Color = cols[j + 1]
		for k in sides:
			var k2 := (k + 1) % sides
			var p00: Vector3 = pts[j][k]
			var p01: Vector3 = pts[j][k2]
			var p10: Vector3 = pts[j + 1][k]
			var p11: Vector3 = pts[j + 1][k2]
			var n00: Vector3 = nrm[j][k]
			var n01: Vector3 = nrm[j][k2]
			var n10: Vector3 = nrm[j + 1][k]
			var n11: Vector3 = nrm[j + 1][k2]
			tri(st, p00, p01, p11, n00, n01, n11, c0, c0, c1)
			tri(st, p00, p11, p10, n00, n11, n10, c0, c1, c1)

	if cap_first:
		_cap(st, pts[0], cols[0], Vector3(0.0, -1.0 if float((rings[1] as Array)[0]) > float((rings[0] as Array)[0]) else 1.0, 0.0))
	if cap_last:
		_cap(st, pts[n - 1], cols[n - 1], Vector3(0.0, 1.0 if float((rings[n - 1] as Array)[0]) > float((rings[n - 2] as Array)[0]) else -1.0, 0.0))


static func _cap(st: SurfaceTool, row: Array, col: Color, nrm: Vector3) -> void:
	var center := Vector3.ZERO
	for p in row:
		center += p
	center /= float(row.size())
	for k in row.size():
		var k2 := (k + 1) % row.size()
		tri(st, center, row[k], row[k2], nrm, nrm, nrm, col, col, col)


## 타원체(일부만 만들 수도 있다). lat은 위(0)에서 아래(PI), lon은 z축 기준 한 바퀴.
static func ellipsoid(
	st: SurfaceTool, c: Vector3, r: Vector3, col: Color,
	lat0 := 0.0, lat1 := PI, lon0 := 0.0, lon1 := TAU,
	lat := 6, lon := 10
) -> void:
	for i in lat:
		var th0 := lat0 + (lat1 - lat0) * float(i) / float(lat)
		var th1 := lat0 + (lat1 - lat0) * float(i + 1) / float(lat)
		for k in lon:
			var ph0 := lon0 + (lon1 - lon0) * float(k) / float(lon)
			var ph1 := lon0 + (lon1 - lon0) * float(k + 1) / float(lon)
			var d00 := _dir(th0, ph0)
			var d01 := _dir(th0, ph1)
			var d10 := _dir(th1, ph0)
			var d11 := _dir(th1, ph1)
			tri(st, c + d00 * r, c + d01 * r, c + d11 * r, _en(d00, r), _en(d01, r), _en(d11, r), col, col, col)
			tri(st, c + d00 * r, c + d11 * r, c + d10 * r, _en(d00, r), _en(d11, r), _en(d10, r), col, col, col)


static func _dir(th: float, ph: float) -> Vector3:
	return Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))


static func _en(d: Vector3, r: Vector3) -> Vector3:
	return Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized()


## 상자. rot은 오일러 각(라디안)이다.
static func box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot)
	var h := size * 0.5
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for ai in 3:
		var n: Vector3 = axes[ai]
		var u: Vector3 = axes[(ai + 1) % 3]
		var v: Vector3 = axes[(ai + 2) % 3]
		for sgn in [-1.0, 1.0]:
			var s: float = sgn
			var nn := n * s
			var wn := (b * nn).normalized()
			var p00 := c + b * ((nn - u - v) * h)
			var p10 := c + b * ((nn + u - v) * h)
			var p01 := c + b * ((nn - u + v) * h)
			var p11 := c + b * ((nn + u + v) * h)
			tri(st, p00, p10, p11, wn, wn, wn, col, col, col)
			tri(st, p00, p11, p01, wn, wn, wn, col, col, col)
