class_name HitReact
extends RefCounted
## 맞았을 때 몸 반응: 맞은 반대쪽으로 몸이 휘었다가 되돌아오고(무거울수록 덜 휜다), 털이 한 순간 하얗게 번쩍인다.
## 모든 길이는 설계값이다 (설계 근거: 고증_근거.md §54).


static func react(beast: Node3D, rig: Node3D, from: Vector3, dmg: float, mass: float) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var away := Vector3(beast.global_position.x - from.x, 0.0, beast.global_position.z - from.z)
	if away.length() < 0.01:
		away = Vector3.BACK
	away = away.normalized()
	var la: Vector3 = beast.global_transform.basis.inverse() * away
	var ang := minf(clampf(0.14 + dmg * 0.012, 0.14, 0.45) / maxf(mass, 0.6), 0.42)
	var lean := Vector3(la.z * ang, 0.0, -la.x * ang)
	var old: Variant = beast.get_meta("hr_tw", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := beast.create_tween()
	beast.set_meta("hr_tw", tw)
	tw.tween_property(rig, "rotation", lean, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(rig, "rotation", -lean * 0.25, 0.12)
	tw.tween_property(rig, "rotation", Vector3.ZERO, 0.18)
	# 하얗게 번쩍
	var meshes: Array = []
	if beast.has_meta("hr_meshes"):
		meshes = beast.get_meta("hr_meshes") as Array
	else:
		_collect(rig, meshes)
		beast.set_meta("hr_meshes", meshes)
	var oldf: Variant = beast.get_meta("hr_ftw", null)
	if oldf is Tween and (oldf as Tween).is_valid():
		(oldf as Tween).kill()
	var peak := clampf(0.55 + dmg * 0.02, 0.55, 1.0)
	var ft := beast.create_tween()
	beast.set_meta("hr_ftw", ft)
	ft.tween_method(func(v: float) -> void:
		for m in meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).set_instance_shader_parameter("flash", v), peak, 0.0, 0.2)


static func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect(c, out)
