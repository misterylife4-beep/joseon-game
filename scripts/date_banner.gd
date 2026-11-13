class_name DateBanner
extends Control
## 화면 위 가운데에 붓으로 쓴 한글 날짜(태조 5년 정월 9일)와 시진·지금 시각(진시 정 · 오전 8시 53분)을 보인다.
## 먹은 마른 붓처럼 갈라지게(shaders/date_ink.gdshader), 날짜가 바뀌면 먹이 스미듯 나타난다.
## 왼쪽 정보줄·오른쪽 단추·알림과 겹치지 않도록 UiFlow가 쓸 수 있는 폭을 알려 주면 그 폭에 맞춰 글자 크기를 줄인다.
## 글꼴은 윈도우의 궁서 계열을 쓴다. 모양과 크기는 설계값이며 실제 현판의 재현이 아니다.

const BRUSH_FONTS: Array[String] = ["Nanum Brush Script", "NanumBrush", "HYGungSo-Bold", "HY궁서B", "Gungsuh", "궁서", "Batang", "바탕"]
const MIN_K := 0.35
const SHRINK := 0.7   ## 기본 크기를 이만큼 줄여 쓴다 (설계값)

static var _font: Font = null

var fit_w := 99999.0   ## UiFlow가 알려 주는, 겹치지 않고 쓸 수 있는 가로 폭
var _ko := ""
var _sub := ""
var _k := 1.0
var _appear := 0.0
var _acc := 1.0
var _ink: _InkLayer


## 한글 날짜: 태조 5년 정월 9일
static func date_ko() -> String:
	var doy := fposmod(Season.day_of_year(), Season.MONTH_LEN * 12.0)
	var m := int(doy / Season.MONTH_LEN)
	var d := int(doy - float(m) * Season.MONTH_LEN) + 1
	var year := 5 + int(Season.day_of_year() / (Season.MONTH_LEN * 12.0))
	return "태조 %d년  %s  %d일" % [year, Season.MONTHS[m], d]


## 시진과 지금 시각: 진시 정 · 오전 8시 53분
static func sijin_ko(hour: float) -> String:
	var h := fposmod(hour + 1.0, 24.0)
	var idx := int(h / 2.0) % 12
	var half := "초" if fposmod(h, 2.0) < 1.0 else "정"
	var hh := int(hour) % 24
	var mm := int((hour - floorf(hour)) * 60.0)
	var ap := "오전" if hh < 12 else "오후"
	var h12 := hh % 12
	if h12 == 0:
		h12 = 12
	return "%s시 %s  ·  %s %d시 %02d분" % [JoseonUI.SIJIN[idx], half, ap, h12, mm]


static func brush_font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(BRUSH_FONTS)
		sf.font_weight = 900
		sf.allow_system_fallback = true
		var fv := FontVariation.new()
		fv.base_font = sf
		fv.variation_embolden = 1.0
		_font = fv
	return _font


func _ready() -> void:
	add_to_group("ui_banner")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, 190.0)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE)
	_ink = _InkLayer.new()
	_ink.banner = self
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := load("res://shaders/date_ink.gdshader") as Shader
	if sh != null:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_ink.material = mat
	add_child(_ink)
	modulate.a = 0.0
	_refresh()


## UiFlow가 부른다: 이 가로 폭(양옆 여백 포함) 안에 들어가게 줄인다
func set_fit(w: float) -> void:
	if absf(w - fit_w) > 0.5:
		fit_w = w
		_relayout()


## 배너가 차지하는 아래쪽 끝(화면 위에서부터). 알림은 이보다 아래에서 시작한다.
func bottom_y() -> float:
	return 8.0 * _k + 74.0 * _k + 6.0 * _k + 48.0 * _k + 4.0


func _pad() -> float:
	return 64.0 * _k


func _widths(k: float) -> Vector2:
	var f := brush_font()
	var w1 := f.get_string_size(_ko, HORIZONTAL_ALIGNMENT_LEFT, -1, int(50.0 * k)).x + 42.0 * k + 22.0 * k
	var w2 := f.get_string_size(_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(27.0 * k)).x
	return Vector2(w1, w2)


## 글자 크기 배율을 정한다: 설정 배율과 쓸 수 있는 폭 중 작은 쪽
func _relayout() -> void:
	UiPrefs.ensure()
	var base := clampf(UiPrefs.font_scale, 0.8, 1.35) * SHRINK
	var k := base
	if _ko != "":
		var w := _widths(1.0)
		var need := maxf(w.x, w.y) + 2.0 * 64.0   # k=1일 때 양옆 여백 포함 폭
		k = minf(base, fit_w / maxf(need, 1.0))
	k = clampf(k, MIN_K, base)
	if absf(k - _k) > 0.002:
		_k = k
	queue_redraw()
	if _ink != null:
		_ink.queue_redraw()


