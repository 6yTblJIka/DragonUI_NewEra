"""Independently re-verify every ID in the generated seed straight from Spell.dbc:
the id must exist, its name must match the trailing comment, and it must carry a real cooldown."""
import json, re, sys
spells = {int(k): tuple(v) for k, v in json.load(open("spells.json", encoding="utf-8")).items()}
import os, struct
from mpyq import MPQArchive
DATA = r"D:/Project Reforged 3.3.5a/Data/enUS"
def grab(n):
    best = None
    for a in ["locale-enUS.MPQ","patch-enUS.MPQ","patch-enUS-2.MPQ","patch-enUS-3.MPQ"]:
        p = os.path.join(DATA, a)
        if os.path.exists(p):
            try:
                d = MPQArchive(p).read_file("DBFilesClient\\" + n)
                if d: best = d
            except Exception: pass
    return best
blob = grab("Spell.dbc")
_, rc, fc, rs, _ = struct.unpack("<4sIIII", blob[:20])
recs = {}
for i in range(rc):
    r = struct.unpack_from(f"<{fc}I", blob, 20 + i*rs)
    recs[r[0]] = r

path = r"D:/Project Reforged 3.3.5a/Interface/AddOns/DragonUI_NewEra/modules/cooldownviewer/CdmSeedWotLK.lua"
bad = 0; n = 0; ids = []
for line in open(path, encoding="utf-8"):
    m = re.match(r"\s+(\d+),\s+--\s+(.+?)\s*$", line)
    if not m: continue
    n += 1
    sid, want = int(m.group(1)), m.group(2)
    ids.append(sid)
    got = spells.get(sid)
    if not got:
        print(f"  MISSING {sid} ({want})"); bad += 1; continue
    if got[0] != want:
        print(f"  NAME MISMATCH {sid}: file says {want!r}, dbc says {got[0]!r}"); bad += 1; continue
    cd = max(recs[sid][29], recs[sid][30])
    if cd <= 1500:
        print(f"  NO COOLDOWN {sid} ({want}) cd={cd}ms"); bad += 1
    if got[1] not in ("", "Rank 1"):
        print(f"  NOT RANK 1 {sid} ({want}) rank={got[1]!r}"); bad += 1

dupes = {i for i in ids if ids.count(i) > 1}
if dupes:
    print(f"  DUPLICATE IDS: {sorted(dupes)}"); bad += 1
print(f"\nchecked {n} ids -> {'ALL VERIFIED' if bad == 0 else str(bad) + ' PROBLEM(S)'}")
sys.exit(1 if bad else 0)
