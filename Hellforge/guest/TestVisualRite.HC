//Hellforge WS4 review test: the hand on a damned screen.
//  python Hellforge/forge.py run Hellforge/guest/TestVisualRite.HC
//Independent checks of the Hellfire visuals, aimed at the places a
//first test can miss:
//  * hardware mouse motion in rot180/vflip (simulated ms_hard evts),
//    including 1 px steps across the reflection's middle row,
//  * MsSet() in a flipped mode (games, InFile, tests) must land where
//    asked, with and without buttons, and leave the hand working,
//  * grid snap stays on the grid when the scrn is upside down,
//  * a real title-bar click on [X] while the scrn is upside down,
//  * the palette survives a real task death, flames flicker in the
//    font itself, the kernel Ctrl-Alt-F font swap round-trips,
//  * the zoomed scrn can be turned upside down (screenshot).

I64 tr_fails=0;

U0 TrCheck(Bool ok,U8 *what)
{
  if (ok)
    HfPrint("TR PASS %s\n",what);
  else {
    HfPrint("TR FAIL %s (ms %d,%d hard %d,%d)\n",what,
	  ms.pos.x,ms.pos.y,ms_hard.pos.x,ms_hard.pos.y);
    tr_fails++;
  }
}

U0 TrHand(I64 dx,I64 dy)
{//Pretend the PS/2 mouse moved the displayed pointer by (dx,dy).
  PUSHFD
  CLI
  ms_hard.pos.x+=dx;
  ms_hard.pos.y+=dy;
  ms_hard.evt=TRUE;
  POPFD
  Sleep(120); //A few WinMgr frames.
}

Bool TrAt(I64 x,I64 y)
{
  return ms.pos.x==x && ms.pos.y==y &&
	ms.pos_text.x==x/FONT_WIDTH && ms.pos_text.y==y/FONT_HEIGHT;
}

U0 TrClick(I64 x,I64 y)
{
  MsSet(x,y,,TRUE);
  Sleep(300);
  MsSet(x,y,,FALSE);
}

Bool TrDacIsHellfire()
{
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    if (GrPaletteColorGet(i)!=gr_palette_hellfire[i])
      return FALSE;
  return TRUE;
}

