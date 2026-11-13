class_name Survival
extends Node
## 조선 생존 모드. 허기·체온·기력·건강·마음 다섯 수치와 땔감·곡식 줍기, 모닥불, 식사를 맡는다.
## 모든 수치·속도·범위는 설계값이다(docs/고증_근거.md 참고, 기획서 '생존 시스템').
## 계절·밤·비는 기존 Season, DayNight 정적 값을 읽어 체온에 반영한다.

const CELL := 64.0
const LOAD_RADIUS := 110.0
const PICK_RANGE := 2.6
const FIRE_RANGE := 5.5
const FIRE_BURN := 240.0
const REGROW := 300.0

var hunger := 80.0
var warmth := 85.0
var _was_wet := false
var stamina := 100.0
var health := 100.0
var morale := 70.0
var firewood := 0
## 가방: 먹거리 종류별 개수, 먹은 기록
var items: Dictionary = {}
var eaten: Dictionary = {}
## 모닥불에서 익힌 음식 개수 (id별)
var cooked: Dictionary = {}
## 지금 익히는 중인 일: id, n, total, left, fire, rig, paused (없으면 빈 사전)
var cook_job: Dictionary = {}
var picked_total := 0
var selected := ""  ## 가방에서 고른 것 (R로 먹을 때 우선)
## 지닌 곡식·열매 전체 개수
var grain: int:
	get:
		var n := 0
		for k in items:
			n += int(items[k])
		for k in cooked:
			n += int(cooked[k])
		return n

signal bag_changed
signal cook_changed

var _player: Player
var _hud: SurvivalHud
var _home: Vector3
var _walk_speed := 5.0
var _sprint_speed := 8.0
var _exhausted := false
var _cells: Dictionary = {}
var _picks: Array[Dictionary] = []
## 큰 바위: node, hp, on(남아 있나), left(다시 생기기까지 초)
var boulders: Array[Dictionary] = []
## 연장·돌·무기를 맡는 상자(main.gd 가 넣어 준다)
var gear: Gear
var _fires: Array[Dictionary] = []
var _cell_timer := 0.0
var _last_warn := ""


func setup(player: Player, hud: SurvivalHud) -> void:
	_player = player
	_hud = hud
	_home = player.position
	_walk_speed = player.walk_speed
	_sprint_speed = player.sprint_speed
	_add_key("forage", KEY_G)
	_add_key("make_fire", KEY_F)
	_add_key("eat", KEY_R)
	_hud.toast("추운 정월이다. 땔감을 모아 불을 피우고, 곡식을 구해 끼니를 챙기자.", 6.0)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	if _player == null:
		return
	_cell_timer -= delta
	if _cell_timer <= 0.0:
		_cell_timer = 1.0
		_load_cells()
	_update_pick_regrow(delta)
	_update_fires(delta)
	_update_cook(delta)
	_update_stats(delta)
	_handle_input()
	_update_hud()


# --- 수치 ---

func near_fire() -> bool:
	for f in _fires:
		var n: Node3D = f["node"]
		if n.global_position.distance_to(_player.global_position) < FIRE_RANGE:
			return true
	return false


