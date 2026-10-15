# Hellforge

Host-side toolchain that turns this repo tree into a bootable TempleOS /
AntichristOS CD image (`.ISO.C`), boots it in QEMU (headless for tests, in a
window with sound for `play`), runs HolyC in the guest, and rebuilds the AOT
binaries (kernel + compiler) inside the guest.

**Requirements:** Python 3 with [Pillow](https://pypi.org/project/pillow/)
(`pip install pillow`; `qemu.py` converts QEMU's PPM screendumps to PNG with it,
and nothing else needs it), NASM (`nasm` on `PATH`, or `NASM=path`) and QEMU
(`qemu-system-x86_64` on `PATH`, or `QEMU=path`). Build outputs go to
`Hellforge/out/` (git-ignored). Hellforge never edits repo files (except
`bootstrap --install`, on request): everything it injects lives only in the
image.

| File | Role |
|---|---|
| `stage1.asm` | NASM port of `BDVD_START..BDVD_END` (`Adam/Opt/Boot/BootDVD.HC`), the El Torito no-emulation loader. The boot message is a build parameter. |
| `mkiso.py` | Pure-Python port of `RedSeaISO()` (`Adam/Opt/Boot/DskISORedSea.HC`). It writes a RedSea ISO from a directory. |
| `qemu.py` | Headless QEMU harness: monitor, screendump to PNG, sendkey, COM1 to a file, isa-debug-exit, timeout, stall detection, guest-requested screenshots. |
| `forge.py` | The CLI: `iso`, `play`, `boot`, `run`, `bootstrap`, `selftest`, `doccheck`. |
| `suite.py` | Runs the whole regression suite (`hosttest.py` plus every `guest/Test*.HC`) in parallel. |
| `hosttest.py` | Host-only checks of the toolchain itself (no QEMU, a few seconds). |
| `guest/Serial.HC` | HolyC helpers for injected code: polled COM1, framed hex dump, `HfShot`, `HfExit`. |
| `guest/Bootstrap.HC` | In-guest rebuild of `Compiler.BIN`, `Kernel.BIN` and the `.MAP` files (driven by `bootstrap`). |
| `guest/VerifyBoot.HC` | Checks that a booted image runs the freshly built kernel (used by `selftest`). |
| `guest/BootOk.HC`, `guest/DumpTest.HC` | Example tests. |
| `guest/Test*.HC` | The regression tests `suite.py` runs (`TestToolchain.HC` checks the image Hellforge builds). |

## Commands

```sh
python Hellforge/forge.py play [--no-build] [--audio sdl] [--display gtk] [--accel tcg]
python Hellforge/forge.py iso  [--out F] [--boot-msg "Summoning AntichristOS"] [--patch-broken-bins] [--no-dotz]
python Hellforge/forge.py boot [--seconds 60] [--every 10] [--shots 3,10] [--keys "12:n"]
python Hellforge/forge.py run  Hellforge/guest/BootOk.HC [--timeout 300] [--accel tcg]
python Hellforge/forge.py run  --eval '"2+2=%d\n",2+2; hf_exit_code=4;'
echo 'HfPrint("hi\n");' | python Hellforge/forge.py run -
python Hellforge/forge.py bootstrap [--install] [--stages 2] [--out-dir D] [--tree DIR]
python Hellforge/forge.py selftest  [--no-stage2]
python Hellforge/forge.py doccheck          # list damaged sprite bins / .GR pictures
python Hellforge/suite.py [-j 4] [--only NAME ...]
python Hellforge/hosttest.py
python Hellforge/mkiso.py --help            # all ISO options (--add, --append, --exclude, ...)
python Hellforge/qemu.py ISO --timeout 60 --shots 5,20 --stop-on TEXT
```

Common options: `--accel auto|whpx|tcg`, `--mem 1024`, and `--smp N` (4 tested).
`--accel auto` tries WHPX first and falls back to TCG.
`--add HOST:ISOPATH` (repeatable) adds or replaces a file in the image only;
ISOPATH may be written with the image's `.Z` name (see below).

## `play`: AntichristOS in a window

`play` builds `out/AntichristOS.ISO.C` and boots it in a QEMU window with the
PC speaker wired to the host's sound card, then returns while QEMU keeps
running. Defaults: `--patch-broken-bins` on (so the sprite demos and the
Personal Menu work), `.Z` names on, `--mem 2048`, `--smp 4`, `--display sdl`,
`--audio` the platform's backend (`dsound` on Windows, `coreaudio` on macOS,
`sdl` elsewhere), `--accel auto`. `--no-build` boots the existing image
(`--out` picks another one). QEMU's own messages go to
`out/play.qemu-stderr.txt`. If QEMU quits within 5 s it prints them; it retries
under TCG only when WHPX itself failed (not after a bad `--audio`, and not when
you simply closed the window).

