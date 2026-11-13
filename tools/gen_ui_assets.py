#!/usr/bin/env python3
"""조선풍 UI 질감 자산 생성기.
한지(섬유·얼룩·가장자리 그을림), 먹선 테두리와 모서리 문양, 두루마리 축, 붓 획, 낙관, 구름무늬 구분선을
PNG로 만든다. 스타일 3종(t0 한지·먹·주칠 / t1 단청·뇌록과 금 / t2 수묵)마다 한 벌씩.
색과 문양은 설계값이다. 실제 유물의 복제가 아니라 조선 서화·문서의 인상을 옮긴 것이다.
사용: python3 tools/gen_ui_assets.py  ->  ui/ 폴더에 PNG 생성
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy.ndimage import gaussian_filter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui")
os.makedirs(OUT, exist_ok=True)

SS = 4  # 문양을 그릴 때의 초과표본 배수
SH_S = 6   # 작은 판 바깥 그림자 여백(px). joseon_ui.gd 의 SHADOW_S 와 같아야 한다
SH_L = 10  # 큰 판

PALETTES = [
    dict(  # t0 한지 · 먹 · 주칠
        paper=(236, 226, 199), burn=(150, 112, 70), fiber_l=(255, 250, 235), fiber_d=(160, 130, 90),
        ink=(38, 30, 26), ink2=(92, 76, 62), seal=(176, 40, 32), gold=(176, 138, 64),
        wood=(78, 50, 28), wood_l=(120, 82, 48), cap=(176, 138, 64)),
    dict(  # t1 단청 · 뇌록과 금
        paper=(38, 74, 66), burn=(10, 28, 24), fiber_l=(110, 150, 130), fiber_d=(20, 46, 40),
        ink=(236, 200, 110), ink2=(196, 160, 84), seal=(214, 60, 44), gold=(236, 190, 84),
        wood=(86, 36, 28), wood_l=(140, 66, 48), cap=(236, 190, 84)),
    dict(  # t2 수묵
        paper=(228, 228, 222), burn=(120, 120, 118), fiber_l=(255, 255, 252), fiber_d=(150, 150, 146),
        ink=(22, 22, 24), ink2=(86, 86, 90), seal=(180, 36, 30), gold=(120, 120, 118),
        wood=(54, 54, 56), wood_l=(96, 96, 100), cap=(150, 150, 150)),
]


def wnoise(w, h, sigma, seed):
    """가장자리가 이어지는(wrap) 정규화 잡음"""
    rng = np.random.default_rng(seed)
    a = rng.normal(size=(h, w))
    a = gaussian_filter(a, sigma=sigma, mode="wrap")
    a -= a.mean()
    s = a.std()
    return a / s if s > 1e-9 else a


def paper_tile(c, pal, seed):
    """c x c 이어 붙일 수 있는 한지 타일 (float RGB 0..255)"""
    base = np.array(pal["paper"], dtype=np.float32)
    v = 0.040 * wnoise(c, c, 22, seed) + 0.028 * wnoise(c, c, 5, seed + 1) + 0.016 * wnoise(c, c, 1.1, seed + 2)
    img = base[None, None, :] * (1.0 + v[:, :, None])
    # 섬유: 짧고 굽은 선을 이음새 너머로도 그려 타일이 매끄럽게 이어지게 한다
    rng = np.random.default_rng(seed + 9)
    for kind, col, n, alpha in (("l", pal["fiber_l"], 120, 0.55), ("d", pal["fiber_d"], 70, 0.22)):
        layer = Image.new("L", (c * 3, c * 3), 0)
        d = ImageDraw.Draw(layer)
        for _ in range(n):
            x, y = rng.uniform(0, c), rng.uniform(0, c)
            ang = rng.uniform(0, np.pi * 2)
            pts = []
            for _s in range(rng.integers(3, 6)):
                pts.append((x, y))
                ang += rng.normal(0, 0.5)
                step = rng.uniform(3, 8)
                x += np.cos(ang) * step
                y += np.sin(ang) * step
            for ox in (0, c, 2 * c):
                for oy in (0, c, 2 * c):
                    d.line([(px + ox, py + oy) for px, py in pts], fill=int(255 * rng.uniform(0.4, 1.0)), width=1)
        layer = layer.filter(ImageFilter.GaussianBlur(0.45))
        m = np.asarray(layer, dtype=np.float32)[c:2 * c, c:2 * c] / 255.0
        img = img * (1 - alpha * m[:, :, None]) + np.array(col, dtype=np.float32)[None, None, :] * (alpha * m[:, :, None])
    return np.clip(img, 0, 255)


def extend_wrap(tile, m):
    """타일을 사방 m만큼 이어 붙여 (c+2m)^2 판으로"""
    return np.pad(tile, ((m, m), (m, m), (0, 0)), mode="wrap")


def downscale(img, factor):
    w, h = img.size
    return img.resize((w // factor, h // factor), Image.LANCZOS)


def finish_3d(rgb, alpha, pal, sh):
    """판에 입체감을 준다: 윗·왼쪽 모서리 빛, 아래·오른쪽 모서리 그늘, 바깥으로 부드러운 그림자.
    그림자 자리로 사방 sh 픽셀 투명 여백을 덧붙인다 (9분할 여백도 그만큼 늘려 써야 한다)."""
    ap = np.pad(alpha.astype(np.float32) / 255.0, sh)
    rp = np.pad(rgb, ((sh, sh), (sh, sh), (0, 0)), mode="edge")
    k = max(2, int(round(sh * 0.35)))
    hl = np.clip(ap - np.roll(ap, (k, k), (0, 1)), 0, 1)
    ds = np.clip(ap - np.roll(ap, (-k, -k), (0, 1)), 0, 1)
    hl = gaussian_filter(hl, 0.7)
    ds = gaussian_filter(ds, 0.9)
    lum = float(np.mean(pal["paper"]))
    hl_gain = 0.55 if lum > 120 else 0.30
    rp = rp + (255.0 - rp) * (hl * hl_gain)[:, :, None]
    rp = rp * (1.0 - 0.34 * ds[:, :, None])
    # 바깥 그림자: 아래로 더 길게
    shadow = np.roll(ap, (int(sh * 0.55), int(sh * 0.12)), (0, 1))
    shadow = gaussian_filter(shadow, sh * 0.42) * 0.62
    out_a = ap + shadow * (1.0 - ap)
    safe = np.maximum(out_a, 1e-4)[:, :, None]
    out_rgb = (rp * ap[:, :, None]) / safe
    out_rgb = np.where(ap[:, :, None] > 0.999, rp, out_rgb)
    return np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a, 0, 1) * 255]).astype(np.uint8)


def plate(name_prefix, pal, idx, m, c=128, big=False, sh=0):
    """9-slice 한지 판: 중앙은 이어 붙는 한지, 가장자리는 먹선 두 줄과 모서리 문양"""
    T = c + 2 * m
    seed = 100 + idx * 10
    tile = paper_tile(c, pal, seed)
    paper = extend_wrap(tile, m)  # (T,T,3)
    X, Y = np.meshgrid(np.arange(T), np.arange(T))
    dx = np.minimum(X, T - 1 - X).astype(np.float32)
    dy = np.minimum(Y, T - 1 - Y).astype(np.float32)
    d = np.minimum(dx, dy)
    # 가장자리 그을림
    burn = np.exp(-d / (m * 0.55))[:, :, None] * 0.34
    burn_col = np.array(pal["burn"], dtype=np.float32)[None, None, :]
    rgb = paper * (1 - burn) + burn_col * burn
    # 먹선 (큰 판은 두 줄, 작은 판은 두 줄을 더 가늘게)
    wob = wnoise(c, c, 3.0, seed + 5)
    wob_ext = np.pad(wob, ((m, m), (m, m)), mode="wrap")
    inv = 0.80 + 0.20 * np.clip(wob_ext, -1.5, 1.5) / 1.5  # 먹이 짙고 옅은 정도

    i1, i2 = m * 0.20, m * 0.38
    w1 = max(1.6, m * 0.085)
    w2 = max(1.0, m * 0.035)

    big_img = Image.new("L", (T * SS, T * SS), 0)
    dr = ImageDraw.Draw(big_img)

    def rect(inset, width):
        a = inset * SS
        b = (T - inset) * SS
        dr.rectangle([a, a, b, b], outline=255, width=int(width * SS))

    rect(i1, w1)
    rect(i2, w2)
    if big:
        # 꺾인 장식 (ㄱ자 겹침): 모서리 안쪽에 두 단 계단무늬
        for sx in (0, 1):
            for sy in (0, 1):
                ox = i2 + m * 0.08 if sx == 0 else T - i2 - m * 0.08
                oy = i2 + m * 0.08 if sy == 0 else T - i2 - m * 0.08
                kx = 1 if sx == 0 else -1
                ky = 1 if sy == 0 else -1
                s = m * 0.22
                pts = [(ox, oy + ky * s * 2.0), (ox, oy), (ox + kx * s * 2.0, oy)]
                dr.line([(p[0] * SS, p[1] * SS) for p in pts], fill=255, width=int(w2 * 1.4 * SS))
                pts2 = [(ox + kx * s * 0.5, oy + ky * s * 1.4), (ox + kx * s * 0.5, oy + ky * s * 0.5), (ox + kx * s * 1.4, oy + ky * s * 0.5)]
                dr.line([(p[0] * SS, p[1] * SS) for p in pts2], fill=255, width=int(w2 * SS))
    gold_img = Image.new("L", (T * SS, T * SS), 0)
    gd = ImageDraw.Draw(gold_img)
    ga = m * 0.295 * SS
    gb = (T - m * 0.295) * SS
    gd.rectangle([ga, ga, gb, gb], outline=255, width=max(1, int(max(1.0, m * 0.03) * SS)))
    gold_m = np.asarray(downscale(gold_img, SS), dtype=np.float32)[:, :, None] / 255.0 * 0.85
    ink_mask = np.asarray(downscale(big_img, SS), dtype=np.float32) / 255.0
    ink_mask = ink_mask * inv
    ink_col = np.array(pal["ink"], dtype=np.float32)[None, None, :]
    gold_col = np.array(pal["gold"], dtype=np.float32)[None, None, :]
    rgb = rgb * (1 - gold_m) + gold_col * gold_m
    rgb = rgb * (1 - ink_mask[:, :, None] * 0.96) + ink_col * (ink_mask[:, :, None] * 0.96)
    # 먹선을 새긴 듯 보이게: 선의 아래·오른쪽에 옅은 빛
    inc = np.clip(np.roll(ink_mask, (1, 1), (0, 1)) - ink_mask, 0, 1)[:, :, None]
    rgb = rgb + (255.0 - rgb) * inc * 0.35

    # 모서리 점: 주홍 마름모 + 둘레 고리
    dot = Image.new("L", (T * SS, T * SS), 0)
    dd = ImageDraw.Draw(dot)
    ring = Image.new("L", (T * SS, T * SS), 0)
    rd = ImageDraw.Draw(ring)
    r = m * 0.20
    for sx in (0, 1):
        for sy in (0, 1):
            cx = (i1 if sx == 0 else T - i1) * SS
            cy = (i1 if sy == 0 else T - i1) * SS
            R = r * SS
            dd.polygon([(cx, cy - R), (cx + R, cy), (cx, cy + R), (cx - R, cy)], fill=255)
            rd.ellipse([cx - R * 1.55, cy - R * 1.55, cx + R * 1.55, cy + R * 1.55], outline=255, width=max(1, int(w2 * SS)))
    dot_m = np.asarray(downscale(dot, SS), dtype=np.float32)[:, :, None] / 255.0
    ring_m = np.asarray(downscale(ring, SS), dtype=np.float32)[:, :, None] / 255.0 * 0.9
    seal_col = np.array(pal["seal"], dtype=np.float32)[None, None, :]
    rgb = rgb * (1 - ring_m) + ink_col * ring_m
    rgb = rgb * (1 - dot_m) + seal_col * dot_m

    # 바깥 테두리 알파: 살짝 해진 가장자리
    edge = wnoise(c, c, 2.0, seed + 7)
    edge_ext = np.pad(edge, ((m, m), (m, m)), mode="wrap")
    alpha = np.clip((d - 0.6 - 0.9 * edge_ext) / 1.4, 0, 1)
    if sh > 0:
        out = finish_3d(np.clip(rgb, 0, 255), alpha * 255, pal, sh)
    else:
        out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, f"{name_prefix}.png"))


def scroll(name_prefix, pal, idx, ml=46, rh=34, c=128, ch=96, sh_rows=10):
    """두루마리 대화창: 위아래 나무 축과 양 끝 금속 마개, 가운데 한지"""
    W = c + 2 * ml
    mt = rh + sh_rows  # 위·아래 비반복 구간: 축 + 그림자
    H = ch + 2 * mt
    seed = 300 + idx * 10
    tile_w = paper_tile(c, pal, seed)  # c x c
    tile = tile_w[:ch, :, :]  # ch x c (세로 주기 ch는 c의 부분이므로 가장자리를 맞춘다)
    # 세로로도 이어 붙게 하려면 ch 주기 잡음을 따로 만든다
    base = np.array(pal["paper"], dtype=np.float32)
    v = 0.040 * wnoise(c, ch, 20, seed + 1) + 0.028 * wnoise(c, ch, 5, seed + 2) + 0.016 * wnoise(c, ch, 1.1, seed + 3)
    tile = base[None, None, :] * (1.0 + v[:, :, None])
    mid = np.pad(tile, ((sh_rows, sh_rows), (ml, ml), (0, 0)), mode="wrap")  # (ch+2*sh_rows) x W
    # 좌우 가장자리 그을림과 안쪽 먹선
    x = np.arange(W, dtype=np.float32)
    dxe = np.minimum(x, W - 1 - x)[None, :]
    burn = np.exp(-dxe / 20.0)[:, :, None] * 0.30
    burn_col = np.array(pal["burn"], dtype=np.float32)[None, None, :]
    mid = mid * (1 - burn) + burn_col * burn
    MH = ch + 2 * sh_rows
    line = np.zeros((MH, W), dtype=np.float32)
    for xi, wd in ((ml * 0.40, 2.2), (ml * 0.40 + 5.0, 1.0)):
        for xx in (xi, W - 1 - xi):
            line += np.exp(-((np.arange(W)[None, :] - xx) ** 2) / (2 * (wd / 2.0) ** 2))
    line = np.clip(line, 0, 1) * 0.85
    ink_col = np.array(pal["ink"], dtype=np.float32)[None, None, :]
    mid = mid * (1 - line[:, :, None]) + ink_col * line[:, :, None]

    # 나무 축
    wood = np.array(pal["wood"], dtype=np.float32)
    wood_l = np.array(pal["wood_l"], dtype=np.float32)
    grain = wnoise(c, rh, (0.9, 14), seed + 20)
    grain_ext = np.pad(grain, ((0, 0), (ml, ml)), mode="wrap")
    yy = (np.arange(rh, dtype=np.float32) + 0.5) / rh
    shade = np.cos((yy - 0.42) * np.pi * 0.95)
    shade = np.clip(shade, 0, 1)[:, None]
    shade = 0.18 + 0.95 * shade
    rod = (wood[None, None, :] * (1 - shade[:, :, None] * 0.0) + (wood_l - wood)[None, None, :] * shade[:, :, None])
    rod = rod * (1 + 0.10 * np.clip(grain_ext, -2, 2)[:, :, None])
    # 마개: 양 끝 금속 띠와 둥근 끝
    cap = np.array(pal["cap"], dtype=np.float32)
    rod_full = np.broadcast_to(rod, (rh, W, 3)).copy()
    ralpha = np.ones((rh, W), dtype=np.float32)
    xs = np.arange(W)[None, :]
    for side in (0, 1):
        xe = (lambda v: v) if side == 0 else (lambda v: W - 1 - v)
        # 띠
        for b0, b1 in ((ml - 14, ml - 8), (ml - 24, ml - 21)):
            lo, hi = (b0, b1)
            if side == 1:
                lo, hi = W - 1 - b1, W - 1 - b0
            mask = ((xs >= lo) & (xs <= hi)).astype(np.float32)
            mask = np.broadcast_to(mask, (rh, W))
            band = cap[None, None, :] * (0.55 + 0.55 * shade[:, :, None])
            rod_full = rod_full * (1 - mask[:, :, None]) + band * mask[:, :, None]
    # 둥근 끝 (타원 마스크)
    for side in (0, 1):
        cxp = 7.0 if side == 0 else W - 8.0
        ex = (xs - cxp) / 7.0
        ey = (np.arange(rh)[:, None] - rh / 2 + 0.5) / (rh / 2)
        inside = ex ** 2 + ey ** 2 <= 1.0
        far = (xs < cxp) if side == 0 else (xs > cxp)
        ralpha = np.where(far & ~inside, 0.0, ralpha)
    # 축 아래 그림자: 반복되지 않는 위·아래 구간에만 넣는다
    ys = np.arange(MH, dtype=np.float32)
    sh = np.exp(-ys / 5.0) + np.exp(-(MH - 1 - ys) / 5.0)
    sh = np.where((ys < sh_rows) | (ys >= MH - sh_rows), sh, 0.0)[:, None] * 0.30
    mid = mid * (1 - sh[:, :, None])
    # 합치기
    out = np.zeros((H, W, 4), dtype=np.float32)
    out[rh:H - rh, :, :3] = mid
    out[rh:H - rh, :, 3] = 255
    top = np.dstack([rod_full, ralpha * 255])
    out[0:rh] = top
    out[H - rh:H] = top[::-1]
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, f"{name_prefix}.png"))


def brush(name, w=256, h=28, seed=1, dry=0.55, taper=True):
    """흰색 붓획 (알파만 의미 있음). 색은 modulate로 입힌다."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cy = h / 2 + 1.4 * np.sin(xx / 38.0 + seed) + 0.8 * np.sin(xx / 13.0 + seed * 2)
    thick = h * 0.50 + 2.6 * np.sin(xx / 21.0 + seed * 3) + 1.5 * wnoise(w, 1, 6, seed + 3)[0][None, :]
    # 시작의 둥근 머리
    thick = thick + 4.5 * np.exp(-xx / 9.0)
    # 가장자리 거칠기
    rough = gaussian_filter(rng.normal(size=(h, w)), sigma=(0.8, 2.5), mode="nearest") * 1.4
    dist = np.abs(yy - cy)
    body = (thick / 2 + rough - dist)
    alpha = np.clip(body / 1.2, 0, 1)
    # 끝: 붓털이 갈라지며 끊긴다
    if taper:
        # 줄(행)마다 끝나는 위치가 다르다
        rows = rng.uniform(0, 1, size=h)
        rows = gaussian_filter(rows, 0.8)
        rows = (rows - rows.min()) / (rows.max() - rows.min() + 1e-6)
        end = w - 6 - rows * (w * 0.18)
        alpha = alpha * np.clip((end[:, None] - xx) / 3.0, 0, 1)
    # 마른 붓: 가로 줄무늬가 오른쪽으로 갈수록 짙다
    streak = gaussian_filter(rng.uniform(size=(h, w)), sigma=(0.7, 14.0), mode="nearest")
    streak = (streak - streak.min()) / (streak.max() - streak.min() + 1e-6)
    gain = np.clip(xx / w, 0, 1) ** 1.4 * dry
    alpha = alpha * (1 - gain * (streak > 0.52) * 0.8 * streak)
    # 먹이 고인 곳: 약간의 농담
    pool = 0.9 + 0.1 * wnoise(w, h, 3, seed + 8)
    alpha = np.clip(alpha * pool, 0, 1)
    img = np.dstack([np.full((h, w), 255, np.uint8), np.full((h, w), 255, np.uint8), np.full((h, w), 255, np.uint8), (alpha * 255).astype(np.uint8)])
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))