func _update_stats(delta: float) -> void:
	var fire := near_fire()
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var sprinting := Input.is_action_pressed("sprint") and speed > _walk_speed + 0.5

	# 체온: 계절 추위, 밤, 비가 목표 체온을 낮추고 불 곁에서는 따뜻하다
	var cres := gear.cold_resist() if gear != null else 0.0
	var ambient := 1.0 - (Season.cold * 0.85 + DayNight.night_amount * 0.2 + DayNight.rain_amount * 0.15) * (1.0 - cres)
	var target := clampf(ambient, 0.0, 1.0) * 100.0
	if fire:
		target = maxf(target, 92.0)
	if _player.swimming:
		target = minf(target, 28.0)  # 물에 젖으면 체온이 빠르게 내려간다
	# 옷이 젖은 채로는 체온이 조금 더 빨리, 조금 더 낮게 식는다 (헤엄이나 개천을 건넌 뒤. 수치는 설계값)
	var wet: float = _player.wetness
	if wet > 0.0:
		target = maxf(target - wet * 10.0, 0.0)
		if fire:
			_player.wetness = move_toward(wet, 0.0, 0.08 * delta)  # 불을 쬐면 빨리 마른다
	var rate := 4.0 if target > warmth else 0.5 * (1.0 + Season.cold) * (1.0 + 0.8 * wet)
	if wet > 0.3 and not _was_wet:
		_was_wet = true
		_hud.toast("옷이 물에 젖었다. 몸이 더 빨리 식는다.", 3.0)
	elif wet < 0.02 and _was_wet:
		_was_wet = false
		_hud.toast("젖은 옷이 말랐다.", 2.5)
	warmth = move_toward(warmth, target, rate * delta)

	# 허기
	var drain := 0.28
	if sprinting or _player.swimming:
		drain += 0.25
	hunger = maxf(0.0, hunger - drain * delta)

	# 기력: 달리면 줄고(초당 7, 약 14초 달릴 수 있다) 쉬면 찬다. 바닥나면 25까지 차기 전에는 달릴 수 없다
	if sprinting and not _exhausted:
		stamina = maxf(0.0, stamina - 7.0 * (1.0 - (gear.stam_save() if gear != null else 0.0)) * delta)
		if stamina <= 0.0:
			_exhausted = true
			_hud.toast("숨이 차서 더는 달릴 수 없다.", 2.5)
	else:
		var regen := 10.0 if hunger > 20.0 else 5.0
		stamina = minf(100.0, stamina + regen * delta)
		if _exhausted and stamina > 25.0:
			_exhausted = false
	_player.sprint_speed = _walk_speed if _exhausted else _sprint_speed

	# 건강: 굶거나 얼면 닳고, 배부르고 따뜻하면 천천히 낫는다
	var loss := 0.0
	if hunger <= 0.0:
		loss += 1.5
	if warmth < 20.0:
		loss += (20.0 - warmth) * 0.08
	if loss > 0.0:
		health -= loss * delta
	elif hunger > 40.0 and warmth > 50.0:
		health = minf(100.0, health + 1.0 * delta)

	# 마음
	var mtarget := 60.0
	if fire:
		mtarget += 20.0
	mtarget -= DayNight.night_amount * 15.0 + Season.cold * 20.0
	if hunger < 25.0:
		mtarget -= 30.0
	if gear != null:
		mtarget += gear.morale_bonus()
	morale = move_toward(morale, clampf(mtarget, 0.0, 100.0), 1.0 * delta)

	_warn()
	if health <= 0.0:
		_die()


## 짐승·사람에게 입은 상처. 체력과 마음이 함께 깎인다.
func hurt(amount_raw: float, msg := "") -> void:
	var amount := amount_raw * (1.0 - (gear.dmg_cut() if gear != null else 0.0))
	health = maxf(health - amount, 0.0)
	morale = maxf(morale - amount * 0.6, 0.0)
	if msg != "":
		_hud.toast(msg, 3.0)


func _warn() -> void:
	var w := ""
	if warmth < 20.0:
		w = "몸이 얼어붙는다. 불을 찾아야 한다."
	elif hunger < 15.0:
		w = "배가 너무 고프다. 먹을 것을 구해야 한다."
	if w != "" and w != _last_warn:
		_hud.toast(w, 3.5)
	_last_warn = w


func _die() -> void:
	# 쓰러져도 연장·옷·돌·가죽은 그대로 지닌다. 땔감은 절반, 먹거리는 3분의 1만 잃는다. [설계]
	_hud.toast("쓰러졌다. 눈을 뜨니 막사 곁이다. 땔감과 먹거리를 일부 잃었다.", 6.0)
	hunger = 60.0
	warmth = 60.0
	stamina = 60.0
	health = 60.0
	morale = 40.0
	firewood = int(float(firewood) * 0.5)
	for store in [items, cooked]:
		for k in store.keys():
			var left := int(store[k]) - int(float(store[k]) / 3.0)
			if left <= 0:
				store.erase(k)
			else:
				store[k] = left
	selected = ""
	bag_changed.emit()
	_player.velocity = Vector3.ZERO
	_player.global_position = _home
	_last_warn = ""


# --- 입력 ---

