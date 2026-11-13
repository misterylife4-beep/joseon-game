class_name AudioFix
extends Node
## 소리 정리: 항상 깔리던 바람 소리를 끄고, 시작할 때 소리가 한꺼번에 터지지 않게
## 마스터 볼륨을 3초에 걸쳐 올리고 마스터 버스에 리미터를 건다. 수치는 설계값이다.

const FADE := 3.0

var _t := 0.0
var _bus := 0


func _ready() -> void:
	_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(_bus, -60.0)
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(_bus):
		if AudioServer.get_bus_effect(_bus, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -3.0
		AudioServer.add_bus_effect(_bus, lim)
	_kill_wind.call_deferred()


func _kill_wind() -> void:
	for c in get_parent().get_children():
		if c is Ambience:
			(c as Ambience)._wind.stop()


func _process(delta: float) -> void:
	if _t >= FADE:
		return
	_t += delta
	AudioServer.set_bus_volume_db(_bus, linear_to_db(clampf(_t / FADE, 0.001, 1.0)))
	if _t >= FADE:
		AudioServer.set_bus_volume_db(_bus, 0.0)