def seal_img(name, pal, text, size=96, seed=1):
    big = size * SS
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    pad = int(size * 0.04 * SS)
    d.rounded_rectangle([pad, pad, big - pad, big - pad], radius=int(size * 0.05 * SS), fill=255)
    inset = int(size * 0.075 * SS)
    d.rounded_rectangle([inset, inset, big - inset, big - inset], radius=int(size * 0.03 * SS), outline=0, width=max(2, int(size * 0.03 * SS)))
    font = None
    for path, index in (("/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc", 1), ("/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc", 0)):
        try:
            font = ImageFont.truetype(path, int(size * (0.50 if len(text) == 1 else 0.36) * SS), index=index)
            break
        except Exception:
            continue
    if font is None:
        font = ImageFont.load_default()
    if len(text) == 1:
        bb = d.textbbox((0, 0), text, font=font)
        d.text(((big - (bb[2] - bb[0])) / 2 - bb[0], (big - (bb[3] - bb[1])) / 2 - bb[1]), text, font=font, fill=0)
    else:
        # 세로로 두 글자
        for i, ch in enumerate(text[:2]):
            bb = d.textbbox((0, 0), ch, font=font)
            cx = big / 2
            cy = big * (0.30 + 0.40 * i)
            d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), ch, font=font, fill=0)
    m = np.asarray(downscale(img, SS), dtype=np.float32) / 255.0
    rng = np.random.default_rng(seed)
    # 인주가 고르지 않게 묻고 가장자리가 해진다
    blotch = 0.88 + 0.12 * wnoise(size, size, 2.5, seed)
    speck = (gaussian_filter(rng.uniform(size=(size, size)), 0.6) > 0.80).astype(np.float32) * 0.45
    edge_noise = gaussian_filter(rng.normal(size=(size, size)), 1.2) * 0.9
    m = np.clip(m + edge_noise * 0.25 * (m > 0.05) * (m < 0.98), 0, 1)
    m = np.clip(m * blotch * (1 - speck), 0, 1)
    col = np.array(pal["seal"], dtype=np.uint8)
    out = np.dstack([np.full((size, size), col[0], np.uint8), np.full((size, size), col[1], np.uint8), np.full((size, size), col[2], np.uint8), (m * 235).astype(np.uint8)])
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, name))