func _handle_input() -> void:
	if _player.input_locked:
		return
	if Input.is_action_just_pressed("forage"):
		_forage()
	if Input.is_action_just_pressed("make_fire"):
		_make_fire()
	if Input.is_action_just_pressed("eat"):
		_eat()


func _nearest_pick() -> int:
	var best := -1
	var best_d := PICK_RANGE
	for i in _picks.size():
		var p: Dictionary = _picks[i]
		if not bool(p["on"]):
			continue
		var n: Node3D = p["node"]
		if not is_instance_valid(n):
			continue
		var d := n.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = i
	return best


func _forage() -> void:
	var i := _nearest_pick()
	if i < 0:
		_hud.toast("주울 것이 없다.", 1.5, "deny")
		return
	var p: Dictionary = _picks[i]
	var kind: String = p["kind"]
	if kind == "meat" or kind == "hide" or kind == "arrow" or (kind == "feather" and bool(p.get("drop", false))):
		var it: String = String(p.get("item", ""))
		var cnt := int(p.get("n", 1))
		if kind == "arrow":
			if gear != null:
				gear.add_arrows(cnt)
			_hud.toast("화살을 주웠다. (지닌 화살 %d발)" % (gear.arrows if gear != null else cnt), 1.8, "pick")
		elif kind == "feather":
			if gear != null:
				gear.add_feather(cnt)
			_hud.toast("깃털 %d개를 주웠다." % cnt, 1.8, "pick")
		elif kind == "meat":
			items[it] = int(items.get(it, 0)) + cnt
			var mnm := String(Items.def(it)["name"])
			_hud.toast("%s %d점을 주웠다. 불에 구워 먹자." % [mnm, cnt], 2.4, "pick")
		elif gear != null:
			gear.add_hide(it, cnt)
			var tendon := 2 if it == "hide_tiger" else 1
			gear.add_sinew(tendon)
			_hud.toast("%s%s 주웠다. 힘줄도 얻었다. (+%d)" % [Gear.hide_name(it), Items.eul(Gear.hide_name(it)), tendon], 2.6, "pick")
		bag_changed.emit()
		(p["node"] as Node3D).queue_free()
		_picks.remove_at(i)
		stamina = maxf(0.0, stamina - 3.0)
		return
	if kind == "feather":
		var fn := 1 + (1 if randf() < 0.4 else 0)
		if gear != null:
			gear.add_feather(fn)
		_hud.toast("깃털을 주웠다. (+%d)" % fn, 1.6, "pick")
		bag_changed.emit()
	elif kind == "wood":
		firewood += 2
		_hud.toast("땔감을 주웠다. (+2)", 1.5, "pick")
	elif kind == "stone":
		var id: String = p["item"]
		var n2 := 1
		if gear != null:
			n2 = gear.add_stone(id)
		_hud.toast("%s을(를) 주웠다. (+%d)" % [Gear.stone_name(id), n2], 1.8, "pick")
		bag_changed.emit()
	else:
		var id: String = p["item"]
		var nm := String(Items.def(id)["name"])
		var more := 1
		if gear != null and gear.has_good("sack") and randf() < 0.5:
			more = 2   # 가죽 자루 덕에 하나 더 담았다
		items[id] = int(items.get(id, 0)) + more
		picked_total += 1
		_hud.toast("%s%s 주웠다. (+%d)" % [nm, Items.eul(nm), more], 1.8, "pick")
	bag_changed.emit()
	(p["node"] as Node3D).visible = false
	p["on"] = false
	p["left"] = REGROW
	stamina = maxf(0.0, stamina - 3.0)


func _make_fire() -> void:
	if firewood < 2:
		_hud.toast("땔감이 두 단 있어야 불을 피운다.", 2.0)
		return
	firewood -= 2
	var dir := Basis(Vector3.UP, _player._yaw) * Vector3(0.0, 0.0, -1.6)
	var pos := _player.global_position + dir
	pos.y = HanyangMap.height(pos.x, pos.z)
	var fire := _build_fire()
	fire.position = pos
	# 장작 타는 소리: 불 가까이에서만 들린다
	var crack := AudioStreamPlayer3D.new()
	crack.stream = UiSfx.stream("crackle")
	crack.unit_size = 4.0
	crack.max_distance = 40.0
	crack.volume_db = -14.0
	crack.autoplay = true
	fire.add_child(crack)
	get_parent().add_child(fire)
	_fires.append({"node": fire, "left": FIRE_BURN})
	_hud.toast("모닥불을 피웠다. 불가에서 C 로 요리할 수 있다.", 3.0, "flint")


