//Regression test for the adam review fixes.
//  python Hellforge/forge.py run Hellforge/guest/TestFixAdam.HC --smp 4
//corrupt sprites (walk guards, mesh tris, gr.empty_sprite, Extents, DemoDoc),
//breathing after SettingsPop, Ctrl-Alt-I under SettingsPush, Ctrl-Alt-Y
//vs Ctrl-Alt-F, the Adversary's colors, God's own pop-ups, doc links,
//Psalmody honoring Ctrl-Alt-R, and the boot splash.

#include "::/Apps/Psalmody/Load"

I64 fa_fails=0,fa_passes=0;

U0 FaCheck(Bool ok,U8 *what)
{
  if (ok) {
    fa_passes++;
    HfPrint("FA PASS %s\n",what);
  } else {
    fa_fails++;
    HfPrint("FA FAIL %s\n",what);
  }
}

Bool FaDocHas(CDoc *doc,U8 *needle)
{//Search the tags of a doc for needle.
  CDocEntry *doc_e;
  if (!doc) return FALSE;
  doc_e=doc->head.next;
  while (doc_e!=doc) {
    if (doc_e->de_flags&DOCEF_TAG && doc_e->tag &&
	  StrMatch(needle,doc_e->tag))
      return TRUE;
    doc_e=doc_e->next;
  }
  return FALSE;
}

CTask *FaWaitPopUp(CTask *t,CTask *not=NULL)
{
  I64 i;
  for (i=0;i<60;i++) {
    Sleep(100);
    if (TaskValidate(t->popup_task) && t->popup_task!=not)
      return t->popup_task;
  }
  return NULL;
}

I64 FaSlotChanges(I64 slot,I64 n=20,I64 ms=100)
{
  I64 i,res=0;
  CBGR48 last=GrPaletteColorGet(slot),c;
  for (i=0;i<n;i++) {
    Sleep(ms);
    c=GrPaletteColorGet(slot);
    if (c!=last) res++;
    last=c;
  }
  return res;
}

Bool FaDacIs(CBGR48 *pal)
{
  I64 i;
  for (i=0;i<COLORS_NUM;i++)
    if (GrPaletteColorGet(i)!=pal[i]) {
      HfPrint("  DAC[%d]=%012X want %012X\n",i,GrPaletteColorGet(i),pal[i]);
      return FALSE;
    }
  return TRUE;
}

//---- Corrupt sprites ----------------------------------------------------
U8 *fa_buf;
Bool fa_done;
I64 fa_size;

U0 FaDraw(I64)
{
  CDC *dc=DCNew(64,64);
  fa_size=SpriteSize(fa_buf);
  Sprite3(dc,32,32,0,fa_buf);
  DCDel(dc);
  fa_done=TRUE;
}

Bool FaWalk(I64 bad_type)
{//COLOR 4, then an element of an impossible type.  Sprite3 must return.
  F64 t0;
  I64 cpu=0;
  if (mp_cnt>1) cpu=1;
  MemSet(fa_buf,0xFF,256);
  fa_buf[0]=SPT_COLOR;
  fa_buf[1]=4;
  fa_buf[2]=bad_type;
  fa_done=FALSE;
  fa_size=-1;
  Spawn(&FaDraw,NULL,"FaDraw",cpu);
  t0=tS;
  while (!fa_done && tS-t0<5.0)
    Sleep(20);
  HfPrint("FA type %d: Sprite3 returned=%d SpriteSize=%d after %5.2fs\n",
	bad_type,fa_done,fa_size,tS-t0);
  return fa_done && fa_size==3;
}

U0 FaMesh()
{//A mesh whose tris were scrambled by lost bytes (KeepAway's) must not
//read outside its vertices: Gr3Mesh() skips those tris.
  CDC *dc=DCNew(64,64);
  CD3I32 v[4];
  CMeshTri tri[3];
  I64 i,good,mixed;
  MemSet(v,0,sizeof(v));
  v[1].x=60; v[2].y=60; v[3].x=60; v[3].y=60;
  for (i=0;i<3;i++)
    tri[i].color=RED;
  tri[0].nums[0]=0; tri[0].nums[1]=1; tri[0].nums[2]=2;
  tri[1].nums[0]=1; tri[1].nums[1]=3; tri[1].nums[2]=2;
  DCFill(dc,BLACK);
  good=Gr3Mesh(dc,4,v,2,tri);
  tri[1].nums[1]=0x7FFFFF00; //Far outside the vertices
  tri[2].nums[0]=-5; tri[2].nums[1]=0; tri[2].nums[2]=1;
  DCFill(dc,BLACK);
  mixed=Gr3Mesh(dc,4,v,3,tri);
  HfPrint("FA mesh: 2 good tris %d pixs, 1 good + 2 scrambled %d pixs\n",
	good,mixed);
  FaCheck(good>0 && 0<mixed<good,"Gr3Mesh skips tris that point past its vertices");
  DCDel(dc);
}

