//Hellforge test for Apps/Descent (WS6).
//Run with the Unholy C keyword aliases in the image's OpCodes.DD:
//  forge.py run Hellforge/guest/TestDescent.HC
//	--add <OpCodes.DD with aliases>:/Compiler/OpCodes.DD
//Spawns the game in a user terminal, drives it with key messages,
//reads its globals through the task's hash table and takes screenshots
//of the title, every circle, the bottom, a second loop and death.

CTask *dt_task;
I64 dt_fails=0;

I64 *DtVar(U8 *name)
{//Address of one of the game's globals, or NULL.
  CHashGlblVar *h;
  if (!TaskValidate(dt_task))
    return NULL;
  if (h=HashFind(name,dt_task->hash_table,HTT_GLBL_VAR))
    return h->data_addr;
  return NULL;
}

I64 DtGet(U8 *name)
{
  I64 *p=DtVar(name);
  if (p)
    return *p;
  return -999;
}

F64 DtGetF(U8 *name)
{
  F64 *p=DtVar(name);
  if (p)
    return *p;
  return -999.0;
}

U0 DtCheck(Bool ok,U8 *what)
{
  if (ok)
    HfPrint("DESCENT_OK %s\n",what);
  else {
    HfPrint("DESCENT_FAIL %s (state=%d circle=%d loop=%d lives=%d)\n",
	  what,DtGet("dsc_state"),DtGet("dsc_circle"),DtGet("dsc_loop"),
	  DtGet("dsc_lives"));
    dt_fails++;
  }
}

U0 DtKey(I64 ch,I64 sc=0)
{
  PostMsg(dt_task,MSG_KEY_DOWN,ch,sc);
  Sleep(60);
}

U0 DtSteer(I64 sc,I64 ms)
{//Hold an arrow key: typematic-style repeated key-down messages.
  F64 t0=tS;
  while ((tS-t0)*1000<ms) {
    PostMsg(dt_task,MSG_KEY_DOWN,0,sc);
    Sleep(70);
  }
  PostMsg(dt_task,MSG_KEY_UP,0,sc|SCF_KEY_UP);
}

U0 DtWiggle(I64 ms)
{
  DtSteer(SC_CURSOR_LEFT,ms/2);
  DtSteer(SC_CURSOR_RIGHT,ms/2);
}

U0 DtShot(U8 *fmt,...)
{
  U8 *buf=StrPrintJoin(NULL,fmt,argc,argv);
  HfShot(buf,700);
  Free(buf);
}

U0 DtProfRst()
{
  I64 *p=DtVar("dsc_prof");
  if (p) MemSet(p,0,10*sizeof(I64));
  p=DtVar("dsc_prof_n");
  if (p) *p=0;
}

U0 DtProf(I64 c)
{//Average TSC cycles per frame for each drawing section.
  I64 *p=DtVar("dsc_prof"),n=DtGet("dsc_prof_n"),i;
  if (!p || n<=0) return;
  HfPrint("DESCENT_PROF c%d frames=%d",c,n);
  for (i=0;i<8;i++)
    HfPrint(" %d",p[i]/n/1000);
  HfPrint(" (kcycles)\n");
}

U0 DescentTest()
{
  I64 i,f0,f1,c;
  F64 x0,x1;

  dt_task=User("#include \"::/Apps/Descent/Run\";\n");
  for (i=0;i<100 && DtGet("dsc_frame")<20;i++)
    Sleep(100);
  if (DtGet("dsc_frame")<20) {
    HfPrint("DESCENT_FAIL the game never started (compile error?)\n");
    HfShot("nostart");
    Kill(dt_task);
    hf_exit_code=99;
    return;
  }
  DtCheck(DtGet("dsc_state")==0,"title screen up");
  f0=DtGet("dsc_frame");
  Sleep(2000);
  f1=DtGet("dsc_frame");
  HfPrint("DESCENT_FPS %d (TSC %d kHz)\n",(f1-f0)/2,
	cnts.time_stamp_freq/1000);
  DtCheck(f1-f0>=30,"game loop runs (>=15 fps)");
  DtShot("title");

  DtKey(CH_SPACE);
  Sleep(700);
  DtCheck(DtGet("dsc_state")==1,"SPACE starts the descent");
  DtShot("c0_banner");

  x0=DtGetF("dsc_x");
  DtSteer(SC_CURSOR_LEFT,700);
  x1=DtGetF("dsc_x");
  HfPrint("DESCENT_STEER %d -> %d\n",ToI64(x0),ToI64(x1));
  DtCheck(x1<x0-40,"left arrow steers left");
  x0=x1;
  DtSteer(SC_CURSOR_RIGHT,700);
  x1=DtGetF("dsc_x");
  DtCheck(x1>x0+40,"right arrow steers right");
  Sleep(1500);
  DtShot("c0_play");

  DtKey('d');	//Deal with the Devil: invulnerable for the tour.
  DtCheck(DtGet("dsc_deal")==TRUE,"deal with the devil");
  for (c=1;c<9;c++) {
    DtKey('n');
    Sleep(500);
    DtCheck(DtGet("dsc_circle")==c,"next circle");
    DtShot("c%d_banner",c);
    DtProfRst;
    DtWiggle(1600);
    Sleep(800);
    DtProf(c);
    DtShot("c%d_play",c);
  }
  DtKey('n');
  Sleep(2500);
  DtCheck(DtGet("dsc_state")==2,"reached the bottom");
  Sleep(1000);
  DtShot("bottom");
  DtKey(CH_SPACE);
  Sleep(1200);
  DtCheck(DtGet("dsc_state")==1 && DtGet("dsc_loop")==1 &&
	DtGet("dsc_circle")==0,"loop II back in Limbo");
  DtShot("loop2");

  DtKey('d');	//Void the deal; now let the ledges do their work.
  for (i=0;i<300 && DtGet("dsc_state")!=3;i++)
    Sleep(100);
  DtCheck(DtGet("dsc_state")==3,"three hits and you are DAMNED");
  Sleep(800);
  DtShot("dead");

  DtKey(CH_SPACE);
  Sleep(500);
  DtCheck(DtGet("dsc_state")==1 && DtGet("dsc_lives")==3,"descend again");
  DtKey('p');
  Sleep(300);
  DtCheck(DtGet("dsc_paused")&0xFF,"pause");
  DtCheck(DtGet("dsc_song_held")&0xFF,"pause holds the hymn");
  DtShot("paused");
  DtKey('p');
  Sleep(600);
  DtCheck(!(DtGet("dsc_song_held")&0xFF),"unpause resumes the hymn");
  DtKey('m');
  DtCheck(DtGet("dsc_mute")&0xFF && DtGet("dsc_song_held")&0xFF,"mute");
  DtKey('m');

  DtKey(CH_ESC);
  Sleep(800);
  DtCheck(TaskValidate(dt_task) && !dt_task->draw_it,"ESC exits cleanly");
  DtShot("exit");
  Kill(dt_task);
  HfPrint("DESCENT_DONE fails=%d\n",dt_fails);
  hf_exit_code=dt_fails;
}

DescentTest;