func _eat() -> void:
	var id := best_food()
	if id == "":
		_hud.toast("먹을 것이 없다.", 1.5)
		return
	eat_item(id)


## 가방 열쇠(날것 id, 익힌 것 "c:id")로 지닌 개수
func count_of(key: String) -> int:
	var id := Items.key_id(key)
	return int((cooked if Items.key_cooked(key) else items).get(id, 0))


## R로 먹을 것: 가방에서 고른 것이 있으면 그것, 없으면 익힌 것 먼저, 그다음 날것 순서의 첫 번째
func best_food() -> String:
	if selected != "" and count_of(selected) > 0:
		return selected
	for id in Items.ORDER:
		if int(cooked.get(id, 0)) > 0:
			return "c:" + String(id)
	for id in Items.ORDER:
		if int(items.get(id, 0)) > 0:
			return id
	return ""


func eat_item(key: String) -> void:
	if count_of(key) < 1:
		return
	var id := Items.key_id(key)
	var is_cooked := Items.key_cooked(key)
	var d := Items.def(id)
	var store: Dictionary = cooked if is_cooked else items
	store[id] = int(store[id]) - 1
	if int(store[id]) <= 0:
		store.erase(id)
	eaten[id] = int(eaten.get(id, 0)) + 1
	if is_cooked:
		hunger = minf(100.0, hunger + float(d["cook"]))
		warmth = minf(100.0, warmth + (8.0 if near_fire() else 4.0))
		morale = minf(100.0, morale + float(d["morale"]))
		_hud.toast(String(d["cook_msg"]), 2.5, "munch")
	else:
		hunger = minf(100.0, hunger + float(d["raw"]))
		morale = maxf(0.0, morale - 2.0)
		var sting := float(d.get("sting", 0))
		if sting > 0.0:
			health = maxf(0.0, health - sting)
		_hud.toast(String(d["raw_msg"]), 2.5, "munch")
	bag_changed.emit()


# --- 요리 ---

## 가까이 있는 모닥불 (없으면 null)
func nearest_fire() -> Node3D:
	var best: Node3D = null
	var best_d := FIRE_RANGE
	for f in _fires:
		var n: Node3D = f["node"]
		var d := n.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func is_cooking() -> bool:
	return not cook_job.is_empty()


## 불가에서 날것 n개를 익히기 시작한다
func start_cook(id: String, n: int) -> bool:
	if is_cooking():
		_hud.toast("지금 다른 음식을 익히고 있다.", 2.0, "deny")
		return false
	var fire := nearest_fire()
	if fire == null:
		_hud.toast("모닥불 가까이에서만 요리할 수 있다.", 2.0, "deny")
		return false
	var have := int(items.get(id, 0))
	var cnt := clampi(n, 1, have)
	if cnt < 1:
		return false
	items[id] = have - cnt
	if int(items[id]) <= 0:
		items.erase(id)
	var rig := CookRig.new()
	rig.setup(id, cnt)
	fire.add_child(rig)
	var total := Items.batch_time(id, cnt)
	cook_job = {"id": id, "n": cnt, "total": total, "left": total, "fire": fire, "rig": rig, "paused": false}
	var nm := String(Items.def(id)["name"])
	var msg := ""
	match Items.cook_style(id):
		"roast":
			msg = "%s%s 잿불에 묻었다. 잘 익을 때까지 기다리자." % [nm, Items.eul(nm)]
		"skewer":
			msg = "%s%s 꼬치에 꿰어 불 위에 얹었다." % [nm, Items.eul(nm)]
		_:
			msg = "%s%s 솥에 안쳐 불에 올렸다." % [nm, Items.eul(nm)]
	_hud.toast(msg, 3.0, "cloth")
	bag_changed.emit()
	cook_changed.emit()
	return true


