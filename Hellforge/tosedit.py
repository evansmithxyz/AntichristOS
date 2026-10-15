"""Byte-safe editing for TempleOS/AntichristOS source files.

TempleOS files are 8-bit (CP437-ish) text with LF line endings, some with a
binary DolDoc tail (sprites) after the first NUL byte.  Generic editors that
decode as UTF-8 or normalise line endings silently corrupt them.  Everything
here round-trips through latin-1, so every byte is preserved except the ones
you replace.

Usage from Python:
    import sys; sys.path.insert(0, r"C:/Users/evans/TempleOS/Hellforge")
    from tosedit import replace, insert_after, read_text, write_text

    replace("Adam/God/GodExt.HC", "old text\n", "new text\n")          # exactly 1 match
    replace("Doc/X.DD", "TempleOS", "AntichristOS", count=None)        # all matches
    insert_after("StartOS.HC", "WallPaperInit;\n", "MyInit;\n")

Newlines: write "\n" in old/new; it is converted to the file's own line
ending (CRLF or LF) automatically.  Only the text part before the first NUL is
searched/edited; the binary tail is carried over untouched.

CLI:
    python tosedit.py replace FILE OLD NEW [--count N|--all]
    python tosedit.py info FILE
"""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _path(p):
    return p if os.path.isabs(p) else os.path.join(REPO, p)


def split(data):
    """Return (text_bytes, tail_bytes). tail starts at the first NUL (inclusive)."""
    i = data.find(b"\x00")
    if i < 0:
        return data, b""
    return data[:i], data[i:]


def eol_of(text):
    crlf = text.count(b"\r\n")
    lf = text.count(b"\n") - crlf
    if crlf and not lf:
        return "\r\n"
    if lf and not crlf:
        return "\n"
    if not crlf and not lf:
        return "\r\n"
    return "\r\n" if crlf >= lf else "\n"


def read_text(path):
    """Return (text_str, eol, tail_bytes). text_str uses '\\n' line endings."""
    data = open(_path(path), "rb").read()
    text, tail = split(data)
    eol = eol_of(text)
    s = text.decode("latin-1")
    if eol == "\r\n":
        s = s.replace("\r\n", "\n")
    return s, eol, tail


def write_text(path, s, eol="\n", tail=b""):
    if eol == "\r\n":
        s = s.replace("\r\n", "\n").replace("\n", "\r\n")
    try:
        raw = s.encode("latin-1")
    except UnicodeEncodeError as e:
        bad = s[e.start:e.end]
        raise SystemExit(f"{path}: non-latin-1 character {bad!r} at {e.start}; "
                         f"TempleOS is 8-bit — use ASCII (or a CP437 byte via chr()).")
    if b"\x00" in raw:
        raise SystemExit(f"{path}: NUL byte in text part is not allowed")
    p = _path(path)
    d = os.path.dirname(p)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(p, "wb") as f:
        f.write(raw + tail)


def replace(path, old, new, count=1):
    """Replace `old` with `new` in the text part.
    count=1 (default): exactly one occurrence must exist.
    count=N: exactly N occurrences must exist.  count=None: replace all (>=1)."""
    s, eol, tail = read_text(path)
    n = s.count(old)
    if count is None:
        if n == 0:
            raise SystemExit(f"{path}: pattern not found: {old[:80]!r}")
    elif n != count:
        raise SystemExit(f"{path}: expected {count} occurrence(s), found {n}: {old[:80]!r}")
    s = s.replace(old, new)
    write_text(path, s, eol, tail)
    return n


def insert_after(path, anchor, new, count=1):
    return replace(path, anchor, anchor + new, count)


def insert_before(path, anchor, new, count=1):
    return replace(path, anchor, new + anchor, count)


def create(path, s, eol="\n"):
    """Create a new text file (LF, like the original TempleOS files)."""
    write_text(path, s, eol, b"")


def main(argv):
    if len(argv) >= 2 and argv[0] == "info":
        s, eol, tail = read_text(argv[1])
        print(f"eol={'CRLF' if eol == chr(13)+chr(10) else 'LF'} text_chars={len(s)} "
              f"binary_tail={len(tail)} highbit={sum(1 for c in s if ord(c) >= 0x80)}")
        return 0
    if len(argv) >= 4 and argv[0] == "replace":
        cnt = 1
        if "--all" in argv:
            cnt = None
        if "--count" in argv:
            cnt = int(argv[argv.index("--count") + 1])
        n = replace(argv[1], argv[2].encode().decode("unicode_escape"),
                    argv[3].encode().decode("unicode_escape"), cnt)
        print(f"replaced {n}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
