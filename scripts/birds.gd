class_name Birds
extends Node
## 마을과 들, 강가, 산에 사는 새: 참새, 까치, 까마귀, 산비둘기, 꿩(장끼·까투리), 청둥오리(겨울), 백로(여름).
## 사는 곳과 움직임은 실제 습성을 본떴다 (docs/고증_근거.md 57장).
##  - 참새: 사람 사는 집 둘레와 도성 안, 가을에는 익은 들판. 무리를 지어 땅에서 폴짝폴짝 낟알을 쪼고, 하나가 놀라면 모두 낮게 날아 지붕·나무로 옮긴다.
##  - 까치: 마을 큰 나무와 지붕, 길가. 짝이나 혼자. 땅을 성큼성큼 걷고, 놀라면 높은 나무 위로 간다.
##  - 까마귀: 들판, 성문 둘레, 성저. 작은 무리로 땅을 걸으며 먹이를 찾는다.
##  - 산비둘기: 궁궐과 절 둘레, 추수한 들. 무리로 땅을 걸으며 고개를 까딱이고, 한꺼번에 날아올라 크게 돈다.
##  - 꿩: 산기슭 덤불과 풀밭, 밭 가장자리. 장끼 한 마리가 까투리 둘 안팎을 거느리고 다니며, 새벽과 해질녘에 활발하다. 가까워지면 웅크려 얼어붙었다가 푸드덕 날아 가까이 내려앉는다.
##  - 청둥오리: 겨울철새. 한강 물 위에 무리를 지어 떠 있고, 놀라면 강을 따라 난다.
##  - 백로: 여름철새. 강가와 논둑에 길쭉한 다리로 서서 오래 꼼짝 않는다.
## 새 종류, 마릿수, 나는 높이와 빠르기, 달아나는 거리는 모두 설계값이다.

const CHECK := 2.0
const SPAWN_MIN := 12.0
const SPAWN_MAX := 58.0
const DESPAWN := 115.0
const MAX_BIRDS := 34
const ROOF_UP := 4.7        ## 지붕 마루 높이(땅 위, m). 한옥 벽 2.6m에 지붕을 얹은 값 근처. [설계]
const TREE_PERCH := 4.4     ## 나무 위에 앉는 높이(나무 크기 배). [설계]

