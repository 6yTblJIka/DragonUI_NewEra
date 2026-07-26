import os, struct, json, re, collections
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

sblob = grab("Spell.dbc")
magic, rc, fc, rs, sbs = struct.unpack("<4sIIII", sblob[:20])
srecs = [struct.unpack_from(f"<{fc}I", sblob, 20 + i*rs) for i in range(rc)]
sb = sblob[20+rc*rs : 20+rc*rs+sbs]
def s(o):
    if o <= 0 or o >= len(sb): return ""
    e = sb.find(b"\0", o); return sb[o:e].decode("utf-8","ignore")
NAME, RANK, REC, CAT = 136, 153, 29, 30
spell = {r[0]: (s(r[NAME]), s(r[RANK]), max(r[REC], r[CAT])) for r in srecs}

ablob = grab("SkillLineAbility.dbc")
_, arc, afc, ars, _ = struct.unpack("<4sIIII", ablob[:20])
arecs = [struct.unpack_from(f"<{afc}I", ablob, 20 + i*ars) for i in range(arc)]

CLASS_BY_ID = {1:"WARRIOR",2:"PALADIN",3:"HUNTER",4:"ROGUE",5:"PRIEST",6:"DEATHKNIGHT",
               7:"SHAMAN",8:"MAGE",9:"WARLOCK",11:"DRUID"}
votes = collections.defaultdict(collections.Counter)
for r in arecs:
    for cid, cname in CLASS_BY_ID.items():
        if r[4] & (1 << (cid-1)): votes[r[1]][cname] += 1
skill2class = {k: v.most_common(1)[0][0] for k, v in votes.items() if v}

def ranknum(rk):
    m = re.search(r"(\d+)\s*$", rk or "")
    return int(m.group(1)) if m else 0

# class -> name -> candidate ids
cand = collections.defaultdict(lambda: collections.defaultdict(set))
for r in arecs:
    cls = skill2class.get(r[1])
    if not cls: continue
    nm = spell.get(r[2])
    if nm and nm[0]: cand[cls][nm[0]].add(r[2])

# Resolve each name to the RANK-1 CASTABLE id: must have a real cooldown (>1.5s), lowest rank,
# then lowest id. Spells with no cooldown are triggers/passives and are never what we want.
resolved = {}
listing  = {}
for cls, byname in cand.items():
    resolved[cls] = {}
    rows = []
    for nm, ids in byname.items():
        withcd = [(ranknum(spell[i][1]), i, spell[i][2]) for i in ids if spell[i][2] > 1500]
        if not withcd: continue
        withcd.sort()
        _, best, cdms = withcd[0]
        resolved[cls][nm] = best
        rows.append((cdms, nm, best))
    rows.sort(key=lambda t: -t[0])
    listing[cls] = rows

json.dump(resolved, open("resolved.json","w",encoding="utf-8"))
print("resolved (name -> rank1 castable id, cooldown > 1.5s):")
for cls in sorted(listing): print(f"  {cls:12s} {len(listing[cls]):3d} abilities")
with open("listing.txt","w",encoding="utf-8") as f:
    for cls in sorted(listing):
        f.write(f"\n===== {cls} =====\n")
        for cdms, nm, sid in listing[cls]:
            f.write(f"  {cdms/1000:8.1f}s  {sid:6d}  {nm}\n")
print("wrote listing.txt")
