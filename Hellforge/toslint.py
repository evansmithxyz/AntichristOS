"""Lint TempleOS/AntichristOS source changes against a git base.

Checks every text file (.HC .HH .DD .IN .PRJ .TXT) that differs from BASE
(default: the 'archive' branch = pristine TempleOS V5.03) or is new:

  E-UTF8     UTF-8 multi-byte sequence introduced (TempleOS is 8-bit; em-dashes,
             smart quotes etc. render as garbage and can break the lexer)
  E-EOL      line-ending style changed (CRLF file got LF lines or vice versa)
  E-TAIL     binary DolDoc tail (sprites after first NUL) changed
  E-DOLLAR   odd number of '$' on a line (every original line has an even count:
             DolDoc commands are $XX...$ and a literal dollar is $$)
  E-DOLCMD   DolDoc command not starting with two uppercase letters
  E-LINK     $LK$ / A="FI:::/..." style link to a file that no longer exists
             (only links that resolved in BASE or are new are checked)
  W-BRACES   net {}/() balance of a .HC/.HH file differs from BASE
  W-CTRL     new control characters other than TAB/CR/LF

Usage:  python toslint.py [--base archive] [paths...]
Exit status 1 if any E-* finding.
"""
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXT_EXT = (".HC", ".HH", ".DD", ".IN", ".PRJ", ".TXT", ".UC", ".UH")
LINK_RE = re.compile(r'(?:A=")?(FI|FL|FF|PI):(::)?(/[^",$]+)')


def git(*args):
    return subprocess.run(["git", "-C", REPO, *args], capture_output=True).stdout


def base_bytes(base, rel):
    r = subprocess.run(["git", "-C", REPO, "show", f"{base}:{rel}"], capture_output=True)
    return r.stdout if r.returncode == 0 else None


def split(b):
    i = b.find(b"\x00")
    return (b, b"") if i < 0 else (b[:i], b[i:])


def eol_style(t):
    crlf = t.count(b"\r\n")
    lf = t.count(b"\n") - crlf
    return crlf, lf


def utf8_seqs(t):
    return set(re.findall(rb"[\xc2-\xf4][\x80-\xbf]+", t))


def braces(t):
    s = t.decode("latin-1")
    s = re.sub(r"//[^\n]*", "", s)
    s = re.sub(r'"(\\.|[^"\\\n])*"', '""', s)
    s = re.sub(r"'(\\.|[^'\\\n])*'", "''", s)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return s.count("{") - s.count("}"), s.count("(") - s.count(")")


def tree_paths():
    out = set()
    for root, ds, fs in os.walk(REPO):
        ds[:] = [d for d in ds if d not in (".git", "Hellforge")]
        for f in fs:
            rel = os.path.relpath(os.path.join(root, f), REPO).replace("\\", "/")
            out.add("/" + rel.upper())
    return out


def link_targets(t):
    res = set()
    for line in t.decode("latin-1").split("\n"):
        for m in LINK_RE.finditer(line):
            p = m.group(3).split(",")[0].strip()
            if "*" in p or "~" in p:
                continue
            res.add(p)
    return res


def resolves(p, paths, dirs):
    u = p.upper().rstrip("/")
    if u in paths or u in dirs:
        return True
    # extensionless include-style targets
    for ext in (".HC", ".DD", ".HH", ".UC", ".UH"):
        if u + ext in paths:
            return True
    return False


def main(argv):
    base = "archive"
    if "--base" in argv:
        i = argv.index("--base")
        base = argv[i + 1]
        del argv[i:i + 2]
    if argv:
        rels = [os.path.relpath(os.path.abspath(a), REPO).replace("\\", "/") for a in argv]
    else:
        changed = git("diff", "--name-only", base, "--").decode().split()
        untracked = git("ls-files", "--others", "--exclude-standard").decode().split()
        rels = sorted(set(changed + untracked))
    rels = [r for r in rels if r.upper().endswith(TEXT_EXT) and not r.startswith("Hellforge/")
            and os.path.exists(os.path.join(REPO, r))]
    paths = tree_paths()
    dirs = set()
    for p in paths:
        parts = p.split("/")
        for k in range(2, len(parts)):
            dirs.add("/".join(parts[:k]))
    errors = warns = 0

    def rep(kind, rel, line, msg):
        nonlocal errors, warns
        if kind.startswith("E"):
            errors += 1
        else:
            warns += 1
        print(f"{kind:9} {rel}:{line}: {msg}")

    for rel in rels:
        new = open(os.path.join(REPO, rel), "rb").read()
        old = base_bytes(base, rel)
        nt, ntail = split(new)
        ot, otail = split(old) if old is not None else (None, None)
        # UTF-8
        newseq = utf8_seqs(nt) - (utf8_seqs(ot) if ot is not None else set())
        if newseq:
            for i, l in enumerate(nt.split(b"\n"), 1):
                for s in newseq:
                    if s in l:
                        rep("E-UTF8", rel, i, f"UTF-8 sequence {s!r} — use plain ASCII")
                        break
        # EOL
        crlf, lf = eol_style(nt)
        if ot is not None:
            ocrlf, olf = eol_style(ot)
            if ocrlf and not olf and lf:
                rep("E-EOL", rel, 0, f"file was CRLF; now has {lf} LF-only lines")
            if olf and not ocrlf and crlf:
                rep("E-EOL", rel, 0, f"file was LF; now has {crlf} CRLF lines")
        elif crlf and lf:
            rep("E-EOL", rel, 0, f"new file mixes CRLF ({crlf}) and LF ({lf})")
        # tail
        if otail is not None and ntail != otail:
            rep("E-TAIL", rel, 0, f"binary tail changed ({len(otail)} -> {len(ntail)} bytes)")
        # dollars / doldoc commands / ctrl chars
        octrl = set(re.findall(rb"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", ot)) if ot is not None else set()
        for i, l in enumerate(nt.split(b"\n"), 1):
            s = l.decode("latin-1")
            if s.count("$") % 2:
                rep("E-DOLLAR", rel, i, f"odd '$' count (use $$ for a literal dollar): {s.strip()[:100]}")
            else:
                parts = s.split("$")
                for k in range(1, len(parts), 2):
                    c = parts[k]
                    if c and not re.match(r"[A-Z][A-Z]", c):
                        rep("E-DOLCMD", rel, i, f"bad DolDoc command ${c[:30]}$ (literal $ must be $$)")
            for ch in set(re.findall(rb"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", l)) - octrl:
                rep("W-CTRL", rel, i, f"control char {ch!r}")
        # links
        old_links = link_targets(ot) if ot is not None else set()
        for tgt in sorted(link_targets(nt)):
            if not resolves(tgt, paths, dirs):
                if tgt in old_links:
                    # was it resolvable in base? approximate: did the path exist in base tree
                    if base_bytes(base, tgt.lstrip("/")) is None:
                        continue
                rep("E-LINK", rel, 0, f"link target missing: {tgt}")
        # braces
        if rel.upper().endswith((".HC", ".HH", ".UC", ".UH")) and ot is not None:
            nb, ob = braces(nt), braces(ot)
            if nb != ob:
                rep("W-BRACES", rel, 0, f"net (braces,parens) {ob} -> {nb}")
    print(f"toslint: {len(rels)} file(s), {errors} error(s), {warns} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
