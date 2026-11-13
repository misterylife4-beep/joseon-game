class_name DayNight
extends Node
## 낮밤 사이클. 하루(24시간)가 day_length_sec초에 흐른다.

signal day_passed(day: int)

@export var day_length_sec := 240.0

var hour := 8.0
var day := 1

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _cloud := 0.0

const SHIJIN := ["자시", "축시", "인시", "묘시", "진시", "사시", "오시", "미시", "신시", "유시", "술시", "해시"]

## 얼마나 밤인지 (0 낮 ~ 1 한밤). 횃불이 켜지는 기준이다.
static var night_amount := 0.0
## 다른 노드가 읽는 현재 시각(0~24)
static var hour_now := 8.0
static var day_now := 1
## 게임 안 한 시간이 실제 몇 초인지
static var sec_per_hour := 10.0
## 0 맑음 ~ 1 비. Weather가 정한다.
static var rain_amount := 0.0

const DAY_TOP := Color(0.32, 0.55, 0.85)
const DAY_HORIZON := Color(0.72, 0.82, 0.92)
const NIGHT_TOP := Color(0.02, 0.035, 0.09)
const NIGHT_HORIZON := Color(0.07, 0.1, 0.18)


func setup(sun: DirectionalLight3D, env: Environment, sky: ShaderMaterial) -> void:
	_sun = sun
	# 달빛: 해의 반대편에서 비추는 푸른 빛. 그림자는 끈다
	_moon = DirectionalLight3D.new()
	_moon.shadow_enabled = false
	_moon.light_color = Color(0.55, 0.66, 0.95)
	sun.get_parent().add_child(_moon)
	_env = env
	_sky = sky
	sec_per_hour = day_length_sec / 24.0
	_apply()


func shijin_name() -> String:
	# 자시는 23시~1시, 이후 두 시간 단위로 이어진다.
	var idx := int(floorf(fposmod(hour + 1.0, 24.0) / 2.0))
	return SHIJIN[idx]


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%s %02d:%02d (%s)" % [Season.date_text(), h, m, shijin_name()]


func _process(delta: float) -> void:
	hour += delta / day_length_sec * 24.0
	_cloud += delta * 0.004
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		day_passed.emit(day)
	_apply()


func _apply() -> void:
	if _sun == null:
		return
	var angle := (hour - 6.0) / 24.0 * TAU
	var sun_h := sin(angle)
	_sun.rotation = Vector3(-angle, deg_to_rad(-30.0), 0.0)
	_sun.visible = sun_h > -0.05
	_sun.light_energy = clampf(sun_h * 2.0, 0.0, 1.0) * 1.2
	_sun.light_color = Color(1.0, 0.6, 0.35).lerp(Color(1.0, 0.96, 0.9), clampf(sun_h * 2.0, 0.0, 1.0))

	var k := smoothstep(-0.12, 0.2, sun_h)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, k)
	# 해 뜰 때와 질 때는 지평선을 따뜻하게
	var warm := clampf(1.0 - absf(sun_h) * 4.0, 0.0, 1.0) * k
	horizon = horizon.lerp(Color(1.0, 0.62, 0.38), warm * 0.55)
	_sky.set_shader_parameter("sun_dir", _sun.basis.z)
	_sky.set_shader_parameter("top_color", NIGHT_TOP.lerp(DAY_TOP, k))
	_sky.set_shader_parameter("horizon_color", horizon)
	_sky.set_shader_parameter("ground_color", NIGHT_TOP.lerp(Color(0.25, 0.28, 0.22), k))
	_sky.set_shader_parameter("night", 1.0 - k)
	_sky.set_shader_parameter("cloud_offset", _cloud)
	# 달빛이 비추는 푸른 밤: 달 높이에 따라 밝기, 하늘빛이 거의 없어도 은은한 주변광
	# 달은 해와의 각거리(위상)에 따라 매일 약 50분씩 늦게 뜬다. 삭일에는 해와 같이 지나가 보이지 않는다.
	var elong := Season.moon_elong()
	var moon_h := sin(angle - elong)
	var lit := (1.0 - cos(elong)) * 0.5
	_moon.rotation = Vector3(-(angle - elong), deg_to_rad(-30.0), 0.0)
	_moon.visible = moon_h > -0.05 and lit > 0.03
	_moon.light_energy = clampf(moon_h * 2.0, 0.0, 1.0) * 0.55 * lit
	var moon_dir := Basis(_sun.basis.x, elong) * _sun.basis.z
	_sky.set_shader_parameter("moon_dir", moon_dir)
	night_amount = 1.0 - k
	hour_now = hour
	day_now = day
	Hanok.set_night(night_amount)
	_env.ambient_light_energy = lerpf(0.45, 0.55, k)
	_env.ambient_light_color = Color(0.32, 0.4, 0.6)
	_env.ambient_light_sky_contribution = lerpf(0.25, 1.0, k)
	_env.tonemap_exposure = lerpf(1.25, 0.85, k)
	_env.fog_light_color = horizon
	# 새벽부터 아침까지 분지에 끼는 옅은 안개 (설계값: 시각과 농도)
	var mist := smoothstep(4.5, 6.5, hour) * (1.0 - smoothstep(7.0, 9.5, hour))
	_env.fog_density = 0.0012 + 0.0045 * mist + 0.006 * rain_amount
	_sun.light_energy *= 1.0 - 0.65 * rain_amount
	_moon.light_energy *= 1.0 - 0.4 * rain_amount
	_env.fog_light_color = _env.fog_light_color.lerp(Color(0.5, 0.54, 0.58) * lerpf(0.25, 1.0, k), rain_amount * 0.8)