func cancel_cook(msg := "") -> void:
	if cook_job.is_empty():
		return
	var id: String = cook_job["id"]
	var n: int = cook_job["n"]
	items[id] = int(items.get(id, 0)) + n
	var rv: Variant = cook_job["rig"]
	if is_instance_valid(rv):
		(rv as CookRig).cancel()
	cook_job = {}
	if msg != "":
		_hud.toast(msg, 3.0, "deny")
	bag_changed.emit()
	cook_changed.emit()


func _fire_alive(fire: Node3D) -> bool:
	for f in _fires:
		if f["node"] == fire:
			return true
	return false


func _update_cook(delta: float) -> void:
	if cook_job.is_empty():
		return
	var fv: Variant = cook_job["fire"]
	if not is_instance_valid(fv) or not _fire_alive(fv as Node3D):
		cancel_cook("불이 꺼졌다. 덜 익은 음식을 도로 거두었다.")
		return
	var fire := fv as Node3D
	var rv: Variant = cook_job["rig"]
	var rig: CookRig = rv as CookRig if is_instance_valid(rv) else null
	var away := fire.global_position.distance_to(_player.global_position) > FIRE_RANGE + 3.0
	if away != bool(cook_job["paused"]):
		cook_job["paused"] = away
		if rig != null:
			rig.set_paused(away)
		if away:
			_hud.toast("불 곁을 떠나 익히는 일이 멈췄다.", 2.5, "none")
	if away:
		return
	cook_job["left"] = float(cook_job["left"]) - delta
	var total: float = cook_job["total"]
	var left: float = cook_job["left"]
	if rig != null:
		rig.set_progress(1.0 - left / total)
	if left <= 0.0:
		var id: String = cook_job["id"]
		var n: int = cook_job["n"]
		cooked[id] = int(cooked.get(id, 0)) + n
		if rig != null:
			rig.finish()
		cook_job = {}
		var nm := Items.cooked_name(id)
		_hud.toast("%s%s 다 익었다. 가방에서 꺼내 먹을 수 있다." % [nm, Items.eul(nm)], 3.5, "none")
		bag_changed.emit()
		cook_changed.emit()


# --- 모닥불 ---

func _build_fire() -> Node3D:
	return FireFx.new()


func _update_fires(delta: float) -> void:
	for i in range(_fires.size() - 1, -1, -1):
		var f: Dictionary = _fires[i]
		f["left"] = float(f["left"]) - delta
		var n: Node3D = f["node"]
		var left: float = f["left"]
		if left <= 0.0:
			n.queue_free()
			_fires.remove_at(i)
			continue
		# 꺼지기 전 30초 동안 불이 점점 잦아든다
		(n as FireFx).set_burn(clampf(left / 30.0, 0.0, 1.0))


# --- 줍기 ---

func _load_cells() -> void:
	var pc := Vector2(_player.global_position.x, _player.global_position.z)
	var r := int(ceilf(LOAD_RADIUS / CELL))
	var cx := int(floorf(pc.x / CELL))
	var cz := int(floorf(pc.y / CELL))
	for ix in range(cx - r, cx + r + 1):
		for iz in range(cz - r, cz + r + 1):
			var key := Vector2i(ix, iz)
			if _cells.has(key):
				continue
			_cells[key] = true
			_spawn_cell(ix, iz)
			_spawn_mountain(ix, iz)