## len 몸 길이(m, 꼬리 빼고), tail 꼬리(몸 길이 곱), leg 다리, neck 목, beak 부리 길이 곱, fly 나는 속도(m/s), walk 걷는 속도,
## scare 이만큼 다가오면 날아 달아남(m), alert 이만큼 다가오면 얼어붙어 살핌(0이면 없음), rate 가만히 있다 저절로 날아오를 확률(초당),
## idle 서 있는 시간 범위(초), max 한 번에 이만큼까지, perch 나무나 지붕에 앉는 새인지, meat 고기 id, feathers 깃털 수, omen 길조 여부.
const SPECIES := {
	"sparrow": {"name": "참새", "len": 0.14, "tail": 0.4, "leg": 0.3, "neck": 0.0, "beak": 1.0, "fly": 8.0, "walk": 0.8, "scare": 5.5, "alert": 0.0, "rate": 0.04, "idle": [0.3, 1.6], "max": 12, "perch": true,
		"back": Color(0.5, 0.36, 0.22), "belly": Color(0.8, 0.72, 0.6), "head": Color(0.45, 0.27, 0.16), "wing": Color(0.4, 0.28, 0.18), "tailc": Color(0.4, 0.3, 0.2), "beak_c": Color(0.2, 0.17, 0.14),
		"meat": "meat_sparrow", "feathers": 1, "fcol": Color(0.5, 0.36, 0.22)},
	"magpie": {"name": "까치", "len": 0.4, "tail": 1.2, "leg": 0.5, "neck": 0.0, "beak": 1.0, "fly": 9.0, "walk": 1.1, "scare": 8.0, "alert": 0.0, "rate": 0.03, "idle": [1.0, 4.0], "max": 6, "perch": true,
		"back": Color(0.07, 0.07, 0.09), "belly": Color(0.95, 0.95, 0.95), "head": Color(0.06, 0.06, 0.08), "wing": Color(0.08, 0.2, 0.34), "tailc": Color(0.06, 0.18, 0.28), "beak_c": Color(0.05, 0.05, 0.05),
		"meat": "", "feathers": 2, "fcol": Color(0.08, 0.2, 0.34), "omen": true},
	"crow": {"name": "까마귀", "len": 0.46, "tail": 0.75, "leg": 0.5, "neck": 0.0, "beak": 1.5, "fly": 10.0, "walk": 1.0, "scare": 9.0, "alert": 0.0, "rate": 0.03, "idle": [1.0, 4.5], "max": 6, "perch": true,
		"back": Color(0.05, 0.05, 0.07), "belly": Color(0.07, 0.07, 0.09), "head": Color(0.05, 0.05, 0.07), "wing": Color(0.06, 0.07, 0.1), "tailc": Color(0.05, 0.05, 0.07), "beak_c": Color(0.04, 0.04, 0.04),
		"meat": "", "feathers": 2, "fcol": Color(0.06, 0.07, 0.1)},
	"pigeon": {"name": "산비둘기", "len": 0.32, "tail": 0.55, "leg": 0.35, "neck": 0.0, "beak": 1.0, "fly": 12.0, "walk": 0.95, "scare": 9.0, "alert": 0.0, "rate": 0.04, "idle": [0.8, 3.0], "max": 8, "perch": true,
		"back": Color(0.5, 0.52, 0.56), "belly": Color(0.62, 0.6, 0.62), "head": Color(0.4, 0.42, 0.52), "wing": Color(0.56, 0.58, 0.62), "tailc": Color(0.3, 0.32, 0.36), "beak_c": Color(0.25, 0.22, 0.2),
		"meat": "meat_pigeon", "feathers": 2, "fcol": Color(0.58, 0.6, 0.64)},
	"pheasant": {"name": "장끼", "grp": "pheasant", "len": 0.5, "tail": 1.5, "leg": 0.6, "neck": 0.0, "beak": 1.0, "fly": 13.0, "walk": 1.3, "scare": 5.0, "alert": 14.0, "rate": 0.004, "idle": [2.0, 7.0], "max": 6, "perch": false,
		"back": Color(0.6, 0.32, 0.14), "belly": Color(0.28, 0.2, 0.12), "head": Color(0.08, 0.34, 0.3), "wing": Color(0.55, 0.36, 0.18), "tailc": Color(0.62, 0.42, 0.2), "beak_c": Color(0.7, 0.62, 0.45),
		"meat": "meat_pheasant", "feathers": 3, "fcol": Color(0.62, 0.38, 0.16), "male": true},
	"hen_pheasant": {"name": "까투리", "grp": "pheasant", "len": 0.42, "tail": 0.9, "leg": 0.6, "neck": 0.0, "beak": 1.0, "fly": 12.5, "walk": 1.2, "scare": 5.0, "alert": 14.0, "rate": 0.004, "idle": [2.0, 7.0], "max": 6, "perch": false,
		"back": Color(0.52, 0.42, 0.28), "belly": Color(0.68, 0.58, 0.42), "head": Color(0.5, 0.4, 0.28), "wing": Color(0.48, 0.38, 0.26), "tailc": Color(0.5, 0.4, 0.28), "beak_c": Color(0.6, 0.55, 0.42),
		"meat": "meat_pheasant", "feathers": 3, "fcol": Color(0.55, 0.43, 0.28)},
	"duck": {"name": "청둥오리", "grp": "duck", "len": 0.5, "tail": 0.3, "leg": 0.3, "neck": 0.15, "beak": 1.0, "fly": 12.0, "walk": 1.0, "scare": 12.0, "alert": 0.0, "rate": 0.02, "idle": [3.0, 8.0], "max": 12, "perch": false,
		"back": Color(0.5, 0.45, 0.4), "belly": Color(0.46, 0.22, 0.12), "head": Color(0.06, 0.4, 0.2), "wing": Color(0.45, 0.4, 0.36), "tailc": Color(0.12, 0.12, 0.14), "beak_c": Color(0.85, 0.75, 0.2),
		"meat": "meat_duck", "feathers": 3, "fcol": Color(0.5, 0.45, 0.4), "male": true},
	"hen_duck": {"name": "청둥오리", "grp": "duck", "len": 0.46, "tail": 0.3, "leg": 0.3, "neck": 0.15, "beak": 1.0, "fly": 12.0, "walk": 1.0, "scare": 12.0, "alert": 0.0, "rate": 0.02, "idle": [3.0, 8.0], "max": 12, "perch": false,
		"back": Color(0.5, 0.4, 0.28), "belly": Color(0.56, 0.45, 0.3), "head": Color(0.46, 0.36, 0.25), "wing": Color(0.44, 0.36, 0.26), "tailc": Color(0.4, 0.32, 0.22), "beak_c": Color(0.8, 0.55, 0.2),
		"meat": "meat_duck", "feathers": 3, "fcol": Color(0.5, 0.4, 0.28)},
	"heron": {"name": "백로", "len": 0.55, "tail": 0.2, "leg": 1.6, "neck": 1.0, "beak": 2.4, "fly": 7.5, "walk": 0.35, "scare": 16.0, "alert": 26.0, "rate": 0.006, "idle": [8.0, 25.0], "max": 6, "perch": false,
		"back": Color(0.96, 0.96, 0.94), "belly": Color(0.95, 0.95, 0.93), "head": Color(0.96, 0.96, 0.94), "wing": Color(0.94, 0.94, 0.92), "tailc": Color(0.92, 0.92, 0.9), "beak_c": Color(0.85, 0.7, 0.2),
		"meat": "", "feathers": 3, "fcol": Color(0.96, 0.96, 0.94)},
}

var _player: Player
var _sv: Survival
var _hud: SurvivalHud
var _timer := 2.0
var _rng := RandomNumberGenerator.new()
var _birds: Array[Bird] = []
var _cm: ChunkManager
static var _mats: Dictionary = {}


