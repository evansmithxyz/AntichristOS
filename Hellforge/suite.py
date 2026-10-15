#!/usr/bin/env python3
"""suite.py -- Hellforge: run every guest regression test against the tree.

    python Hellforge/suite.py [-j 4] [--only SUBSTR ...] [--src DIR]

Each test boots its own image (forge.py run), so they run in parallel. The
table at the end lists the exit code of each test (0 = pass), its wall time,
and its work dir under Hellforge/out/run/suite_<name>/. Exit status is the
number of failed tests.

Tests marked "rebuilt" need the Unholy C compiler/kernel built from the
current sources (forge.py bootstrap --install). Key-driven tests use
--anchor-ready, so their scripted key times follow the real boot time.
"{guest}" in a test's arguments stands for the absolute Hellforge/guest dir.
"hosttest" is Hellforge/hosttest.py (host-side toolchain checks, no QEMU).
"""
import argparse
import concurrent.futures as cf
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)

# (test file stem, extra forge.py run args, note)
TESTS = [
    ("hosttest", [], "host: stage 1, sprite rule, .Z layout, --add, parsing"),
    ("BootOk", [], "boot to the autorun"),
    ("TestToolchain", ["--add", "{guest}/TestToolchain.HC:Doc/Glossary.DD.Z",
                       "--add", "{guest}/TestToolchain.HC:Tmp/HfAddZ.HC.Z"],
     "image: .Z overlays, AutoComplete dictionary, sound sprite bins, .GR"),
    ("TestUnholyC", [], "keyword aliases, StrRev/Backmask/BEAST"),
    ("TestUnholyC2", [], "rebuilt: unless/until/do..until/backwards, BLASPHEMY, .UC"),
    ("TestUnholyC3", [], "rebuilt: reindenter"),
    ("TestUnholyC4", ["--timeout", "600"], "rebuilt: adversarial branch-sense matrix"),
    ("TestFixCompiler", [], "rebuilt: .UC fallback/Silent, backwards arrays+meta, fault names"),
    ("TestKernel", ["--shots", "1,2,3,4,6"], "rebuilt: V6.66, task names, ST_INT_NAMES"),
    ("TestKernelReview", ["--smp", "4"], "rebuilt: kernel identity on 4 cores"),
    ("TestKernelISO", [], "in-guest RedSeaISO carries the AntichristOS ids"),
    ("TestKernelDbg", ["--shots", "11,13", "--keys", "15:G<semicolon><ret>",
                       "--anchor-ready", "7.5"], "The Exorcist debugger"),
    ("TestKernelPanic", ["--shots", "12", "--keys", "15:G<semicolon><ret>",
                         "--anchor-ready", "7.5"], "Panic('Unholy Exception')"),
    ("TestOracle", ["--smp", "4"], "Adversary oracle, music, Psalmody, DoomBox"),
    ("TestOracleAdv", [], "Play parser / PlayStrRev / GodSongStr equivalence"),
    ("TestOracleWarn", [], "WS3 files compile warning-free"),
    ("TestOracleKeys", ["--keys", "11:<f7>;11.5:<f7>;12:<f8>;12.5:<shift-f7>;14:<ctrl-alt-r>;"
                                  "15:<f6>;17:<esc>;21:<ctrl-alt-b>",
                        "--shots", "16", "--anchor-ready", "7.5"], "F-keys for real"),
    ("TestFixAdam", ["--smp", "4"], "sprite guards, breathing, fonts, Adversary colours, God popup"),
    ("TestVisual", [], "palettes, flips, fonts, chrome"),
    ("TestVisualRite", [], "mouse compensation, pixel-exact flips"),
    ("TestVisualKeys", ["--keys", "16:<ctrl-alt-i>;19:<ctrl-alt-u>;22:<ctrl-alt-y>;"
                                  "25:<ctrl-alt-shift-y>;28:<ctrl-alt-shift-u>;31:<ctrl-alt-shift-i>",
                        "--anchor-ready", "9.0"], "Ctrl-Alt hotkeys for real"),
    ("TestFixDocs", [], "guardrail removals, facts, prompt examples"),
    ("TestDocs", [], "rewritten docs load, temptations"),
    ("TestDocsExamples", [], "rebuilt: doc code examples compile and run"),
    ("TestDocsReview", ["--timeout", "600"], "every doc parses; the Descent tour"),
    ("TestDocsTour", [], "tour parts"),
    ("TestDescent", [], "Descent: message-driven play"),
    ("TestDescentBot", ["--timeout", "420"], "Descent: honest autopilot run"),
    ("TestDescentKeys", ["--keys", "14:<spc>;16:" + "<left>" * 8 + ";19:" + "<right>" * 8 + ";22:<esc>",
                         "--anchor-ready", "7.5"], "Descent: real keyboard"),
]


def run_one(stem, extra, src):
    name = "suite_" + stem
    guest = os.path.join(HERE, "guest")
    extra = [x.replace("{guest}", guest) for x in extra]
    if stem == "hosttest":
        cmd = [sys.executable, os.path.join(HERE, "hosttest.py"), "--src", src] + extra
    else:
        cmd = [sys.executable, os.path.join(HERE, "forge.py"), "run",
               os.path.join(guest, stem + ".HC"), "--quiet", "--name", name,
               "--src", src] + extra
    t0 = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    wd = os.path.join(HERE, "out", "run", name)
    os.makedirs(wd, exist_ok=True)
    with open(os.path.join(wd, "forge.log"), "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n\n" + r.stdout + "\n" + r.stderr)
    return stem, r.returncode, time.time() - t0, wd


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("-j", "--jobs", type=int, default=4)
    ap.add_argument("--only", nargs="*", default=None, help="substrings of test names")
    ap.add_argument("--src", default=REPO)
    a = ap.parse_args(argv)
    tests = [t for t in TESTS if not a.only or any(s.lower() in t[0].lower() for s in a.only)]
    notes = {t[0]: t[2] for t in TESTS}
    results = []
    with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = [ex.submit(run_one, stem, extra, a.src) for stem, extra, _ in tests]
        for fu in cf.as_completed(futs):
            stem, rc, secs, wd = fu.result()
            results.append((stem, rc, secs, wd))
            print(f"{'PASS' if rc == 0 else 'FAIL':4} {stem:18} rc={rc:<3} {secs:6.1f}s", flush=True)
    order = {t[0]: i for i, t in enumerate(TESTS)}
    results.sort(key=lambda r: order[r[0]])
    print("\n==== Hellforge suite ====")
    for stem, rc, secs, wd in results:
        print(f"{'PASS' if rc == 0 else 'FAIL':4}  {stem:18} {secs:6.1f}s  {notes[stem]}")
        if rc:
            print(f"      rc={rc}  see {wd}")
    bad = sum(1 for r in results if r[1])
    print(f"{len(results) - bad}/{len(results)} passed")
    return bad


if __name__ == "__main__":
    sys.exit(main())
