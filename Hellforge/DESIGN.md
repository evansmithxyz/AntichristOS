# AntichristOS V6.66 — design spec

AntichristOS is the inverse of TempleOS V5.03. Where TempleOS is God's temple, AntichristOS is
Pandemonium's basement. Where HolyC is holy, **Unholy C** is backmasked. It is a parody of
TempleOS's *own* framing, built from heavy-metal / satanic-panic tropes: backmasking, the tritone
(*diabolus in musica*), 666, hellfire, Dante, Milton.

## Ground rules (every workstream)

1. **Tone.** Playful heavy-metal parody. Never mock Terry A. Davis, his health or his beliefs, and
   never mock real believers. Remove personal data and the offensive or paranoid passages rather
   than parodying them (see WS5). Credit TempleOS and Terry A. Davis respectfully.
2. **It must boot.** Every change is verified by booting it in QEMU with Hellforge
   (`Hellforge/README.md`). Adam/Home/StartOS code is JIT-compiled at boot by the *old*
   `Compiler.BIN`, so a single syntax error breaks boot.
3. **Byte-safe edits only.** Files are 8-bit DolDoc with LF line endings. Some have binary
   sprite tails after the first NUL; some contain CP437 bytes. Use `Hellforge/tosedit.py`, or
   Python reading and writing bytes / latin-1. Never let an editor re-encode a file to UTF-8, and
   never use non-ASCII characters (no em dashes or smart quotes). Run
   `python Hellforge/toslint.py` on your files; it must report 0 errors.
4. **DolDoc.** A literal `$` in any .HC/.DD/.IN text must be written `$$`. Every line has an
   even number of `$`.
5. **Compatibility.** Keep every existing public identifier, function signature, class layout,
   numeric define, exception code and file path that other code uses. Add new names; don't rename
   old ones. Header edits (`Kernel/*.HH`, `Compiler/*.HH`) must be additive (new `#define`s, or
   string-valued define changes) because StartOS JIT-includes them against the old binaries.
6. **Frozen strings.** Never change the ISO publisher id `"TempleOS RedSea"` (the kernel matches
   it to mount the CD), `'TOSB'`, `"CD001"`, the paths `"/Compiler"`, `"StartOS"` and
   `"::/Doc/HelpIndex.DD"`, or the registry keys `"TempleOS/<App>"`.
7. **HolyC gotchas.** There is no `?:`. `<<` and `>>` bind tighter than `*` and `/`, which bind
   tighter than `&` `^` `|`, which bind tighter than `+` and `-`, so parenthesize. Boot compiles
   with paren and dup-type warnings on. Persistent hooks (Ctrl-Alt callbacks, `gr.fp_*`, font
   pointers) must be compiled in the Adam task (MakeAdam/MakeHome/HomeSys), never from Once.HC.
   Ctrl-Alt callbacks run in WinMgr and must not Sleep.
8. **File ownership.** Only edit files your workstream owns (table below). If you need something
   from another workstream's file, don't edit it; say so in your report.
9. **New Unholy C syntax** (`unless`, `until`, `backwards`) exists only after the compiler is
   rebuilt. Never use it in boot-path code (Kernel, Compiler, Adam, StartOS, Home files). Only
   use it in demos, apps and tests that run after boot. The keyword *aliases* (`fi`, `elihw`,
   `summon`, ...) come from `OpCodes.DD` at boot and work with the old compiler, but boot-path
   code should still use standard spellings for readability.

## Fixed names (all workstreams must agree)