## 한 무리: 하나가 놀라면 나머지도 따라 난다
class Flock extends RefCounted:
	var members: Array = []


func setup(player: Player, sv: Survival, hud: SurvivalHud) -> void:
	_player = player
	_sv = sv
	_hud = hud
	_rng.randomize()


static func mat(col: Color, rough := 0.85) -> StandardMaterial3D:
	var key := col.to_html() + str(rough)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	_mats[key] = m
	return m


## 한강 물 위인가 (남쪽 강변에서 땅이 수면보다 낮으면 물)
static func is_water(x: float, z: float) -> bool:
	return z > 150.0 and HanyangMap.surface(x, z) < HanyangMap.RIVER_LEVEL + 0.05


## 새가 딛는 높이: 물 위면 수면
static func floor_y(x: float, z: float) -> float:
	var h := HanyangMap.surface(x, z)
	if z > 150.0 and h < HanyangMap.RIVER_LEVEL:
		return HanyangMap.RIVER_LEVEL
	return h


func _chunks() -> ChunkManager:
	if _cm == null or not is_instance_valid(_cm):
		_cm = get_tree().get_first_node_in_group("chunks") as ChunkManager
	return _cm


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK
	_prune()
	if _player.riding != null or _player.swimming or DayNight.night_amount > 0.55:
		return
	if _birds.size() >= MAX_BIRDS:
		return
	_try_spawn()


func _count(grp: String) -> int:
	var n := 0
	for b in _birds:
		if String(b.d.get("grp", b.sp)) == grp:
			n += 1
	return n


func _prune() -> void:
	var keep: Array[Bird] = []
	var pp := _player.global_position
	for b in _birds:
		if not is_instance_valid(b) or b.dead:
			continue
		if Vector2(b.global_position.x - pp.x, b.global_position.z - pp.z).length() > DESPAWN:
			b.queue_free()
			continue
		keep.append(b)
	_birds = keep


func _near_house(x: float, z: float, r: float) -> bool:
	var hp := HanyangCity.house_points
	for i in hp.size():
		if absf(hp[i].x - x) < r and absf(hp[i].y - z) < r:
			return true
	return false


## 이 자리에 사는 새의 가중치 (사는 곳, 계절, 시간대를 반영한다)
func _weights(x: float, z: float) -> Dictionary:
	var w := {}
	var h := HanyangMap.surface(x, z)
	var u := HanyangMap.u_of(x, z)
	var zn := Region.zone_at(x, z)
	var danger := int(zn["danger"])
	var town := bool(zn["town"])
	var inside := u < 1.0
	var palace := Vector2(x, z).distance_to(HanyangMap.PALACE_C) < 75.0
	var houses := _near_house(x, z, 16.0)
	var rd := HanyangMap.river_dist(x, z) if z > 200.0 else 999.0
	var winter := Season.cold > 0.4
	var summer := Season.cold < 0.55
	var harvest := Season.autumn > 0.35 or Season.crop > 0.7
	if danger >= 2 or (h > 8.0 and u > 1.0):
		w = {"pheasant": 40, "pigeon": 22, "magpie": 22, "crow": 10, "sparrow": 6}
	elif palace:
		w = {"pigeon": 28, "magpie": 26, "sparrow": 24, "crow": 6}
	elif inside and houses:
		w = {"sparrow": 50, "magpie": 20, "pigeon": 12, "crow": 8}
	elif inside:
		w = {"sparrow": 26, "magpie": 18, "pigeon": 12, "crow": 6}
	elif town or houses:
		w = {"sparrow": 46, "magpie": 28, "pigeon": 14, "crow": 12}
	elif rd < 75.0:
		w = {"magpie": 8, "crow": 12, "sparrow": 10}
		if summer:
			w["heron"] = 50
	else:
		w = {"sparrow": 22 + (34 if harvest else 0), "pigeon": 18 + (14 if harvest else 0), "crow": 20, "magpie": 14, "pheasant": 18}
		if summer and rd < 130.0:
			w["heron"] = 16
	if winter:
		w["crow"] = int(w.get("crow", 0) * 1.4)
		if w.has("pheasant"):
			w["pheasant"] = int(w["pheasant"] * 0.8)
	# 새벽과 해질녘에는 꿩과 비둘기가 활발하다
	var hr := DayNight.hour_now
	if hr < 9.0 or hr > 16.0:
		if w.has("pheasant"):
			w["pheasant"] = int(w["pheasant"] * 1.8)
		if w.has("pigeon"):
			w["pigeon"] = int(w["pigeon"] * 1.3)
	return w


func _pick_species(x: float, z: float) -> String:
	var w := _weights(x, z)
	var total := 0
	for k in w:
		if _count(String(SPECIES[k].get("grp", k))) < int(SPECIES[k]["max"]):
			total += int(w[k])
	if total <= 0:
		return ""
	var r := _rng.randi_range(0, total - 1)
	for k in w:
		if _count(String(SPECIES[k].get("grp", k))) >= int(SPECIES[k]["max"]):
			continue
		r -= int(w[k])
		if r < 0:
			return String(k)
	return ""


