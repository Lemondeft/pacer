#!/usr/bin/env python3
"""Generate standalone printable SVG and PNG QR codes for Pacer's download page.

Pure-Python ISO/IEC 18004 QR encoder (Byte mode, Error Correction Level M,
versions 1..12) + Pillow PNG output. Zero third-party QR packages required.

Usage:
  python3 scripts/generate_download_qr.py
  python3 scripts/generate_download_qr.py --url https://lemondeft.github.io/pacer/ --verify
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image

DEFAULT_URL = "https://lemondeft.github.io/pacer/"
REPO_ROOT = Path(__file__).resolve().parent.parent
OUT_SVG = REPO_ROOT / "docs" / "assets" / "pacer-download-qr.svg"
OUT_PNG = REPO_ROOT / "docs" / "assets" / "pacer-download-qr.png"
JS_QR_PATH = REPO_ROOT / "docs" / "qr.js"

# Official ISO/IEC 18004 Level M tables for versions 1..12:
# (total_codewords, ec_per_block, g1_blocks, g1_data, g2_blocks, g2_data)
VERSION_M: list[tuple[int, int, int, int, int, int] | None] = [
    None,
    (26, 10, 1, 16, 0, 0),
    (44, 16, 1, 28, 0, 0),
    (70, 26, 1, 44, 0, 0),
    (100, 18, 2, 32, 0, 0),
    (134, 24, 2, 43, 0, 0),
    (172, 16, 4, 27, 0, 0),
    (196, 18, 4, 31, 0, 0),
    (242, 22, 2, 38, 2, 39),
    (292, 22, 3, 36, 2, 37),
    (346, 26, 4, 43, 1, 44),
    (404, 30, 1, 50, 4, 51),
    (466, 22, 6, 36, 2, 37),
]

ALIGNMENT: list[list[int] | None] = [
    None,
    [],
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
    [6, 22, 38],
    [6, 24, 42],
    [6, 26, 46],
    [6, 28, 50],
    [6, 30, 54],
    [6, 32, 58],
]

# GF(256) with primitive polynomial 0x11d
GF_EXP = [0] * 512
GF_LOG = [0] * 256
_x = 1
for _i in range(255):
    GF_EXP[_i] = _x
    GF_LOG[_x] = _i
    _x <<= 1
    if _x & 0x100:
        _x ^= 0x11D
for _j in range(255, 512):
    GF_EXP[_j] = GF_EXP[_j - 255]


def gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return GF_EXP[GF_LOG[a] + GF_LOG[b]]


def rs_generator(degree: int) -> list[int]:
    poly = [1]
    for i in range(degree):
        nxt = [0] * (len(poly) + 1)
        factor = GF_EXP[i]
        for j, coeff in enumerate(poly):
            nxt[j] ^= coeff
            nxt[j + 1] ^= gf_mul(coeff, factor)
        poly = nxt
    return poly


def rs_remainder(data: list[int], ec_count: int) -> list[int]:
    gen = rs_generator(ec_count)
    rem = [0] * ec_count
    for b in data:
        factor = b ^ rem[0]
        rem = rem[1:] + [0]
        if factor != 0:
            for j in range(ec_count):
                rem[j] ^= gf_mul(gen[j + 1], factor)
    return rem


def choose_version(byte_len: int) -> int:
    for v in range(1, len(VERSION_M)):
        spec = VERSION_M[v]
        assert spec is not None
        data_cws = spec[2] * spec[3] + spec[4] * spec[5]
        len_bits = 8 if v < 10 else 16
        cap = (data_cws * 8 - 4 - len_bits) // 8
        if byte_len <= cap:
            return v
    raise ValueError(f"Payload too long for version 12 Level M ({byte_len} bytes)")


def build_codewords(payload: bytes, version: int) -> list[int]:
    spec = VERSION_M[version]
    assert spec is not None
    _, ec_per_block, g1_cnt, g1_data, g2_cnt, g2_data = spec
    total_data_cws = g1_cnt * g1_data + g2_cnt * g2_data

    bits: list[int] = []

    def push_bits(val: int, count: int) -> None:
        for i in range(count - 1, -1, -1):
            bits.append((val >> i) & 1)

    push_bits(0x4, 4)  # Byte mode
    push_bits(len(payload), 8 if version < 10 else 16)
    for b in payload:
        push_bits(b, 8)

    max_bits = total_data_cws * 8
    push_bits(0, min(4, max_bits - len(bits)))
    while len(bits) % 8 != 0:
        bits.append(0)

    data_cws: list[int] = []
    for i in range(0, len(bits), 8):
        val = 0
        for bit in bits[i : i + 8]:
            val = (val << 1) | bit
        data_cws.append(val)

    pad_bytes = (0xEC, 0x11)
    p = 0
    while len(data_cws) < total_data_cws:
        data_cws.append(pad_bytes[p % 2])
        p += 1

    data_blocks: list[list[int]] = []
    ec_blocks: list[list[int]] = []
    off = 0
    for _ in range(g1_cnt):
        blk = data_cws[off : off + g1_data]
        off += g1_data
        data_blocks.append(blk)
        ec_blocks.append(rs_remainder(blk, ec_per_block))
    for _ in range(g2_cnt):
        blk = data_cws[off : off + g2_data]
        off += g2_data
        data_blocks.append(blk)
        ec_blocks.append(rs_remainder(blk, ec_per_block))

    interleaved: list[int] = []
    max_data = max(g1_data, g2_data)
    for d in range(max_data):
        for blk in data_blocks:
            if d < len(blk):
                interleaved.append(blk[d])
    for e in range(ec_per_block):
        for ec in ec_blocks:
            interleaved.append(ec[e])
    return interleaved


def format_bits(mask: int) -> int:
    data = (0x0 << 3) | mask  # Level M = 00
    rem = data
    for _ in range(10):
        rem = (rem << 1) ^ ((rem >> 9) * 0x537)
    return ((data << 10) | rem) ^ 0x5412


def version_bits(version: int) -> int:
    rem = version
    for _ in range(12):
        rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
    return (version << 12) | rem


def mask_bit(mask: int, r: int, c: int) -> bool:
    if mask == 0:
        return (r + c) % 2 == 0
    if mask == 1:
        return r % 2 == 0
    if mask == 2:
        return c % 3 == 0
    if mask == 3:
        return (r + c) % 3 == 0
    if mask == 4:
        return ((r // 2) + (c // 3)) % 2 == 0
    if mask == 5:
        return ((r * c) % 2) + ((r * c) % 3) == 0
    if mask == 6:
        return (((r * c) % 2) + ((r * c) % 3)) % 2 == 0
    return (((r + c) % 2) + ((r * c) % 3)) % 2 == 0


def penalty_score(modules: list[list[int]], size: int) -> int:
    score = 0
    for r in range(size):
        run_c, run_l = modules[r][0], 1
        for c in range(1, size):
            if modules[r][c] == run_c:
                run_l += 1
                if run_l == 5:
                    score += 3
                elif run_l > 5:
                    score += 1
            else:
                run_c, run_l = modules[r][c], 1

    for c in range(size):
        run_c, run_l = modules[0][c], 1
        for r in range(1, size):
            if modules[r][c] == run_c:
                run_l += 1
                if run_l == 5:
                    score += 3
                elif run_l > 5:
                    score += 1
            else:
                run_c, run_l = modules[r][c], 1

    for r in range(size - 1):
        for c in range(size - 1):
            v = modules[r][c]
            if v == modules[r][c + 1] == modules[r + 1][c] == modules[r + 1][c + 1]:
                score += 3

    pat1 = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0]
    pat2 = [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1]
    for r in range(size):
        row = modules[r]
        for i in range(size - 10):
            seg = row[i : i + 11]
            if seg == pat1 or seg == pat2:
                score += 40
    for c in range(size):
        col = [modules[r][c] for r in range(size)]
        for i in range(size - 10):
            seg = col[i : i + 11]
            if seg == pat1 or seg == pat2:
                score += 40

    dark = sum(sum(row) for row in modules)
    k = abs(dark * 20 - size * size * 10) // (size * size)
    score += k * 10
    return score


def encode_matrix(text: str) -> tuple[int, int, list[list[int]]]:
    payload = text.encode("utf-8")
    version = choose_version(len(payload))
    codewords = build_codewords(payload, version)
    size = version * 4 + 17
    modules = [[0] * size for _ in range(size)]
    is_func = [[False] * size for _ in range(size)]

    def set_func(r: int, c: int, val: bool) -> None:
        if 0 <= r < size and 0 <= c < size:
            modules[r][c] = 1 if val else 0
            is_func[r][c] = True

    def place_finder(top: int, left: int) -> None:
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                r, c = top + dr, left + dc
                if 0 <= r < size and 0 <= c < size:
                    in_outer = 0 <= dr <= 6 and 0 <= dc <= 6
                    border = dr in (0, 6) or dc in (0, 6)
                    center = 2 <= dr <= 4 and 2 <= dc <= 4
                    set_func(r, c, in_outer and (border or center))

    place_finder(0, 0)
    place_finder(0, size - 7)
    place_finder(size - 7, 0)

    for i in range(8, size - 8):
        set_func(6, i, i % 2 == 0)
        set_func(i, 6, i % 2 == 0)

    centers = ALIGNMENT[version] or []
    last_idx = len(centers) - 1
    for ai, cr in enumerate(centers):
        for aj, cc in enumerate(centers):
            if (ai == 0 and aj == 0) or (ai == 0 and aj == last_idx) or (ai == last_idx and aj == 0):
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    d = max(abs(dr), abs(dc))
                    set_func(cr + dr, cc + dc, d in (0, 2))

    for f in range(9):
        if f != 6:
            set_func(8, f, False)
            set_func(f, 8, False)
    for f2 in range(8):
        set_func(8, size - 1 - f2, False)
        if f2 < 7:
            set_func(size - 1 - f2, 8, False)
    set_func(size - 8, 8, True)

    if version >= 7:
        vbits = version_bits(version)
        for vb in range(18):
            bit = ((vbits >> vb) & 1) == 1
            vr, vc = vb // 3, size - 11 + (vb % 3)
            set_func(vr, vc, bit)
            set_func(vc, vr, bit)

    # Zigzag data placement
    bit_idx = 0
    total_bits = len(codewords) * 8
    upward = True
    right = size - 1
    while right >= 1:
        if right == 6:
            right = 5
        for step in range(size):
            r = (size - 1 - step) if upward else step
            for dx in (0, 1):
                c = right - dx
                if not is_func[r][c]:
                    bit = 0
                    if bit_idx < total_bits:
                        bit = (codewords[bit_idx >> 3] >> (7 - (bit_idx & 7))) & 1
                        bit_idx += 1
                    modules[r][c] = bit
        upward = not upward
        right -= 2

    best_mask = 0
    best_score = 10**12
    best_modules: list[list[int]] = []

    for mask in range(8):
        cand = [row[:] for row in modules]
        for r in range(size):
            for c in range(size):
                if not is_func[r][c] and mask_bit(mask, r, c):
                    cand[r][c] ^= 1
        fb = format_bits(mask)
        for i in range(6):
            cand[8][i] = (fb >> (14 - i)) & 1
        cand[8][7] = (fb >> 8) & 1
        cand[8][8] = (fb >> 7) & 1
        cand[7][8] = (fb >> 6) & 1
        for j in range(9, 15):
            cand[14 - j][8] = (fb >> (14 - j)) & 1
        for k in range(7):
            cand[size - 1 - k][8] = (fb >> (14 - k)) & 1
        for m in range(8):
            cand[8][size - 8 + m] = (fb >> (7 - m)) & 1

        sc = penalty_score(cand, size)
        if sc < best_score:
            best_score = sc
            best_mask = mask
            best_modules = cand

    return version, best_mask, best_modules


def write_svg(url: str, modules: list[list[int]], out_path: Path, quiet: int = 4) -> None:
    size = len(modules)
    total = size + quiet * 2
    cmds: list[str] = []
    for r in range(size):
        c = 0
        while c < size:
            if modules[r][c]:
                start = c
                while c < size and modules[r][c]:
                    c += 1
                cmds.append(f"M{start + quiet},{r + quiet}h{c - start}v1h-{c - start}z")
            else:
                c += 1
    safe = (
        url.replace("&", "&amp;")
        .replace('"', "&quot;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total} {total}" '
        f'width="512" height="512" role="img" aria-label="QR code for {safe}" '
        f'shape-rendering="crispEdges">\n'
        f'  <rect width="{total}" height="{total}" fill="#FFFFFF"/>\n'
        f'  <path fill="#0F172A" d="{"".join(cmds)}"/>\n'
        f"</svg>\n"
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(svg, encoding="utf-8")


def write_png(modules: list[list[int]], out_path: Path, quiet: int = 4, target_px: int = 1024) -> None:
    size = len(modules)
    total = size + quiet * 2
    img = Image.new("RGB", (total, total), (255, 255, 255))
    px = img.load()
    assert px is not None
    for r in range(size):
        for c in range(size):
            if modules[r][c]:
                px[c + quiet, r + quiet] = (15, 23, 42)  # #0F172A high-contrast dark navy
    scale = max(1, target_px // total)
    final_size = total * scale
    img = img.resize((final_size, final_size), Image.Resampling.NEAREST)
    # Pad cleanly to exact target_px x target_px white square so quiet zone stays even
    if final_size < target_px:
        canvas = Image.new("RGB", (target_px, target_px), (255, 255, 255))
        offset = (target_px - final_size) // 2
        canvas.paste(img, (offset, offset))
        img = canvas
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, format="PNG", optimize=True)


def verify_js_parity(urls: list[str]) -> None:
    for url in urls:
        v_py, m_py, mod_py = encode_matrix(url)
        js_code = (
            f"const qr = require({json.dumps(str(JS_QR_PATH))});"
            f"const res = qr.encodeMatrix({json.dumps(url)});"
            "console.log(JSON.stringify({version: res.version, mask: res.mask, "
            "modules: res.modules.map(r => Array.from(r))}));"
        )
        out = subprocess.check_output(["node", "-e", js_code], text=True)
        res_js = json.loads(out)
        assert res_js["version"] == v_py, f"Version mismatch for {url}: JS={res_js['version']} PY={v_py}"
        assert res_js["mask"] == m_py, f"Mask mismatch for {url}: JS={res_js['mask']} PY={m_py}"
        assert res_js["modules"] == mod_py, f"Matrix mismatch for {url}"
        print(f"PARITY OK: v{v_py} mask={m_py} ({len(mod_py)}x{len(mod_py)}) -> {url}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Pacer download page QR assets.")
    parser.add_argument("--url", default=DEFAULT_URL, help="Target URL encoded into standalone QR files.")
    parser.add_argument("--verify", action="store_true", help="Verify exact matrix parity against docs/qr.js.")
    args = parser.parse_args()

    version, mask, modules = encode_matrix(args.url)
    write_svg(args.url, modules, OUT_SVG)
    write_png(modules, OUT_PNG)
    print(f"Generated {OUT_SVG} & {OUT_PNG} (QR v{version}, mask {mask}, {len(modules)}x{len(modules)} modules)")

    if args.verify:
        verify_js_parity([
            args.url,
            "https://github.com/Lemondeft/pacer/releases/download/v0.2.15/pacer-v0.2.15-android.apk",
        ])


if __name__ == "__main__":
    main()
