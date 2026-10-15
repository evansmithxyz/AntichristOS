//Hellforge WS4 test: AntichristOS Hellfire visuals.
//  python Hellforge/forge.py run Hellforge/guest/TestVisual.HC
//Calls the toggles directly and asks the host for a screenshot of
//every mode (hellfire, flames_a/b, negative, holy, upside, reflect,
//mirrorfont, rotfont, backmask, normal_again, pat_*, chrome, ...).
//The pat_* shots show a static noise scrn: pat_rot180 must equal
//pat_normal rotated 180 degrees, pixel for pixel, and pat_vflip must
//equal it flipped.  The guest checks the same thing itself by reading
//the 4 VGA planes back.  TestVisualKeys.HC presses the real keys.

I64 tv_fails=0;

U0 TvCheck(Bool ok,U8 *what)
{
  if (ok)
    HfPrint("TV PASS %s\n",what);
  else {
    HfPrint("TV FAIL %s\n",what);
    tv_fails++;
  }
}

U0 TvShot(U8 *name,I64 settle=300,I64 hold=700)
{//Let the WinMgr paint a few frames, then shoot.
  Sleep(settle);
  HfShot(name,hold);
}

U0 TvClick(I64 x,I64 y)
{//Left click, held long enough for the WinMgr to see it.
  MsSet(x,y,,TRUE);
  Sleep(300);
  MsSet(x,y,,FALSE);
}

Bool TvDacIs(CBGR48 *pal)
{
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    if (GrPaletteColorGet(i)!=pal[i]) {
      HfPrint("  DAC[%d]=%012X want %012X\n",i,GrPaletteColorGet(i),pal[i]);
      return FALSE;
    }
  return TRUE;
}

U0 TvPattern(I64 seed)
{//Fill the persistent layer with deterministic noise (no TRANSPARENT),
//so the whole scrn is static and asymmetric.
  U8 *dst=gr.dc->body;
  I64 i,n=gr.dc->width_internal*gr.dc->height;
  for (i=0;i<n;i++) {
    seed=seed*6364136223846793005+1442695040888963407;
    dst[i]=seed.u8[7]&15;
  }
}

I64 TvVgaBad(I64 mode)
{//Read the 4 VGA planes back (GC Read Map Select) and count the bytes
//that differ from what the source planes in gr.dc1 should look like
//in this orientation.  Needs a static scrn.
  I64 p,k,s,idx,want,bad=0,n=GR_WIDTH*GR_HEIGHT/8,w=GR_WIDTH/8;
  U8 *vga=MAlloc(4*n),*src=gr.dc1->body;
  for (p=0;p<4;p++) {
    PUSHFD
    CLI
    OutU8(0x3CE,4); //Graphics Controller: Read Map Select
    OutU8(0x3CF,p);
    POPFD
    MemCpy(vga+p*n,text.vga_alias,n);
  }
  for (p=0;p<4;p++)
    for (k=0;k<n;k++) {
      s=src[p*n+k];
      if (mode==UNHOLY_FLIP_ROT180) {
	idx=n-1-k;
	want=s;
      } else if (mode==UNHOLY_FLIP_VFLIP) {
	idx=(GR_HEIGHT-1-k/w)*w+k%w;
	want=rev_bits_table[s];
      } else {
	idx=k;
	want=rev_bits_table[s];
      }
      if (vga[p*n+idx]!=want)
	bad++;
    }
  Free(vga);
  return bad;
}