def divider(name, pal, w=256, h=24, seed=1):
    """구름무늬(서운문) 구분선: 반원 물결과 작은 소용돌이"""
    S = 4
    img = Image.new("L", (w * S, h * S), 0)
    d = ImageDraw.Draw(img)
    cy = h * S / 2
    period = 32
    R = 7 * S
    lw = int(1.6 * S)
    for k in range(w // period + 1):
        cx = (k * period + period / 2) * S
        # 위로 볼록한 구름 윗선 세 겹
        d.arc([cx - R, cy - R, cx + R, cy + R], 180, 360, fill=255, width=lw)
        r2 = R * 0.55
        d.arc([cx - r2, cy - r2, cx + r2, cy + r2], 180, 360, fill=255, width=lw)
        # 양옆 꼬리
        d.line([cx - R - 5 * S, cy, cx - R, cy], fill=255, width=lw)
        d.line([cx + R, cy, cx + R + 5 * S, cy], fill=255, width=lw)
        d.ellipse([cx - 1.6 * S, cy - 1.6 * S, cx + 1.6 * S, cy + 1.6 * S], fill=255)
    a = np.asarray(downscale(img, S), dtype=np.float32) / 255.0
    a = a * (0.78 + 0.22 * wnoise(w, h, 4, seed))
    col = np.array(pal["ink2"], dtype=np.uint8)
    out = np.dstack([np.full((h, w), col[0], np.uint8), np.full((h, w), col[1], np.uint8), np.full((h, w), col[2], np.uint8), (np.clip(a, 0, 1) * 255).astype(np.uint8)])
    Image.fromarray(out, "RGBA").save(os.path.join(OUT, name))


def main():
    for i, pal in enumerate(PALETTES):
        plate(f"t{i}_plate_s", pal, i, m=22, big=False, sh=SH_S)
        plate(f"t{i}_plate_l", pal, i, m=40, big=True, sh=SH_L)
        scroll(f"t{i}_scroll", pal, i)
        seal_img(f"t{i}_seal_gil.png", pal, "路", seed=3 + i)
        seal_img(f"t{i}_seal_saeng.png", pal, "生", seed=11 + i)
        seal_img(f"t{i}_seal_wi.png", pal, "危", seed=21 + i)
        divider(f"t{i}_divider.png", pal, seed=5 + i)
    brush("brush_fill.png", seed=4, dry=0.7)
    brush("brush_track.png", seed=9, dry=0.15, taper=False)
    print("done ->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
