class_name NightWildlife
extends Node
## 저녁·밤 한양 바깥 산길의 으스스한 분위기. 범이 나오는 곳이 아니어도 늑대 울음, 부엉이, 덤불 소리,
## 어둠 속 눈빛이 이따금 이어진다. 눈빛이나 소리는 위협의 기척일 뿐 실제로 공격하지는 않는다.
## 사료상 조선 초 한양 둘레 산에는 호랑이·표범·늑대·멧돼지가 살았다(일반 서술, [추정]). 간격·거리·확률은 설계값이다.

const START_NIGHT := 0.45
const OUTSIDE_U := 1.08
const EYE_MAX := 3
const LINES := [
	"어디선가 늑대 울음이 길게 이어진다.",
	"덤불 속에서 무언가 숨죽여 지켜보는 기척이 난다.",
	"우는 새소리가 뚝 끊겼다. 나뭇가지 부러지는 소리가 난다.",
	"등 뒤에서 낙엽 밟는 소리가 났다. 돌아보면 아무것도 없다.",
	"멀리서 멧돼지가 씩씩거리는 소리가 들린다.",
	"어둠 속에서 눈 두 개가 번뜩였다.",
]

static var _wavs := {}

var _player: Player
var _hud: SurvivalHud
var _vig: InkVignette
var _timer := 5.0
var _eyes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _amb := 0.0
var _last_line := -1


func setup(player: Player, hud: SurvivalHud, vig: InkVignette) -> void:
	_player = player
	_hud = hud
	_vig = vig
	_rng.randomize()


## 지금 이곳이 저녁 바깥 산길인가: (0~1) 세기
func _intensity(pp: Vector2) -> float:
	var night := clampf((DayNight.night_amount - START_NIGHT) / (1.0 - START_NIGHT), 0.0, 1.0)
	if night <= 0.0:
		return 0.0
	var zn := Region.zone_at(pp.x, pp.y)
	if bool(zn["town"]):
		return 0.0
	var u := HanyangMap.u_of(pp.x, pp.y)
	var danger := int(zn["danger"])
	if u < OUTSIDE_U and danger < 2:
		return 0.0
	var place := 0.55 + 0.15 * float(clampi(danger, 0, 3))
	return night * minf(place, 1.0)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var k := _intensity(pp)
	_amb = lerpf(_amb, k * 0.3, clampf(delta * 0.6, 0.0, 1.0))
	if _vig != null:
		_vig.set_ambient(_amb)
	_update_eyes(delta)
	if k <= 0.0 or _player.input_locked:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(13.0, 26.0) / (0.6 + k)
		_event(pp, k)


func _event(pp: Vector2, k: float) -> void:
	var kinds := ["howl", "owl", "rustle", "growl", "snap"]
	var kind: String = kinds[_rng.randi() % kinds.size()]
	var ang := _rng.randf() * TAU
	var dist := _rng.randf_range(24.0, 48.0)
	var p3 := _player.global_position + Vector3(cos(ang) * dist, 0.5, sin(ang) * dist)
	var a := AudioStreamPlayer3D.new()
	a.stream = _wav(kind)
	a.unit_size = 12.0
	a.max_distance = 110.0
	a.volume_db = -3.0 + 6.0 * k
	add_child(a)
	a.global_position = p3
	a.finished.connect(a.queue_free)
	a.play()
	if _rng.randf() < 0.45 and _eyes.size() < EYE_MAX:
		_spawn_eyes(pp)
	if _rng.randf() < 0.55:
		var i := _rng.randi() % LINES.size()
		if i == _last_line:
			i = (i + 1) % LINES.size()
		_last_line = i
		_hud.toast(String(LINES[i]), 3.5)


func _spawn_eyes(pp: Vector2) -> void:
	var yaw := _player._yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var ang := fwd.angle() + _rng.randf_range(-1.1, 1.1)
	var d := _rng.randf_range(17.0, 32.0)
	var q := pp + Vector2(cos(ang), sin(ang)) * d
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.15)
	mat.emission_energy_multiplier = 2.0
	for sx in [-0.09, 0.09]:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.035
		sp.height = 0.07
		sp.radial_segments = 8
		sp.rings = 4
		m.mesh = sp
		m.material_override = mat
		m.position = Vector3(float(sx), 0.0, 0.0)
		n.add_child(m)
	add_child(n)
	n.global_position = Vector3(q.x, HanyangMap.height(q.x, q.y) + _rng.randf_range(0.35, 0.8), q.y)
	n.look_at(_player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	_eyes.append({"n": n, "life": _rng.randf_range(4.0, 8.0), "blink": _rng.randf_range(1.0, 2.5)})


func _update_eyes(delta: float) -> void:
	var i := _eyes.size() - 1
	while i >= 0:
		var e: Dictionary = _eyes[i]
		var n: Node3D = e["n"]
		var life: float = float(e["life"]) - delta
		var blink: float = float(e["blink"]) - delta
		e["life"] = life
		if blink <= 0.0:
			n.visible = false
			if blink < -0.18:
				n.visible = true
				blink = _rng.randf_range(1.2, 3.0)
		e["blink"] = blink
		var close := n.global_position.distance_to(_player.global_position) < 9.0
		if life <= 0.0 or close:
			n.queue_free()
			_eyes.remove_at(i)
		i -= 1


static func _wav(kind: String) -> AudioStreamWAV:
	if _wavs.has(kind):
		return _wavs[kind]
	var rate := 16000
	var dur := 1.2
	match kind:
		"howl":
			dur = 2.8
		"owl":
			dur = 1.2
		"rustle":
			dur = 0.9
		"growl":
			dur = 1.4
		"snap":
			dur = 0.25
	var n := int(float(rate) * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + kind.length() * 31
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var x := float(i) / float(n)
		var noise := rng.randf() * 2.0 - 1.0
		var v := 0.0
		match kind:
			"howl":
				var f := (230.0 + 150.0 * sin(PI * clampf(x * 1.1, 0.0, 1.0))) * (1.0 + 0.015 * sin(TAU * 5.5 * t))
				ph += TAU * f / float(rate)
				var env := smoothstep(0.0, 0.18, x) * (1.0 - smoothstep(0.62, 1.0, x))
				v = (sin(ph) + 0.5 * sin(2.0 * ph) + 0.25 * sin(3.0 * ph)) * 0.45 * env + noise * 0.03 * env
			"owl":
				var f2 := 400.0 - 40.0 * x
				ph += TAU * f2 / float(rate)
				var e1 := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.22, 0.36, t))
				var e2 := smoothstep(0.52, 0.58, t) * (1.0 - smoothstep(0.85, 1.0, t))
				v = (sin(ph) + 0.3 * sin(2.0 * ph)) * 0.5 * maxf(e1, e2)
			"rustle":
				lp = lp * 0.55 + noise * 0.45
				var env2 := 0.0
				for b in [0.1, 0.3, 0.45, 0.7]:
					env2 += exp(-absf(x - float(b)) * 28.0)
				v = lp * minf(env2, 1.0) * 0.8
			"growl":
				ph += TAU * 62.0 / float(rate)
				lp = lp * 0.8 + noise * 0.2
				var env3 := smoothstep(0.0, 0.2, x) * (1.0 - smoothstep(0.6, 1.0, x))
				v = (sin(ph) * 0.5 + lp * 0.8) * (0.65 + 0.35 * sin(TAU * 26.0 * t)) * env3
			"snap":
				v = noise * exp(-x * 14.0) * 0.9
		var s := int(clampf(v, -1.0, 1.0) * 30000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_wavs[kind] = w
	return w
