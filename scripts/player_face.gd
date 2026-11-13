class_name PlayerFace
extends PlayerSurvivor
## 주인공. 얼굴 조각(FaceKit)을 달고, V를 누르는 동안 카메라를 앞쪽으로 돌려 얼굴을 볼 수 있게 한다.

var _kit: FaceKit


func _ready() -> void:
	super()
	_kit = FaceKit.new()
	add_child(_kit)
	_kit.setup(_person)


func _process(delta: float) -> void:
	super(delta)
	if Input.is_key_pressed(KEY_V) and not input_locked:
		_cam_pivot.rotation.y = _yaw + PI
