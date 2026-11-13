class_name LookManager
extends CanvasLayer
## 화면 후처리 룩 전환. 지금은 한국화(수묵담채) 룩 하나를 켜고 끈다.
## HUD(layer 1)보다 아래(layer 0)에 그려서 UI는 영향을 받지 않는다.

var enabled := false

var _rect: ColorRect


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ink_wash.gdshader") as Shader
	_rect.material = mat
	_rect.visible = false
	add_child(_rect)


func toggle() -> bool:
	enabled = not enabled
	_rect.visible = enabled
	return enabled