U0 FaSprites()
{
  CTask *t;
  I64 u0,frames;
  F64 t0;
  Bool dbg=FALSE;
  HfPrint("-- sprites\n");
  FaCheck(SpriteSize(gr.empty_sprite)==38,
	"gr.empty_sprite walks to SPT_END at its size, 38");
  FaCheck(!(SpriteTypeMask(gr.empty_sprite)&1<<SPT_TYPES_NUM),
	"gr.empty_sprite has no corrupt element");
  fa_buf=CAlloc(256);
  FaCheck(FaWalk(0x78),"type 120 element: Sprite3 and SpriteSize stop");
  FaCheck(FaWalk(35),"type 35 element: Sprite3 and SpriteSize stop");
  FaCheck(FaWalk(SPT_TYPES_NUM),"type SPT_TYPES_NUM element stops the walk");
  FaMesh;

  t=User;
  Sleep(300);
  XTalk(t,"#include \"::/Demo/Graphics/Extents\";\n");
  t0=tS;
  while (tS-t0<3.0) {
    if (IsDbgMode) dbg=TRUE;
    Sleep(50);
  }
  HfShot("extents");
  PostMsgWait(t,MSG_KEY_DOWN_UP,CH_SPACE,0);
  Sleep(1000);
  FaCheck(!dbg && !IsDbgMode,"Extents demo: no fault");
  FaCheck(FaDocHas(t->put_doc,"X: -11 to 49") &&
	FaDocHas(t->put_doc,"Y: -12 to 23"),"Extents demo: X -11..49, Y -12..23");
  Kill(t);
  Sleep(300);

  t=User;
  Sleep(300);
  XTalk(t,"Ed(\"::/Demo/DolDoc/DemoDoc.DD\");\n");
  Sleep(1500);
  u0=winmgr.updates;
  Sleep(4000);
  frames=winmgr.updates-u0;
  HfPrint("FA DemoDoc: %d WinMgr frames in 4 s\n",frames);
  HfShot("demodoc");
  FaCheck(frames>=40,"DemoDoc in the editor: the WinMgr keeps painting");
  Kill(t);
  Sleep(500);
  Free(fa_buf);
}

//---- Palette -------------------------------------------------------------
U0 FaBreath()
{
  I64 i,a,b,frozen=0;
  CBGR48 bgr;
  HfPrint("-- breathing\n");
  PaletteUnholyBreathingSet(TRUE);
  a=FaSlotChanges(1);
  FaCheck(a>0,"breathing before any app");

  SettingsPush; //A Palette.HC-style app.
  for (i=0;i<COLORS_NUM;i++) {
    bgr=gr_palette_gray[i];
    GrPaletteColorSet(i,bgr);
  }
  Sleep(500);
  a=FaSlotChanges(1,5,100);
  FaCheck(!a,"an app's own palette wins over the bellows");
  SettingsPop;
  a=FaSlotChanges(1);
  b=FaSlotChanges(3);
  HfPrint("FA after palette app: slot1 changes=%d slot3 changes=%d\n",a,b);
  FaCheck(a>0 && b>0,"breathing resumes after a palette app's SettingsPop");

  for (i=0;i<6;i++) {//Apps that never touch the palette.
    SettingsPush;
    Sleep(300+i*370);
    SettingsPop;
    if (!FaSlotChanges(1,15,100))
      frozen++;
  }
  HfPrint("FA frozen after %d/6 no-palette apps\n",frozen);
  FaCheck(!frozen,"breathing survives SettingsPush/SettingsPop");
  PaletteUnholyBreathingSet(FALSE);
  FaCheck(FaDacIs(gr_palette_hellfire),"breathing off: hellfire again");
}

