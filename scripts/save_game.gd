class_name SaveGame
extends RefCounted
## 저장 파일(user://save.json) 읽고 쓰기. 한 칸짜리 저장이다.
## 무엇을 담는지는 main.gd 의 _collect_save()가 정하고, 여기서는 파일 처리만 한다.
## 쓸 때는 임시 파일에 먼저 쓴 뒤 바꿔치기해서, 저장 도중 꺼져도 옛 저장이 깨지지 않게 한다.
## 증거(Records), 막 목표(ActGoals), 발견한 거점(Discovery)은 각자 user:// 파일에 바로바로 저장된다.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const VERSION := 1

## 새로 시작하며 장면을 다시 불러온 직후에는 시작 화면을 건너뛰고 바로 오프닝을 튼다.
static var skip_title := false


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	data["saved"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var tmp_abs := ProjectSettings.globalize_path(TMP)
	var dst_abs := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(dst_abs)
	return DirAccess.rename_absolute(tmp_abs, dst_abs) == OK


static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return clean(parsed) as Dictionary
	return {}


## 시작 화면에 보여 줄 요약: {summary, saved}. 저장이 없거나 깨졌으면 빈 사전
static func info() -> Dictionary:
	var d := read()
	if d.is_empty() or not d.has("player"):
		return {}
	return {"summary": String(d.get("summary", "")), "saved": String(d.get("saved", ""))}


static func delete() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


## JSON은 숫자를 모두 실수로 읽어 오므로, 정수로 떨어지는 값은 정수로 되돌린다 (가방 개수 등).
static func clean(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in (v as Dictionary):
			out[k] = clean((v as Dictionary)[k])
		return out
	if v is Array:
		var arr: Array = []
		for e in (v as Array):
			arr.append(clean(e))
		return arr
	if v is float:
		var f: float = v
		if is_equal_approx(f, roundf(f)) and absf(f) < 1.0e9:
			return int(roundf(f))
	return v