func _spawn_cell(ix: int, iz: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(ix, iz)) + 1396
	var x0 := float(ix) * CELL
	var z0 := float(iz) * CELL
	for i in 3:
		var x := x0 + rng.randf() * CELL
		var z := z0 + rng.randf() * CELL
		var h := HanyangMap.height(x, z)
		if h < -4.0 or _near_house(x, z, 5.0):
			continue
		_add_pick("wood", Vector3(x, h, z))
	# 들과 마을 가장자리에 떨어진 깃털 (새가 많은 곳일수록 흔하다)
	for i in 3:
		var ffx := x0 + rng.randf() * CELL
		var ffz := z0 + rng.randf() * CELL
		var ffh := HanyangMap.height(ffx, ffz)
		if ffh < HanyangMap.RIVER_LEVEL + 0.5 or HanyangMap.u_of(ffx, ffz) < 0.9:
			continue
		if rng.randf() < 0.6:
			_add_pick("feather", Vector3(ffx, ffh, ffz))
	# 산자락과 고개의 돌: 지대가 높거나 위험한 산길이면 몇 개 놓인다 (종류는 Gear.roll_stone)
	for i in 3:
		var sx := x0 + rng.randf() * CELL
		var sz := z0 + rng.randf() * CELL
		var sh := HanyangMap.height(sx, sz)
		var sr := rng.randf()
		var sid := Gear.roll_stone(rng)
		if sh < 2.0 or HanyangMap.u_of(sx, sz) < 1.0 or _near_house(sx, sz, 5.0):
			continue
		if int(Region.zone_at(sx, sz)["danger"]) >= 1 and (sh > 8.0 or sr < 0.35):
			_add_pick("stone", Vector3(sx, sh, sz), sid)
	# 곡식은 민가 곁에서 얻고, 성 밖 밭과 강가 논, 산에서도 얻는다. 종류는 Items.POOLS 가중치로 정한다.
	var hp := HanyangCity.house_points
	for i in hp.size():
		var p := hp[i]
		if p.x < x0 or p.x >= x0 + CELL or p.y < z0 or p.y >= z0 + CELL:
			continue
		var nh := 0
		if rng.randf() < 0.8:
			nh = 2 if rng.randf() < 0.4 else 1
		for hi in nh:
			var gx := p.x + rng.randf_range(-4.0, 4.0)
			var gz := p.y + rng.randf_range(2.0, 5.0)
			_add_pick("grain", Vector3(gx, HanyangMap.height(gx, gz), gz), Items.roll("house", rng))
	# 성 밖 밭·논과 산
	for i in 5:
		var fx := x0 + rng.randf() * CELL
		var fz := z0 + rng.randf() * CELL
		var fh := HanyangMap.height(fx, fz)
		var roll := rng.randf()
		var u := HanyangMap.u_of(fx, fz)
		if fh < -4.0 or u < 1.1 or _near_house(fx, fz, 5.0):
			continue
		var zn := Region.zone_at(fx, fz)
		if bool(zn["town"]):
			continue
		var danger := int(zn["danger"])
		if danger >= 1 and fh > 0.5 and roll < 0.6:
			_add_pick("grain", Vector3(fx, fh, fz), Items.roll("wild", rng))
		elif danger <= 1 and roll < 0.75:
			var near_river := fz > 150.0 and HanyangMap.river_dist(fx, fz) < 90.0
			_add_pick("grain", Vector3(fx, fh, fz), Items.roll("paddy" if near_river else "field", rng))


func _spawn_mountain(ix: int, iz: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(ix, iz)) + 2417
	var x0 := float(ix) * CELL
	var z0 := float(iz) * CELL
	# 산에서 캐고 따는 것: 산나물·뿌리·열매·버섯 (높고 깊은 산일수록 많다)
	for i in 4:
		var x := x0 + rng.randf() * CELL
		var z := z0 + rng.randf() * CELL
		var h := HanyangMap.height(x, z)
		if h < 5.0 or HanyangMap.u_of(x, z) < 1.1 or _near_house(x, z, 5.0):
			continue
		var zn := Region.zone_at(x, z)
		if bool(zn["town"]) or int(zn["danger"]) < 1:
			continue
		if rng.randf() < 0.65:
			_add_pick("grain", Vector3(x, h, z), Items.roll("wild", rng))
	# 산 깃털: 꿩과 산비둘기가 떨어뜨린다
	for i in 2:
		var mfx := x0 + rng.randf() * CELL
		var mfz := z0 + rng.randf() * CELL
		var mfh := HanyangMap.height(mfx, mfz)
		if mfh < 3.0 or HanyangMap.u_of(mfx, mfz) < 1.1:
			continue
		if rng.randf() < 0.7:
			_add_pick("feather", Vector3(mfx, mfh, mfz))
	# 큰 바위: 곡괭이로만 깰 수 있다 (높은 산비탈에 흩어져 있다)
	for i in 2:
		var bx := x0 + rng.randf() * CELL
		var bz := z0 + rng.randf() * CELL
		var bh := HanyangMap.height(bx, bz)
		var bseed := rng.randi()
		if bh < 9.0 or HanyangMap.u_of(bx, bz) < 1.05 or _near_house(bx, bz, 8.0):
			continue
		var bz2 := Region.zone_at(bx, bz)
		if bool(bz2["town"]) or int(bz2["danger"]) < 1:
			continue
		if rng.randf() < 0.6:
			_add_boulder(Vector3(bx, bh - 0.1, bz), bseed)