U0 FaCtrlAltI()
{
  CTask *t;
  HfPrint("-- Ctrl-Alt-I under an app\n");
  PaletteUnholySet(UNHOLY_PAL_HELLFIRE);
  SettingsPush;
  Sleep(300);
  CtrlAltI(0x17); //<CTRL-ALT-i> while the app runs
  FaCheck(unholy_palette==UNHOLY_PAL_NEGATIVE,"Ctrl-Alt-I: negative");
  GrPaletteSet(gr_palette_gray); //The app's own colors
  SettingsPop;
  FaCheck(unholy_palette==UNHOLY_PAL_NEGATIVE &&
	FaDacIs(gr_palette_negative),
	"SettingsPop keeps the palette Ctrl-Alt-I chose");

  SettingsPush;
  SettingsPush;
  PaletteUnholySet(UNHOLY_PAL_HOLY);
  SettingsPop;
  SettingsPop;
  FaCheck(FaDacIs(gr_palette_holy),"nested SettingsPop keeps it too");

  t=User;
  Sleep(300);
  XTalkWait(t,"SettingsPush;\n");
  PaletteUnholySet(UNHOLY_PAL_HELLFIRE);
  XTalkWait(t,"SettingsPop;\n");
  Sleep(200);
  FaCheck(unholy_palette==UNHOLY_PAL_HELLFIRE &&
	FaDacIs(gr_palette_hellfire),"another task's SettingsPop agrees");
  Kill(t);
  Sleep(200);
}

//---- Fonts ---------------------------------------------------------------
U8 *FaFontName(U64 *f)
{
  if (f==unholy_font) return "unholy_std";
  if (f==unholy_font_mirror) return "unholy_mirror";
  if (f==unholy_font_rot180) return "unholy_rot180";
  if (f==sys_font_cyrillic) return "cyrillic";
  return "other";
}

U0 FaKey(U8 *what)
{
  Sleep(300); //UnholyKeyEcho() swallows a repeat within 0.25 s.
  if (!StrCmp(what,"F"))
    SwapI64(&text.font,&text.aux_font); //What CtrlAltF does.
  else if (!StrCmp(what,"Y"))
    CtrlAltY(0x15);
  else
    CtrlAltY(0x15|SCF_SHIFT);
}

U0 FaFont()
{
  U64 *cyr=text.aux_font,*f;
  I64 i;
  U8 *keys="Y\0F\0Y\0F\0F\0Y\0SY\0F\0SY\0F\0SY\0",*k;
  Bool ok=TRUE,changed=TRUE;
  HfPrint("-- fonts\n");
  FaCheck(text.font==unholy_font && cyr==sys_font_cyrillic,
	"boot: unholy font, Cyrillic in aux_font");
  for (i=0;i<11;i++) {
    k=LstSub(i,keys);
    f=text.font;
    FaKey(k);
    if (StrCmp(k,"F") && f==text.font)
      changed=FALSE;
    if (text.font!=cyr && text.aux_font!=cyr)
      ok=FALSE;
    HfPrint("FA key %-2s font=%s aux=%s mode=%d\n",k,
	  FaFontName(text.font),FaFontName(text.aux_font),unholy_font_mode);
  }
  FaCheck(ok,"Cyrillic is always one Ctrl-Alt-F away");
  FaCheck(changed,"every Ctrl-Alt-Y press changes the font");
  if (text.font==cyr)
    SwapI64(&text.font,&text.aux_font);
  UnholyFontSet(UNHOLY_FONT_STD);
  FaCheck(text.font==unholy_font && text.aux_font==cyr,"fonts restored");
}

//---- Oracle --------------------------------------------------------------
U0 FaPopUp(U8 *cmd,U8 *want1,U8 *want2,U8 *nope,Bool doodle=FALSE)
{
  CTask *t,*p;
  I64 i;
  F64 t0;
  U8 buf[STR_LEN];
  FifoU8Flush(god.fifo);
  t=User("%s;\n",cmd);
  if (p=FaWaitPopUp(t)) {
    Sleep(500);
    StrPrint(buf,"%s pop-up says %s and %s",cmd,want1,want2);
    FaCheck(FaDocHas(p->display_doc,want1) && FaDocHas(p->display_doc,want2),
	  buf);
    StrPrint(buf,"%s pop-up does not say %s",cmd,nope);
    FaCheck(!FaDocHas(p->display_doc,nope),buf);
    PostMsg(p,MSG_KEY_DOWN_UP,CH_ESC,0);
    if (doodle) {//Doodle to the end, then throw it away (god.doodle_dc freed).
      Sleep(800);
      StrPrint(buf,"%s pop-up gone after <ESC>",cmd);
      FaCheck(!TaskValidate(t->popup_task),buf);
//A doodle eats about 2000 bits, 24 per key, and GodDoodleSmooth() is
      //slow, so keep pressing until it is done (keys queue while it smooths).
      t0=tS;
      for (i=0;i<200 && !god.doodle_done;i++) {
	PostMsg(t,MSG_KEY_DOWN_UP,CH_SPACE,0);
	Sleep(40);
      }
      while (!god.doodle_done && tS-t0<40.0)
	Sleep(50);
      HfPrint("FA %s: done=%d after %d <SPACE>s, %5.2fs\n",cmd,
	    god.doodle_done,i,tS-t0);
      Sleep(500);
      HfShot(cmd);
      StrPrint(buf,"%s: the <SPACE>s it asks for reach the doodle",cmd);
      FaCheck(god.doodle_done,buf);
      PostMsg(t,MSG_KEY_DOWN_UP,CH_SHIFT_ESC,0);
    }
  } else {
    StrPrint(buf,"%s pops up",cmd);
    FaCheck(FALSE,buf);
  }
  Sleep(800);
  if (doodle)
    FaCheck(!god.doodle_dc,"the thrown-away doodle is freed");
  Kill(t);
  Sleep(300);
}

