extends Node3D
## 프로토타입 메인. 환경, 지형, 플레이어, 한양 도성과 경복궁 터, 증거, NPC, UI를 코드로 조립하고
## 1막(도입 - 증거 수집 - 기록 선택 - 결말) 흐름을 진행한다.

const INTERACT_RANGE := 3.0
const WALL_START := 0.35
const WALL_PER_DAY := 0.1
const SPEAKER_NARRATION := "나레이션"

const INTRO_LINES: Array[String] = [
	"1394년, 새 도읍 한양에서 도성 공사가 한창이다. 사초를 정리하던 말단 서리 도윤은 선대 기록자에게서 아무것도 적히지 않은 책 한 권을 넘겨받았다.",
	"이름은 백지본. 공식 기록에서 지워지는 이야기를 몰래 남기는 책이다. 하지만 무엇을 쓰느냐에 따라 가문이 위험해질 수 있다.",
	"성안을 돌며 사람들의 이야기와 흔적을 모으자. 모은 이야기는 J로 펼쳐서 기록할 것을 고를 수 있다.",
]

var _player: Player
var _chunks: ChunkManager
var _day_night: DayNight
var _site: HanyangSite
var _wall: HanyangWall
var _works: WallWorks
var _hud: Hud
var _look: LookManager
var _env: Environment
var _ledger_open := false
var _survival: Survival
var _gear: Gear
var _menu: GameMenu
var _playing := false   ## 시작 화면을 지나 실제로 플레이 중인가 (자동 저장은 이때만)
var _autosave_t := 0.0
const AUTOSAVE_SEC := 300.0
var _act_finished := false
var _crew: PalaceCrew

var _dialogue_active := false
var _dialogue_speaker := ""
var _dialogue_lines: Array = []
var _dialogue_index := 0
var _dialogue_done := Callable()


