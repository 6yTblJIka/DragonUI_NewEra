#!/usr/bin/env python3
"""Repack an uncompressed (BGRA) BLP2 to power-of-two dimensions, the way this client needs it.

WHY THIS EXISTS
---------------
The 3.3.5a client renders a BLP it cannot sample as SOLID BRIGHT GREEN — no error, no fallback.
Two container properties decide it, and retail-extracted art routinely violates both:

  * NON-POWER-OF-TWO width or height. 822 of the 829 BLPs this addon ships are power-of-two; the
    exceptions were the four Details!-skin regions this script was written for (they came out of
    retail's `Blizzard_DamageMeter` sheets already cropped to their art, e.g. 280x28) and two
    profession-book files that predate it.
  * A MISSING PALETTE BLOCK. BLP2's 1024-byte (256 x BGRA) palette sits between the 148-byte header
    and the first mip, and is dead weight for an uncompressed BGRA image — so a writer may skip it
    and put mip 0 at offset 148. Every BLP that works in game here has it and starts mip 0 at 1172.

Art that is STRETCHED at draw time (a status-bar fill, a header band, a backdrop) can simply be
resampled to the nearest sensible power of two: the client stretches it to the frame either way, so
the resample is invisible. Art read through texcoords must NOT go through this — padding would move
every rect. That is why this takes explicit target sizes rather than guessing.

USAGE
-----
    python tools/blp/repack_pot.py --info  Textures/DetailsSkin/*.blp
    python tools/blp/repack_pot.py --png   Textures/DetailsSkin/7499559-dm-header.blp out.png
    python tools/blp/repack_pot.py --resize 256x32 Textures/DetailsSkin/7499559-dm-header.blp

`--resize` rewrites the file in place (POT dimensions, palette block, no mips, comp=3/aDepth=8/
aType=8 — byte-for-byte the shape of the addon's working BGRA art). `--png` is for eyeballing the
result; it needs no third-party module (zlib + struct only).
"""

import argparse
import os
import struct
import sys
import zlib

HDR = 148
PALETTE = 1024
MIP0 = HDR + PALETTE


def is_pot(n):
    return n > 0 and (n & (n - 1)) == 0


def read_blp(path):
    """-> (width, height, bytearray of BGRA rows). Uncompressed BLP2 only."""
    with open(path, "rb") as fh:
        blob = fh.read()
    if blob[:4] != b"BLP2":
        raise ValueError(f"{path}: not a BLP2 file")
    comp, alpha_depth, alpha_type, has_mips = blob[8], blob[9], blob[10], blob[11]
    if comp != 3:
        raise ValueError(f"{path}: compression {comp} is not uncompressed BGRA (3); "
                         "this script does not decode DXT")
    w, h = struct.unpack_from("<II", blob, 12)
    off0, = struct.unpack_from("<I", blob, 20)
    size0, = struct.unpack_from("<I", blob, 84)
    want = w * h * 4
    if size0 and size0 != want:
        raise ValueError(f"{path}: mip 0 is {size0} bytes, expected {want} for {w}x{h}")
    px = bytearray(blob[off0:off0 + want])
    if len(px) != want:
        raise ValueError(f"{path}: truncated pixel data ({len(px)} of {want})")
    return w, h, px, (comp, alpha_depth, alpha_type, has_mips, off0)


def resample(src, sw, sh, dw, dh):
    """Bilinear, on premultiplied-by-nothing BGRA. Small images, so clarity over speed."""
    dst = bytearray(dw * dh * 4)
    x_ratio = sw / dw
    y_ratio = sh / dh
    for dy in range(dh):
        fy = (dy + 0.5) * y_ratio - 0.5
        y0 = int(fy) if fy >= 0 else 0
        y1 = min(y0 + 1, sh - 1)
        wy = max(0.0, fy - y0)
        for dx in range(dw):
            fx = (dx + 0.5) * x_ratio - 0.5
            x0 = int(fx) if fx >= 0 else 0
            x1 = min(x0 + 1, sw - 1)
            wx = max(0.0, fx - x0)
            i00 = (y0 * sw + x0) * 4
            i01 = (y0 * sw + x1) * 4
            i10 = (y1 * sw + x0) * 4
            i11 = (y1 * sw + x1) * 4
            o = (dy * dw + dx) * 4
            for c in range(4):
                top = src[i00 + c] * (1 - wx) + src[i01 + c] * wx
                bot = src[i10 + c] * (1 - wx) + src[i11 + c] * wx
                dst[o + c] = int(top * (1 - wy) + bot * wy + 0.5)
    return dst


def write_blp(path, w, h, px):
    """BLP2, uncompressed BGRA, one mip, WITH the palette block — the shape that works in game."""
    hdr = bytearray(HDR)
    hdr[0:4] = b"BLP2"
    struct.pack_into("<I", hdr, 4, 1)     # type: direct
    hdr[8] = 3                            # compression: uncompressed BGRA
    hdr[9] = 8                            # alpha depth
    hdr[10] = 8                           # alpha type
    hdr[11] = 0                           # no mips
    struct.pack_into("<II", hdr, 12, w, h)
    struct.pack_into("<I", hdr, 20, MIP0)          # mipOffsets[0]
    struct.pack_into("<I", hdr, 84, len(px))       # mipSizes[0]
    with open(path, "wb") as fh:
        fh.write(hdr)
        fh.write(b"\0" * PALETTE)   # unused for BGRA, but every working file here carries it
        fh.write(px)


def write_png(path, w, h, px):
    """BGRA -> RGBA PNG. For looking at the art; nothing in the addon reads this."""
    rows = bytearray()
    for y in range(h):
        rows.append(0)  # filter: none
        row = px[y * w * 4:(y + 1) * w * 4]
        for x in range(w):
            b, g, r, a = row[x * 4:x * 4 + 4]
            rows += bytes((r, g, b, a))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", ihdr))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(rows), 9)))
        fh.write(chunk(b"IEND", b""))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--info", action="store_true", help="report dimensions / container layout")
    ap.add_argument("--png", metavar="OUT", help="decode the single input to a PNG and stop")
    ap.add_argument("--resize", metavar="WxH", help="resample in place to these POT dimensions")
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()

    if args.png:
        w, h, px, _ = read_blp(args.files[0])
        write_png(args.png, w, h, px)
        print(f"{args.files[0]} -> {args.png} ({w}x{h})")
        return 0

    if args.resize:
        dw, dh = (int(v) for v in args.resize.lower().split("x"))
        if not (is_pot(dw) and is_pot(dh)):
            print(f"refusing {dw}x{dh}: both dimensions must be powers of two", file=sys.stderr)
            return 2
        for path in args.files:
            w, h, px, _ = read_blp(path)
            out = px if (w, h) == (dw, dh) else resample(px, w, h, dw, dh)
            write_blp(path, dw, dh, out)
            print(f"{os.path.basename(path):38s} {w}x{h} -> {dw}x{dh}  "
                  f"({os.path.getsize(path)} bytes)")
        return 0

    for path in args.files:
        w, h, px, (comp, ad, at, mips, off0) = read_blp(path)
        flag = "" if (is_pot(w) and is_pot(h)) else "  <- NOT power-of-two"
        pal = "" if off0 == MIP0 else f"  <- no palette block (mip0 at {off0})"
        print(f"{os.path.basename(path):38s} {w}x{h} comp={comp} aDepth={ad} aType={at} "
              f"mips={mips}{flag}{pal}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