U0 FaOracle()
{
  U8 *st;
  I64 i;
  Bool old_hell=god.doodle_hell;
  HfPrint("-- oracle colors and pop-ups\n");
  FaCheck(unholy_palette==UNHOLY_PAL_HELLFIRE,"palette is hellfire");
  FaCheck(AdversaryColor(RED)==LTCYAN && AdversaryColor(PURPLE)==LTGREEN &&
	AdversaryColor(BLACK)==WHITE,"hellfire: red is CRIMSON, the doodle is on the ABYSS");
  FaCheck(gr_palette_std[AdversaryColor(RED)].r>0xC000 &&
	gr_palette_std[AdversaryColor(RED)].g<0x4000,"the Adversary's red is red");
  god.doodle_hell=TRUE;
  FaCheck(GodDoodleBackColor==WHITE,"hellfire doodle background is slot 15");
  god.doodle_hell=old_hell;
  i=0;
  while (i<god.num_words && StrCmp(god.words[i],"god"))
    i++;
  st=AdversaryWordDolDoc(i);
  FaCheck(!StrCmp(st,"$$FG,11$$dog$$FG$$ "),"TRUE BACKMASK god->dog is FG,11");
  Free(st);
  PaletteUnholySet(UNHOLY_PAL_HOLY);
  FaCheck(AdversaryColor(RED)==RED,"holy palette: red is RED");
  PaletteUnholySet(UNHOLY_PAL_NEGATIVE);
  FaCheck(gr_palette_std[AdversaryColor(RED)].r>0xA000 &&
	gr_palette_std[AdversaryColor(RED)].g<0x4000,"negative: red is red");
  PaletteUnholySet(UNHOLY_PAL_HELLFIRE);

  FaPopUp("GodWord","OKAY","Holy Spirit","Adversary");
  FaPopUp("GodDoodle","Holy Spirit","SPACE","Adversary",TRUE);
  FaPopUp("AdversaryDoodle","doodler","SPACE","Holy Spirit",TRUE);
  FaPopUp("AdversaryWord","SUMMON","Adversary","Holy Spirit");
  FaPopUp("AdversaryPassage","SUMMON","Adversary","Holy Spirit");
}

//---- Links ---------------------------------------------------------------
I64 FaCensus(U8 *filename)
{//Like LinkChk.  An MN: link must also resolve in a task that never
//loaded the app, so look the symbol up from Adam.
  CDoc *doc=DocRead(filename,DOCF_NO_CURSOR);
  CDocEntry *doc_e=doc->head.next;
  U8 *st;
  I64 n=0,bad=0;
  while (doc_e!=doc) {
    if (st=DocEntryLink(doc,doc_e)) {
      n++;
      if (!DocLinkChk(doc,st) || !StrNCmp(st,"MN:",3) &&
	    !HashFind(st+3,adam_task->hash_table,HTG_SRC_SYM)) {
	HfPrint("FA BROKEN %s line %d: %s\n",filename,doc_e->y+1,st);
	bad++;
      }
      Free(st);
    }
    doc_e=doc_e->next;
  }
  HfPrint("FA census %s links=%d bad=%d\n",filename,n,bad);
  DocDel(doc);
  return bad;
}

U0 FaLinks()
{
  HfPrint("-- links\n");
  FaCheck(!FaCensus("::/Adam/God/AdvNotes.DD"),"AdvNotes.DD links resolve");
  FaCheck(!FaCensus("::/Apps/Psalmody/JukeBox.HC"),"JukeBox.HC links resolve");
  FaCheck(!FaCensus("::/Apps/Psalmody/Help.DD"),"Psalmody Help links resolve");
}

