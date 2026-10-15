# Hellforge

Host-side toolchain that turns this repo tree into a bootable TempleOS /
AntichristOS CD image (`.ISO.C`), boots it headless in QEMU, runs HolyC in the
guest, and rebuilds the AOT binaries (kernel + compiler) inside the guest.
Pure Python 3 + NASM + QEMU. Build outputs go to `Hellforge/out/` (git-ignored).
Hellforge never edits repo files (except `bootstrap --install`, on request):
everything it injects lives only in the image.

| File | Role |
|---|---|
| `stage1.asm` | NASM port of `BDVD_START..BDVD_END` (`Adam/Opt/Boot/BootDVD.HC`), the El Torito no-emulation loader. The boot message is a build parameter. |
| `mkiso.py` | Pure-Python port of `RedSeaISO()` (`Adam/Opt/Boot/DskISORedSea.HC`). It writes a RedSea ISO from a directory. |
| `qemu.py` | Headless QEMU harness: monitor, screendump to PNG, sendkey, COM1 to a file, isa-debug-exit, timeout, stall detection, guest-requested screenshots. |
| `forge.py` | The CLI: `iso`, `boot`, `run`, `bootstrap`, `selftest`, `doccheck`. |
| `guest/Serial.HC` | HolyC helpers for injected code: polled COM1, framed hex dump, `HfShot`, `HfExit`. |
| `guest/Bootstrap.HC` | In-guest rebuild of `Compiler.BIN`, `Kernel.BIN` and the `.MAP` files (driven by `bootstrap`). |
| `guest/VerifyBoot.HC` | Checks that a booted image runs the freshly built kernel (used by `selftest`). |
| `guest/BootOk.HC`, `guest/DumpTest.HC` | Example tests. |

## Commands

```sh
python Hellforge/forge.py iso  [--out F] [--boot-msg "Loading AntichristOS"] [--patch-broken-bins]
python Hellforge/forge.py boot [--seconds 60] [--every 10] [--shots 3,10] [--keys "12:n"]
python Hellforge/forge.py run  Hellforge/guest/BootOk.HC [--timeout 300] [--accel tcg]
python Hellforge/forge.py run  --eval '"2+2=%d\n",2+2; hf_exit_code=4;'
echo 'HfPrint("hi\n");' | python Hellforge/forge.py run -
python Hellforge/forge.py bootstrap [--install] [--stages 2] [--out-dir D]
python Hellforge/forge.py selftest  [--no-stage2]
python Hellforge/forge.py doccheck          # list files with corrupted DolDoc bin tails
python Hellforge/mkiso.py --help            # all ISO options (--add, --append, --exclude, ...)
python Hellforge/qemu.py ISO --timeout 60 --shots 5,20 --stop-on TEXT
```

Common options: `--accel auto|whpx|tcg`, `--mem 1024`, and `--smp N` (4 tested).
`--accel auto` tries WHPX first and falls back to TCG.

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

**Failure diagnostics.**

- The test task's terminal (its `Print` output and compiler errors) comes back
  between `HELLFORGE_DOC_BEGIN` / `HELLFORGE_DOC_END` (`--no-doc` to skip). With
  `--quiet` nothing is echoed, but this text is printed if the test fails.
- When the test fails (exit code != 0) the wrapper asks for a final
  screenshot, `<name>_fail.png`, before leaving QEMU (`--no-fail-shot` to skip).
- **Boot-time errors** (an Adam/StartOS/Home file that doesn't compile) happen
  before the autorun gets control, so nothing reaches the serial port. The
  harness watches for `HELLFORGE_STARTOS_END`; if it hasn't appeared after
  `--boot-timeout` seconds (default 120 with `--patch-broken-bins`, disabled
  without it, because the unpatched tree takes ~45 min to boot), it stops,
  saves `<name>_timeout.png`, explains which stage was missed and returns 124.
  A hanging test is handled the same way at `--timeout`.

## `bootstrap`: rebuild the AOT binaries inside TempleOS

`bootstrap` rebuilds `Compiler/Compiler.BIN`, `Compiler/Compiler.MAP`,
`Kernel/Kernel.MAP` and the CD boot kernel `0000Boot/0000Kernel.BIN.C` from the
**current** sources, the way `Misc/DoDistro.HC` does, and copies them to the
host:

1. The image boots (with `--patch-broken-bins`) and runs `guest/Bootstrap.HC`
   behind a generated prelude (`hf_bs_drv`, `hf_bs_cfg`, `hf_bs_trees`).
2. The guest copies `::/Kernel` and `::/Compiler` (add more with `--tree DIR`)
   from the read-only CD `T:` to the RAM drive `B:` (`--drv`) and `Cd("B:/")`.
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
ATAPI at 0x170).

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

**Deviations, none of which affect function:**

- Entries are sorted by name.
- Every timestamp is fixed (`--date`, default 2017-08-09 12:00), so builds are reproducible.
- `unique_id` is derived from a hash instead of `GetTSC^Now`.
- `--volume-id` is optional. TempleOS never sets one.

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
DolDoc-format files**, including from their binary tails. That shifts the
`CDocBin` headers, so bins go missing.

- **Affected:** `Kernel/Kernel.MAP`, `Compiler/Compiler.MAP`, `PersonalMenu.DD`, and
  about 30 sprite-bearing `.HC`/`.DD` files. `forge.py doccheck` lists them.
- **Not affected:** the `.BIN` files, which still contain 0x05 bytes.
- **Effect at boot:** `DocBinsValidate()` calls `RawPrint(3000,"Bin Not Found")` for
  every reference to a missing bin. `MapFileLoad()` in `MakeHome.HC` alone hits about 860
  of them, so a faithful image sits for roughly 40-45 minutes before the desktop appears.
- **Workaround:** `--patch-broken-bins` keeps the intact bins and handles the lost ones
  in the image only. In `.MAP` files it drops `,BI=n`. Elsewhere it adds an empty sprite.
  With the patch, the desktop is up in about 6 s.
- **Defaults:** the patch is on for `boot`, `run`, `bootstrap` and `selftest`, and off for `iso`.
- **The `.MAP` part is fixed by `bootstrap`:** the in-guest rebuild produces
  `.MAP` files whose bins are intact (they contain the 0x05 bytes: 105 in
  `Compiler.MAP`, 92 in `Kernel.MAP`; the repo copies are exactly that many
  bytes shorter). `bootstrap --install` puts them in the repo. The sprite files
  still need the original V5.03 ISO.

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
