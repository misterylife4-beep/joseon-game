class_name Season
extends Node
## 계절. 게임 날짜에서 음력 월·일을 계산하고 셰이더 전역 값과 나무 색, 소리를 계절에 맞춘다.
## 사료(docs/고증_근거.md 18장): 도성 축조는 태조 5년(1396) 음력 1월 9일~2월 28일, 8월 6일~9월 24일에 이루어졌다.
## 1막은 첫 구간이라 겨울~이른 봄이다. 게임 하루가 실제 7일에 해당한다(공사 49일을 7일로 압축한 설계값).
## 월별 기온·단풍·농사 값은 한반도의 일반적인 계절 흐름에 맞춘 설계값이고, 당시 기후 기록은 쓰지 않았다.

const START_DOY := 8.0  # 음력 1월 9일 = 0부터 세어 8일째
const DAYS_PER_GAME_DAY := 7.0
const MONTH_LEN := 29.5
const MONTHS := ["정월", "2월", "3월", "4월", "5월", "6월", "7월", "8월", "9월", "10월", "11월", "12월"]

## 달 시작 시점(1월부터 12월, 마지막은 다음 해 1월)의 값
const COLD := [0.95, 0.7, 0.35, 0.08, 0.0, 0.0, 0.0, 0.02, 0.15, 0.4, 0.75, 0.92, 0.95]
const AUTUMN := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.05, 0.35, 0.9, 0.7, 0.1, 0.0, 0.0]
const CROP := [0.0, 0.0, 0.0, 0.25, 0.8, 1.0, 1.0, 0.95, 0.3, 0.0, 0.0, 0.0, 0.0]
const BLOOM := [0.0, 0.2, 0.9, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

static var debug_shift := 0.0
static var month_f := 1.3  # 1.0 = 정월 1일
static var cold := 0.95
static var autumn := 0.0
static var snow := 0.0
static var crop := 0.0
static var bloom := 0.0


static func _sample(arr: Array, m: float) -> float:
	var i := int(floorf(m - 1.0))
	i = clampi(i, 0, 11)
	var f := (m - 1.0) - float(i)
	return lerpf(float(arr[i]), float(arr[i + 1]), clampf(f, 0.0, 1.0))


static func day_of_year() -> float:
	return START_DOY + float(DayNight.day_now - 1) * DAYS_PER_GAME_DAY + DayNight.hour_now / 24.0 + debug_shift


static func compute() -> void:
	var doy := fposmod(day_of_year(), MONTH_LEN * 12.0)
	month_f = 1.0 + doy / MONTH_LEN
	cold = _sample(COLD, month_f)
	autumn = _sample(AUTUMN, month_f)
	crop = _sample(CROP, month_f)
	bloom = _sample(BLOOM, month_f)
	# 눈은 한겨울에 며칠 단위로 쌓였다 녹는다
	var patch := 0.55 + 0.45 * fposmod(sin(floorf(doy / 3.0) * 12.9898) * 43758.5453, 1.0)
	snow = smoothstep(0.7, 0.92, cold) * patch


## 달의 위상 각(0=삭, PI=보름). 음력 초하루가 삭, 보름이 15일 무렵이다(사료: 음력의 정의).
static func moon_elong() -> float:
	var age := fposmod(day_of_year(), MONTH_LEN)
	return age / MONTH_LEN * TAU


static func date_text() -> String:
	var doy := fposmod(day_of_year(), MONTH_LEN * 12.0)
	var m := int(doy / MONTH_LEN)
	var d := int(doy - float(m) * MONTH_LEN) + 1
	var year := 5 + int(day_of_year() / (MONTH_LEN * 12.0))
	return "태조 %d년 %s %d일" % [year, MONTHS[m], d]


## 계절별 소리·생물 활동 정도(0~1)
static func firefly() -> float:
	return smoothstep(4.6, 5.2, month_f) * (1.0 - smoothstep(7.2, 7.8, month_f))


static func cricket() -> float:
	return smoothstep(6.4, 7.2, month_f) * (1.0 - smoothstep(9.6, 10.2, month_f))


static func frog() -> float:
	return smoothstep(3.4, 4.2, month_f) * (1.0 - smoothstep(7.0, 7.8, month_f))


static func birdsong() -> float:
	return clampf(0.25 + 0.75 * (1.0 - cold), 0.0, 1.0)


func _ready() -> void:
	_push()


func _process(_delta: float) -> void:
	_push()


func _push() -> void:
	compute()
	RenderingServer.global_shader_parameter_set("season_cold", cold)
	RenderingServer.global_shader_parameter_set("season_autumn", autumn)
	RenderingServer.global_shader_parameter_set("season_snow", snow)
	RenderingServer.global_shader_parameter_set("season_crop", crop)
	# 나무 잎: 봄에는 연분홍 꽃 기운, 가을에는 단풍, 겨울에는 잎이 진다
	if ChunkManager.broad_crown_mat != null:
		var leaf := Color(1, 1, 1)
		leaf = leaf.lerp(Color(3.4, 1.1, 2.2), bloom * 0.55)
		leaf = leaf.lerp(Color(2.8, 1.2, 0.45), autumn)
		leaf = leaf.lerp(Color(1.7, 0.85, 0.85), clampf(cold * 1.2, 0.0, 1.0))
		leaf = leaf.lerp(Color(3.0, 3.0, 3.2), snow * 0.35)
		ChunkManager.broad_crown_mat.albedo_color = leaf
	if ChunkManager.rock_mat != null:
		ChunkManager.rock_mat.albedo_color = Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.7), snow * 0.5)
	if ChunkManager.shrub_mat != null:
		var sc := Color(1, 1, 1)
		sc = sc.lerp(Color(3.0, 1.0, 1.8), bloom * 0.6)
		sc = sc.lerp(Color(2.6, 1.3, 0.4), autumn)
		sc = sc.lerp(Color(1.8, 1.0, 0.9), clampf(cold * 1.2, 0.0, 1.0))
		sc = sc.lerp(Color(3.0, 3.0, 3.2), snow * 0.4)
		ChunkManager.shrub_mat.albedo_color = sc
	if ChunkManager.pine_crown_mat != null:
		var pc := Color(1, 1, 1).lerp(Color(3.0, 3.0, 3.3), snow * 0.45)
		ChunkManager.pine_crown_mat.albedo_color = pc
