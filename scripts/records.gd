extends Node
## 비사(秘史) 기록 시스템 - 오토로드 이름: Records
## 증거를 수집하고, 어떤 증거를 『백지본』에 쓸지 선택한다.
## 쓰면 진실이 남지만 가문의 위험도가 올라간다.

signal evidence_collected(entry: Dictionary)
signal ledger_changed

const SAVE_PATH := "user://baekjibon.json"

var evidence: Dictionary = {}  # id -> {id, title, text, risk, truth, written}
var order: Array[String] = []
var family_risk: int = 0


func _ready() -> void:
	load_ledger()


func collect(entry: Dictionary) -> bool:
	var id: String = entry["id"]
	if evidence.has(id):
		return false
	var e: Dictionary = entry.duplicate()
	e["written"] = false
	evidence[id] = e
	order.append(id)
	evidence_collected.emit(e)
	ledger_changed.emit()
	save_ledger()
	return true


func toggle_written(id: String) -> void:
	if not evidence.has(id):
		return
	var e: Dictionary = evidence[id]
	e["written"] = not bool(e["written"])
	_recalculate()
	ledger_changed.emit()
	save_ledger()


func written_truth() -> int:
	var total := 0
	for id in order:
		var e: Dictionary = evidence[id]
		if bool(e["written"]):
			total += int(e["truth"])
	return total


func total_truth() -> int:
	var total := 0
	for id in order:
		total += int((evidence[id] as Dictionary)["truth"])
	return total


func reset() -> void:
	evidence.clear()
	order.clear()
	family_risk = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	ledger_changed.emit()


func save_ledger() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"evidence": evidence, "order": order}))


func load_ledger() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var loaded_evidence: Variant = parsed.get("evidence", {})
	if loaded_evidence is Dictionary:
		evidence = loaded_evidence
	order.clear()
	for s in parsed.get("order", []):
		if evidence.has(str(s)):
			order.append(str(s))
	_recalculate()


func _recalculate() -> void:
	family_risk = 0
	for id in order:
		var e: Dictionary = evidence[id]
		if bool(e["written"]):
			family_risk += int(e["risk"])