U0 TvMain()
{
  I64 x,y;
  CBGR48 c0,c1;
  CTask *t;

  HfPrint("TV start: palette=%d flip=%d font=%d\n",
	unholy_palette,unholy_scrn_flip,unholy_font_mode);
  TvCheck(unholy_palette==UNHOLY_PAL_HELLFIRE,"hellfire is the boot palette");
  TvCheck(TvDacIs(gr_palette_hellfire),"DAC holds hellfire (6-bit exact)");
  TvCheck(!MemCmp(gr_palette_std,gr_palette_hellfire,
	COLORS_NUM*sizeof(CBGR48)),"gr_palette_std is hellfire");
  TvCheck(text.font==unholy_font,"unholy font installed");
  TvCheck(unholy_font[CH_UNHOLY_TRIDENT]==0x080808087F494949,
	"trident glyph in slot 0x10");
  TvCheck(unholy_font['A']==0x006666667E66663C,"std glyphs kept");
  TvCheck(unholy_font_rot180['A']==0x3C66667E66666600,"rot180 font");
  TvCheck(unholy_font_mirror['b']==0x007C6666667C6060,"mirror font");
  TvCheck(unholy_font_mirror[4]==0x1818181818181818 &&
	unholy_font_rot180[13]==0x0000007F606F6C6C,"border glyphs untouched");
  TvCheck(UnholyGlyphRot180(UnholyGlyphRot180(0x0123456789ABCDEF))==
	0x0123456789ABCDEF,"rot180 is an involution");
  TvCheck(keydev.fp_ctrl_alt_cbs['I'-'A']==&CtrlAltI &&
	keydev.fp_ctrl_alt_cbs['U'-'A']==&CtrlAltU &&
	keydev.fp_ctrl_alt_cbs['Y'-'A']==&CtrlAltY,"Ctrl-Alt I/U/Y bound");
  TvCheck(keydev.ctrl_alt_shift_descs['I'-'A'] &&
	keydev.ctrl_alt_shift_descs['U'-'A'] &&
	keydev.ctrl_alt_shift_descs['Y'-'A'],"Ctrl-Alt-Shift I/U/Y described");

//Unholy color names in DolDoc: $$BLOOD$$ is slot 14.
  {
    CDoc *doc=DocNew;
    CDocEntry *doc_e;
    Bool found=FALSE;
    DocPrint(doc,"$$BLOOD$$Hell$$FG$$");
    doc_e=doc->head.next;
    while (doc_e!=doc) {
      if (doc_e->type_u8==DOCT_FOREGROUND && doc_e->attr==YELLOW)
	found=TRUE;
      doc_e=doc_e->next;
    }
    DocDel(doc);
    TvCheck(found,"DolDoc knows the BLOOD color cmd");
  }

//Pitchfork over the left window.
  MsSet(200,150);
  Sleep(200);

//Default boot look.
  TvShot("hellfire");

//Flames: two shots a fraction of a second apart.
  TvShot("flames_a",100,10);
  TvShot("flames_b",300,700);

//Palettes.
  PaletteUnholySet(UNHOLY_PAL_NEGATIVE);
  TvCheck(TvDacIs(gr_palette_negative),"negative palette in DAC");
  TvShot("negative");
  CtrlAltI(0); //Negative -> Holy
  TvCheck(unholy_palette==UNHOLY_PAL_HOLY && TvDacIs(gr_palette_holy),
	"Ctrl-Alt-I cycles to holy");
  TvShot("holy");
  CtrlAltI(0); //Holy -> Hellfire
  TvCheck(unholy_palette==UNHOLY_PAL_HELLFIRE &&
	TvDacIs(gr_palette_hellfire),"Ctrl-Alt-I cycles back to hellfire");
  (*fp_set_std_palette)();
  TvCheck(TvDacIs(gr_palette_hellfire),"task-death palette reset stays damned");

//Breathing hellfire.
  CtrlAltI(SCF_SHIFT);
  TvCheck(unholy_breathing,"Ctrl-Alt-Shift-I starts breathing");
  Sleep(250);
  c0=GrPaletteColorGet(1);
  Sleep(400);
  c1=GrPaletteColorGet(1);
  HfPrint("  breathing slot1 %012X -> %012X\n",c0,c1);
  TvCheck(c0!=c1,"hellfire breathes");
  TvShot("breathing",100,300);
  CtrlAltI(SCF_SHIFT);
  Sleep(100);
  TvCheck(!unholy_breathing && TvDacIs(gr_palette_hellfire),
	"breathing stops and DAC restored");

//Scrn orientation.
  TvShot("normal");
  UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  TvShot("upside");
  UnholyScrnFlipSet(UNHOLY_FLIP_VFLIP);
  TvShot("reflect");
  UnholyScrnFlipSet(UNHOLY_FLIP_NONE);

//Fonts.
  CtrlAltY(0);
  TvCheck(text.font==unholy_font_mirror,"Ctrl-Alt-Y mirror font");
  TvShot("mirrorfont");
  CtrlAltY(SCF_SHIFT);
  TvCheck(text.font==unholy_font_rot180,"Ctrl-Alt-Shift-Y rot180 font");
  TvShot("rotfont");

//Backmask mode: upside-down scrn with upside-down font.
  CtrlAltU(0);
  TvCheck(unholy_scrn_flip==UNHOLY_FLIP_ROT180,"Ctrl-Alt-U upside down");
  TvShot("backmask");
  CtrlAltU(0);
  CtrlAltY(SCF_SHIFT);
  TvCheck(unholy_scrn_flip==UNHOLY_FLIP_NONE && text.font==unholy_font,
	"Ctrl-Alt-U/Shift-Y toggle back");
  TvShot("normal_again");

//Hand-eye compensation, with the WinMgr's own update path.
  UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  MsUpdate(100,50,0,FALSE,FALSE);
  UnholyMsUpdate;
  x=ms.pos.x; y=ms.pos.y;
  HfPrint("  rot180 ms (100,50) -> (%d,%d) text (%d,%d)\n",
	x,y,ms.pos_text.x,ms.pos_text.y);
  TvCheck(x==GR_WIDTH-1-100 && y==GR_HEIGHT-1-50 &&
	ms.pos_text.x==x/FONT_WIDTH && ms.pos_text.y==y/FONT_HEIGHT,
	"rot180 mouse compensation");
  UnholyScrnFlipSet(UNHOLY_FLIP_VFLIP);
  MsUpdate(100,50,0,FALSE,FALSE);
  UnholyMsUpdate;
  TvCheck(ms.pos.x==100 && ms.pos.y==GR_HEIGHT-1-50,
	"vflip mouse compensation");
  UnholyScrnFlipSet(UNHOLY_FLIP_NONE);
  MsUpdate(100,50,0,FALSE,FALSE);
  UnholyMsUpdate;
  TvCheck(ms.pos.x==100 && ms.pos.y==50,"normal mouse untouched");

//Objective blit check: static noise, no pointer.
  ms.show=FALSE;
  TvPattern(666);
  TvShot("pat_normal",400);
  x=TvVgaBad(UNHOLY_FLIP_NONE);
  HfPrint("  VGA readback normal: %d bad bytes; as if rot180: %d\n",
	x,TvVgaBad(UNHOLY_FLIP_ROT180));
  TvCheck(!x,"VGA planes exact in normal mode");
  UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  TvShot("pat_rot180",400);
  x=TvVgaBad(UNHOLY_FLIP_ROT180);
  HfPrint("  VGA readback rot180: %d bad bytes\n",x);
  TvCheck(!x,"VGA planes exact in rot180 mode");
  UnholyScrnFlipSet(UNHOLY_FLIP_VFLIP);
  TvShot("pat_vflip",400);
  x=TvVgaBad(UNHOLY_FLIP_VFLIP);
  HfPrint("  VGA readback vflip: %d bad bytes\n",x);
  TvCheck(!x,"VGA planes exact in vflip mode");
  UnholyScrnFlipSet(UNHOLY_FLIP_NONE);
  TvShot("pat_normal2",400);
  TvCheck(!TvVgaBad(UNHOLY_FLIP_NONE),"VGA planes exact back in normal mode");
  DCFill;
  ms.show=TRUE;

//Inverted chrome: [X] on the left, MENU on the right.  Real clicks
//through the WinMgr's title-bar hit zones.
  t=User;
  Sleep(600);
  WinToTop(t);
  WinFocus(t);
  Sleep(300);
  HfPrint("  new term win l=%d r=%d t=%d\n",t->win_left,t->win_right,t->win_top);
  TvShot("chrome",300,700);
  TvClick(t->win_left*FONT_WIDTH+12,(t->win_top-1)*FONT_HEIGHT+4);
  Sleep(1200);
  TvCheck(!TaskValidate(t),"[X] on the left closes the window");

  t=User;
  Sleep(600);
  WinToTop(t);
  WinFocus(t);
  Sleep(300);
  TvClick(t->win_right*FONT_WIDTH+4,(t->win_top-1)*FONT_HEIGHT+4);
  Sleep(1200);
  TvCheck(TaskValidate(t),"right end of the title bar no longer closes");
  TvCheck(TaskValidate(t) && DocPut(t) &&
	StrMatch("PersonalMenu",DocPut(t)->filename.name),
	"MENU on the right opens the personal menu");
  MsSet(320,240);
  TvShot("menu_click",300,700);

  HfPrint("TV DONE fails=%d\n",tv_fails);
  hf_exit_code=tv_fails;
}

TvMain;