//---- Psalmody ------------------------------------------------------------
Bool FaOnaSame(U8 *note,I64 flags)
{//Play() of note in Unholy mode vs Psalmody's PsmSndOna().
  CPlayNote *notes;
  I64 oct=4,top=4,bot=4,std,unholy,psm;
  F64 len=1.0;
  Bool old=music.unholy;
  PlayNotesNew(note,&notes,music.note_map,&oct,&len,&top,&bot);
  std=notes[0].ona;
  Free(notes);
  oct=4;
  PlayNotesNew(note,&notes,music_unholy_note_map,&oct,&len,&top,&bot);
  unholy=notes[0].ona;
  Free(notes);
  music.unholy=TRUE;
  psm=PsmSndOna(std,flags);
  music.unholy=FALSE;
  if (PsmSndOna(std,flags)!=std)
    psm=-1;
  music.unholy=old;
  if (psm!=unholy)
    HfPrint("FA %s: std %d Play() unholy %d Psalmody %d\n",note,std,unholy,psm);
  return psm==unholy;
}

U0 FaPsalmody()
{
  CTask *task;
  I64 i,popups=0,n;
  CHashGlblVar *g;
  PsmCtrl *p;
  Bool ok=TRUE,back=FALSE;
  U8 *naturals="A\0B\0C\0D\0E\0F\0G\0",*buf=MAlloc(8);
  HfPrint("-- Psalmody and Ctrl-Alt-R\n");
  for (i=0;i<7;i++) {
    StrPrint(buf,"%s",LstSub(i,naturals));
    if (!FaOnaSame(buf,0)) ok=FALSE;
    StrPrint(buf,"%s#",LstSub(i,naturals));
    if (!FaOnaSame(buf,1<<PSMf_SHARP)) ok=FALSE;
    StrPrint(buf,"%sb",LstSub(i,naturals));
    if (!FaOnaSame(buf,1<<PSMf_FLAT)) ok=FALSE;
  }
  Free(buf);
  FaCheck(ok,"Psalmody's Unholy notes are the ones Play() sounds");

  task=User("#include \"::/Apps/Psalmody/Run\";\n");
  Sleep(2000);
  PostMsg(task,MSG_KEY_DOWN_UP,',',0); //A random song from God.
  for (i=0;i<80;i++) {
    Sleep(150);
    if (TaskValidate(task->popup_task)) {
      popups++;
      PostMsg(task->popup_task,MSG_KEY_DOWN_UP,CH_ESC,0);
    }
  }
  if (g=HashFind("psm",task->hash_table,HTT_GLBL_VAR)) {
    p=g->data_addr;
    n=QueCnt(&p->head);
    HfPrint("FA random song: %d notes, %d pop-ups\n",n,popups);
    if (n>=4) {
      music.backmask=TRUE;
      PostMsg(task,MSG_KEY_DOWN_UP,'x',0);
      for (i=0;i<20 && !back;i++) {
	Sleep(25);
	if (p->playing && p->cur_note==p->head.last)
	  back=TRUE;
      }
      PostMsg(task,MSG_KEY_DOWN_UP,CH_SPACE,0); //Any key stops it.
      Sleep(500);
      music.backmask=FALSE;
      FaCheck(back,"Ctrl-Alt-R on: Psalmody plays from the last note");
    } else
      FaCheck(FALSE,"random song loaded into Psalmody");
  } else
    FaCheck(FALSE,"psm found");
  FaCheck(TaskValidate(task),"Psalmody survives");
  PostMsgWait(task,MSG_KEY_DOWN_UP,CH_SHIFT_ESC,0);
  Sleep(300);
  Kill(task);
}

//---- Splash --------------------------------------------------------------
U0 FaSplash()
{
  HfPrint("-- splash\n");
  FaCheck(!summoning,"the summoning circle is banished before Adam serves");
}

U0 FaMain()
{
  FaSplash;
  FaSprites;
  FaBreath;
  FaCtrlAltI;
  FaFont;
  FaOracle;
  FaLinks;
  FaPsalmody;
  PaletteUnholySet(UNHOLY_PAL_HELLFIRE);
  HfPrint("FA %d passed, %d failed\n",fa_passes,fa_fails);
  if (fa_fails)
    hf_exit_code=1;
  else
    hf_exit_code=0;
}

FaMain;