func _try_spawn() -> void:
	var pp := _player.global_position
	# 겨울 한강 오리 떼: 강이 가까우면 물 위에 먼저 시도한다
	if Season.cold > 0.4 and pp.z > 200.0 and HanyangMap.river_dist(pp.x, pp.z) < 130.0 and _count("duck") < 6 and _rng.randf() < 0.5:
		var dx := pp.x + _rng.randf_range(-60.0, 60.0)
		var dz := HanyangMap.river_z(dx) + _rng.randf_range(-10.0, 10.0)
		if is_water(dx, dz) and Vector2(dx - pp.x, dz - pp.z).length() > 14.0:
			_spawn_flock("duck", dx, dz)
			return
	for _i in 4:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var x := pp.x + cos(a) * d
		var z := pp.z + sin(a) * d
		if is_water(x, z):
			continue
		var sp := _pick_species(x, z)
		if sp == "":
			continue
		_spawn_flock(sp, x, z)
		return


func _spawn_flock(sp: String, x: float, z: float) -> void:
	var fk := Flock.new()
	var list: Array = []   # [종류, 흩어짐]
	match sp:
		"sparrow":
			for i in _rng.randi_range(3, 7):
				list.append("sparrow")
		"pigeon":
			for i in _rng.randi_range(2, 5):
				list.append("pigeon")
		"crow":
			for i in _rng.randi_range(1, 4):
				list.append("crow")
		"magpie":
			for i in _rng.randi_range(1, 2):
				list.append("magpie")
		"pheasant":
			list.append("pheasant")
			for i in _rng.randi_range(1, 2):
				list.append("hen_pheasant")
		"duck":
			for i in _rng.randi_range(3, 8):
				list.append("duck" if _rng.randf() < 0.5 else "hen_duck")
		_:
			list.append(sp)
	var water := is_water(x, z)
	for s in list:
		var bx := x + _rng.randf_range(-2.2, 2.2)
		var bz := z + _rng.randf_range(-2.2, 2.2)
		if water != is_water(bx, bz):
			bx = x
			bz = z
		var b := Bird.new()
		b.setup(self, String(s), _rng.randi())
		b.flock = fk
		fk.members.append(b)
		add_child(b)
		b.global_position = Vector3(bx, floor_y(bx, bz), bz)
		b.home = b.global_position
		_birds.append(b)
		if water:
			b.start_swim()
		elif bool(b.d["perch"]) and _rng.randf() < 0.3:
			var p := find_perch(b.global_position, Vector2.ZERO, false)
			if p.size() > 0:
				b.start_perch(p[0])


