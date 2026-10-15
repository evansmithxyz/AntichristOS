#help_index "Graphics/Unholy"
//AntichristOS Hellfire visuals: unholy fonts, infernal glyphs,
//upside-down and reflected screens.  Everything here is an Adam
//global, so the pointers we hand to the WinMgr never get freed.
//
//Ctrl-Alt-I	Next palette: Hellfire, Negative, Holy
//Ctrl-Alt-Shift-I	Breathing hellfire on/off
//Ctrl-Alt-U	Upside-down screen (rot180) on/off
//Ctrl-Alt-Shift-U	Reflection (vertical flip) on/off
//Ctrl-Alt-Y	Mirror-script font on/off
//Ctrl-Alt-Shift-Y	Upside-down (rot180) font on/off
//
//Upside-down screen plus upside-down font is Backmask mode: every
//glyph stands upright, but text runs right-to-left, bottom-to-top.

//Infernal glyphs live in the blank font slots 14-21.
#define CH_UNHOLY_PENTAGRAM	0x0E
#define CH_UNHOLY_HORNS		0x0F
#define CH_UNHOLY_TRIDENT	0x10
#define CH_UNHOLY_SKULL		0x11
#define CH_UNHOLY_FLAME		0x12 //0x12-0x15 are four flickering flames
#define UNHOLY_FLAMES_NUM	4

#define UNHOLY_FONT_STD		0
#define UNHOLY_FONT_MIRROR	1
#define UNHOLY_FONT_ROT180	2

#define UNHOLY_FLIP_NONE	0
#define UNHOLY_FLIP_VFLIP	1 //Reflection, as in a dark pool
#define UNHOLY_FLIP_ROT180	2 //Upside-down

public U64 unholy_font[256],unholy_font_mirror[256],unholy_font_rot180[256];
public I64 unholy_font_mode=UNHOLY_FONT_STD,
	unholy_scrn_flip=UNHOLY_FLIP_NONE;

//Byte r is row r (top first), bit c is column c (bit 0 is leftmost).
U64 unholy_glyphs[4]={
0x00081C7F3E1C3622, //Inverted pentagram
0x18247E5A3C664242, //Horns
0x080808087F494949, //Trident
0x243C66FF9999FF7E};//Skull

U64 unholy_flame_frames[3]={
0x7EE363763E5C1808,0x7EC7C66E7C3A1810,0x7E6373767E5C4C04};

U64 UnholyGlyphMirror(U64 g)
{//Mirror left-right: reverse the bits of every row.
  I64 r;
  U64 res=0;
  for (r=0;r<FONT_HEIGHT;r++)
    res|=rev_bits_table[g>>(r<<3)&0xFF]<<(r<<3);
  return res;
}

U64 UnholyGlyphRot180(U64 g)
{//Rotate 180 degrees: mirror and swap rows top-for-bottom.
  I64 r;
  U64 res=0;
  for (r=0;r<FONT_HEIGHT;r++)
    res|=rev_bits_table[g>>(r<<3)&0xFF]<<((FONT_HEIGHT-1-r)<<3);
  return res;
}

U0 UnholyFontInit()
{//Copy the std font, carve in the infernal glyphs, forge the
//mirror and rot180 fonts.  Slots 0-31 (window borders and our
//glyphs) are never flipped.
  I64 i;
  MemCpy(unholy_font,text.font,sizeof(unholy_font));
  for (i=0;i<4;i++)
    unholy_font[CH_UNHOLY_PENTAGRAM+i]=unholy_glyphs[i];
  for (i=0;i<UNHOLY_FLAMES_NUM;i++)
    unholy_font[CH_UNHOLY_FLAME+i]=unholy_flame_frames[i];
  MemCpy(unholy_font_mirror,unholy_font,sizeof(unholy_font));
  MemCpy(unholy_font_rot180,unholy_font,sizeof(unholy_font));
  for (i=32;i<256;i++) {
    unholy_font_mirror[i]=UnholyGlyphMirror(unholy_font[i]);
    unholy_font_rot180[i]=UnholyGlyphRot180(unholy_font[i]);
  }
  text.font=unholy_font;
}

