class_name JoseonUI
extends RefCounted
## 조선풍 UI 공통 꾸밈: 한지·먹·주칠(朱漆)·쪽빛. 지도부터 쓰고, 상태 표시와 대화창에도 넓혀 간다.
## 색과 틀은 설계값이다. 한지의 아이보리, 먹의 검정, 도장의 붉은색, 쪽물의 푸른색은
## 조선 서화·문서의 일반적인 인상을 옮긴 것이고, 특정 유물의 색을 재현한 것이 아니다.

## 글꼴 후보: res://fonts/ 에 파일을 두면 우선 쓴다. 없으면 윈도우에 깔린 바탕·궁서 계열, 그래도 없으면 기본 글꼴.
const FONT_BODY: Array[String] = [
	"res://fonts/NanumMyeongjo.ttf", "res://fonts/NanumMyeongjo-Regular.ttf", "res://fonts/GowunBatang-Regular.ttf",
	"res://fonts/NotoSerifKR-Regular.ttf", "res://fonts/NotoSerifKR-VF.ttf", "res://fonts/NotoSansKR-Regular.ttf"]
const FONT_TITLE: Array[String] = [
	"res://fonts/NanumBrush.ttf", "res://fonts/NanumBrushScript-Regular.ttf", "res://fonts/NanumPen.ttf",
	"res://fonts/NanumMyeongjo-Bold.ttf", "res://fonts/NanumMyeongjo.ttf"]
const SYSTEM_BODY: Array[String] = ["Nanum Myeongjo", "NanumMyeongjo", "Batang", "바탕", "Gungsuh", "Malgun Gothic", "맑은 고딕"]
const SYSTEM_TITLE: Array[String] = ["Nanum Brush Script", "HYGungSo-Bold", "HY궁서B", "Gungsuh", "궁서", "Batang", "바탕", "Malgun Gothic"]

static var _font_body: Font = null
static var _font_title: Font = null
static var _tex_cache: Dictionary = {}


## 가는 글꼴(바탕·명조)은 화면에서 흐려 보이므로 획을 덧입혀 굵게 만든다.
static func _pick_font(paths: Array[String], system_names: Array[String], bold: bool) -> Font:
	var base: Font = null
	for p in paths:
		if ResourceLoader.exists(p):
			base = load(p) as Font
			if base != null:
				break
	if base == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(system_names)
		sf.font_weight = 700 if bold else 500
		sf.allow_system_fallback = true
		base = sf
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = 0.75 if bold else 0.45
	return fv


static func font() -> Font:
	if _font_body == null:
		_font_body = _pick_font(FONT_BODY, SYSTEM_BODY, false)
	return _font_body


## 제목·이름·지명에 쓰는 글꼴 (붓글씨체가 있으면 그것)
static func title_font() -> Font:
	if _font_title == null:
		_font_title = _pick_font(FONT_TITLE, SYSTEM_TITLE, true)
	return _font_title


