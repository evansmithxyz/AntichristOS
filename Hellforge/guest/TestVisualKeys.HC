//Hellforge WS4 test: the Ctrl-Alt hotkeys, pressed for real.
//  python Hellforge/forge.py run Hellforge/guest/TestVisualKeys.HC
//    --keys "16:<ctrl-alt-i>;19:<ctrl-alt-u>;22:<ctrl-alt-y>;
//            25:<ctrl-alt-shift-y>;28:<ctrl-alt-shift-u>;31:<ctrl-alt-shift-i>"
//(one line, no spaces).  Each key reaches its callback through the
//keyboard driver and the WinMgr; this task only watches the state.

I64 tk_fails=0;

Bool TkWait(I64 *var,I64 val,U8 *what,U8 *shot)
{
  F64 timeout=tS+40.0;
  while (*var!=val && tS<timeout)
    Sleep(20);
  Sleep(400); //One press must toggle once: no echo flips it back.
  if (*var==val) {
    HfPrint("TK PASS %s (tS %5.1f sc %X)\n",what,tS,kbd.last_down_scan_code);
    HfShot(shot,600);
    return TRUE;
  } else {
    HfPrint("TK FAIL %s (still %d, last sc %X)\n",what,*var,
	  kbd.last_down_scan_code);
    tk_fails++;
    return FALSE;
  }
}

U0 TkMain()
{
  I64 breathing;
  F64 deadline;
  HfPrint("TK start palette=%d flip=%d font=%d\n",
	unholy_palette,unholy_scrn_flip,unholy_font_mode);
  MsSet(200,150);
  TkWait(&unholy_palette,UNHOLY_PAL_NEGATIVE,
	"Ctrl-Alt-I: hellfire -> negative","k_negative");
  TkWait(&unholy_scrn_flip,UNHOLY_FLIP_ROT180,
	"Ctrl-Alt-U: upside down","k_upside");
  TkWait(&unholy_font_mode,UNHOLY_FONT_MIRROR,
	"Ctrl-Alt-Y: mirror font","k_mirror");
  TkWait(&unholy_font_mode,UNHOLY_FONT_ROT180,
	"Ctrl-Alt-Shift-Y: rot180 font (backmask with rot180 scrn)","k_backmask");
  TkWait(&unholy_scrn_flip,UNHOLY_FLIP_VFLIP,
	"Ctrl-Alt-Shift-U: reflection","k_reflect");
  deadline=tS+40.0;
  while (!unholy_breathing && tS<deadline)
    Sleep(20);
  Sleep(400);
  breathing=unholy_breathing;
  TkWait(&breathing,TRUE,"Ctrl-Alt-Shift-I: breathing hellfire","k_breathing");
  HfPrint("TK DONE fails=%d\n",tk_fails);
  hf_exit_code=tk_fails;
}

TkMain;