U0 UnholyFlamesUpdate()
{//Hellfire flickers.  One U64 store per flame per font, per frame.
  I64 i,j,
	k=winmgr.updates/3;
  U64 g;
  for (i=0;i<UNHOLY_FLAMES_NUM;i++) {
//Hash the frame cnt so the flicker never falls into step.
    j=((k*0x9E3779B1+i*0x7F4A7C15)>>13&0xFFFF)%6;
    if (j<3)
      g=unholy_flame_frames[j];
    else
      g=UnholyGlyphMirror(unholy_flame_frames[j-3]);
    unholy_font[CH_UNHOLY_FLAME+i]=g;
    unholy_font_mirror[CH_UNHOLY_FLAME+i]=g;
    unholy_font_rot180[CH_UNHOLY_FLAME+i]=g;
  }
}

public U0 UnholyFontSet(I64 mode=UNHOLY_FONT_STD)
{//Select std, mirror-script or upside-down font.
  if (mode==UNHOLY_FONT_MIRROR)
    text.font=unholy_font_mirror;
  else if (mode==UNHOLY_FONT_ROT180)
    text.font=unholy_font_rot180;
  else {
    mode=UNHOLY_FONT_STD;
    text.font=unholy_font;
  }
  unholy_font_mode=mode;
}

U0 UnholyMsXform(I64 mode)
{//Map the mouse between logical and displayed orientation.
//It is its own inverse, even with the grid snap on.
  if (mode==UNHOLY_FLIP_ROT180) {
    ms.presnap.x=GR_WIDTH-1-ms.presnap.x;
    if (ms_grid.snap)
      ms.pos.x=Trunc(ms.presnap.x/ms_grid.x)*ms_grid.x+ms_grid.x_offset;
    else
      ms.pos.x=GR_WIDTH-1-ms.pos.x;
  }
  if (mode) {
    ms.presnap.y=GR_HEIGHT-1-ms.presnap.y;
    if (ms_grid.snap)
      ms.pos.y=Trunc(ms.presnap.y/ms_grid.y)*ms_grid.y+ms_grid.y_offset;
    else
      ms.pos.y=GR_HEIGHT-1-ms.pos.y;
  }
  ms.pos.x=ClampI64(ms.pos.x,0,GR_WIDTH-1);
  ms.pos.y=ClampI64(ms.pos.y,0,GR_HEIGHT-1);
  ms.pos_text.x=ms.pos.x/FONT_WIDTH;
  ms.pos_text.y=ms.pos.y/FONT_HEIGHT;
}

class CUnholyMs
{
  I64 x,y;
  Bool lb,rb;
};

CUnholyMs unholy_ms_pre,	//ms just before the WinMgr's MsUpdate
	unholy_ms_last,		//ms as we left it last time
	unholy_ms_hard;		//Where the hardware pointer really is

U0 UnholyMsSnap(CUnholyMs *m)
{
  m->x=ms.pos.x;
  m->y=ms.pos.y;
  m->lb=ms.lb;
  m->rb=ms.rb;
}

U0 UnholyMsPre()
{//Called by $LK,"WinMsUpdate",A="MN:WinMsUpdate"$() just before $LK,"MsUpdate",A="MN:MsUpdate"$().
  UnholyMsSnap(&unholy_ms_pre);
}