## 앉을 곳(나무 꼭대기나 지붕 마루)을 찾는다. 없으면 빈 배열. away 가 있으면 그쪽 방향을 우선한다.
func find_perch(pos: Vector3, away: Vector2, scared: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	for _i in 3:
		var ang := _rng.randf() * TAU
		if scared and away.length() > 0.01:
			ang = atan2(away.x, away.y) + _rng.randf_range(-1.0, 1.0)
		var probe := pos + Vector3(sin(ang), 0.0, cos(ang)) * _rng.randf_range(10.0, 34.0)
		# 지붕
		var hp := HanyangCity.house_points
		var best := -1
		var best_d := 16.0
		for i in hp.size():
			var dd := Vector2(hp[i].x - probe.x, hp[i].y - probe.z).length()
			if dd < best_d:
				best_d = dd
				best = i
		if best >= 0 and _rng.randf() < 0.6:
			var hx := hp[best].x
			var hz := hp[best].y - 4.0
			out.append(Vector3(hx + _rng.randf_range(-1.6, 1.6), HanyangMap.surface(hx, hz) + ROOF_UP, hz + _rng.randf_range(-0.8, 0.8)))
			return out
		# 나무
		var cm := _chunks()
		if cm != null:
			var e := cm.nearest_tree(probe, 14.0)
			if not e.is_empty():
				var ch: Node3D = e["chunk"]
				var xf: Transform3D = e["xf"]
				var o: Vector3 = ch.position + xf.origin
				var s := xf.basis.get_scale().y
				out.append(Vector3(o.x + _rng.randf_range(-0.4, 0.4), o.y + TREE_PERCH * s, o.z + _rng.randf_range(-0.4, 0.4)))
				return out
	return out


## 한 마리가 놀라 날아오르면 같은 무리가 곧 따라 난다
func alarm(from_bird: Bird, dir: Vector2, scared: bool) -> void:
	if from_bird.flock == null:
		return
	for m in from_bird.flock.members:
		if not is_instance_valid(m):
			continue
		var b := m as Bird
		if b == null or b == from_bird or b.dead:
			continue
		if b.state == Bird.S.GROUND or b.state == Bird.S.PERCH or b.state == Bird.S.SWIM:
			b.pending = _rng.randf_range(0.05, 0.5)
			b.pend_dir = dir
			b.pend_scared = scared


## 새가 화살에 맞아 땅이나 물에 떨어졌다: 고기와 깃털을 남긴다
func on_bird_killed(b: Bird) -> void:
	var d: Dictionary = b.d
	var nm := String(d["name"])
	var meat := String(d["meat"])
	var p := b.global_position
	var fy := floor_y(p.x, p.z)
	_sv.add_bird_drops(p, meat, int(d["feathers"]), d["fcol"], fy)
	if bool(d.get("omen", false)):
		_sv.reward_kill(-4.0)
		_hud.toast("까치를 맞혔다. 길조를 해쳐 마음이 가라앉는다. 깃털만 줍자.", 3.5, "deny")
	elif meat == "":
		_hud.toast("%s%s 잡았다. 먹을 만한 살은 없다. 깃털만 줍자." % [nm, Items.eul(nm)], 3.0, "done")
	else:
		_hud.toast("%s%s 잡았다! 곁의 고기와 깃털을 G 로 줍자." % [nm, Items.eul(nm)], 3.0, "done")


## 새 한 마리 (모양을 만들고, 걷기·날기·앉기·헤엄치기·떨어지기를 한다)
class Bird extends Node3D:
	enum S { GROUND, FLY, PERCH, SWIM, DEAD }
	var mgr: Birds
	var sp := ""
	var d: Dictionary
	var flock: Flock
	var state := S.GROUND
	var home := Vector3.ZERO
	var dead := false
	var pending := -1.0
	var pend_dir := Vector2.ZERO
	var pend_scared := false
	var _rng := RandomNumberGenerator.new()
	var _t := 0.0
	var _idle := 1.0
	var _target := Vector2.ZERO
	var _moving := false
	var _heading := 0.0
	var _fly_t := 0.0
	var _alt := 6.0
	var _turn := 0.0
	var _turn_t := 0.0
	var _vy := 0.0
	var _dest := Vector3.ZERO
	var _to_perch := false
	var _perch_t := 0.0
	var _wl: Node3D
	var _wr: Node3D
	var _head: Node3D
	var _head_z0 := 0.0
	var _len := 0.3

	func setup(m: Birds, species: String, seed_i: int) -> void:
		mgr = m
		sp = species
		d = Birds.SPECIES[species]
		_len = float(d["len"])
		_rng.seed = seed_i
		_t = _rng.randf() * 10.0
		_idle = _rng.randf_range(float(d["idle"][0]) * 0.3, float(d["idle"][1]))
		_heading = _rng.randf() * TAU
		_build()
		_fold(true)

	func _ready() -> void:
		add_to_group("bird")
		rotation.y = _heading

	func arrow_center() -> Vector3:
		return global_position + Vector3(0.0, float(d["leg"]) * _len + 0.25 * _len + float(d["neck"]) * _len * 0.3, 0.0)

	func arrow_radius() -> float:
		return maxf(0.3, 0.9 * _len)

	func start_swim() -> void:
		state = S.SWIM
		global_position.y = HanyangMap.RIVER_LEVEL

	func start_perch(p: Vector3) -> void:
		state = S.PERCH
		global_position = p
		_perch_t = _rng.randf_range(6.0, 22.0)

	# --- 모양 ---

	func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = Birds.mat(col)
		mi.position = pos
		mi.scale = scl
		parent.add_child(mi)
		return mi

	func _ball(parent: Node3D, col: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
		var sp_m := SphereMesh.new()
		sp_m.radius = 0.5
		sp_m.height = 1.0
		sp_m.radial_segments = 8
		sp_m.rings = 4
		return _part(parent, sp_m, col, pos, scl)

	func _box(parent: Node3D, col: Color, pos: Vector3, size: Vector3) -> MeshInstance3D:
		var bm := BoxMesh.new()
		bm.size = size
		return _part(parent, bm, col, pos)

	func _build() -> void:
		var L := _len
		var leg := float(d["leg"]) * L
		var neck := float(d["neck"]) * L
		var by := leg + 0.22 * L
		var leg_col := Color(0.55, 0.42, 0.3)
		if sp == "duck" or sp == "hen_duck":
			leg_col = Color(0.9, 0.55, 0.15)
		elif sp == "heron":
			leg_col = Color(0.2, 0.18, 0.15)
		elif sp == "crow" or sp == "magpie":
			leg_col = Color(0.1, 0.1, 0.1)
		for sx in [-1.0, 1.0]:
			var s: float = sx
			var cm := CylinderMesh.new()
			cm.top_radius = 0.012 * maxf(L, 0.2)
			cm.bottom_radius = 0.01 * maxf(L, 0.2)
			cm.height = leg
			cm.radial_segments = 4
			_part(self, cm, leg_col, Vector3(s * 0.12 * L, leg * 0.5, 0.0))
		_ball(self, d["back"], Vector3(0.0, by + 0.04 * L, 0.0), Vector3(0.5 * L, 0.44 * L, 1.0 * L))
		_ball(self, d["belly"], Vector3(0.0, by - 0.06 * L, 0.06 * L), Vector3(0.44 * L, 0.34 * L, 0.8 * L))
		# 목과 머리
		var head_y := by + 0.2 * L + neck * 0.8
		var head_z := 0.5 * L + neck * 0.15
		if neck > 0.0:
			var nm := CylinderMesh.new()
			nm.top_radius = 0.05 * L
			nm.bottom_radius = 0.08 * L
			nm.height = neck * 0.9
			nm.radial_segments = 6
			var nmi := _part(self, nm, d["head"], Vector3(0.0, by + 0.2 * L + neck * 0.45, 0.42 * L + neck * 0.08))
			nmi.rotation.x = 0.18
		_head = Node3D.new()
		_head.position = Vector3(0.0, head_y, head_z)
		_head_z0 = head_z
		add_child(_head)
		_ball(_head, d["head"], Vector3(0.0, 0.1 * L, 0.04 * L), Vector3(0.3 * L, 0.3 * L, 0.34 * L))
		var bk := CylinderMesh.new()
		bk.top_radius = 0.0
		bk.bottom_radius = (0.06 if sp != "duck" and sp != "hen_duck" else 0.09) * L
		bk.height = 0.17 * L * float(d["beak"])
		bk.radial_segments = 6
		var bm := _part(_head, bk, d["beak_c"], Vector3(0.0, 0.08 * L, 0.2 * L + bk.height * 0.5))
		bm.rotation.x = PI * 0.5
		if sp == "duck" or sp == "hen_duck":
			bm.scale = Vector3(1.4, 1.0, 0.6)
		if sp == "duck":
			_ball(_head, Color(0.95, 0.95, 0.95), Vector3(0.0, -0.06 * L, -0.06 * L), Vector3(0.22 * L, 0.05 * L, 0.22 * L))
		if sp == "pheasant":
			_ball(_head, Color(0.75, 0.1, 0.1), Vector3(0.0, 0.1 * L, 0.12 * L), Vector3(0.32 * L, 0.2 * L, 0.2 * L))
			_ball(_head, Color(0.95, 0.95, 0.92), Vector3(0.0, -0.1 * L, -0.02 * L), Vector3(0.28 * L, 0.06 * L, 0.28 * L))
		if sp == "magpie":
			_ball(self, d["belly"], Vector3(0.0, by + 0.18 * L, 0.18 * L), Vector3(0.46 * L, 0.2 * L, 0.5 * L))
		var tl := float(d["tail"]) * L
		_box(self, d["tailc"], Vector3(0.0, by + 0.07 * L, -0.5 * L - tl * 0.5), Vector3(0.22 * L, 0.03 * L, tl))
		_wl = Node3D.new()
		_wl.position = Vector3(0.22 * L, by + 0.14 * L, 0.1 * L)
		add_child(_wl)
		_wr = Node3D.new()
		_wr.position = Vector3(-0.22 * L, by + 0.14 * L, 0.1 * L)
		add_child(_wr)
		_box(_wl, d["wing"], Vector3(0.45 * L, 0.0, 0.0), Vector3(0.9 * L, 0.03 * L, 0.55 * L))
		_box(_wr, d["wing"], Vector3(-0.45 * L, 0.0, 0.0), Vector3(0.9 * L, 0.03 * L, 0.55 * L))

	func _fold(on: bool) -> void:
		if on:
			_wl.rotation.z = -1.35
			_wr.rotation.z = 1.35

	# --- 움직임 ---

	func _process(delta: float) -> void:
		if mgr == null or mgr._player == null:
			return
		_t += delta
		if pending >= 0.0:
			pending -= delta
			if pending < 0.0 and state != S.DEAD and not dead:
				_take_off(pend_dir, pend_scared, true, true)
		match state:
			S.GROUND:
				_ground(delta)
			S.FLY:
				_fly(delta)
			S.PERCH:
				_perch(delta)
			S.SWIM:
				_swim(delta)
			S.DEAD:
				_fall(delta)

	func _player_dist() -> Vector3:
		var pp := mgr._player.global_position
		return Vector3(global_position.x - pp.x, 0.0, global_position.z - pp.z)

	func _ground(delta: float) -> void:
		var pd := _player_dist()
		var dist := Vector2(pd.x, pd.z).length()
		var scare := float(d["scare"])
		if dist < scare:
			_take_off(Vector2(pd.x, pd.z), true, false, true)
			return
		var alert := float(d["alert"])
		var frozen := alert > 0.0 and dist < alert
		if not frozen and _rng.randf() < float(d["rate"]) * delta:
			_take_off(Vector2.from_angle(_rng.randf() * TAU), false, false, true)
			return
		_idle -= delta
		if frozen:
			# 가까이 오면 웅크려 얼어붙어 살핀다
			_moving = false
			_idle = maxf(_idle, 0.5)
			_head.rotation.x = -0.25
			global_position.y = Birds.floor_y(global_position.x, global_position.z)
		elif _moving:
			var pos2 := Vector2(global_position.x, global_position.z)
			var to := _target - pos2
			if to.length() < 0.15:
				_moving = false
				_idle = _rng.randf_range(float(d["idle"][0]), float(d["idle"][1]))
			else:
				var dir := to.normalized()
				var spd := float(d["walk"]) * (1.7 if sp == "sparrow" else 1.0)
				var np := pos2 + dir * spd * delta
				if Birds.is_water(np.x, np.y) and sp != "duck" and sp != "hen_duck":
					_moving = false
				else:
					var ny := HanyangMap.surface(np.x, np.y)
					var hop := absf(sin(_t * 12.0)) * 0.24 * _len if sp == "sparrow" else 0.0
					global_position = Vector3(np.x, ny + hop, np.y)
					_heading = atan2(dir.x, dir.y)
			_head.rotation.x = 0.0
			# 비둘기·까치·까마귀는 걸을 때 고개를 앞뒤로 끄덕인다
			if sp == "pigeon" or sp == "magpie" or sp == "crow":
				_head.position.z = _head_z0 + sin(_t * 11.0) * 0.07 * _len
		else:
			global_position.y = Birds.floor_y(global_position.x, global_position.z)
			# 모이를 쪼는 시늉: 고개를 까딱인다 (백로는 꼿꼿이 서서 물속을 노린다)
			if sp == "heron":
				_head.rotation.x = 0.0
			else:
				_head.rotation.x = maxf(0.0, sin(_t * 9.0)) * 0.7 if int(_t * 0.5) % 3 == 0 else 0.0
			if _idle <= 0.0:
				var a := _rng.randf() * TAU
				_target = Vector2(home.x, home.z) + Vector2(cos(a), sin(a)) * _rng.randf_range(0.8, 3.5 if sp != "heron" else 2.0)
				_moving = true
		rotation.y = lerp_angle(rotation.y, _heading, clampf(8.0 * delta, 0.0, 1.0))

	func _take_off(away: Vector2, scared: bool, from_flock: bool, allow_perch: bool) -> void:
		state = S.FLY
		_moving = false
		_to_perch = false
		_head.rotation.x = 0.0
		_head.position.z = _head_z0
		var a := away.normalized() if away.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
		_heading = atan2(a.x, a.y) + _rng.randf_range(-0.45, 0.45)
		_fly_t = _rng.randf_range(8.0, 16.0) if scared else _rng.randf_range(10.0, 22.0)
		_alt = _rng.randf_range(5.0, 11.0)
		match sp:
			"sparrow":
				_fly_t = _rng.randf_range(3.0, 7.0)   # 참새는 낮게 짧게 옮겨 앉는다
				_alt = _rng.randf_range(1.5, 4.0)
			"pheasant", "hen_pheasant":
				_fly_t = _rng.randf_range(3.5, 6.0)   # 꿩은 푸드덕 날았다가 멀지 않은 곳에 내려앉는다
				_alt = _rng.randf_range(2.5, 4.5)
			"heron":
				_alt = _rng.randf_range(3.0, 7.0)
				_fly_t = _rng.randf_range(10.0, 20.0)
		_turn = 0.0
		_turn_t = 0.0
		if bool(d["perch"]) and allow_perch and _rng.randf() < (0.8 if scared else 0.55):
			var p := mgr.find_perch(global_position, a, scared)
			if p.size() > 0:
				_dest = p[0]
				_to_perch = true
				_fly_t = 25.0
		if not from_flock and flock != null:
			mgr.alarm(self, a, scared)

	func _fly(delta: float) -> void:
		_fly_t -= delta
		var spd := float(d["fly"])
		var cx := global_position.x
		var cz := global_position.z
		if _to_perch:
			var to := Vector2(_dest.x - cx, _dest.z - cz)
			var hd := to.length()
			if hd > 0.3:
				_heading = lerp_angle(_heading, atan2(to.x, to.y), clampf(5.0 * delta, 0.0, 1.0))
			if hd < 5.0:
				spd *= 0.5
			var want_y := _dest.y if hd < 7.0 else maxf(_dest.y + 2.5, Birds.floor_y(cx, cz) + 3.5)
			var step_dir := Vector2(sin(_heading), cos(_heading))
			var gx2 := cx + step_dir.x * spd * delta
			var gz2 := cz + step_dir.y * spd * delta
			var ny2 := move_toward(global_position.y, want_y, 4.5 * delta)
			global_position = Vector3(gx2, ny2, gz2)
			rotation.y = lerp_angle(rotation.y, _heading, clampf(6.0 * delta, 0.0, 1.0))
			_flap(delta)
			if hd < 0.8 and absf(ny2 - _dest.y) < 0.9:
				start_perch(_dest)
				rotation.x = 0.0
				_fold(true)
			elif _fly_t <= 0.0:
				_to_perch = false
				_fly_t = 3.0
			return
		_turn_t -= delta
		if _turn_t <= 0.0:
			_turn_t = _rng.randf_range(1.0, 2.2)
			_turn = _rng.randf_range(-0.45, 0.45)
		_heading += _turn * delta
		# 오리는 강을 따라 날고, 백로도 강 쪽으로 이끌린다
		if sp == "duck" or sp == "hen_duck" or sp == "heron":
			var off := HanyangMap.river_z(cx) - cz
			var along := 1.0 if sin(_heading) >= 0.0 else -1.0
			var pull := 0.9 if sp != "heron" else 0.3
			_heading = lerp_angle(_heading, atan2(along, clampf(off * 0.05, -1.0, 1.0)), clampf(pull * delta, 0.0, 1.0))
		var dir := Vector2(sin(_heading), cos(_heading))
		var gx := cx + dir.x * spd * delta
		var gz := cz + dir.y * spd * delta
		var ground := Birds.floor_y(gx, gz)
		var want := ground + (_alt if _fly_t > 0.0 else 0.0)
		var rate := 4.5 if want > global_position.y else 3.0
		var ny := move_toward(global_position.y, want, rate * delta)
		global_position = Vector3(gx, maxf(ny, ground), gz)
		rotation.y = lerp_angle(rotation.y, _heading, clampf(6.0 * delta, 0.0, 1.0))
		rotation.x = lerpf(rotation.x, -0.25 if want > ny + 0.2 else (0.2 if want < ny - 0.2 else 0.0), clampf(4.0 * delta, 0.0, 1.0))
		_flap(delta)
		if _fly_t <= 0.0 and ny <= ground + 0.05:
			var wet := Birds.is_water(gx, gz) or (gz > 150.0 and HanyangMap.surface(gx, gz) < HanyangMap.RIVER_LEVEL + 0.05)
			rotation.x = 0.0
			if wet and (sp == "duck" or sp == "hen_duck"):
				state = S.SWIM
				_idle = _rng.randf_range(2.0, 6.0)
				_fold(true)
			elif wet:
				_fly_t = 2.5   # 물 위에는 앉지 못하니 조금 더 난다
			else:
				state = S.GROUND
				home = global_position
				_idle = _rng.randf_range(0.5, 3.0)
				_fold(true)

	func _flap(_delta: float) -> void:
		var fr := 22.0 if sp == "sparrow" else (16.0 if _len < 0.4 else (6.0 if sp == "heron" else 10.0))
		var flap := sin(_t * fr)
		_wl.rotation.z = flap * 0.9
		_wr.rotation.z = -flap * 0.9

	func _perch(delta: float) -> void:
		var pd := _player_dist()
		var dist := Vector2(pd.x, pd.z).length()
		_perch_t -= delta
		# 앉은 새는 땅의 새보다 조금 덜 놀란다
		if dist < float(d["scare"]) * 0.7:
			_take_off(Vector2(pd.x, pd.z), true, false, true)
			return
		if _perch_t <= 0.0:
			_take_off(Vector2.from_angle(_rng.randf() * TAU), false, false, _rng.randf() < 0.5)
			return
		# 가끔 고개를 돌리고 꼬리를 까딱인다
		_head.rotation.y = sin(_t * 1.3 + float(get_instance_id() % 7)) * 0.8
		rotation.y = lerp_angle(rotation.y, _heading, clampf(4.0 * delta, 0.0, 1.0))

	func _swim(delta: float) -> void:
		var pd := _player_dist()
		var dist := Vector2(pd.x, pd.z).length()
		if dist < float(d["scare"]):
			_take_off(Vector2(pd.x, pd.z), true, false, true)
			return
		if _rng.randf() < float(d["rate"]) * delta:
			_take_off(Vector2.from_angle(_rng.randf() * TAU), false, false, true)
			return
		_idle -= delta
		if _idle <= 0.0:
			_idle = _rng.randf_range(float(d["idle"][0]), float(d["idle"][1]))
			_turn = _rng.randf_range(-0.6, 0.6)
		_heading += _turn * delta * 0.4
		var dir := Vector2(sin(_heading), cos(_heading))
		var np := Vector2(global_position.x, global_position.z) + dir * 0.45 * delta
		if Birds.is_water(np.x, np.y):
			global_position = Vector3(np.x, HanyangMap.RIVER_LEVEL + sin(_t * 1.5) * 0.02, np.y)
		else:
			_heading += PI * 0.7   # 물가에 닿으면 돌아선다
		# 이따금 물속으로 머리를 박는다
		rotation.x = 0.8 if int(_t * 0.4 + float(get_instance_id() % 5)) % 6 == 0 else 0.0
		rotation.y = lerp_angle(rotation.y, _heading, clampf(3.0 * delta, 0.0, 1.0))

	## 화살에 맞았다
	func arrow_hit(_pos: Vector3, _dir: Vector3) -> void:
		if dead:
			return
		dead = true
		remove_from_group("bird")
		if state == S.GROUND or state == S.SWIM:
			_finish()
			return
		state = S.DEAD
		_vy = 0.0

	func _fall(delta: float) -> void:
		_vy -= 16.0 * delta
		global_position.y += _vy * delta
		rotation.z += 7.0 * delta
		var g := Birds.floor_y(global_position.x, global_position.z)
		if global_position.y <= g:
			global_position.y = g
			_finish()

	func _finish() -> void:
		if mgr != null:
			mgr.on_bird_killed(self)
		queue_free()