func _ready() -> void:
	UiPrefs.ensure()
	_setup_input()
	_build_environment()

	_chunks = ChunkManager.new()
	add_child(_chunks)

	# 경복궁 터: 북쪽 백악 아래, 평탄하게 다진 자리
	_site = PalaceSite.new()
	_site.position = Vector3(
		HanyangMap.PALACE_C.x,
		HanyangMap.height(HanyangMap.PALACE_C.x, HanyangMap.PALACE_C.y),
		HanyangMap.PALACE_C.y
	)
	add_child(_site)
	_site.set_progress(0.15)
	_crew = PalaceCrew.new()
	_crew.setup(_site)
	add_child(_crew)

	# 종묘와 사직단: 좌묘우사 (경복궁 동쪽과 서쪽)
	add_child(Shrines.new())

	# 도성: 능선을 따라 97구간, 일부만 올라간 상태로 시작
	_wall = HanyangWall.new()
	add_child(_wall)
	_wall.set_progress(WALL_START)
	_works = WallWorks.new()
	add_child(_works)
	_works.set_progress(WALL_START)

	# 시작 위치: 육조거리 남쪽 끝 황토현, 운종가와 만나는 곳
	var start := HanyangMap.HWANGTOHYEON + Vector2(0.0, 8.0)
	_player = PlayerFace.new()
	_player.position = Vector3(start.x, HanyangMap.height(start.x, start.y) + 2.0, start.y)
	add_child(_player)
	_chunks.target = _player
	_chunks.prime(_player.position)

	_look = LookManager.new()
	add_child(_look)

	_hud = Hud.new()
	add_child(_hud)

	# 생존 모드: 허기·체온·기력·건강·마음, 땔감·곡식 줍기, 모닥불
	var survival_hud := SurvivalHud.new()
	add_child(survival_hud)
	var survival := Survival.new()
	add_child(survival)
	survival.setup(_player, survival_hud)
	_survival = survival
	var bag := BagPanel.new()
	add_child(bag)
	bag.setup(survival)
	var gear := Gear.new()
	add_child(gear)
	gear.setup(_player, survival)
	_gear = gear
	var craft := CraftPanel.new()
	add_child(craft)
	craft.setup(survival, gear)

	_spawn_evidence()
	_spawn_npcs()
	_spawn_altar()
	if ActGoals.finished("a1_finale") and ActGoals.act_complete(0):
		_act_finished = true
		_complete_palace(false)
	_spawn_city()
	# 영남길 첫 구간(광나루 남쪽 ~ 양재 ~ 달래내 고개 ~ 너덜이)과 야외 위험(호랑이, 나룻배)
	var body_sfx := BodySfx.new()
	add_child(body_sfx)
	body_sfx.setup(_player, survival)
	var south := SouthRoad.new()
	add_child(south)
	south.build()
	var watch := WildWatch.new()
	add_child(watch)
	watch.setup(_player, survival, survival_hud)
	var cook := CookPanel.new()
	add_child(cook)
	cook.setup(survival, _player)
	var water := WaterTravel.new()
	add_child(water)
	water.setup(_player, survival, survival_hud)
	var beast_fx := BeastFx.new()
	add_child(beast_fx)
	beast_fx.setup(_player, survival)
	var wildlife := Wildlife.new()
	add_child(wildlife)
	wildlife.setup(_player, survival, survival_hud)
	var birds := Birds.new()
	add_child(birds)
	birds.setup(_player, survival, survival_hud)
	# M 키로 여는 조선 지도 (조선 전도 / 지역도)
	var world_map := WorldMap.new()
	add_child(world_map)
	world_map.setup(_player)
	world_map.hud = survival_hud
	var discovery := Discovery.new()
	add_child(discovery)
	discovery.setup(_player, survival_hud)
	var mini_map := MiniMap.new()
	add_child(mini_map)
	mini_map.setup(_player)
	var procession := RoyalProcession.new()
	add_child(procession)
	procession.setup(_player, survival, survival_hud)
	var goals := GoalsPanel.new()
	add_child(goals)
	goals.setup(_player)
	var tracker := MissionTracker.new()
	add_child(tracker)
	add_child(UiSettings.new())
	_day_night.day_passed.connect(_on_day_passed)
	Records.evidence_collected.connect(_on_evidence_collected)

	# 시작: 새로 시작해서 장면을 다시 불러온 경우는 곧바로 오프닝, 아니면 시작 화면(이어하기/새로 시작/나가기)
	if SaveGame.skip_title:
		SaveGame.skip_title = false
		_start_new_intro()
	else:
		_open_menu(GameMenu.Mode.TITLE)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.light_angular_distance = 0.5
	sun.shadow_blur = 1.5
	add_child(sun)

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# 노출을 낮춰 지면이 하얗게 날아가지 않게 하고, 한낮에도 색이 살아 있게 한다.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.9
	_env = env

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_day_night = DayNight.new()
	add_child(_day_night)
	_day_night.setup(sun, env, sky_mat)
	add_child(Fireflies.new())
	add_child(HanRiver.new())
	add_child(Season.new())
	var time_panel := TimePanel.new()
	add_child(time_panel)
	time_panel.setup(_day_night)
	add_child(Weather.new())
	add_child(WaterSound.new())
	add_child(AudioFix.new())
	add_child(ChimneyManager.new())
	add_child(FaceManager.new())


func _spawn_evidence() -> void:
	for entry in Act1Data.EVIDENCE:
		if entry.get("npc", false):
			continue  # NPC와 대화해서 얻는 증거
		var id: String = entry["id"]
		if Records.evidence.has(id):
			continue
		var node := EvidenceNode.new()
		node.setup(entry, _on_ground(entry["pos"]))
		add_child(node)


func _spawn_npcs() -> void:
	for entry in Act1Data.NPCS:
		var npc := Npc.new()
		var d: Dictionary = entry.duplicate()
		d["pos"] = _on_ground(entry["pos"])
		npc.setup(d)
		add_child(npc)
		# 밤에도 얼굴이 보이도록 곁에 횃불
		var tc := Torch.new()
		var tp: Vector3 = d["pos"]
		var tx := tp.x + 1.8
		var tz := tp.z + 1.0
		tc.position = Vector3(tx, HanyangMap.height(tx, tz), tz)
		add_child(tc)


