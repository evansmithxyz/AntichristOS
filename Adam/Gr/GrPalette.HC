#help_index "Graphics/Color"
public U8 gr_rainbow_10[10]={
  BLACK,BROWN,RED,LTRED,YELLOW,GREEN,BLUE,PURPLE,LTGRAY,WHITE};

DefineLstLoad("ST_RAINBOW_10",
  "BLACK\0BROWN\0RED\0LTRED\0YELLOW\0GREEN\0BLUE\0PURPLE\0LTGRAY\0WHITE\0");

U0 GrPaletteIndicesSet()
{//There is a level of indirection that we identity map.
// Set 16-colors to use first 16 DAC BGR entries, so we
// never need to worry about indexes, just DAC palette settings.
  I64 i;
  if (!Bt(&sys_run_level,RLf_VGA)) return;
  PUSHFD
  CLI
  while (LBts(&sys_semas[SEMA_VGA],0))
    Yield;
  InU8(VGAP_INPUT_STAT); //Rsts attr index/data
  for (i=0;i<COLORS_NUM;i++) {
    OutU8(VGAP_ATTR_INDEX,i);
    OutU8(VGAP_ATTR_DATA_WRITE,i);
  }
  OutU8(VGAP_ATTR_INDEX,0x20);
  OutU8(VGAP_ATTR_DATA_WRITE,0); //Dummy write
  InU8(VGAP_INPUT_STAT); //Rsts attr index/data
  LBtr(&sys_semas[SEMA_VGA],0);
  POPFD
}

public U0 GrPaletteColorSet(I64 color_num,CBGR48 bgr48)
{//VGA has 6-bits for blue, for green, and for red.
  if (!Bt(&sys_run_level,RLf_VGA)) return;
  PUSHFD
  CLI
  while (LBts(&sys_semas[SEMA_VGA],0))
    Yield;
  OutU8(VGAP_PALETTE_MASK,0xFF);
  OutU8(VGAP_REG_WRITE,color_num);
  OutU8(VGAP_PALETTE_DATA,bgr48.r>>10);
  OutU8(VGAP_PALETTE_DATA,bgr48.g>>10);
  OutU8(VGAP_PALETTE_DATA,bgr48.b>>10);
  LBtr(&sys_semas[SEMA_VGA],0);
  POPFD
}

public CBGR48 GrPaletteColorGet(I64 color_num)
{//VGA has 6-bits for blue, for green, and for red.
  CBGR48 res=0;
  if (!Bt(&sys_run_level,RLf_VGA)) return 0;
  PUSHFD
  CLI
  while (LBts(&sys_semas[SEMA_VGA],0))
    Yield;
  OutU8(VGAP_PALETTE_MASK,0xFF);
  OutU8(VGAP_REG_READ,color_num);
  res.r=0xFFFF<<10*InU8(VGAP_PALETTE_DATA)/0xFC00;
  res.g=0xFFFF<<10*InU8(VGAP_PALETTE_DATA)/0xFC00;
  res.b=0xFFFF<<10*InU8(VGAP_PALETTE_DATA)/0xFC00;
  LBtr(&sys_semas[SEMA_VGA],0);
  POPFD
  return res;
}

public CBGR48 gr_palette_std[COLORS_NUM]={
0x000000000000,0x00000000AAAA,0x0000AAAA0000,0x0000AAAAAAAA,
0xAAAA00000000,0xAAAA0000AAAA,0xAAAA55550000,0xAAAAAAAAAAAA,
0x555555555555,0x55555555FFFF,0x5555FFFF5555,0x5555FFFFFFFF,
0xFFFF55555555,0xFFFF5555FFFF,0xFFFFFFFF5555,0xFFFFFFFFFFFF};

public CBGR48 gr_palette_gray[COLORS_NUM]={
0x000000000000,0x111111111111,0x222222222222,0x333333333333,
0x444444444444,0x555555555555,0x666666666666,0x777777777777,
0x888888888888,0x999999999999,0xAAAAAAAAAAAA,0xBBBBBBBBBBBB,
0xCCCCCCCCCCCC,0xDDDDDDDDDDDD,0xEEEEEEEEEEEE,0xFFFFFFFFFFFF};

CBGR48 unholy_breath[COLORS_NUM]; //What the bellows last wrote to the DAC.
public Bool unholy_breathing=FALSE; //Hellfire breathes (slots 1 and 3).

public U0 GrPaletteGet(CBGR48 *bgr48)
{//16 colors
  I64 i;
  CBGR48 b;
  for (i=0;i<COLORS_NUM;i++) {
    b=unholy_breath[i];
    bgr48[i]=GrPaletteColorGet(i);
//AntichristOS: a breath of the bellows is not the slot's color.  Save
    //the std color, so $LK,"SettingsPop",A="MN:SettingsPop"$() hands the slot back to the bellows.
    if (unholy_breathing && (i==1 || i==3) &&
	  (bgr48[i]==b || bgr48[i]==unholy_breath[i]))
      bgr48[i]=gr_palette_std[i];
  }
}

public U0 GrPaletteSet(CBGR48 *bgr48)
{//16 colors
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    GrPaletteColorSet(i,bgr48[i]);
}

public U0 PaletteSetStd()
{//Activate std palette.
  GrPaletteSet(gr_palette_std);
}

