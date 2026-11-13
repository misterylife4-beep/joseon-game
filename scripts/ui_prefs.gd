class_name UiPrefs
extends RefCounted
## 사용자가 고르는 UI 설정. user://ui_prefs.cfg 에 저장된다.
## 바꾸면 version이 올라가고, 각 UI는 version이 바뀐 것을 보고 스스로 다시 꾸민다.

const PATH := "user://ui_prefs.cfg"

static var theme_id := 0
const DEFAULT_SCALE := 0.8  ## 화면 크기 기본값 (너무 크다는 의견으로 낮춤)
static var font_scale := DEFAULT_SCALE
static var opacity := 0.92
static var ornament := true
static var hint_open := false
static var minimap_on := true
static var version := 0
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		theme_id = clampi(int(cf.get_value("ui", "theme", 0)), 0, 2)
		font_scale = clampf(float(cf.get_value("ui", "font_scale", DEFAULT_SCALE)), 0.5, 1.5)
		if int(cf.get_value("ui", "layout_v", 1)) < 2:
			font_scale = DEFAULT_SCALE  # 옛 저장값(1.0)을 새 기본값으로 옮긴다
		opacity = clampf(float(cf.get_value("ui", "opacity", 0.92)), 0.4, 1.0)
		ornament = bool(cf.get_value("ui", "ornament", true))
		hint_open = bool(cf.get_value("ui", "hint_open", false))
		minimap_on = bool(cf.get_value("ui", "minimap", true))
	JoseonUI.apply_theme(theme_id)


## 값을 바꾼 뒤 부른다. 색을 다시 채우고 저장하며 각 UI에 알린다.
static func changed() -> void:
	ensure()
	JoseonUI.apply_theme(theme_id)
	version += 1
	var cf := ConfigFile.new()
	cf.set_value("ui", "theme", theme_id)
	cf.set_value("ui", "font_scale", font_scale)
	cf.set_value("ui", "layout_v", 2)
	cf.set_value("ui", "opacity", opacity)
	cf.set_value("ui", "ornament", ornament)
	cf.set_value("ui", "hint_open", hint_open)
	cf.set_value("ui", "minimap", minimap_on)
	cf.save(PATH)