## x, z는 그대로 두고 y에 그 자리의 지형 높이를 더한다.
func _on_ground(pos: Vector3) -> Vector3:
	return Vector3(pos.x, pos.y + HanyangMap.height(pos.x, pos.z), pos.z)


func _spawn_altar() -> void:
	# 경복궁 터 정전 기둥 사이
	var altar := FinaleAltar.new()
	altar.position = _site.position + Vector3(0.0, 1.25, 0.0)
	add_child(altar)


func _spawn_city() -> void:
	# 이야기 지점 주변에는 민가를 놓지 않는다
	var reserved: Array[Vector2] = []
	for e in Act1Data.EVIDENCE:
		if e.has("pos"):
			reserved.append(Vector2(e["pos"].x, e["pos"].z))
	for n in Act1Data.NPCS:
		reserved.append(Vector2(n["pos"].x, n["pos"].z))
	reserved.append(CityLife.SMITHY)
	reserved.append(CityLife.CARPENTER)
	for dx in [-8.0, 0.0, 8.0]:
		var ddx: float = dx
		reserved.append(StreetLife.DRILL + Vector2(ddx, 3.0))
	var city := HanyangCity.new()
	add_child(city)
	city.build(reserved)
	var life := StreetLife.new()
	add_child(life)
	life.build(city.road_points(), 26, 4)
	life.build_patrol(city.road_points())
	life.build_drill()
	life.build_yukjo_street()
	var gentry := GentryTravel.new()
	add_child(gentry)
	gentry.build(city.road_points())
	var cl := CityLife.new()
	add_child(cl)
	cl.build(city.road_points())
	var outer := OuterRoads.new()
	add_child(outer)
	outer.build()


# --- 매 프레임 ---

func _process(delta: float) -> void:
	if _playing and _menu == null and not _dialogue_active:
		_autosave_t += delta
		if _autosave_t >= AUTOSAVE_SEC:
			_autosave_t = 0.0
			if save_now():
				_hud.show_toast("자동 저장했습니다.", 1.8)
	_hud.set_info(
		"공사 %d일째 · 가문 위험도 %d · 수집한 증거 %d\n%s"
		% [
			_day_night.day,
			Records.family_risk,
			Records.order.size(),
			_goal_text(),
		]
	)

	if _dialogue_active:
		_hud.set_prompt("")
		if Input.is_action_just_pressed("interact"):
			_advance_dialogue()
		return
	if _ledger_open:
		_hud.set_prompt("")
		return

	var target := _nearest_interactable()
	if target == null:
		_hud.set_prompt("")
		return

	if target is Npc:
		var npc := target as Npc
		_hud.set_prompt("[E] 대화: %s" % npc.data["name"])
		if Input.is_action_just_pressed("interact"):
			_start_npc_dialogue(npc)
	elif target is EvidenceNode:
		var ev := target as EvidenceNode
		_hud.set_prompt("[E] 수집: %s" % ev.data["title"])
		if Input.is_action_just_pressed("interact"):
			var entry: Dictionary = ev.data.duplicate()
			entry.erase("pos")
			ev.queue_free()
			Records.collect(entry)
	elif target is FinaleAltar:
		_hud.set_prompt("[E] 백지본")
		if Input.is_action_just_pressed("interact"):
			_use_altar()


func _goal_text() -> String:
	var total := Act1Data.EVIDENCE.size()
	if _act_finished:
		return "1막 완료 (Esc 메뉴에서 새로 시작할 수 있다)"
	if Records.order.size() < total:
		return "목표: 성안을 돌며 증거 모으기 (%d/%d)" % [Records.order.size(), total]
	return "목표: 경복궁 터의 백지본으로 가서 1막을 마무리하세요"


func _nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	var origin := _player.global_position + Vector3(0.0, 0.9, 0.0)
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("evidence"))
	candidates.append_array(get_tree().get_nodes_in_group("npc"))
	candidates.append_array(get_tree().get_nodes_in_group("finale"))
	for n in candidates:
		var node := n as Node3D
		if node == null or node.is_queued_for_deletion():
			continue
		var d := node.global_position.distance_to(origin)
		if node is Npc:
			d = node.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