## res://ui/ 의 PNG를 읽는다. 에디터가 아직 가져오기(import)를 안 했어도 파일에서 직접 읽는다.
static func tex(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	var path := "res://ui/" + file
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_tex_cache[file] = t
	return t


## 현재 스타일에 맞는 질감 파일 이름 (t0_, t1_, t2_)
static func tname(base: String) -> String:
	return "t%d_%s" % [clampi(UiPrefs.theme_id, 0, 2), base]


## 색은 스타일(UiPrefs.theme_id)에 따라 바뀐다. apply_theme()가 채운다.
static var PAPER := Color(0.93, 0.89, 0.78)
static var PAPER_LIGHT := Color(0.96, 0.93, 0.84)
static var PAPER_DARK := Color(0.84, 0.78, 0.64)
static var INK := Color(0.11, 0.09, 0.08)
static var INK_SOFT := Color(0.32, 0.27, 0.22)
static var SEAL := Color(0.70, 0.15, 0.12)
static var INDIGO := Color(0.16, 0.28, 0.43)
static var SEA := Color(0.64, 0.74, 0.74)
static var PINE := Color(0.30, 0.42, 0.28)
static var OCHRE := Color(0.62, 0.42, 0.18)

const THEME_NAMES: Array[String] = ["한지 · 먹 · 주칠", "단청 · 뇌록과 금", "수묵 · 흑백"]
const WOOD := Color(0.24, 0.16, 0.09)
const SIJIN: Array[String] = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"]
const SIJIN_HANJA: Array[String] = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

const SHADOW_S := 6.0
const SHADOW_L := 10.0
const LEVEL_NAMES: Array[String] = ["마을", "들길", "구릉", "산길", "깊은 산"]


## 글자 둘레에 한지색 테두리를 둘러 그림 위에서도 읽히게 한다.
static func text_halo(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color, halo := PAPER) -> void:
	var f := font()
	ci.draw_string(f, pos + Vector2(1.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.22))
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var off: Vector2 = o
		ci.draw_string(f, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, halo)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 굵은 글씨: 제목 글꼴을 살짝 어긋나게 겹쳐 그려 획을 굵게 하고, 종이색 테두리를 둘러 바탕과 겹쳐도 읽히게 한다.
static func text_bold(ci: CanvasItem, pos: Vector2, text: String, size: int, col: Color, halo := PAPER) -> void:
	var f := title_font()
	ci.draw_string(f, pos + Vector2(1.5, 2.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.28))
	for o in [Vector2(-1.6, 0), Vector2(1.6, 0), Vector2(0, -1.6), Vector2(0, 1.6), Vector2(-1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2), Vector2(1.2, -1.2)]:
		var off: Vector2 = o
		ci.draw_string(f, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, halo)
	for o in [Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0, 0.4), Vector2.ZERO]:
		var off2: Vector2 = o
		ci.draw_string(f, pos + off2, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 이중 테두리와 네 모서리의 붉은 점으로 만든 틀.
static func frame(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, INK, false, 3.0)
	var inner := r.grow(-7.0)
	ci.draw_rect(inner, INK_SOFT, false, 1.2)
	for c in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
		var p: Vector2 = c
		ci.draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), SEAL)


## 붉은 도장: 네모 안에 글자.
static func seal(ci: CanvasItem, pos: Vector2, size: float, text: String) -> void:
	ci.draw_rect(Rect2(pos, Vector2(size, size)), SEAL)
	ci.draw_rect(Rect2(pos, Vector2(size, size)).grow(-3.0), PAPER_LIGHT, false, 1.2)
	var f := font()
	var fs := int(size * 0.42)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(f, pos + Vector2((size - w) * 0.5, size * 0.62), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PAPER_LIGHT)