## `run`: compile and run HolyC in the guest

`run FILE.HC`, `run -` (stdin) or `run --eval CODE` builds an image whose
autorun compiles and executes the code with `ExeFile2` in its own task, after
boot has finished (Adam in server mode). `Serial.HC` is already included, so
the code can call `HfPrint`, `HfDumpFile`, `HfShot` and set `hf_exit_code`.

Each run gets its own work directory, `out/run/<name>/` (`--name`, default:
the file's stem, `eval` or `stdin`), so agents running different tests don't
collide. It contains `Test.ISO.C`, `serial.txt` (raw COM1), `dumps/`,
`<name>_*.png` and `<name>.qemu-stderr.txt`. At the end forge prints
`result: N (...)`, the serial log path and every screenshot path to stderr.

**Exit status.** The guest's exit code, 0..127, set with `hf_exit_code=N;` or
`HfExit(N)`. 126 means an uncaught exception or a compile error in the test,
124 a host timeout or a stalled boot, and 125 a harness error (including QEMU
exiting without the exit device, e.g. a triple fault).

**Keys and screenshots.** `--keys "SECS:text;SECS:<name>"` types into the guest
(`<name>` is a QEMU sendkey name such as `<ret>`, `<ctrl-alt-i>`), and
`--shots 3,10` / `--every S` take screenshots, all at host seconds after QEMU
started. Boot time varies, so a script written against one boot drifts on the
next. `--anchor-ready SECS` fixes that: every scripted time `>= SECS` is held
until the autorun prints `HELLFORGE_READY` and then fires at
`t - SECS + <real ready time>`. Pass the ready time of the boot you wrote the
script against (the suite uses `7.5`; `forge` logs `autorun ready at N s`), or
`0` to make every time relative to READY. `boot` has no autorun, so it has no
`--anchor-ready`.

**Failure diagnostics.**

- The test task's terminal (its `Print` output and compiler errors) comes back
  between `HELLFORGE_DOC_BEGIN` / `HELLFORGE_DOC_END` (`--no-doc` to skip). With
  `--quiet` nothing is echoed, but this text is printed if the test fails.
- When the test fails (exit code != 0) the wrapper asks for a final
  screenshot, `<name>_fail.png`, before leaving QEMU (`--no-fail-shot` to skip).
- **Boot-time errors** (an Adam/StartOS/Home file that doesn't compile) happen
  before the autorun gets control, so nothing reaches the serial port. The
  harness watches for `HELLFORGE_STARTOS_END`; if it hasn't appeared after
  `--boot-timeout` seconds (default 120; a healthy boot takes about 10 s,
  with or without `--patch-broken-bins`; 0 disables the check), it stops,
  saves `<name>_timeout.png`, explains which stage was missed and returns 124.
  A hanging test is handled the same way at `--timeout`.

## `suite.py`: the regression suite

`python Hellforge/suite.py -j 4` runs `hosttest.py` and every guest test in
its `TESTS` table (each one `forge.py run guest/<Test>.HC --quiet` with that
test's extra arguments, e.g. `--keys ... --anchor-ready 7.5` or `--add`
overlays) in parallel, each in `out/run/suite_<name>/` with a `forge.log`.
It prints PASS/FAIL per test and a summary table; the exit status is the number
of failures. `--only SUBSTR ...` picks tests by name and `--src DIR` tests
another tree. Tests marked "rebuilt" need binaries built from the current
sources (`forge.py bootstrap --install`). Add a new test by dropping
`guest/Test<Name>.HC` (it must set `hf_exit_code=0` when it passes) and adding
a `TESTS` row.

## `bootstrap`: rebuild the AOT binaries inside TempleOS

`bootstrap` rebuilds `Compiler/Compiler.BIN`, `Compiler/Compiler.MAP`,
`Kernel/Kernel.MAP` and the CD boot kernel `0000Boot/0000Kernel.BIN.C` from the
**current** sources, the way `Misc/DoDistro.HC` does, and copies them to the
host:

1. The image boots (with `--patch-broken-bins`) and runs `guest/Bootstrap.HC`
   behind a generated prelude (`hf_bs_drv`, `hf_bs_cfg`, `hf_bs_trees`).
2. The guest copies `::/Kernel` and `::/Compiler`, plus any `--tree DIR`
   (repeatable, in addition to those two), from the read-only CD `T:` to the
   RAM drive `B:` (`--drv`) and `Cd("B:/")`.
3. `Cmp("/Compiler/Compiler","Compiler",,':')`, then
   `In(STD_DISTRO_DVD_CFG)` and `Cmp("/Kernel/Kernel","Kernel",,':')`, then
   `Move("/Kernel/Kernel.BIN.Z","/0000Boot/0000Kernel.BIN.C")`. That is
   `BootDVDIns()`'s `MakeAll` + `Move`, but keeping each project's error count
   (`--bootdvdins` calls `BootDVDIns()` itself instead).
4. The four files are sent back with `HfDumpFile` (expanded `.Z` contents) and
   checked on the host (CRC-32, size, `TOSB` signature on the BINs).
5. The host writes them to `out/bootstrap/` (same relative paths as in the
   repo) with `bootstrap.json` (sizes, CRC-32, SHA-1, the new kernel's
   `compile_time`, guest timings), prints a byte diff against the repo's
   binaries, and with `--install` overwrites the binaries in `--install-root`
   (default `--src`, i.e. the repo).

`--stages N` rebuilds N times; stage k>1 boots an image carrying stage k-1's
four files and rebuilds with them (a self-hosting/fixpoint check). The final
stage goes to `--out-dir`, earlier ones to `--out-dir/stageK/`.

**Kernel configuration.** `STD_DISTRO_DVD_CFG = "TB\nScale2Mem(2048,0x40000)\nT \n\n\n\n"`
answers `Kernel/KCfg.HC` (run from `#exe` in `Kernel.PRJ`): boot drive `T`;
mount `B` as a RAM drive (`<ENTER>` = MAlloc it, `Scale2Mem(2048,0x40000)`
blocks); mount `T` as ATAPI (the space answers `ATARep`'s probe prompt and
`<ENTER>` at "I/O Port Base0" selects "use booted CD/DVD", i.e. `GetBaseUnit`);
`<ENTER>` ends mounting; default disk cache; no options. The guest transcript
confirms each prompt gets the intended answer. This is the configuration of the
stock CD kernel: same `B:`/`T:` layout seen at boot (`B` RAM 0x58-0x40000, `T`
ATAPI at 0x170). `--cfg` replaces it; backslash escapes are decoded, so the
string above can be typed on a shell as `--cfg 'TB\nScale2Mem(2048,0x40000)\nT \n\n\n\n'`.

**Guest exit codes:** 10 Compiler.PRJ errors, 11 Kernel.PRJ errors, 12 an output
file missing, 13 sources could not be staged; 124/125/126 as for `run`.
`bootstrap` returns 0 on success, 1 on a build failure, or 124/125/126.

## `selftest`

Runs the whole chain on the unmodified sources and prints a PASS/FAIL table:

1. `bootstrap` (to `out/selftest/bootstrap/`) and the byte diff against the repo.
2. Copies the tree to `out/selftest/scratch/` (no `.git`/`Hellforge`) and
   installs the new binaries there. The repo's own binaries are hashed before
   and after; the last step fails if they changed.
3. Builds and boots an image from the scratch tree running
   `guest/VerifyBoot.HC`: `sys_compile_time` must equal the CDate in the new
   kernel at offset 0x34 (`CKernel.compile_time`), and the CRC/size of
   `::/0000Boot/0000Kernel.BIN.C` and `::/Compiler/Compiler.BIN` must match. It
   saves the desktop screenshot `out/run/selftest-verify/selftest-verify_desktop.png`.
4. Stage 2 (unless `--no-stage2`): bootstraps again from the scratch tree, i.e.
   booted on the new kernel and compiler, and diffs stage 2 against stage 1.

## Image layout (same as RedSeaISO)

DVD sectors are 2048 bytes; RedSea blocks are 512 bytes.

| Location | Contents |
|---|---|
| sectors 0-15 | zero |
| sector 16 | PVD (`CISOPriDesc` layout) |
| sector 17 | El Torito boot record; catalog at sector 20 |
| sector 18 | Supplementary descriptor with publisher `TempleOS RedSea`. `ISOInit()` looks for this string, so do not rename it. |
| sector 19 | Terminator |
| sector 20 | Boot catalog: no-emulation, load_rba 21, sect_cnt 4 |
| sector 21 | Patched stage-1 |
| block 88 (`drv_offset`) onward | `CRedSeaBoot`, then the bitmap. `data_area` is `drv_offset+bitmap_sects`, and "alloc #1" reserves it. Next comes the root dir, then dirs and files, allocated contiguously in CopyTree pre-order. Each dir is pre-sized `ceil((n+3)*64, 512)`, with a `.` entry carrying the dir's own name and size, and a `..` entry. |

Stage-1 patching follows `RedSeaISO9660Stage1()`:
`BLK_LO = clus>>2`, `BLK_CNT = ceil(size/2048) (+1 if shift)`, and `SHIFT = clus&3`.

`mkiso.py` also adds the empty dirs `/Home`, `/Tmp` and `/Tmp/ScrnShots`, as `Misc/DoDistro.HC` does.
`/Home` is required: without it, `#include "~/MakeHome"` fails.

The kernel finds its boot CD by comparing `CKernel.compile_time` in the CD's
`0000Kernel.BIN.C` with its own `sys_compile_time` (`BootDVDProbe`), so a
rebuilt kernel works only on an image that carries that same file, which is
what `--add`, `--install` and the overlays do.

### `.Z` names (CT_NONE)

The original CD stored nearly every file TempleOS-compressed under a
`<name>.Z` name, and the OS looks several of them up by that exact name
(`::/Doc/StandBy.DD.Z`, `~/PersonalMenu.DD.Z`, `ACWords.DATA.Z`, ...). The repo
holds the expanded files, so by default `mkiso` stores each one as
`<name>.Z`: the file's bytes behind a 17-byte `CArcCompress` header
(`compressed_size`, `expanded_size`, type `CT_NONE`), flagged
`RS_ATTR_COMPRESSED`, exactly what `FileWrite()` produces. `ExpandBuf()`
returns a `CT_NONE` body as is, so nothing is actually compressed and every
byte stays verbatim. These stay under their plain names, unwrapped:

- `/0000Boot/*` and `*.C` (contiguous files read raw, e.g. the boot kernel);
- `ACDefs.DATA` (AutoComplete reads it with `FOpen()` block access);
- a file whose name plus `.Z` would exceed RedSea's 37 characters (logged).

`--add HOST:Dir/File.DD.Z` is the same as `--add HOST:Dir/File.DD`: it replaces
the repo file and is wrapped like it. A HOST file that already is a
`CArcCompress` blob is stored as given. `mkiso` refuses an image with two
entries of one name or a `.Z` file that is not `CArcCompress` data.
`--no-dotz` stores everything under plain names instead (no headers); the OS's
exact-name `.Z` lookups then fail (for example `ACWords.DATA.Z`, so
AutoComplete has no dictionary words), so use it only to compare with older
images.

## Autorun and serial protocol

`mkiso --inject-autorun F` places F at `::/Hellforge/AutoRun.HC` and appends
`#include "::/Hellforge/AutoRun.HC"` to the image's `StartOS.HC`.

The generated wrapper does the following:

1. Prints `HELLFORGE_STARTOS_END <ms>` (this is the end of `StartOS.HC`, after `MakeHome`).
2. Spawns a task that waits for `RLf_ADAM_SERVER`, then prints `HELLFORGE_READY <ms>`.
3. Runs `ExeFile2("::/Hellforge/Test.HC")` inside try/catch.
4. Sends the task's terminal text between `HELLFORGE_DOC_BEGIN` and `HELLFORGE_DOC_END`.
5. If the exit code is non-zero, `HfShot("fail")`.
6. Ends with `HfExit(hf_exit_code)`, which prints `HELLFORGE_EXIT <code>` and does `OutU8(0xF4,code)`.

| Line | Meaning |
|---|---|
| `HELLFORGE_STARTOS_END <ms>` / `HELLFORGE_READY <ms>` | boot milestones (guest `tS`) |
| `HELLFORGE_EXCEPT <ch> <callers>` | uncaught exception in the test |
| `HELLFORGE_EXIT <code>` | about to leave QEMU |
| `HELLFORGE_SHOT <name>` | host takes `<workdir>/<prefix>_<name>.png` now (`HfShot(name)` prints it, then sleeps 1.5 s) |
| `HFDUMP BEGIN <name> <size>`, `HFD <hex>`..., `HFDUMP END <crc32>` | framed file; `<name>` may contain `/`, it is saved under `dumps/<name>` |
| `HFBS ...` / `HFVF ...` | bootstrap / verify status lines |

A dump runs at about 43 KB/s of payload under WHPX (polled UART, hex): the
four bootstrap files (~710 KB) take ~17 s.

## Known repo data problem (read this)

The archive this repo came from had **every 0x05 byte (CH_CURSOR) stripped from
DolDoc-format files**, including from their binary tails, and from the `.GR`
picture `Demo/Games/Stadium/StadiumBG.GR` (its compressed body is 20 bytes
short, and `GRRead()` of it hangs). A lost byte shifts everything after
it inside the tail, so a damaged DolDoc file shows one or more of:

- **lost bins:** later `CDocBin` headers are garbage, so `DocLoad()` drops the
  bins and `DocBinsValidate()` calls `RawPrint(3000,"Bin Not Found")` for every
  reference: a 3 s stall each (Ctrl-M's `PersonalMenu.DD` alone: ~80 s);
- **a truncated last bin:** its declared size runs past the end of the file
  (`doccheck` "tail overrun N"), so `DocLoad()` copies whatever follows the
  file buffer;
- **malformed sprites:** a bin whose elements no longer parse. `Sprite3()` and
  friends then index `sprite_elem_base_sizes[]` with a type of 30 or more and
  walk into the heap: General Protection faults (`Demo/Graphics/Extents.HC`),
  endless WinMgr loops (`gr.empty_sprite` in `Adam/AMouse.HC`, the fallback for
  every bad document sprite), and QEMU-WHPX dying with "failed to decode
  instruction" (`SpritePlot3D`, `Shadow`);
- **shifted sprites:** a bin that still parses but whose numbers moved by a
  byte: mesh triangles naming vertex 0x03000000 of a 6-vertex mesh
  (`Demo/Graphics/Pick3D.HC`: `Gr3Mesh()` reads far past the vertex list and
  QEMU-WHPX dies the same way), or a line to y=184549375 (`X-Caliber`).

The QEMU-WHPX deaths are what stop the stock `Misc/OSTestSuite.HC` under WHPX
on an unpatched image. The error comes from WHPX's instruction emulator, so
`--accel tcg` does not raise it (it reads the wild addresses instead). On a
patched image the suite runs under WHPX except for two steps: `DunGen` (its
map sprite is lost, see below) and `Strut`, whose `DrawIt` takes a General
Protection fault under WHPX on a stock tree too (not sprite data).

`forge.py doccheck` lists every affected file: it parses each tail the way
`DocLoad()` does, walks each sprite bin the way `SpriteElemSize()` does (a
sound sprite ends in `SPT_END` exactly at its last byte, which is how the
sprite editor saves it, keeps every coordinate and size within +-2^20 and has
no mesh triangle naming a vertex outside its mesh), and checks each `.GR`
picture's `DCSave()` layout.
It currently reports about 40 sprite-bearing `.HC`/`.DD` files, including
`PersonalMenu.DD`, plus `StadiumBG.GR`.

- **The `.MAP` files are fixed:** `bootstrap --install` rebuilt
  `Kernel/Kernel.MAP` and `Compiler/Compiler.MAP` in the guest, with their 0x05
  bytes, and they are in the repo, so the old ~45 minute boot stall is gone:
  every image reaches the desktop in about 10 s.
- **Workaround for the sprite files:** `--patch-broken-bins` rewrites, in the
  image only, every damaged tail that `doccheck` reports: sound bins are kept,
  and each lost, truncated, malformed or shifted sprite becomes the 1-byte
  empty sprite (`SPT_END`), so nothing stalls or walks out of bounds (those
  sprites are simply blank). In a `.MAP` file it drops the `,BI=n` of a lost
  bin instead. A damaged `.GR` picture becomes a blank one of the same size
  and palette. Files that are sound are never touched. A program that needs a
  lost sprite's data still fails: `DunGen` builds its map from its lost first
  sprite and takes a General Protection fault.
- **Defaults:** the patch is on for `play`, `boot`, `run`, `bootstrap` and
  `selftest`, and off for `iso`, which builds a faithful image (it boots in
  ~10 s, but opening a damaged file stalls 3 s per lost bin, and the malformed
  and shifted sprites misbehave as above).
- **The real fix needs the original V5.03 ISO:** restoring the stripped bytes
  means copying the files from the original TempleOS V5.03 distribution
  (expanded from their `.Z` form). A byte can be restored by hand only when the
  sprite structure makes it unambiguous; afterwards `doccheck` must no longer
  list the file.

## Editing TempleOS sources safely: `tosedit.py`, `toslint.py`

TempleOS sources are 8-bit DolDoc with LF line endings; some carry a binary
sprite tail after the first NUL and some contain CP437 bytes. `.gitattributes`
(`* -text`) keeps git from converting line endings. Never re-encode to UTF-8.

- `tosedit.py`: byte-safe find/replace that edits only the text before the
  first NUL and keeps the binary tail and every other byte unchanged
  (`from tosedit import replace, insert_after, create`).
- `toslint.py [--base archive] [files]`: checks changed files against pristine
  TempleOS. It flags UTF-8 sequences, line-ending changes, altered binary tails,
  odd `$` counts per line (every original line has an even count), bad DolDoc
  commands, broken `FI:`/`FF:`/`FL:` link targets and brace-balance drift.