# --- 대화 ---

func _begin_dialogue(speaker: String, lines: Array, on_done: Callable = Callable()) -> void:
	_dialogue_speaker = speaker
	_dialogue_lines = lines
	_dialogue_index = 0
	_dialogue_done = on_done
	_dialogue_active = true
	_player.input_locked = true
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	var last := _dialogue_index >= _dialogue_lines.size() - 1
	_hud.show_dialogue(
		_dialogue_speaker,
		str(_dialogue_lines[_dialogue_index]),
		"E: 닫기" if last else "E: 다음"
	)


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index < _dialogue_lines.size():
		_show_dialogue_line()
		return
	_dialogue_active = false
	_player.input_locked = false
	_hud.hide_dialogue()
	if _dialogue_done.is_valid():
		_dialogue_done.call()


func _start_npc_dialogue(npc: Npc) -> void:
	var gives: String = npc.data.get("gives", "")
	var lines: Array = npc.data["lines"]
	if gives != "" and Records.evidence.has(gives):
		lines = [npc.data["after"]]
	_begin_dialogue(str(npc.data["name"]), lines, _give_npc_evidence.bind(gives))


func _give_npc_evidence(evidence_id: String) -> void:
	if evidence_id == "" or Records.evidence.has(evidence_id):
		return
	var entry := Act1Data.evidence_by_id(evidence_id)
	entry.erase("pos")
	entry.erase("npc")
	Records.collect(entry)


# --- 1막 결말 ---

func _use_altar() -> void:
	var total := Act1Data.EVIDENCE.size()
	if _act_finished:
		_begin_dialogue(SPEAKER_NARRATION, ["1막은 끝났다. 백지본은 다음 세대를 기다리고 있다."])
	elif Records.order.size() < total:
		_begin_dialogue(
			SPEAKER_NARRATION,
			["아직 모아야 할 이야기가 남아 있다. (%d/%d)" % [Records.order.size(), total]]
		)
	else:
		_start_ending()


func _start_ending() -> void:
	var written := Records.written_truth()
	var total := Records.total_truth()
	var tail: String
	if written == total:
		tail = "모든 것을 남겼다. 진실은 책에 남았지만, 가문은 감시받기 시작했다."
	elif written == 0:
		tail = "아무것도 쓰지 않았다. 가문은 안전하지만, 그 밤은 다시 아무도 기억하지 못할 것이다."
	else:
		tail = "일부만 남겼다. 남긴 진실과 묻은 진실 사이에서 가문은 아슬아슬한 균형을 택했다."
	var lines: Array = [
		"도윤은 백지본의 첫 장을 덮었다.",
		"기록한 진실 %d/%d, 가문 위험도 %d." % [written, total, Records.family_risk],
		tail,
		"수십 년이 흘렀다. 백지본은 다음 세대의 손으로 넘어간다.",
		"1막 끝. 2막 '대왕의 시대'는 준비 중입니다.",
	]
	_begin_dialogue(SPEAKER_NARRATION, lines, _finish_act)


func _finish_act() -> void:
	_act_finished = true
	ActGoals.mark("a1_finale")
	_complete_palace(true)
	_hud.show_toast("1막 완료", 5.0)
	UiSfx.play(self, "gong", -6.0)


## 경복궁이 끝까지 지어진다: 궁성·전각·근정전이 서고, 일꾼은 물러가며 궁녀와 관원이 궁을 채운다.
func _complete_palace(announce: bool) -> void:
	_site.complete()
	_crew.set_complete(true)
	get_tree().call_group("finale", "queue_free")
	if announce:
		# 정전 기둥 사이에 서 있던 자리가 근정전이 되므로 앞마당으로 옮긴다
		_player.global_position = _site.position + Vector3(0.0, 1.4, 9.5)
		_player.velocity = Vector3.ZERO
		_player._yaw = 0.0
		_hud.show_toast("경복궁이 완공되었다. 근정전이 우뚝 섰다.", 6.0)
		UiSfx.play(self, "gong", -4.0)