## 삐뚤게 찍힌 한지 섬유 무늬 (고정 난수)
static func fibers(r: Rect2, count: int, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector2Array()
	for i in count:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var a := rng.randf() * TAU
		var l := rng.randf_range(6.0, 22.0)
		out.append(p)
		out.append(p + Vector2.from_angle(a) * l)
	return out


# --- 스타일 ---

static func apply_theme(id: int) -> void:
	match id:
		1:
			# 단청: 뇌록(짙은 청록) 바탕에 금빛 글자, 주홍 포인트
			PAPER = Color(0.14, 0.28, 0.25)
			PAPER_LIGHT = Color(0.20, 0.36, 0.32)
			PAPER_DARK = Color(0.10, 0.20, 0.18)
			INK = Color(0.97, 0.93, 0.80)
			INK_SOFT = Color(0.82, 0.72, 0.45)
			SEAL = Color(0.88, 0.24, 0.17)
			INDIGO = Color(0.50, 0.74, 0.88)
			SEA = Color(0.20, 0.34, 0.42)
			PINE = Color(0.55, 0.78, 0.50)
			OCHRE = Color(0.92, 0.74, 0.30)
		2:
			# 수묵: 흑백과 옅은 회색, 도장만 붉다
			PAPER = Color(0.89, 0.89, 0.86)
			PAPER_LIGHT = Color(0.95, 0.95, 0.93)
			PAPER_DARK = Color(0.78, 0.78, 0.75)
			INK = Color(0.07, 0.07, 0.08)
			INK_SOFT = Color(0.30, 0.30, 0.32)
			SEAL = Color(0.72, 0.14, 0.11)
			INDIGO = Color(0.26, 0.32, 0.38)
			SEA = Color(0.72, 0.75, 0.77)
			PINE = Color(0.33, 0.38, 0.33)
			OCHRE = Color(0.40, 0.37, 0.32)
		_:
			PAPER = Color(0.93, 0.89, 0.78)
			PAPER_LIGHT = Color(0.96, 0.93, 0.84)
			PAPER_DARK = Color(0.84, 0.78, 0.64)
			INK = Color(0.11, 0.09, 0.08)
			INK_SOFT = Color(0.32, 0.27, 0.22)
			SEAL = Color(0.70, 0.15, 0.12)
			INDIGO = Color(0.16, 0.28, 0.43)
			SEA = Color(0.64, 0.74, 0.74)
			PINE = Color(0.30, 0.42, 0.28)
			OCHRE = Color(0.62, 0.42, 0.18)


## 단추 바탕: 한지판이 살짝 도드라진 모양. 부드러운 그림자, 위쪽 빛, 아래쪽 그늘, 금빛 안쪽 선. 눌려 있으면 가라앉아 보인다.
static func button_plate(ci: CanvasItem, size: Vector2, hover: bool, open: bool) -> void:
	UiPrefs.ensure()
	var k := clampf(UiPrefs.font_scale, 0.5, 1.5) * 0.74
	var lift := 0.0 if open else (1.5 * k if hover else 0.0)
	var r := Rect2(Vector2(0.0, -lift), size)
	var a := maxf(UiPrefs.opacity, 0.9)
	# 그림자 (눌리면 가까이, 올라오면 멀리)
	var sd := 1.0 if open else 3.0
	for i in 4:
		var g := float(i) * 1.2 * k
		ci.draw_rect(Rect2(r.position + Vector2(0.5, sd + 1.0) * k, size).grow(g), Color(0.0, 0.0, 0.0, 0.07))
	# 바탕: 위는 밝고 아래는 짙은 그라데이션
	var top_c := PAPER_LIGHT if not open else PAPER_DARK
	var bot_c := PAPER_DARK if not open else PAPER
	top_c = Color(top_c.r, top_c.g, top_c.b, a)
	bot_c = Color(bot_c.r, bot_c.g, bot_c.b, a)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top_c, top_c, bot_c, bot_c]))
	# 입체 모서리
	var hi := Color(1.0, 1.0, 1.0, 0.55 if not open else 0.12)
	var lo := Color(0.0, 0.0, 0.0, 0.30 if not open else 0.5)
	var t := maxf(1.5, 2.0 * k)
	ci.draw_rect(Rect2(r.position, Vector2(size.x, t)), hi)
	ci.draw_rect(Rect2(r.position, Vector2(t, size.y)), hi)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - t), Vector2(size.x, t)), lo)
	ci.draw_rect(Rect2(Vector2(r.end.x - t, r.position.y), Vector2(t, size.y)), lo)
	# 먹선 테두리와 금빛 안쪽 선
	var edge := INK if (hover or open) else INK_SOFT
	ci.draw_rect(r, edge, false, maxf(1.5, 1.8 * k))
	var gold := OCHRE if UiPrefs.theme_id != 2 else INK_SOFT
	ci.draw_rect(r.grow(-4.0 * k), Color(gold.r, gold.g, gold.b, 0.75), false, 1.0)
	if hover or open:
		ci.draw_rect(r.grow(-5.0 * k), Color(INK.r, INK.g, INK.b, 0.05 if hover else 0.10))


