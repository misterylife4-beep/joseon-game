class_name Discovery
extends Node
## 거점 발견. 나루터, 마을, 고개, 경복궁 앞에 가까이 가면 "발견"으로 기록하고 알려 준다.
## 발견한 거점은 지도(M, 지역도)에서 붉은 깃발을 눌러 바로 이동할 수 있다. 기록은 user://discovered.cfg 에 저장한다(새로 시작하면 지워진다).
## 발견 거리와 이동 자리는 설계값이다. 마을과 고개는 길 위(비어 있는 자리)로 내려선다.

const SAVE_PATH := "user://discovered.cfg"

static var found: Dictionary = {}
static var _loaded := false
static var _places: Array[Dictionary] = []

var _player: Player
var _hud: SurvivalHud
var _timer := 1.0


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for k in cf.get_section_keys("found"):
			found[k] = true


static func _save() -> void:
	var cf := ConfigFile.new()
	for k in found.keys():
		cf.set_value("found", String(k), true)
	cf.save(SAVE_PATH)


static func reset() -> void:
	found.clear()
	_loaded = true
	_save()


static func is_found(id: String) -> bool:
	_ensure()
	return found.has(id)


static func mark(id: String) -> void:
	_ensure()
	if not found.has(id):
		found[id] = true
		_save()


static func _nearest_road(c: Vector2) -> Vector2:
	var best := c
	var best_d := INF
	for p in Region.road_points():
		var d := p.distance_to(c)
		if d < best_d:
			best_d = d
			best = p
	return best


## 모든 거점. id, name, c(발견 중심), r(발견 거리), dest(이동해 서는 자리), yaw(서서 바라볼 방향)
static func places() -> Array[Dictionary]:
	if not _places.is_empty():
		return _places
	for fy in HanRiver.FERRIES:
		var fx := float(fy["x"])
		var rz := HanyangMap.river_z(fx)
		_places.append({"id": "ferry_" + String(fy["name"]), "name": String(fy["name"]) + " 나루터",
			"c": Vector2(fx, rz - 40.0), "r": 60.0, "dest": Vector2(fx + 4.0, rz - 47.0), "yaw": PI})
	var ls := Region.landing_south()
	_places.append({"id": "jetty_s", "name": "광나루 남쪽 나루터", "c": ls, "r": 60.0, "dest": ls + Vector2(0.0, 8.0), "yaw": PI})
	for tn in Region.towns():
		var rp := _nearest_road(tn["c"] as Vector2)
		_places.append({"id": String(tn["id"]), "name": String(tn["name"]), "c": rp, "r": 80.0, "dest": rp, "yaw": PI})
	var dp := _nearest_road(Vector2(660.0, 1370.0))
	_places.append({"id": "dalnae", "name": "달래내 고개", "c": dp, "r": 110.0, "dest": dp, "yaw": PI})
	_places.append({"id": "palace", "name": "경복궁 앞", "c": HanyangMap.PALACE_C, "r": 90.0,
		"dest": HanyangMap.PALACE_C + Vector2(0.0, HanyangMap.PALACE_HALF.y + 14.0), "yaw": 0.0})
	return _places


static func place(id: String) -> Dictionary:
	for p in places():
		if String(p["id"]) == id:
			return p
	return {}


static func count_found() -> int:
	var n := 0
	for p in places():
		if is_found(String(p["id"])):
			n += 1
	return n


func setup(player: Player, hud: SurvivalHud) -> void:
	_player = player
	_hud = hud


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	for p in places():
		var id := String(p["id"])
		if is_found(id):
			continue
		if pp.distance_to(p["c"] as Vector2) < float(p["r"]):
			mark(id)
			_hud.toast("새 거점을 발견했다: %s. 지도(M)에서 눌러 바로 갈 수 있다." % String(p["name"]), 5.0, "gong")
