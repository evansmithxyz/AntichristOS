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
  W-CTRL     new control characters other than TAB/CR/LF, CH_CURSOR (0x05) and
             CH_SHIFT_SPACE (0x1F); see CTRL_RE

Usage:  python toslint.py [--base archive] [paths...]
Exit status 1 if any E-* finding.
"""
import hashlib
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Deliberate repairs of binary tails damaged by the archive's stripped 0x05
# bytes (see README "Known repo data problem"): path -> sha1 of the repaired
# tail.  Any other tail change is still an error.  Every one is the original
# tail from TOS_Distro.ISO (V5.03, SHA-1 1a1ec79), expanded in binary mode,
# except Titanium.HC: there bin 9's last two bytes (0x28 0x38) are junk in
# V5.03 itself and are 0x00 0x00 as in its sibling frames, bins 7 and 8.
TAIL_REPAIRS = {
    "Adam/AMouse.HC": "22481c99a18fbf56f43603777564ebc2f2d76d6d",       # gr.empty_sprite radius
    "Demo/Graphics/Extents.HC": "40e6560be46e9ffe78f882fdf9b0bc2067c6bcb5",  # first LINE y1
    "Apps/KeepAway/KeepAway.HC": "86abc9c114c230b19246bf2cc89de5ea0a196a33",
    "Apps/Logic/Logic.HC": "67bbcfe143d8a13a8b789ca49f39caa780940be0",
    "Apps/Psalmody/PsalmodyDraw.HC": "c747c64233c1ad5c9edb75abc9e6a3e787d59023",
    "Apps/Titanium/Titanium.HC": "6288880bd6212f40b757da9352ce92efe045f41f",  # + bin 9 end
    "Apps/ToTheFront/TTFInit.HC": "14f55537ed7391265b5f585789f3ca4c3b752557",
    "Apps/X-Caliber/X-Caliber.HC": "7eb39b7cbc0adeeaac292c3f7b47cc4eb96d7178",
    "Demo/AcctExample/PersonalMenu.DD": "b9bc71c4744304e9494bcd5b59758afc4a6a2087",
    "Demo/AcctExample/TOS/TOSTheme.HC": "54e7870273d87f20577cc393c278f7ee74d56701",
    "Demo/Games/BattleLines.HC": "ea9a516f3cc6a824c791ddc73d263bbf15ff6550",
    "Demo/Games/BlackDiamond.HC": "2f0f2b7eb866f3cfda29b027e8a63190b9038012",
    "Demo/Games/BomberGolf.HC": "19d575ef3352fb469d6be6d3d2f3c94a01c121b5",
    "Demo/Games/CastleFrankenstein.HC": "ab762b42ab944863c877d542f3eeebedeffeb1a6",
    "Demo/Games/DunGen.HC": "fbb65a10af2c1148d365aff9943facc26e3d689d",
    "Demo/Games/FlapBat.HC": "4150ca51d8e38d4b7cd500e7954cfcd646f7dd77",
    "Demo/Games/FlatTops.HC": "cf8cb653dd5c312f00532560b6a8af6fa52f9d8f",
    "Demo/Games/RawHide.HC": "2cda576517f42d91445781f08389562cf079f8cb",
    "Demo/Games/RocketScience.HC": "b8afcd3499f17fea24eb4b7081123640f9c3bb50",
    "Demo/Games/Talons.HC": "0e280625af89fc8b8709395f57c6b6976c460c18",
    "Demo/Games/TheDead.HC": "dcd683c6fe6c6089d38c66b2b602b4762d009a0f",
    "Demo/Games/Varoom.HC": "948975e6494c32f93b18e5e2d6d17ddbadeee4ea",
    "Demo/Games/Wenceslas.HC": "cf667bf21ed3ade375c7473069024c916578959f",
    "Demo/Games/Zing.HC": "ab1fc16c26f152822aa6b0b8704d723e67c39b4d",
    "Demo/Games/ZoneOut.HC": "1a2a5f164752cb789edad41d1d09371d0838fcc9",
    "Demo/Graphics/EdSprite.HC": "8861fdb0521b8ec7c079b454f56c36d66fda6e94",
    "Demo/Graphics/Elephant.HC": "e7e812a6d886352df83ce74d210dfef074d02a46",
    "Demo/Graphics/LightTable.HC": "6774211d0d57dafe1f20280998f4d2f91812c5b2",
    "Demo/Graphics/Pick.HC": "071168c8fc10d9a75b6651a8f28fb601c5883f7e",
    "Demo/Graphics/Pick3D.HC": "190678eecd750d9cef3039f1135045ecda0a7bf8",
    "Demo/Graphics/RotateTank.HC": "01e90752e8ddf751b9cd0736cc760ebd3f067648",
    "Demo/Graphics/Shadow.HC": "95461fe19fecc3bafadc60009b0b6b52d20a4d42",
    "Demo/Graphics/SpritePlot.HC": "a9964758b4a3a67346144da02a1ab8d7ccc3b2ea",
    "Demo/Graphics/SpritePlot3D.HC": "3cfee3b15b0541b821ca91873bf171fa6eb4adc7",
    "Demo/Graphics/SpriteText.HC": "11fd5bec1d2cbdefd66fdecdad8f4220bdbf13f0",
    "Demo/Graphics/WallPaperFish.HC": "db49b8138d14a46e5820bc9e2ac1db20373e0fe9",
    "Doc/Hash.DD": "37df300f847dbedcf441d28934f1cdbe5e225ea5",
    "Doc/HelpIndex.DD": "51d2b53565ef7355a0d8e2475d9360fab03a4115",
    "PersonalMenu.DD": "f55f9e7c82cff1a518c7653dd0ba6638d0d303c6",
}
# W-CTRL's control characters.  Not TAB/LF/CR, and not CH_CURSOR (0x05) or
# CH_SHIFT_SPACE (0x1F): those two are ordinary DolDoc text (DocSave() writes
# the cursor as 0x05, Shift-Space types 0x1F, and the lexer skips 0x05 and
# reads 0x1F as a space).  BASE cannot show them: TOSZ -ascii dropped every
# 0x05 and made every 0x1F a space in the 'archive' branch, so each one put
# back from the V5.03 ISO (2,745 0x1F in 152 text parts) would look new.
CTRL_RE = re.compile(rb"[\x00-\x04\x06-\x08\x0b\x0c\x0e-\x1e\x7f]")
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
        if otail is not None and ntail != otail and \
                TAIL_REPAIRS.get(rel) != hashlib.sha1(ntail).hexdigest():
            rep("E-TAIL", rel, 0, f"binary tail changed ({len(otail)} -> {len(ntail)} bytes)")
        # dollars / doldoc commands / ctrl chars
        octrl = set(CTRL_RE.findall(ot)) if ot is not None else set()
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
            for ch in set(CTRL_RE.findall(l)) - octrl:
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
