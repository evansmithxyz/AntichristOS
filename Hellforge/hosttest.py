#!/usr/bin/env python3
"""hosttest.py -- Hellforge: host-side checks of the toolchain (no QEMU).

    python Hellforge/hosttest.py [--src DIR]

Covers the parts of mkiso/forge/qemu that a guest test cannot see: stage-1
builds from a temp dir with a space in it, the DolDoc bin/sprite rule behind
doccheck and --patch-broken-bins (checked against every file of the tree),
the .Z layout and --add overlays, --add/--append parsing, the bootstrap
prelude, --anchor-ready 0, play's accelerator fallback and the quoting of the
HMP screendump path.  Exit status: the number of failed checks.
"""
import argparse
import os
import shutil
import struct
import sys
import tempfile
import types

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import forge  # noqa: E402
import mkiso  # noqa: E402
import qemu   # noqa: E402

fails = []


def check(name, ok, info=""):
    print(f"{'PASS' if ok else 'FAIL'}  {name}{('  ' + info) if info else ''}", flush=True)
    if not ok:
        fails.append(name)


def raises(fn, exc=mkiso.IsoError):
    try:
        fn()
    except exc:
        return True
    return False


def t_stage1_space():
    with tempfile.TemporaryDirectory(prefix="hf host ") as d:
        sub = os.path.join(d, "has space")
        os.makedirs(sub)
        old = tempfile.tempdir
        tempfile.tempdir = sub
        try:
            code, syms = mkiso.build_stage1("Summoning AntichristOS")
            ok = len(code) < mkiso.DVD_BOOT_LOADER_SIZE and "BDVD_BLK_LO" in syms
            stray = [f for f in os.listdir(d) if f != "has space"]
        except mkiso.IsoError as e:
            ok, stray = False, str(e)
        finally:
            tempfile.tempdir = old
    check("stage1 builds with a space in TEMP", ok and not stray, f"stray={stray}")


def t_sprite_unit():
    E = b"\0"
    cases = [
        ("end only", E, True),
        ("color+end", b"\x01\x04" + E, True),
        ("circle r=5", b"\x0e" + struct.pack("<3i", 0, 0, 5) + E, True),
        ("polyline 2", b"\x0b" + struct.pack("<i", 2) + bytes(16) + E, True),
        ("text", b"\x1b" + struct.pack("<2i", 1, 2) + b"Hell\0" + E, True),
        ("bitmap 3x2", b"\x17" + struct.pack("<4i", 0, 0, 3, 2) + bytes(16) + E, True),
        ("selected bit", b"\x81\x04" + E, True),
        ("type 30", b"\x1e" + E, False),
        ("type 120", b"\x78" + bytes(30) + E, False),
        ("end early", b"\x01\x04" + E + b"\x01", False),
        ("no end", b"\x01\x04", False),
        ("truncated circle", b"\x0e" + struct.pack("<2i", 0, 0) + E, False),
        ("negative polyline", b"\x0b" + struct.pack("<i", -3) + E, False),
        ("text without NUL", b"\x1b" + struct.pack("<2i", 1, 2) + b"Hell", False),
        ("empty", b"", False),
    ]
    bad = [n for n, d, want in cases if mkiso.sprite_ok(d) != want]
    check("sprite_ok unit cases", not bad, f"wrong: {bad}" if bad else f"{len(cases)} cases")


def _restore(data, old_hex, new_hex):
    """The repo file with one stripped 0x05 put back (the sprite structure makes
    the position unambiguous), or as is if it already has it."""
    old, new = bytes.fromhex(old_hex), bytes.fromhex(new_hex)
    if data.count(new) == 1:
        return data
    if data.count(old) == 1:
        return data.replace(old, new)
    return None


