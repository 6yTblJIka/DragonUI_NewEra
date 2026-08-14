"""Line-ending-aware literal patcher used to drive the localisation pass.

The addon's Lua sources are CRLF; patterns are written here with plain \n. Normalising on read and
restoring the file's own ending on write keeps the diffs to the lines actually changed.
"""

import io


def patch(path, subs, once=True):
    raw = io.open(path, encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    s = raw.replace("\r\n", "\n")
    for old, new in subs:
        if old not in s:
            raise AssertionError("%s: no match for %r" % (path, old[:90]))
        s = s.replace(old, new, 1 if once else -1)
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(path, "w", encoding="utf-8", newline="").write(s)
    return len(subs)


def bind_seam(path, after="if not NE then return end", name="L", expr="NE.L"):
    """Add `local L = NE.L` at file scope if the file doesn't already bind the seam.

    Refuses when the file already uses that name for something else. modules/lfg/Window.lua binds
    `local L = NE.lfg`, and silently adding a second `local L` there shadows the seam with the
    module table -- every lookup then returns nil instead of a string, with no error to notice.
    """
    import re
    raw = io.open(path, encoding="utf-8", newline="").read()
    crlf = "\r\n" in raw
    s = raw.replace("\r\n", "\n")
    if "local %s = %s" % (name, expr) in s:
        return False
    clash = re.search(r"^\s*local %s\s*=\s*(?!%s)(\S+)" % (name, re.escape(expr)), s, re.M)
    if clash:
        raise AssertionError(
            "%s: `%s` is already bound to %s; pick another name for the seam"
            % (path, name, clash.group(1)))
    # Anchor on a real statement, not a mention of one inside a comment -- core/FrameUtil.lua
    # documents its own `local NE = DragonUI_NewEra` line in the file header, and anchoring there
    # splices the binding into prose.
    at = -1
    for m in re.finditer(re.escape(after), s):
        line = s[s.rfind("\n", 0, m.start()) + 1:m.start()]
        if not line.lstrip().startswith("--") and "`" not in line:
            at = m.start()
            break
    if at < 0:
        raise AssertionError("%s: anchor %r not found outside a comment" % (path, after))
    s = s[:at] + after + "\nlocal %s = %s" % (name, expr) + s[at + len(after):]
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(path, "w", encoding="utf-8", newline="").write(s)
    return True