func _refresh() -> void:
	var t := date_ko()
	if t != _ko:
		if _ko != "":
			_appear = 0.0   # 날이 바뀌면 먹이 다시 스민다
		_ko = t
	_sub = sijin_ko(DayNight.hour_now)
	_relayout()


func _process(delta: float) -> void:
	_acc += delta
	if _acc > 0.4:
		_acc = 0.0
		_refresh()
	_appear = move_toward(_appear, 1.0, delta / 1.6)
	modulate.a = smoothstep(0.0, 1.0, _appear)


func _band(cx: float, half: float, y0: float, h: float, alpha: float, lines: bool) -> void:
	var pc := JoseonUI.PAPER
	var ic := JoseonUI.INK_SOFT
	var steps := 24
	for i in steps:
		var a0 := float(i) / float(steps)
		var a1 := float(i + 1) / float(steps)
		var x0 := cx - half + a0 * 2.0 * half
		var x1 := cx - half + a1 * 2.0 * half
		var e0 := 1.0 - absf(a0 * 2.0 - 1.0)
		var e1 := 1.0 - absf(a1 * 2.0 - 1.0)
		var c0 := Color(pc.r, pc.g, pc.b, smoothstep(0.0, 0.55, e0) * alpha)
		var c1 := Color(pc.r, pc.g, pc.b, smoothstep(0.0, 0.55, e1) * alpha)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y0 + h), Vector2(x0, y0 + h)]), PackedColorArray([c0, c1, c1, c0]))
		if lines:
			var la := smoothstep(0.1, 0.7, (e0 + e1) * 0.5) * 0.75
			var lc := Color(ic.r, ic.g, ic.b, la)
			draw_line(Vector2(x0, y0), Vector2(x1, y0), lc, 2.0)
			draw_line(Vector2(x0, y0 + h), Vector2(x1, y0 + h), lc, 2.0)
			draw_line(Vector2(x0, y0 + 5.0 * _k), Vector2(x1, y0 + 5.0 * _k), Color(lc.r, lc.g, lc.b, la * 0.5), 1.0)
			draw_line(Vector2(x0, y0 + h - 5.0 * _k), Vector2(x1, y0 + h - 5.0 * _k), Color(lc.r, lc.g, lc.b, la * 0.5), 1.0)


## 바탕: 날짜 줄의 한지색 띠, 그 아래 시각 줄의 얇은 띠, 붉은 낙관
func _draw() -> void:
	if _ko == "":
		return
	var k := _k
	var cx := size.x * 0.5
	var w := _widths(k)
	var half := maxf(w.x, w.y) * 0.5 + _pad()
	var top := 8.0 * k
	var h1 := 74.0 * k
	_band(cx, half, top, h1, 0.68, true)
	var f := brush_font()
	var tw := f.get_string_size(_ko, HORIZONTAL_ALIGNMENT_LEFT, -1, int(50.0 * k)).x
	var ss := 40.0 * k
	JoseonUI.seal(self, Vector2(cx + tw * 0.5 + 16.0 * k, top + (h1 - ss) * 0.5), ss, "朝")
	var y2 := top + h1 + 6.0 * k
	_band(cx, half * 0.9, y2, 48.0 * k, 0.55, false)
	var gc := JoseonUI.OCHRE
	for sx in [-1.0, 1.0]:
		var sgn: float = sx
		var dp := Vector2(cx + sgn * (half * 0.9 - 10.0 * k), y2 + 24.0 * k)
		draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -5), dp + Vector2(5, 0), dp + Vector2(0, 5), dp + Vector2(-5, 0)]), gc)


## 글자 층: 마른 붓 셰이더가 이 층에만 걸린다
class _InkLayer extends Control:
	var banner: DateBanner

	func _write(f: Font, p: Vector2, text: String, fs: int, col: Color) -> void:
		# 그림자와 번진 먹, 그 위에 살짝 어긋나게 겹친 본 획
		draw_string(f, p + Vector2(2.2, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.0, 0.0, 0.0, 0.26))
		for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.4), Vector2(0, 1.4)]:
			var off: Vector2 = o
			draw_string(f, p + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.28))
		for o in [Vector2.ZERO, Vector2(0.7, 0.0), Vector2(0.0, 0.6)]:
			var off2: Vector2 = o
			draw_string(f, p + off2, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _draw() -> void:
		if banner == null or banner._ko == "":
			return
		var k := banner._k
		var f := DateBanner.brush_font()
		var cx := size.x * 0.5
		var top := 8.0 * k
		var fs1 := int(50.0 * k)
		var tw := f.get_string_size(banner._ko, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
		var seal_w := 0.0
		_write(f, Vector2(cx - tw * 0.5 - seal_w, top + 56.0 * k), banner._ko, fs1, JoseonUI.INK)
		var fs2 := int(27.0 * k)
		var sw := f.get_string_size(banner._sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var y2 := top + 74.0 * k + 6.0 * k
		_write(f, Vector2(cx - sw * 0.5, y2 + 34.0 * k), banner._sub, fs2, JoseonUI.INK_SOFT)