def t_tree_rule(src):
    n_patched, still, changed_good, not_idem = 0, [], [], []
    for dp, dn, fn in os.walk(src):
        dn[:] = [d for d in dn if d not in (".git", "Hellforge", ".claude")]
        for f in fn:
            if not mkiso.DOLDOC_EXT_RE.search(f):
                continue
            p = os.path.join(dp, f)
            with open(p, "rb") as fh:
                data = fh.read()
            is_map = bool(mkiso.MAP_EXT_RE.search(f))
            prob = mkiso.doc_bin_problems(data, map_file=is_map)
            new = mkiso.patch_bin_tail(data, strip_refs=is_map)
            rel = os.path.relpath(p, src)
            if prob is None:
                if new is not None:
                    changed_good.append(rel)
                continue
            n_patched += 1
            if new is None or mkiso.doc_bin_problems(new, map_file=is_map) is not None:
                still.append(rel)
            elif mkiso.patch_bin_tail(new, strip_refs=is_map) is not None:
                not_idem.append(rel)
    check("patch leaves sound files alone", not changed_good, f"{changed_good[:5]}")
    check("every patched tail is sound", not still and n_patched > 0,
          f"{n_patched} patched, still broken {still[:5]}")
    check("patch is idempotent", not not_idem, f"{not_idem[:5]}")
    # The sprites a restored byte makes sound again must pass unpatched.
    fixes = [("Adam/AMouse.HC",            # CIRCLE radius 5 (gr.empty_sprite)
              "0e 00000000 00000000 000000 0a f8ffffff",
              "0e 00000000 00000000 05000000 0a f8ffffff"),
             ("Demo/Graphics/Extents.HC",  # LINE y1=5
              "0a 16000000 000000 23000000 f8ffffff",
              "0a 16000000 05000000 23000000 f8ffffff")]
    for rel, old, new in fixes:
        p = os.path.join(src, *rel.split("/"))
        if not os.path.isfile(p):
            continue
        with open(p, "rb") as fh:
            data = _restore(fh.read(), old, new)
        check(f"restored {rel} is sound unpatched",
              data is not None and mkiso.doc_bin_problems(data) is None
              and mkiso.patch_bin_tail(data) is None)
    check(".GR is not DolDoc", not mkiso.DOLDOC_EXT_RE.search("StadiumBG.GR"))
    grs, bad_gr = 0, []
    for dp, dn, fn in os.walk(src):
        dn[:] = [d for d in dn if d not in (".git", "Hellforge", ".claude")]
        for f in fn:
            if not mkiso.GR_EXT_RE.search(f):
                continue
            with open(os.path.join(dp, f), "rb") as fh:
                data = fh.read()
            grs += 1
            new = mkiso.patch_gr(data)
            if (mkiso.gr_problem(data) is None) != (new is None) or \
                    (new is not None and mkiso.gr_problem(new) is not None):
                bad_gr.append(f)
    check("damaged .GR pictures patch to whole ones", grs and not bad_gr,
          f"{grs} pictures, wrong: {bad_gr}")
    w, wi, h = 5, 8, 3
    body = mkiso.arc_wrap(bytes(wi * h))
    good = mkiso.GR_HDR.pack(0, 0, 0, w, wi, h, mkiso.DCF_COMPRESSED) + body
    check("gr_problem on a sound and a short picture",
          mkiso.gr_problem(good) is None and mkiso.patch_gr(good) is None
          and mkiso.gr_problem(good[:-3]) == "picture data 3 bytes short")


