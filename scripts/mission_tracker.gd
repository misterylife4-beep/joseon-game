class_name MissionTracker
extends CanvasLayer
## 화면 오른쪽 위에 늘 떠 있는 "지금 할 일" 판. 지도를 켜지 않아도 지금 막에서 남은 목표가 보인다.
## 위치는 UiFlow가 시간 설정 판 아래로 맞춘다. 문구와 갱신 주기는 설계값이다.

var _label: Label
var _acc := 0.0
var _seen := -1


func _ready() -> void:
	layer = 6
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	UiFlow.register(_label, "ui_right", 0)
	_refresh(true)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.3:
		return
	_acc = 0.0
	_refresh(false)


func _refresh(force: bool) -> void:
	if force or _seen != UiPrefs.version:
		_seen = UiPrefs.version
		JoseonUI.style_label(_label, 18)
		_label.set_meta("ui_key", "")
	var t := _text()
	if _label.text != t:
		_label.text = t


func _text() -> String:
	var ai := ActGoals.current_act()
	var act: Dictionary = ActGoals.ACTS[ai]
	var lines: Array[String] = ["지금 할 일 · %s" % String(act["name"])]
	var rest := ActGoals.remaining(ai)
	if rest.is_empty():
		if ai + 1 < ActGoals.ACTS.size() and bool(ActGoals.ACTS[ai + 1]["open"]):
			lines.append("● 이 막의 일을 모두 마쳤다")
		elif ai == 0:
			lines.append("● 1막의 일을 모두 마쳤다")
			lines.append("나룻배로 한강을 건너 귀향길에 오른다")
		else:
			lines.append("● 이 막의 일을 모두 마쳤다")
	else:
		for g in rest:
			lines.append("○ " + ActGoals.goal_text(g))
	if ai == 0 and not rest.is_empty():
		lines.append("※ 1막을 마치기 전에는 한양을 떠날 수 없다")
	return "\n".join(lines)