| Thing | Value |
|---|---|
| OS name / version | `AntichristOS`, `sys_os_version` = 6.66, shown as `V6.66` (`%4.2f`) |
| Language | `Unholy C` (the doc file is `Doc/UnholyC.DD`). Source extension `.UC`/`.UH` is accepted alongside `.HC`/`.HH`. |
| Build toolchain | `Hellforge/` (host side: excluded from the ISO) |
| Error / warning prefix | `BLASPHEMY:` / `TEMPTATION:`; compile summary `Sins:%d Temptations:%d Code:%X Size:%X` |
| Cmd-line prompt | `T:/Home<` (the `>` is inverted) |
| Stage-1 boot msg | `Summoning AntichristOS` (dots follow) |
| Kernel banner | `AntichristOS V6.66`, then a backmasked line |
| Debugger | `Unholy C Debugger -- The Exorcist` |
| Oracle | **The Adversary**. `AdversaryWord` (F7), `AdversaryPassage` (Shift-F7), `DiabolusSong` (F6), `AdversaryDoodle` (Shift-F6). The originals stay: `GodWord` (F8), `GodBiblePassage` (Shift-F8), `GodSong` (F9), `GodDoodle` (Shift-F9). |
| Oracle notes doc | `Adam/God/AdvNotes.DD` (new). `Adam/God/HSNotes.DD` stays as is, and new docs stop linking to it. |
| Ctrl-Alt keys | `I` cycles palette Hellfire, Negative, Holy (Shift-I: breathing fire on/off). `U` = upside-down screen (Shift-U: reflection). `Y` = mirror-script font (Shift-Y: rot180 font). `R` = backmask ALL music (Shift-R: Unholy/Locrian mode). `B` = Bible, opens at Revelation. |
| Default palette | Hellfire, applied at boot |
| Tip system | `Doc/Temptations.DD` + "Temptation of the Day" (Once.HC) |
| Tour | "The Descent" (12 circles + TourD.IN "The Number of the Beast") |
| About doc | `Doc/AboutAntichristOS.DD` (`Doc/AboutTempleOS.DD` becomes a stub) |
| PC spec doc | `Doc/StdAntichristOSPC.DD` (replaces `Doc/StdTempleOSPC.DD`) |
| Charter | `Doc/Charter.DD`, rewritten in place as "The Anti-Charter" |
| New demos | `Demo/UnholyC/HelloHell.UC`, `Demo/UnholyC/Backmasked.UC`, `Demo/UnholyC/UnlessUntil.UC` (WS1); `Demo/MultiCore/Semordnilap.HC` (WS3) |
| New game | `Apps/Descent/` with `Run.HC` and `Descent.UC` (WS6): fall through Dante's nine circles |
| New Adam file | `Adam/UnholyC.HC` (WS1): `StrRev`, `Backmask(fmt,...)`, `#define BEAST 666` |

### Unholy C keyword set (WS1 implements, WS5 documents, WS6 uses)

**Backmasked aliases.** Each one is an `OpCodes.DD` line mapping the reversed word to the
existing keyword number. No rebuild is needed.

`edulcni`=include, `enifed`=define, `noinu`=union, `hctac`=catch, `ssalc`=class, `yrt`=try,
`fi`=if, `esle`=else, `rof`=for, `elihw`=while, `nretxe`=extern, `nruter`=return, `foezis`=sizeof,
`od`=do, `msa`=asm, `otog`=goto, `kaerb`=break, `hctiws`=switch, `trats`=start, `dne`=end,
`esac`=case, `tluafed`=default, `cilbup`=public, `tesffo`=offset, `tropmi`=import, `fedfi`=ifdef,
`fednfi`=ifndef, `fidne`=endif, `tressa`=assert, `citats`=static, `kcol`=lock, `denifed`=defined,
`ssalctsal`=lastclass.

WS1 must grep for identifier collisions first and drop any alias that collides. Skip the
palindrome `exe` and the underscore keywords.

**Heavy-metal aliases**, also `OpCodes.DD`-only: `summon`=include (`#summon "File"`),
`curse`=define (`#curse BEAST 666`), `forsake`=break, `sacrifice`=return, `descend`=goto,
`otherwise`=else, `tempt`=try, `repent`=catch, `legion`=switch.

**New keywords** (rebuild of Compiler.BIN required; free numbers 48-50):

- `unless (c) S [else S]` is `if (!(c)) ...`, done by flipping the branch sense.
- `until (c) S` is `while (!(c)) S`.
- `do S until (c);` is the inverse do-while. `do S while (c);` still works.
- `backwards "text"` gives a string constant with its bytes reversed (after escapes are
  processed). It works as an expression, and as a print statement:
  `backwards "\n!dlroW ,olleH";` prints `Hello, World!`.