def _tree(files):
    d = tempfile.mkdtemp(prefix="hf_tree_")
    for rel, data in files.items():
        p = os.path.join(d, *rel.split("/"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "wb") as f:
            f.write(data)
    return d


def _names(root):
    return sorted(n.path() for n in root.walk() if not n.is_dir)


def t_dotz():
    long_name = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456.DD"   # 36 chars: fits, .Z would not
    d = _tree({"Doc/A.DD": b"Hello\n", "Doc/" + long_name: b"x",
               "Adam/AutoComplete/ACWords.DATA": b"w", "Adam/AutoComplete/ACDefs.DATA": b"d",
               "0000Boot/0000Kernel.BIN.C": b"k", "Misc/X.BIN.C": b"c"})
    try:
        _t_dotz(d, long_name)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def _t_dotz(d, long_name):
    root = mkiso.scan_tree(d, [])
    logs = []
    mkiso.dotz_tree(root, logs.append)
    mkiso.check_tree(root)
    want = ["/0000Boot/0000Kernel.BIN.C", "/Adam/AutoComplete/ACDefs.DATA",
            "/Adam/AutoComplete/ACWords.DATA.Z", "/Doc/A.DD.Z", "/Doc/" + long_name,
            "/Misc/X.BIN.C"]
    check("dotz names", _names(root) == want, f"{_names(root)}")
    check("dotz long name logged", any(long_name in s for s in logs))
    a = mkiso.get_file(root, "Doc/A.DD.Z")
    check("dotz CT_NONE header", mkiso.is_arc(a.data) and a.data[17:] == b"Hello\n")

    # --add with .Z names: replaces, never duplicates, never raw bytes as .Z
    for dotz in (True, False):
        root = mkiso.scan_tree(d, [])
        mkiso.add_file(root, "Doc/A.DD.Z", b"plain", dotz)         # plain over a repo file
        mkiso.add_file(root, "Doc/New.DD.Z", b"new", dotz)         # plain under a new .Z name
        mkiso.add_file(root, "Misc/Blob.DD", b"b", dotz)
        mkiso.add_file(root, "Misc/Blob.DD.Z", mkiso.arc_wrap(b"blob"), dotz)  # arc replaces
        if dotz:
            mkiso.dotz_tree(root)
        mkiso.check_tree(root)
        names = _names(root)
        a = mkiso.get_file(root, "Doc/A.DD.Z")
        ok = (names.count("/Doc/A.DD.Z") == 1 and "/Doc/A.DD" not in names
              and a.data[17:] == b"plain" and "/Doc/New.DD.Z" in names
              and "/Misc/Blob.DD.Z" in names and "/Misc/Blob.DD" not in names
              and all(mkiso.is_arc(mkiso.file_bytes(n)) for n in root.walk()
                      if not n.is_dir and n.name.endswith(".Z")))
        check(f"--add .Z overlay (dotz={dotz})", ok, f"{names}")

    root = mkiso.scan_tree(d, [])
    mkiso.put_file(root, "Doc/A.DD.Z", b"raw")
    check("check_tree refuses raw .Z", raises(lambda: mkiso.check_tree(root)))
    root = mkiso.scan_tree(d, [])
    mkiso.get_file(root, "Doc").add(mkiso.Node("A.DD", False, data=b"dup"))
    check("check_tree refuses duplicates", raises(lambda: mkiso.check_tree(root)))


def t_parse():
    ok = (mkiso.split_add("C:/x/T.HC:Doc/T.HC") == ("C:/x/T.HC", "Doc/T.HC")
          and mkiso.split_add("a.HC:/Doc\\T.HC") == ("a.HC", "/Doc/T.HC")
          and all(raises(lambda s=s: mkiso.split_add(s))
                  for s in ("Hellforge/guest/BootOk.HC", "C:/x/BootOk.HC", "C:\\x\\B.HC",
                            "a.HC:", ":Doc/A.HC"))
          and mkiso.split_append("StartOS.HC:x.HC") == ("StartOS.HC", "x.HC")
          and raises(lambda: mkiso.split_append("StartOS.HC")))
    check("--add/--append parsing", ok)


def t_bootstrap():
    def prelude(tree, cfg):
        a = types.SimpleNamespace(tree=tree, drv="B", cfg=cfg, bootdvdins=False)
        return forge.bs_prelude(a).decode()
    typed = "TB\\nScale2Mem(2048,0x40000)\\nT \\n\\n\\n\\n"
    p0, p1 = prelude([], forge.BS_CFG), prelude(["Linux", "/Kernel/"], typed)
    ok = ('{"Kernel","Compiler",NULL}' in p0
          and '{"Kernel","Compiler","Linux",NULL}' in p1
          and p0.splitlines()[2] == p1.splitlines()[2]
          and '"TB\\nScale2Mem(2048,0x40000)\\nT \\n\\n\\n\\n"' in p0)
    check("bootstrap --tree is additive, --cfg escapes decode", ok)


def t_anchor_play():
    run = lambda *x: forge.anchor_spec(types.SimpleNamespace(anchor_ready=x[0]))  # noqa: E731
    check("--anchor-ready 0 anchors", run(0.0) == (b"HELLFORGE_READY", 0.0)
          and run(None) is None)
    whpx = ("C:\\Program Files\\qemu\\qemu-system-x86_64.exe: -accel whpx: "
            "WHPX: No accelerator found, hr=80004005")
    audio = ("C:\\Program Files\\qemu\\qemu-system-x86_64.exe: -audiodev bogus,"
             "id=hellsnd: Parameter 'driver' does not accept value 'bogus'")
    warn = ("qemu-system-x86_64.exe: warning: host doesn't support requested "
            "feature: CPUID[eax=80000001h].ECX.svm [bit 2]")
    check("play retries only accelerator failures",
          forge.accel_failed(whpx) and not forge.accel_failed(audio)
          and not forge.accel_failed(warn + "\n" + audio) and not forge.accel_failed(""))


def t_screendump_quote():
    """Qemu.screendump() against a fake monitor that splits arguments the way
    HMP does: an unquoted name ends at the first blank."""
    try:
        import PIL  # noqa: F401
    except ImportError:
        check("screendump path quoting", False, "Pillow is not installed")
        return
    with tempfile.TemporaryDirectory(prefix="hf host ") as d:
        q = qemu.Qemu.__new__(qemu.Qemu)

        def hmp(cmd):
            arg = cmd.split(" ", 1)[1]
            path = arg[1:arg.index('"', 1)] if arg.startswith('"') else arg.split(" ")[0]
            if not path.startswith(d.replace("\\", "/")) or \
                    not os.path.isdir(os.path.dirname(path)):
                return cmd + "\r\nError: Could not create '%s'\r\n(qemu) " % path
            with open(path, "wb") as f:
                f.write(b"P6\n2 1\n255\n" + bytes(6))
            return cmd + "\r\n(qemu) "
        q.hmp = hmp
        png = os.path.join(d, "out dir", "spc x.png")
        os.makedirs(os.path.dirname(png))
        try:
            ok = q.screendump(png) == png and os.path.isfile(png)
        except Exception as e:  # noqa
            ok = False
            print("   ", e)
        missing = os.path.join(d, "nodir", "x.png")
        check("screendump path quoting", ok and raises(lambda: q.screendump(missing), OSError))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--src", default=os.path.dirname(HERE))
    a = ap.parse_args(argv)
    for t in (t_stage1_space, t_sprite_unit, lambda: t_tree_rule(a.src), t_dotz,
              t_parse, t_bootstrap, t_anchor_play, t_screendump_quote):
        try:
            t()
        except Exception as e:  # noqa
            check(getattr(t, "__name__", "check"), False, f"{type(e).__name__}: {e}")
    print(f"hosttest: {len(fails)} failed")
    return len(fails)


if __name__ == "__main__":
    sys.exit(main())