## 곡괭이로 깨는 큰 바위
func _add_boulder(pos: Vector3, seed: int) -> void:
	var n := Gear.boulder_node(seed)
	n.position = pos
	get_parent().add_child(n)
	boulders.append({"node": n, "hp": Gear.BOULDER_HP, "on": true, "left": 0.0})


## p 가까이의 큰 바위 번호 (없으면 -1)
func nearest_boulder(p: Vector3, r: float) -> int:
	var best := -1
	var best_d := r
	for i in boulders.size():
		var b: Dictionary = boulders[i]
		if not bool(b["on"]) or not is_instance_valid(b["node"]):
			continue
		var d := Vector2((b["node"] as Node3D).global_position.x - p.x, (b["node"] as Node3D).global_position.z - p.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func _near_house(x: float, z: float, r: float) -> bool:
	var hp := HanyangCity.house_points
	for i in hp.size():
		if absf(hp[i].x - x) < r and absf(hp[i].y - z) < r:
			return true
	return false


func _add_pick(kind: String, pos: Vector3, item := "") -> void:
	var n := Node3D.new()
	n.position = pos
	if kind == "wood":
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.3, 0.2, 0.11)
		wood.roughness = 1.0
		for i in 4:
			var m := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.05
			c.bottom_radius = 0.06
			c.height = 1.1
			m.mesh = c
			m.material_override = wood
			m.position = Vector3(float(i) * 0.1 - 0.15, 0.08 + 0.06 * float(i % 2), 0.0)
			m.rotation = Vector3(PI * 0.5, float(i) * 0.5, 0.0)
			n.add_child(m)
	elif kind == "stone":
		n.add_child(Gear.stone_node(item))
	elif kind == "feather":
		n.add_child(Gear.feather_node([Color(0.55, 0.38, 0.22), Color(0.78, 0.74, 0.66), Color(0.24, 0.24, 0.26), Color(0.62, 0.45, 0.2)][absi(hash(pos)) % 4]))
	else:
		n.add_child(Items.make_node(item))
	get_parent().add_child(n)
	_picks.append({"node": n, "kind": kind, "item": item, "on": true, "left": 0.0})


## 쓰러뜨린 짐승 곁에 고기와 가죽이 떨어진다. 줍는 쪽(사람 쪽)으로 두 덩이를 나란히 놓는다.
func add_drops(at: Vector3, meat_id: String, meat_n: int, hide_id: String, spread: float) -> void:
	var to_p := Vector2(_player.global_position.x - at.x, _player.global_position.z - at.z)
	var dir := to_p.normalized() if to_p.length() > 0.1 else Vector2(0.0, 1.0)
	var side := Vector2(-dir.y, dir.x)
	for k in 2:
		var off := dir * spread + side * (0.7 if k == 0 else -0.7)
		var x := at.x + off.x
		var z := at.z + off.y
		var n := Gear.meat_node(meat_id) if k == 0 else Gear.hide_node(hide_id)
		n.position = Vector3(x, HanyangMap.surface(x, z) + 0.03, z)
		n.rotation.y = randf() * TAU
		get_parent().add_child(n)
		_picks.append({"node": n, "kind": "meat" if k == 0 else "hide", "item": meat_id if k == 0 else hide_id, "on": true, "left": 0.0, "n": meat_n if k == 0 else 1})
		get_tree().create_timer(160.0).timeout.connect(func() -> void:
			if is_instance_valid(n):
				n.queue_free())