## 글자판. 한지 질감 9분할 이미지(작은 것 m=22, 큰 것 m=40). 질감 파일이 없거나 장식을 끄면 평면판.
static func plate_style(pad := 8.0, big := false) -> StyleBox:
	UiPrefs.ensure()
	var t := tex(tname("plate_l.png" if big else "plate_s.png")) if UiPrefs.ornament else null
	if t == null:
		return flat_plate_style(pad)
	var k := clampf(UiPrefs.font_scale, 0.5, 1.5)
	var m := (40.0 if big else 22.0) * k
	var shd := (SHADOW_L if big else SHADOW_S) * k   # 질감 바깥의 그림자 여백 (tools/gen_ui_assets.py 의 SH_L, SH_S)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = m + shd
	sb.texture_margin_right = m + shd
	sb.texture_margin_top = m + shd
	sb.texture_margin_bottom = m + shd
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = Color(1, 1, 1, UiPrefs.opacity)
	var inner := m * 0.5
	sb.content_margin_left = (pad + 4.0) * k + inner + shd
	sb.content_margin_right = (pad + 4.0) * k + inner + shd
	sb.content_margin_top = pad * k + inner * 0.7 + shd
	sb.content_margin_bottom = pad * k + inner * 0.7 + shd
	return sb


## 평면 한지판 (버튼·팝업과, 질감을 쓸 수 없을 때)
static func flat_plate_style(pad := 8.0) -> StyleBoxFlat:
	UiPrefs.ensure()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, UiPrefs.opacity)
	sb.border_color = INK_SOFT
	sb.set_border_width_all(2 if UiPrefs.ornament else 0)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = pad + 4.0
	sb.content_margin_right = pad + 4.0
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 4
	return sb


## 버튼용 입체 상자: 그림자, 위아래 그라데이션, 위·왼쪽 빛, 아래·오른쪽 그늘, 눌리면 가라앉는다.
class BevelBox extends StyleBox:
	var top_col := Color(1, 1, 1)
	var bot_col := Color(0.8, 0.8, 0.8)
	var edge_col := Color(0.3, 0.25, 0.2)
	var pressed := false
	var lift := 0.0

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var r := rect
		var sd := 1.0 if pressed else 3.0
		for i in 3:
			RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(r.position + Vector2(0.0, sd), r.size).grow(float(i) * 1.2), Color(0.0, 0.0, 0.0, 0.08))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top_col, top_col, bot_col, bot_col]))
		var hi := Color(1.0, 1.0, 1.0, 0.12 if pressed else 0.5)
		var lo := Color(0.0, 0.0, 0.0, 0.45 if pressed else 0.28)
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(r.position, Vector2(r.size.x, 2.0)), hi)
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(r.position, Vector2(2.0, r.size.y)), hi)
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(Vector2(r.position.x, r.end.y - 2.0), Vector2(r.size.x, 2.0)), lo)
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(Vector2(r.end.x - 2.0, r.position.y), Vector2(2.0, r.size.y)), lo)
		var l := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, l, PackedColorArray([edge_col]), 1.6)


static func bevel_style(top: Color, bottom: Color, pad := 6.0, pressed := false) -> StyleBox:
	UiPrefs.ensure()
	var b := BevelBox.new()
	b.top_col = Color(top.r, top.g, top.b, maxf(UiPrefs.opacity, 0.9))
	b.bot_col = Color(bottom.r, bottom.g, bottom.b, maxf(UiPrefs.opacity, 0.9))
	b.edge_col = INK_SOFT
	b.pressed = pressed
	b.content_margin_left = pad + 6.0
	b.content_margin_right = pad + 6.0
	b.content_margin_top = pad + (2.0 if pressed else 0.0)
	b.content_margin_bottom = pad + (0.0 if pressed else 2.0)
	return b