## Workstreams and file ownership

| WS | Theme | Owns (exclusive) |
|---|---|---|
| WS1 | Unholy C compiler and language | `Compiler/**` (sources, `OpCodes.DD`, `CompilerA/B.HH`), `Kernel/KernelA.HH`, `Adam/MakeAdam.HC`, `Adam/UnholyC.HC` (new), `Adam/DolDoc/DocCodeTools.HC`, `Adam/DolDoc/DocPopUp.HC`, `Demo/UnholyC/**` (new), `Hellforge/guest/TestUnholyC*.HC` (new) |
| WS2 | Kernel and boot identity | `Kernel/**` except `KernelA.HH`, `Adam/Opt/Boot/**`, `StartOS.HC`, `Hellforge/guest/TestKernel*.HC` (new) |
| WS3 | The Adversary oracle and music | `Adam/God/**` (but leave `HSNotes.DD`'s content alone), `Adam/ASnd.HC`, `Adam/DolDoc/DocPutKey.HC`, `Apps/Psalmody/**`, `Apps/Vocabulary/**`, `Linux/**`, `Downloads/Linux/**`, `HomeKeyPlugIns.HC`, `Demo/MultiCore/Semordnilap.HC` (new), `Hellforge/guest/TestOracle*.HC` (new) |
| WS4 | Hellfire visuals | `Adam/Gr/**`, `Adam/WallPaper.HC`, `Adam/Win.HC`, `Adam/WinMgr.HC`, `Adam/Menu.HC`, `Adam/AMouse.HC`, `Adam/Ctrls/**`, `Adam/DolDoc/DocTerm.HC`, `Adam/DolDoc/DocEd.HC`, `Adam/DolDoc/DocInit.HC`, `HomeSys.HC`, `Hellforge/guest/TestVisual*.HC` (new) |
| WS5 | Docs, narrative, voice | `Doc/**`, `Misc/Tour/**`, `Misc/OSInstall.HC` (plain prompts only), `Misc/OSTestSuite.HC` (strings only), `Once.HC`, `ReadMe.TXT`, `Downloads/ReadMe.TXT`, `PersonalMenu.DD`, `PersonalNotes.DD`, `Adam/ADefine.HC`, `Adam/Training.HC`, `Adam/DolDoc/DocLink.HC`, `Adam/DolDoc/DocGr.HC`, `Adam/DolDoc/MakeDoc.HC`, `Demo/**` (text edits) except the new files owned by WS1, WS3 and WS6 |
| WS6 | Showcase game "Descent" | `Apps/Descent/**` (new), `Hellforge/guest/TestDescent*.HC` (new) |
| Integration | Hellforge, merge, bootstrap, ISO | `Hellforge/**` (other than the new test files above), binaries |

Nobody edits `Misc/Bible.TXT`, `Adam/AutoComplete/*.DATA`, `Demo/WebLogDemo/*.LOG`, the
binaries, or anything not listed.

### WS1 — Unholy C (compiler and language)

- Add the `OpCodes.DD` alias lines (backmasked and heavy-metal) after the KEYWORD block.
- Add `KW_UNLESS 48`, `KW_UNTIL 49` and `KW_BACKWARDS 50` to `CompilerA.HH`, plus `OpCodes.DD`
  lines, plus the parser in `PrsStmt.HC`/`PrsExp.HC`. Flip the branch sense; don't insert NOT.
  `do..until` goes in `PrsDoWhile`. `backwards` works in `PrsUnaryTerm` and as a print statement.
- Diagnostics: set `ST_ERR_ST`/`ST_WARN_ST` in `KernelA.HH` to `BLASPHEMY:`/`TEMPTATION:`,
  and the `Cmp` summary to `Sins:%d Temptations:%d`. The `CExcept.HC` boot note can be themed,
  but keep `Fix;`. Make `PrsExp.HC:731` say "Use AntichristOS postfix typecasting". The
  `CInit.HC` display name becomes `UNHOLYC_TYPECAST`, and the define name stays.
- Inverted prompt: `CMisc.HC` `CmdLinePmt` prints `<` instead of `>`.
- `.UC`/`.UH`: append `;*.UC*;*.UH*` to `FILEMASK_JIT/AOT/SRC` in `KernelA.HH`. Add the
  `"UC.Z"` fallback in `DocCodeTools.HC` Load discovery. Change `DocPopUp.HC` messages to
  "Not .HC/.UC File". Extensionless `#include`/`ExeFile` retries `.UC` **only after the
  `.HC` lookup has failed** (no extra cost on the boot path).
- Reindenter (`DocCodeTools.HC` EdRIStmt) learns `unless`/`until`.
- `Adam/UnholyC.HC` (new, included from MakeAdam after the string and math libs):
  `public U8 *StrRev(U8 *src,CTask *mem_task=NULL)`, `public U0 Backmask(U8 *fmt,...)`
  (prints each line reversed and escapes `$`), `#define BEAST 666`. Don't name anything
  `Rev` (it's used by Demo/RevFileDemo).
- Demos: `Demo/UnholyC/HelloHell.UC`, `Backmasked.UC` (a whole program in backmasked keywords)
  and `UnlessUntil.UC`.
- Tests: `Hellforge/guest/TestUnholyC.HC` (aliases; old compiler) and `TestUnholyC2.HC`
  (unless/until/backwards; needs the rebuilt compiler). Validate with
  `forge.py bootstrap --install` *inside your worktree*, then restore the binaries with
  `git checkout -- 0000Boot Compiler/Compiler.BIN Compiler/Compiler.MAP Kernel/Kernel.MAP`.
  Integration does the final rebuild.

### WS2 — Kernel and boot identity

- `KGlbls.HC`: `sys_os_version=6.660;`. `KMain.HC:160`: `"AntichristOS V%4.2f\t%D %T\n"` plus
  a backmasked second line. Themed boot progress lines ("Summoning IRQs", "We Are Legion"
  multicore, "Loading the Unholy C Compiler"); keep every functional string.
- Task display names: `madA Task CPU00`, `hteS Task CPU%02X`, `Idle Hands`. The identifiers stay.
- `KDbg.HC`: `Unholy C Debugger -- The Exorcist` banner and a tritone (B4, then F5) instead of
  the beep. Change help text comments only; the commands stay.
- `KExcept.HC`: `Panic("Unholy Exception")`. Theme `KDefine.HC` `ST_INT_NAMES` entries,
  keeping the exact count and order.
- `KMisc.HC` `Beep`: same signature, plays the note and then the tritone below it.
- `DskAddDev.HC` port prompt: "not a soul contract" text; prompt order and parsing are unchanged.
- Optional, verify with screenshots: hellfire raw console (DAC tweak in SysGrInit's VGA
  branch, `Display.HC` text attr). Drop it if it misbehaves.
- `Adam/Opt/Boot/BootDVD.HC` messages: "Summoning AntichristOS" and "AntichristOS requires a
  64-bit capable processor (and your soul)." Stay under the size assert. El Torito ID
  `AntichristOS` in `DskISORedSea.HC`/`DskISO9660.HC`. The publisher stays.
  `BootMHDIns.HC` menu text becomes "AntichristOS".
- Do not touch `KCfg.HC` prompt order (the distro answer string depends on it).
- Validate with `forge.py bootstrap --install` in your worktree, boot, check the banner via
  screenshot or serial, then restore the binaries (see WS1).

### WS3 — The Adversary oracle and music

- `AdversaryWord`: a backmasked vocab word. Precompute reversed words in GodInit. If the
  reversal is itself a word (god/dog, evil/live, devil/lived...), print it red as a TRUE
  BACKMASK with a tritone. `AdversaryPassage`: a Bible passage printed with lines in reverse
  order and characters reversed, plus a reversed verse header and "(hold to a mirror)".
- `DiabolusSong`: GodSong's form gains a mode (Holy Ionian / Unholy Locrian / Diabolus
  tritone) and a Backmask checkbox. `GodSongStr`'s signature stays.
- `ASnd.HC`: `PlayStrRev(st)`. Add `music.backmask` and `music.unholy` (Locrian map, a separate
  table; never mutate `music.note_map`) appended at the end of CMusicGlbls, with Ctrl-Alt-R
  toggles.
- JukeBox ("DoomBox"): `b` plays the selected hymn backmasked, `r` appends curses, legend
  updated. Psalmody: Song menu Backmask, Invert and PlayBackwards. `AdversaryDoodle` (hellfire
  doodle). Vocabulary quiz shows backmasked words. Ctrl-Alt-B Bible opens at Revelation.
- `DocPutKey.HC`: the F6-F9 bindings above with `KeyDescSet` "Cmd /..." strings. SHIFT-F1
  opens `::/Doc/AboutAntichristOS.DD.Z`. F5 Run discovery falls back to `"UC.Z"`.
- `Adam/God/AdvNotes.DD`: the Adversary's notes, in heavy-metal parody voice. Re-point the
  HSNotes links inside Adam/God code to it.
- `Demo/MultiCore/Semordnilap.HC`: a multicore Bible scan for words whose reversal is also a word.
- `Linux/`: `AdversaryWords` and `AdversaryPassage` scripts (LF endings, `rev`/`tac`).

### WS4 — Hellfire visuals

- `GrPalette.HC`: `gr_palette_hellfire` / `_negative` / `_holy` (values in the WS4 brief),
  `PaletteUnholySet(mode)`, hellfire at boot, Ctrl-Alt-I (+Shift breathing).
- Upside-down screen (rot180) and reflection (vflip) in `GrUpdateVGAGraphics`, with
  mouse-position compensation, on Ctrl-Alt-U. The mode-0 blit path stays identical.
- Unholy fonts: mirror and rot180 copies of glyphs 32-255 (0-31 untouched), on Ctrl-Alt-Y.
  Infernal glyphs (inverted pentagram, horns, trident, skull, 3 flame frames) go in blank slots
  14-21 of a RAM font. The flames animate in the wallpaper.
- Wallpaper top bar: 666 and flame ornaments in the free columns. Term button reads "Hell"
  (same-length tail patch).
- Pitchfork mouse pointer.
- Inverted window chrome: `[X]` on the left, MENU on the right; hit zones swapped to match.
- `HomeSys.HC`: summoning-circle boot splash (pentagram in circle, "AntichristOS", tritone),
  banner `"AntichristOS V%4.2f"`.

### WS5 — Docs, narrative, voice

Anti-Charter; Welcome ("Abandon all hope, ye who boot here"); Start.DD; HelpIndex labels ("Hellp")
with the filename kept; `AboutAntichristOS.DD` (respectful credit, no personal data); FAQ of the
Damned; `UnholyC.DD` documenting exactly the keyword set above plus the inherited HolyC reference;
a `HolyC.DD` stub that keeps the `DemoHolyC` and `operator precedence` anchors; Temptations.DD
and Once.HC; The Descent tour plus TourD; StandBy labels for the new F-keys and Ctrl-Alt keys;
DemoIndex headings plus an "Unholy Rites" section linking the new demos and game; PersonalMenu
labels (tail-splice); EdPullDown names; ChgLog entry; Credits fork line; StdAntichristOSPC.DD;
guardrail removals; ADefine `DD_OS_NAME_VERSION` "AntichristOS V%0.2f"; a prose substitution pass
(TempleOS to AntichristOS, HolyC to Unholy C) in plain text only, never inside link args; and the
ReadMe files.

### WS6 — "Descent" (showcase game in Unholy C)

`Apps/Descent/Descent.UC` + `Apps/Descent/Run.HC` (`#include "Descent.UC"` + launch). You are a
lost soul falling through Dante's nine circles (Limbo, Lust, Gluttony, Greed, Wrath, Heresy,
Violence, Fraud, Treachery). Steer through gaps in fiery ledges, with speed rising per circle, a
circle banner, a palette or colour shift per circle, a tritone sting at each transition and a
depth score. Written in Unholy C: heavy use of the metal and backmasked aliases (`summon`, `fi`,
`esle`, `elihw`, `forsake`, `sacrifice`...). No `unless`/`until`/`backwards`, so it runs on the
current compiler. Test it by overlaying WS1's alias lines into the image (`mkiso --add`).