## 새를 잡으면 곁에 고기와 깃털이 떨어진다 (meat_id 가 빈 글이면 고기는 없다)
func add_bird_drops(at: Vector3, meat_id: String, feathers_n: int, feather_col := Color(0.55, 0.38, 0.22), fy := -9999.0) -> void:
	var to_p := Vector2(_player.global_position.x - at.x, _player.global_position.z - at.z)
	var dir := to_p.normalized() if to_p.length() > 0.1 else Vector2(0.0, 1.0)
	var side := Vector2(-dir.y, dir.x)
	var specs: Array = []
	if meat_id != "":
		specs.append(["meat", 0.2, 0.5])
	if feathers_n > 0:
		specs.append(["feather", 0.2, -0.5])
	for sp in specs:
		var off := dir * float(sp[1]) + side * float(sp[2])
		var x := at.x + off.x
		var z := at.z + off.y
		var n: Node3D = Gear.meat_node(meat_id) if String(sp[0]) == "meat" else Gear.feather_node(feather_col)
		n.position = Vector3(x, (HanyangMap.surface(x, z) if fy < -9000.0 else maxf(fy, HanyangMap.surface(x, z))) + 0.03, z)
		get_parent().add_child(n)
		_picks.append({"node": n, "kind": String(sp[0]), "item": meat_id if String(sp[0]) == "meat" else "", "on": true, "left": 0.0, "drop": true, "n": 1 if String(sp[0]) == "meat" else feathers_n})
		get_tree().create_timer(160.0).timeout.connect(func() -> void:
			if is_instance_valid(n):
				n.queue_free())


## 땅이나 나무에 박힌 화살: 가서 G 로 주울 수 있다
func add_arrow_pick(pos: Vector3, dir: Vector3) -> void:
	var n := Gear.arrow_node()
	n.position = pos
	get_parent().add_child(n)
	var d := dir.normalized()
	if d.length() > 0.5 and absf(d.y) < 0.98:
		n.look_at_from_position(pos, pos + d, Vector3.UP)
	_picks.append({"node": n, "kind": "arrow", "item": "", "on": true, "left": 0.0, "drop": true, "n": 1})
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		if is_instance_valid(n):
			n.queue_free())


func drop_notice(nm: String) -> void:
	_hud.toast("%s%s 쓰러뜨렸다! 곁에 떨어진 고기와 가죽을 G 로 줍자." % [nm, Items.eul(nm)], 3.5, "done")


## 큰 짐승을 잡으면 마음이 오른다
func reward_kill(morale_gain: float) -> void:
	morale = minf(100.0, morale + morale_gain)


func _update_boulders(delta: float) -> void:
	for b in boulders:
		if bool(b["on"]) or not is_instance_valid(b["node"]):
			continue
		b["left"] = float(b["left"]) - delta
		if float(b["left"]) <= 0.0:
			b["on"] = true
			b["hp"] = Gear.BOULDER_HP
			var n: Node3D = b["node"]
			n.visible = true
			var cs := n.get_node_or_null("Body/Shape") as CollisionShape3D
			if cs != null:
				cs.disabled = false


func _update_pick_regrow(delta: float) -> void:
	_update_boulders(delta)
	for pi in range(_picks.size() - 1, -1, -1):
		if not is_instance_valid(_picks[pi]["node"]):
			_picks.remove_at(pi)
	for p in _picks:
		if String(p["kind"]) == "meat" or String(p["kind"]) == "hide" or String(p["kind"]) == "arrow" or bool(p.get("drop", false)):
			continue
		if bool(p["on"]):
			continue
		p["left"] = float(p["left"]) - delta
		if float(p["left"]) <= 0.0:
			p["on"] = true
			(p["node"] as Node3D).visible = true


# --- 화면 ---

func _update_hud() -> void:
	var vals: Array[float] = [hunger, warmth, stamina, health, morale]
	_hud.set_stats(vals)
	_hud.set_bag(firewood, grain)
	var i := _nearest_pick()
	if i >= 0:
		var kind: String = _picks[i]["kind"]
		var nm := "땔감"
		if kind == "stone":
			nm = Gear.stone_name(String(_picks[i]["item"]))
		elif kind == "hide":
			nm = Gear.hide_name(String(_picks[i]["item"]))
		elif kind == "feather":
			nm = "깃털"
		elif kind == "arrow":
			nm = "화살"
		elif kind != "wood":
			nm = String(Items.def(String(_picks[i]["item"]))["name"])
		_hud.set_prompt("G  %s 줍기" % nm)
	else:
		var bi := nearest_boulder(_player.global_position, 3.4)
		_hud.set_prompt("큰 바위  ·  곡괭이를 들고 좌클릭으로 깬다" if bi >= 0 else "")