## 알림 글 상자: 비쳐 보이는 한지에 가는 먹선과 금빛 안쪽 선, 네 모서리의 붉은 마름모, 부드러운 그림자.
class ToastBox extends StyleBox:
	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		UiPrefs.ensure()
		var r := rect
		var op := clampf(UiPrefs.opacity + 0.1, 0.4, 1.0)
		var pl := JoseonUI.PAPER_LIGHT
		var pp := JoseonUI.PAPER
		var top_c := Color(pl.r, pl.g, pl.b, 0.66 * op)
		var bot_c := Color(pp.r, pp.g, pp.b, 0.56 * op)
		for i in 4:
			RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(r.position + Vector2(0.0, 3.0), r.size).grow(float(i) * 1.6), Color(0.0, 0.0, 0.0, 0.05))
		RenderingServer.canvas_item_add_polygon(to_canvas_item, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([top_c, top_c, bot_c, bot_c]))
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(r.position + Vector2(2.0, 2.0), Vector2(r.size.x - 4.0, 1.5)), Color(1.0, 1.0, 1.0, 0.38))
		var ink := JoseonUI.INK_SOFT
		var gold := JoseonUI.OCHRE
		var o := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, o, PackedColorArray([Color(ink.r, ink.g, ink.b, 0.8)]), 1.8)
		var ri := r.grow(-5.0)
		var inn := PackedVector2Array([ri.position, Vector2(ri.end.x, ri.position.y), ri.end, Vector2(ri.position.x, ri.end.y), ri.position])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, inn, PackedColorArray([Color(gold.r, gold.g, gold.b, 0.85)]), 1.2)
		for c in [ri.position, Vector2(ri.end.x, ri.position.y), ri.end, Vector2(ri.position.x, ri.end.y)]:
			var p: Vector2 = c
			var sc := JoseonUI.SEAL
			RenderingServer.canvas_item_add_polygon(to_canvas_item, PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), PackedColorArray([Color(sc.r, sc.g, sc.b, 0.95)]))


static func toast_style() -> StyleBox:
	var b := ToastBox.new()
	b.content_margin_left = 20.0
	b.content_margin_right = 20.0
	b.content_margin_top = 9.0
	b.content_margin_bottom = 11.0
	return b


static var _toast_font: Font = null


## 알림·안내 글 전용 글꼴: 굵은 붓 궁서체 (윈도우의 궁서 계열, 없으면 바탕)
static func toast_font() -> Font:
	if _toast_font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["HYGungSo-Bold", "HY궁서B", "Gungsuh", "궁서", "GungsuhChe", "Batang", "바탕"])
		sf.font_weight = 900
		sf.allow_system_fallback = true
		var fv := FontVariation.new()
		fv.base_font = sf
		fv.variation_embolden = 1.15
		_toast_font = fv
	return _toast_font


## 화면에 뜨는 말(알림, [E] 안내 등) 꾸미기: 붓 궁서체 먹글씨에 한지색 굵은 테두리와 그림자를 둘러 또렷하고, 비치는 한지 상자에 담는다.
static func style_toast(l: Label, base_size: int) -> void:
	UiPrefs.ensure()
	l.add_theme_font_override("font", toast_font())
	l.add_theme_font_size_override("font_size", int(float(base_size) * UiPrefs.font_scale * 1.1))
	l.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 1.0))
	l.add_theme_color_override("font_outline_color", Color(PAPER_LIGHT.r, PAPER_LIGHT.g, PAPER_LIGHT.b, 0.95))
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.30))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("line_spacing", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", toast_style())


## 두루마리: 위아래 나무 축과 금속 마개가 달린 대화창 (질감 9분할: 좌우 46, 상하 44)
static func scroll_style() -> StyleBox:
	UiPrefs.ensure()
	var t := tex(tname("scroll.png"))
	if t == null:
		return flat_scroll_style()
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var k := clampf(UiPrefs.font_scale, 0.5, 1.5)
	sb.texture_margin_left = 46.0 * k
	sb.texture_margin_right = 46.0 * k
	sb.texture_margin_top = 44.0 * k
	sb.texture_margin_bottom = 44.0 * k
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = Color(1, 1, 1, maxf(UiPrefs.opacity, 0.9))
	sb.content_margin_left = 56.0 * k
	sb.content_margin_right = 56.0 * k
	sb.content_margin_top = 46.0 * k
	sb.content_margin_bottom = 46.0 * k
	return sb


static func flat_scroll_style() -> StyleBoxFlat:
	UiPrefs.ensure()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, maxf(UiPrefs.opacity, 0.85))
	sb.border_color = WOOD
	sb.border_width_top = 12
	sb.border_width_bottom = 12
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.shadow_size = 6
	return sb


