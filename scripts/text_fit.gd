class_name TextFit
extends RefCounted
## 글자판의 줄바꿈을 깔끔하게 맞춘다. 글자 한가운데서 끊기지 않고, 문장 끝이나 띄어쓰기에서만 줄을 나누며,
## 마지막 줄만 짧게 남지 않도록 줄 길이를 고르게 한다(문장 > " · " 토막 > 낱말 순으로 끊는다).
## 줄 수는 가장 적게, 그다음 줄 길이 차이는 가장 작게 만든다.


static func _w(font: Font, fs: int, t: String) -> float:
	return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## 라벨의 글꼴과 틀 여백을 고려해 max_w(라벨 전체 폭) 안에 들어가는 줄바꿈 문장을 돌려준다.
static func fit(label: Label, raw: String, max_w: float) -> String:
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var sb := label.get_theme_stylebox("normal")
	var margin := sb.get_minimum_size().x if sb != null else 0.0
	var w := maxf(max_w - margin - 6.0, 40.0)
	var out: Array[String] = []
	for para in raw.split("\n"):
		out.append_array(_lines(font, fs, para, w, 0))
	return "\n".join(out)


static func _lines(font: Font, fs: int, text: String, w: float, level: int) -> Array[String]:
	if _w(font, fs, text) <= w or level > 2:
		return [text]
	var toks := _tokens(text, level)
	if toks.size() <= 1:
		return _lines(font, fs, text, w, level + 1)
	var out: Array[String] = []
	for ln in _pack(font, fs, toks, w):
		if _w(font, fs, ln) > w:
			out.append_array(_lines(font, fs, ln, w, level + 1))
		else:
			out.append(ln)
	return out


## level 0: 문장, 1: " · " 토막, 2: 낱말. 조각 끝에 붙는 문장부호와 점은 조각과 함께 둔다.
static func _tokens(text: String, level: int) -> Array[String]:
	var out: Array[String] = []
	match level:
		0:
			var cur := ""
			for i in text.length():
				var ch := text[i]
				cur += ch
				if (ch == "." or ch == "!" or ch == "?") and i + 1 < text.length() and text[i + 1] == " ":
					out.append(cur.strip_edges())
					cur = ""
			if cur.strip_edges() != "":
				out.append(cur.strip_edges())
		1:
			var parts := text.split(" · ")
			for i in parts.size():
				out.append(parts[i] + (" ·" if i < parts.size() - 1 else ""))
		_:
			for p in text.split(" "):
				if p != "":
					out.append(p)
	return out


## 조각을 줄로 묶는다: 줄 수 최소, 그다음 줄 길이 제곱 차이 합 최소(마지막 줄 포함).
static func _pack(font: Font, fs: int, toks: Array[String], w: float) -> Array[String]:
	var n := toks.size()
	var INF_C := 1.0e18
	var cost: Array[float] = []
	var lines: Array[int] = []
	var prev: Array[int] = []
	cost.resize(n + 1)
	lines.resize(n + 1)
	prev.resize(n + 1)
	for i in n + 1:
		cost[i] = INF_C
		lines[i] = 1 << 30
		prev[i] = -1
	cost[0] = 0.0
	lines[0] = 0
	for j in range(1, n + 1):
		for i in range(j - 1, -1, -1):
			var seg := " ".join(PackedStringArray(toks.slice(i, j)))
			var sw := _w(font, fs, seg)
			if sw > w and j - i > 1:
				break
			var slack := maxf(w - sw, 0.0)
			var nl := lines[i] + 1
			var nc := cost[i] + slack * slack
			if lines[i] < (1 << 30) and (nl < lines[j] or (nl == lines[j] and nc < cost[j])):
				lines[j] = nl
				cost[j] = nc
				prev[j] = i
	var res: Array[String] = []
	var j2 := n
	while j2 > 0:
		var i2 := prev[j2]
		if i2 < 0:
			i2 = j2 - 1
		res.push_front(" ".join(PackedStringArray(toks.slice(i2, j2))))
		j2 = i2
	return res