U0 UnholyMsUpdate()
{//Hand-eye compensation: called after every hardware mouse event,
//so the pointer moves the way your hand does on a damned screen.
  CUnholyMs raw;
  I64 x,y;
  UnholyMsSnap(&raw);
  if (unholy_scrn_flip && Bt(&sys_run_level,RLf_VGA)) {
//$LK,"MsSet",A="MN:MsSet"$() puts the hardware where the logical pointer already
    //is.  Obey it (no mirror jump) and re-anchor the hardware at the
    //spot where the pointer is displayed, so the hand keeps working.
    if (raw.x==unholy_ms_pre.x && raw.y==unholy_ms_pre.y &&
	  (unholy_ms_pre.x!=unholy_ms_last.x ||
	  unholy_ms_pre.y!=unholy_ms_last.y ||
	  unholy_ms_pre.lb!=unholy_ms_last.lb ||
	  unholy_ms_pre.rb!=unholy_ms_last.rb ||
	  AbsI64(raw.x-unholy_ms_hard.x)>8 ||
	  AbsI64(raw.y-unholy_ms_hard.y)>8)) {
      x=raw.x;
      if (unholy_scrn_flip==UNHOLY_FLIP_ROT180)
	x=GR_WIDTH-1-x;
      y=GR_HEIGHT-1-raw.y;
      MsSet(x,y,,ms.lb,ms.rb); //Hardware to the displayed spot,
      UnholyMsXform(unholy_scrn_flip); //ms back to the logical one.
      raw.x=x;
      raw.y=y;
    } else
      UnholyMsXform(unholy_scrn_flip);
  }
  MemCpy(&unholy_ms_hard,&raw,sizeof(CUnholyMs));
  UnholyMsSnap(&unholy_ms_last);
}

public U0 UnholyScrnFlipSet(I64 mode=UNHOLY_FLIP_NONE)
{//Turn the scrn upside-down (rot180), reflect it (vflip) or restore.
  if (!(UNHOLY_FLIP_NONE<=mode<=UNHOLY_FLIP_ROT180))
    mode=UNHOLY_FLIP_NONE;
  PUSHFD
  CLI
  if (Bt(&sys_run_level,RLf_VGA)) {
    UnholyMsXform(unholy_scrn_flip);
    UnholyMsXform(mode);
  }
  UnholyMsSnap(&unholy_ms_last);
  unholy_scrn_flip=mode;
  POPFD
  VGAFlush;
}

Bool UnholyKeyEcho(I64 sc)
{//The keyboard driver can hand us one Ctrl-Alt-Shift press twice.
//A toggle hit twice is no toggle, so swallow the echo.
  static I64 last_sc=0;
  static F64 last_t=0;
  Bool res=sc==last_sc && tS-last_t<0.25;
  last_sc=sc;
  last_t=tS;
  return res;
}

U0 CtrlAltI(I64 sc)
{
  if (UnholyKeyEcho(sc)) return;
  if (sc&SCF_SHIFT)
    PaletteUnholyBreathingSet(!unholy_breathing);
  else
    PaletteUnholySet((unholy_palette+1)%UNHOLY_PAL_NUM);
}

U0 CtrlAltU(I64 sc)
{
  if (UnholyKeyEcho(sc)) return;
  if (sc&SCF_SHIFT) {
    if (unholy_scrn_flip==UNHOLY_FLIP_VFLIP)
      UnholyScrnFlipSet(UNHOLY_FLIP_NONE);
    else
      UnholyScrnFlipSet(UNHOLY_FLIP_VFLIP);
  } else {
    if (unholy_scrn_flip==UNHOLY_FLIP_ROT180)
      UnholyScrnFlipSet(UNHOLY_FLIP_NONE);
    else
      UnholyScrnFlipSet(UNHOLY_FLIP_ROT180);
  }
}

U0 CtrlAltY(I64 sc)
{
  if (UnholyKeyEcho(sc)) return;
  if (sc&SCF_SHIFT) {
    if (unholy_font_mode==UNHOLY_FONT_ROT180)
      UnholyFontSet(UNHOLY_FONT_STD);
    else
      UnholyFontSet(UNHOLY_FONT_ROT180);
  } else {
    if (unholy_font_mode==UNHOLY_FONT_MIRROR)
      UnholyFontSet(UNHOLY_FONT_STD);
    else
      UnholyFontSet(UNHOLY_FONT_MIRROR);
  }
}

UnholyFontInit;