static func style_label(l: Label, base_size: int, plate := true, col := Color(-1, 0, 0)) -> void:
	UiPrefs.ensure()
	l.add_theme_font_size_override("font_size", int(float(base_size) * UiPrefs.font_scale))
	l.add_theme_color_override("font_color", INK if col.r < 0.0 else col)
	l.add_theme_constant_override("outline_size", 0)
	if plate:
		l.add_theme_stylebox_override("normal", plate_style())
	else:
		l.remove_theme_stylebox_override("normal")


## 상자·버튼·슬라이더 같은 기본 조작 요소에 입히는 테마
static func make_theme() -> Theme:
	UiPrefs.ensure()
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = int(16.0 * UiPrefs.font_scale)
	for cls in ["Label", "Button", "CheckBox", "OptionButton", "PopupMenu"]:
		th.set_color("font_color", cls, INK)
		th.set_color("font_hover_color", cls, SEAL)
		th.set_color("font_pressed_color", cls, SEAL)
		th.set_color("font_focus_color", cls, INK)
	th.set_color("font_hover_pressed_color", "CheckBox", SEAL)
	th.set_stylebox("panel", "PanelContainer", plate_style(10.0, true))
	th.set_stylebox("panel", "PopupMenu", flat_plate_style(4.0))
	var btn := bevel_style(PAPER_LIGHT, PAPER_DARK)
	var btn_hover := bevel_style(Color(PAPER_LIGHT.r + 0.03, PAPER_LIGHT.g + 0.03, PAPER_LIGHT.b + 0.03), PAPER)
	var btn_down := bevel_style(Color(SEAL.r, SEAL.g, SEAL.b, 1.0).lerp(PAPER_DARK, 0.62), Color(SEAL.r, SEAL.g, SEAL.b, 1.0).lerp(PAPER_DARK, 0.48), 6.0, true)
	for cls in ["Button", "OptionButton"]:
		th.set_stylebox("normal", cls, btn)
		th.set_stylebox("hover", cls, btn_hover)
		th.set_stylebox("pressed", cls, btn_down)
		th.set_stylebox("focus", cls, StyleBoxEmpty.new())
	var pop_hover := flat_plate_style(4.0)
	pop_hover.bg_color = PAPER_LIGHT
	th.set_stylebox("hover", "PopupMenu", pop_hover)
	return th


# --- 시진 ---

## 시각(0~24)을 12시진으로. 자시는 밤 11시~1시. 시진의 앞 한 시간은 초, 뒤 한 시간은 정.
static func sijin_text(hour: float) -> String:
	var h := fposmod(hour + 1.0, 24.0)
	var idx := int(h / 2.0) % 12
	var half := "초" if fposmod(h, 2.0) < 1.0 else "정"
	return "%s시(%s時) %s" % [SIJIN[idx], SIJIN_HANJA[idx], half]


static func sijin_short(hour: float) -> String:
	var h := fposmod(hour + 1.0, 24.0)
	return "%s시" % SIJIN[int(h / 2.0) % 12]