#help_index "Graphics/Color;Graphics/Unholy"
//AntichristOS: the 16 slots keep their names (BLACK..WHITE) so
//every binary and doc keeps working, but the RGB is damned.
//Slot c and slot 15-c stay a contrasting pair, so XOR cursors,
//selections and the mouse pointer still show.
#define UNHOLY_PAL_HELLFIRE	0
#define UNHOLY_PAL_NEGATIVE	1
#define UNHOLY_PAL_HOLY		2
#define UNHOLY_PAL_NUM		3

DefineLstLoad("ST_UNHOLY_PALETTES","Hellfire\0Negative\0Holy\0");
DefineLstLoad("ST_UNHOLY_COLORS",
  "BONE\0HELLFIRE\0INFERNAL\0EMBER\0SOULFIRE\0BRIMSTONE\0WITCHLIGHT\0ASH\0"
  "SMOKE\0RUST\0BRUISE\0CRIMSON\0SULFUR\0POISON\0BLOOD\0ABYSS\0");

public CBGR48 gr_palette_hellfire[COLORS_NUM]={
//BONE		HELLFIRE	INFERNAL	EMBER
0xF3CEE38DCB2B,0xFFFFAAAA2081,0xFFFF6185D34C,0xFFFF59654103,
//SOULFIRE	BRIMSTONE	WITCHLIGHT	ASH
0x6185F3CED34C,0xAAAAF3CE4103,0x71C64103E38D,0x69A659655965,
//SMOKE		RUST		BRUISE		CRIMSON
0xBAEAAAAAA289,0xCB2B59651040,0xB2CA20819248,0xE38D20812081,
//SULFUR	POISON		BLOOD		ABYSS
0x00009A698A28,0x30C2AAAA30C2,0xA28900000000,0x104000000000};

public CBGR48 gr_palette_negative[COLORS_NUM]={//Exact RGB complement.
0xFFFFFFFFFFFF,0xFFFFFFFF5555,0xFFFF5555FFFF,0xFFFF55555555,
0x5555FFFFFFFF,0x5555FFFF5555,0x55555555FFFF,0x555555555555,
0xAAAAAAAAAAAA,0xAAAA55550000,0xAAAA0000AAAA,0xAAAA00000000,
0x0000AAAAAAAA,0x0000AAAA0000,0x00000000AAAA,0x000000000000};

public CBGR48 gr_palette_holy[COLORS_NUM]={//The old CGA ways.
0x000000000000,0x00000000AAAA,0x0000AAAA0000,0x0000AAAAAAAA,
0xAAAA00000000,0xAAAA0000AAAA,0xAAAA55550000,0xAAAAAAAAAAAA,
0x555555555555,0x55555555FFFF,0x5555FFFF5555,0x5555FFFFFFFF,
0xFFFF55555555,0xFFFF5555FFFF,0xFFFFFFFF5555,0xFFFFFFFFFFFF};

public I64 unholy_palette=UNHOLY_PAL_HOLY;

U0 PaletteUnholySettingsFix(CBGR48 *old_std)
{//Every task's $LK,"SettingsPush",A="MN:SettingsPush"$() palette that was the old std palette
//becomes the new one, so an app's $LK,"SettingsPop",A="MN:SettingsPop"$() can't undo <CTRL-ALT-i>.
  I64 i;
  CTask *task,*task1;
  CTaskSettings *tmpse;
  PUSHFD
  CLI
  for (i=0;i<mp_cnt;i++) {
    task1=task=cpu_structs[i].seth_task;
    do {
      if (!TaskValidate(task)) break;
      tmpse=task->next_settings;
      while (tmpse) {
	if (!MemCmp(tmpse->palette,old_std,COLORS_NUM*sizeof(CBGR48)))
	  MemCpy(tmpse->palette,gr_palette_std,COLORS_NUM*sizeof(CBGR48));
	tmpse=tmpse->next;
      }
      task=task->next_task;
    } while (task!=task1);
  }
  POPFD
}

public U0 PaletteUnholySet(I64 mode=UNHOLY_PAL_HELLFIRE)
{//Damn (or redeem) the std palette. Survives task deaths.
  CBGR48 *src,old_std[COLORS_NUM];
  if (!(0<=mode<UNHOLY_PAL_NUM))
    mode=UNHOLY_PAL_HELLFIRE;
  if (mode==UNHOLY_PAL_NEGATIVE)
    src=gr_palette_negative;
  else if (mode==UNHOLY_PAL_HOLY)
    src=gr_palette_holy;
  else
    src=gr_palette_hellfire;
  MemCpy(old_std,gr_palette_std,COLORS_NUM*sizeof(CBGR48));
  MemCpy(gr_palette_std,src,COLORS_NUM*sizeof(CBGR48));
  unholy_palette=mode;
  PaletteUnholySettingsFix(old_std);
  PaletteSetStd;
}

public U0 PaletteUnholyBreathe()
{//Hellfire breathes. Called every frame; touches only the DAC.
//If an app has programmed the slot itself, its palette wins.
  CBGR48 c;
  F64 f;
  I64 i;
  if (!unholy_breathing) return;
  f=0.78+0.22*Sin(tS*2.2);
  for (i=1;i<4;i+=2) {//Slots 1 and 3
    c=GrPaletteColorGet(i);
    if (c==unholy_breath[i] || c==gr_palette_std[i]) {
      c=gr_palette_std[i];
      c.r=ToI64(c.r*f);
      c.g=ToI64(c.g*f*f);
      c.b=ToI64(c.b*f*f);
      GrPaletteColorSet(i,c);
      unholy_breath[i]=GrPaletteColorGet(i);
    }
  }
}

public U0 PaletteUnholyBreathingSet(Bool val)
{
  unholy_breathing=val;
  if (!val)
    PaletteSetStd;
}