# --- 저장·시작 화면·메뉴 ---

func _start_new_intro() -> void:
	_playing = true
	var opening := OpeningVideo.new()
	add_child(opening)
	if Records.order.is_empty():
		if opening.active:
			opening.finished.connect(func() -> void: _begin_dialogue(SPEAKER_NARRATION, INTRO_LINES))
		else:
			_begin_dialogue(SPEAKER_NARRATION, INTRO_LINES)


func _open_menu(mode: GameMenu.Mode) -> void:
	if _menu != null:
		return
	_menu = GameMenu.new()
	_menu.mode = mode
	_menu.do_save = Callable(self, "save_now")
	_menu.resume.connect(_close_menu)
	_menu.quit_game.connect(_quit)
	_menu.continue_game.connect(_on_continue)
	_menu.new_game.connect(_on_new_game)
	add_child(_menu)


func _close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_continue() -> void:
	var data := SaveGame.read()
	if data.is_empty() or not data.has("player"):
		_close_menu()
		_hud.show_toast("저장 파일을 읽지 못했습니다. 새로 시작해 주세요.", 4.0)
		_playing = true
		return
	_apply_save(data)
	_close_menu()
	_playing = true
	_hud.show_toast("이어서 시작합니다.", 2.5)


func _on_new_game() -> void:
	SaveGame.delete()
	Records.reset()
	ActGoals.reset()
	Discovery.reset()
	Season.debug_shift = 0.0
	SaveGame.skip_title = true
	get_tree().paused = false
	get_tree().reload_current_scene()


## 지금 상태를 저장 파일에 쓴다
func save_now() -> bool:
	if _player == null or _survival == null or _gear == null:
		return false
	return SaveGame.write(_collect_save())


func _collect_save() -> Dictionary:
	var sv := _survival
	var g := _gear
	var p := _player.global_position
	return {
		"summary": "%s · %s" % [DateBanner.date_ko().replace("  ", " "), DateBanner.sijin_ko(_day_night.hour).replace("  ", " ")],
		"player": {"x": p.x, "y": p.y, "z": p.z, "yaw": _player._yaw},
		"time": {"day": _day_night.day, "hour": _day_night.hour, "shift": Season.debug_shift},
		"survival": {
			"hunger": sv.hunger, "warmth": sv.warmth, "stamina": sv.stamina, "health": sv.health, "morale": sv.morale,
			"firewood": sv.firewood, "items": sv.items, "eaten": sv.eaten, "cooked": sv.cooked,
			"picked_total": sv.picked_total, "selected": sv.selected,
		},
		"gear": {
			"stones": g.stones, "tools": g.tools, "equipped": g.equipped, "hides": g.hides, "goods": g.goods,
			"worn": g.worn, "feathers": g.feathers, "sinew": g.sinew, "arrows": g.arrows,
		},
	}