U0 TrMain()
{
  I64 i,x,y;
  U64 f0[UNHOLY_FLAMES_NUM];
  Bool changed;
  CTask *t;

  HfPrint("TR start: ms_hard.installed=%d scale %5.2f offset %d,%d\n",
	ms_hard.installed,ms.scale.x,ms.offset.x,ms.offset.y);
  TrCheck(ms_hard.installed,"PS/2 mouse is installed");

//--- rot180: MsSet lands where asked, then the hand drives it.
  UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  MsSet(100,50);
  Sleep(150);
  TrCheck(TrAt(100,50),"rot180: MsSet(100,50) stays at logical (100,50)");
  TrCheck(ms_hard.pos.x==GR_WIDTH-1-100 && ms_hard.pos.y==GR_HEIGHT-1-50,
	"rot180: hardware re-anchored at the displayed spot");
  TrHand(10,0);
  TrCheck(TrAt(90,50),"rot180: hand right 10 -> logical left 10");
  TrHand(0,-20);
  TrCheck(TrAt(90,70),"rot180: hand up 20 -> logical down 20");
  MsSet(,,,TRUE);
  Sleep(150);
  TrCheck(TrAt(90,70) && ms.lb,"rot180: button-only MsSet does not jump");
  MsSet(,,,FALSE);
  Sleep(150);
  TrCheck(TrAt(90,70) && !ms.lb,"rot180: button release does not jump");
  TrHand(-5,5);
  TrCheck(TrAt(95,65),"rot180: hand still works after MsSet");
  for (i=0;i<4;i++)
    TrHand(1,1);
  TrCheck(TrAt(91,61),"rot180: four 1 px steps");

//--- grid snap with the scrn upside down.
  ms_grid.snap=TRUE;
  ms_grid.x=ms_grid.y=8;
  TrHand(3,3);
  TrCheck(!(ms.pos.x%8) && !(ms.pos.y%8),"rot180: grid snap stays on grid");
  HfPrint("  snapped at %d,%d\n",ms.pos.x,ms.pos.y);
  ms_grid.snap=FALSE;
  TrHand(0,0);

//--- vflip: 1 px steps across the middle row must not stick.
  UnholyScrnFlipSet(UNHOLY_FLIP_VFLIP);
  MsSet(300,236);
  Sleep(150);
  TrCheck(TrAt(300,236),"vflip: MsSet(300,236) stays put");
  for (i=0;i<8;i++)
    TrHand(0,-1);
  TrCheck(TrAt(300,244),"vflip: eight 1 px steps up cross the middle row");
  for (i=0;i<8;i++)
    TrHand(1,1);
  TrCheck(TrAt(308,236),"vflip: and back down again");

//--- flip off: everything is the plain old mouse.
  UnholyScrnFlipSet(UNHOLY_FLIP_NONE);
  x=ms.pos.x; y=ms.pos.y;
  HfPrint("  after flip off: ms %d,%d hard %d,%d\n",x,y,
	ms_hard.pos.x,ms_hard.pos.y);
  TrCheck(x==ms_hard.pos.x && y==ms_hard.pos.y,
	"normal: pointer stays where it was displayed");
  TrHand(7,-3);
  TrCheck(TrAt(x+7,y-3),"normal: hand moves untouched");
  MsSet(123,321);
  Sleep(150);
  TrCheck(TrAt(123,321),"normal: MsSet untouched");

//--- A real [X] click while the world is upside down.
  UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  t=User;
  Sleep(600);
  WinToTop(t);
  WinFocus(t);
  Sleep(300);
  TrClick(t->win_left*FONT_WIDTH+12,(t->win_top-1)*FONT_HEIGHT+4);
  Sleep(1200);
  TrCheck(!TaskValidate(t),"rot180: [X] on the left still closes the window");

//--- Palette survives a real task death (kernel calls fp_set_std_palette).
  GrPaletteColorSet(4,0x123412341234); //An app scribbles on the DAC...
  t=User;
  Sleep(500);
  Kill(t);
  Sleep(800);
  TrCheck(TrDacIsHellfire(),"task death restores hellfire, not CGA");
  UnholyScrnFlipSet(UNHOLY_FLIP_NONE);

//--- Breathing hellfire leaves an app's own palette alone.
  PaletteUnholyBreathingSet(TRUE);
  Sleep(300);
  GrPaletteColorSet(1,0x123412341234);
  x=GrPaletteColorGet(1);
  Sleep(400);
  TrCheck(GrPaletteColorGet(1)==x,"breathing does not stomp an app palette");
  PaletteSetStd; //The app exits: the bellows take over again.
  changed=FALSE;
  for (i=0;i<20 && !changed;i++) {
    Sleep(100);
    if (GrPaletteColorGet(1)!=gr_palette_std[1])
      changed=TRUE;
  }
  TrCheck(changed,"breathing resumes on the std palette");
  PaletteUnholyBreathingSet(FALSE);
  Sleep(100);
  TrCheck(TrDacIsHellfire(),"breathing off restores hellfire");

//--- Flames flicker in the font itself.
  for (i=0;i<UNHOLY_FLAMES_NUM;i++)
    f0[i]=text.font[CH_UNHOLY_FLAME+i];
  changed=FALSE;
  for (x=0;x<20 && !changed;x++) {
    Sleep(100);
    for (i=0;i<UNHOLY_FLAMES_NUM;i++)
      if (text.font[CH_UNHOLY_FLAME+i]!=f0[i])
	changed=TRUE;
  }
  TrCheck(changed,"flame glyphs flicker");

//--- Kernel Ctrl-Alt-F swaps fonts; twice is a round trip.
  (*keydev.fp_ctrl_alt_cbs['F'-'A'])(0);
  TrCheck(text.font!=unholy_font,"Ctrl-Alt-F swaps to the aux font");
  (*keydev.fp_ctrl_alt_cbs['F'-'A'])(0);
  TrCheck(text.font==unholy_font,"Ctrl-Alt-F swaps back to the unholy font");

//--- Zoomed and upside down.
  MsSet(320,240);
  Sleep(100);
  GrScaleZoom(2.0);
  UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  Sleep(300);
  HfShot("zoom_upside",600);
  TrCheck(gr.scrn_zoom==2,"zoom 2 while upside down");
  UnholyScrnFlipSet(UNHOLY_FLIP_NONE);
  GrScaleZoom(0.5);
  Sleep(300);
  TrCheck(gr.scrn_zoom==1,"zoom back to 1");
  HfShot("after",600);

  HfPrint("TR DONE fails=%d\n",tr_fails);
  hf_exit_code=tr_fails;
}

TrMain;