func _apply_save(d: Dictionary) -> void:
	var t: Dictionary = d.get("time", {})
	_day_night.day = int(t.get("day", 1))
	_day_night.hour = float(t.get("hour", 8.0))
	DayNight.day_now = _day_night.day
	DayNight.hour_now = _day_night.hour
	Season.debug_shift = float(t.get("shift", 0.0))
	if not _act_finished:
		var day := _day_night.day
		_site.set_progress(0.15 + (day - 1) * 0.15)
		_wall.set_progress(WALL_START + (day - 1) * WALL_PER_DAY)
		_works.set_progress(WALL_START + (day - 1) * WALL_PER_DAY)

	var s: Dictionary = d.get("survival", {})
	var sv := _survival
	sv.hunger = float(s.get("hunger", sv.hunger))
	sv.warmth = float(s.get("warmth", sv.warmth))
	sv.stamina = float(s.get("stamina", sv.stamina))
	sv.health = maxf(float(s.get("health", sv.health)), 5.0)
	sv.morale = float(s.get("morale", sv.morale))
	sv.firewood = int(s.get("firewood", 0))
	sv.items = _dict(s.get("items", {}))
	sv.eaten = _dict(s.get("eaten", {}))
	sv.cooked = _dict(s.get("cooked", {}))
	sv.picked_total = int(s.get("picked_total", 0))
	sv.selected = String(s.get("selected", ""))
	sv.cook_job = {}

	var gd: Dictionary = d.get("gear", {})
	var g := _gear
	g.stones = _dict(gd.get("stones", {}))
	g.tools = _dict(gd.get("tools", {}))
	g.hides = _dict(gd.get("hides", {}))
	g.goods = _dict(gd.get("goods", {}))
	g.worn = _dict(gd.get("worn", {}))
	g.feathers = int(gd.get("feathers", 0))
	g.sinew = int(gd.get("sinew", 0))
	g.arrows = int(gd.get("arrows", 0))
	g.equip(String(gd.get("equipped", "")))
	sv.bag_changed.emit()
	sv.cook_changed.emit()
	g.changed.emit()

	var pl: Dictionary = d.get("player", {})
	var pos := Vector3(float(pl.get("x", 0.0)), float(pl.get("y", 0.0)) + 0.6, float(pl.get("z", 0.0)))
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player._yaw = float(pl.get("yaw", 0.0))
	_chunks.prime(pos)


func _dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate() if v is Dictionary else {}


func _notification(what: int) -> void:
	# 창을 닫을 때도 플레이 중이었다면 저장한다 (시작 화면에서는 저장을 덮어쓰지 않는다)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _playing and (_menu == null or _menu.mode == GameMenu.Mode.PAUSE):
		save_now()


# --- 이벤트 ---

func _on_evidence_collected(entry: Dictionary) -> void:
	_hud.show_toast("증거를 수집했습니다: %s  (J로 백지본 열기)" % entry["title"])
	UiSfx.play(self, "stamp", -8.0)


func _on_day_passed(day: int) -> void:
	# 1막이 끝나면 공사 연출과 알림을 멈춘다 (완공된 궁궐이 되돌아가지 않게)
	if _act_finished:
		return
	_site.set_progress(0.15 + (day - 1) * 0.15)
	_wall.set_progress(WALL_START + (day - 1) * WALL_PER_DAY)
	_works.set_progress(WALL_START + (day - 1) * WALL_PER_DAY)
	_hud.show_toast("공사 %d일째, 도성이 조금 더 올라갔습니다." % day)


func _unhandled_input(event: InputEvent) -> void:
	# Esc: 다른 창(가방·제작·지도·설정 등)이 열려 있으면 그 창이 먼저 받아 닫는다. 아무것도 안 열려 있을 때만 메뉴를 연다.
	if event.is_action_pressed("ui_cancel") and _menu == null and _playing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_open_menu(GameMenu.Mode.PAUSE)
		get_viewport().set_input_as_handled()
		return
	if _dialogue_active:
		return
	if event.is_action_pressed("ledger"):
		_set_ledger(not _ledger_open)
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode == KEY_F2:
			var on := _look.toggle()
			_hud.show_toast("한국화 스타일 " + ("켬" if on else "끔"), 2.0)
			return
		if key.keycode == KEY_F10:
			Season.debug_shift += 30.0
			_hud.show_toast("날짜 한 달 건너뜀: " + Season.date_text(), 2.0)
			return
		if key.keycode == KEY_F3:
			_env.sdfgi_enabled = not _env.sdfgi_enabled
			_hud.show_toast("고급 조명(SDFGI) " + ("켬" if _env.sdfgi_enabled else "끔"), 2.0)
			return
		if _ledger_open:
			var idx := int(key.keycode) - int(KEY_1)
			if idx >= 0 and idx < Records.order.size():
				Records.toggle_written(Records.order[idx])


func _set_ledger(on: bool) -> void:
	_ledger_open = on
	_player.input_locked = on
	_hud.show_ledger(on)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _setup_input() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_SPACE])
	_add_key_action("sprint", [KEY_SHIFT])
	_add_key_action("interact", [KEY_E])
	_add_key_action("ledger", [KEY_J])


func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
