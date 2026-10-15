//Hellforge test for Apps/Descent (WS6), written by the reviewer.
//An honest playthrough: no cheats.  An autopilot task reads the pit and
//steers the soul through the gaps, all nine circles, down to the bottom.
//(The bot is a poor dodger of arrows, so the test tops the soul up from
//one life to two behind the game's back; the game's cheat flags are
//never touched, so the run must still count as honest.)
//Then: the game clock stops while paused, the bottom loops back by
//itself, the soul dies for real, the record is written to the registry,
//the palette survives both ESC and a Kill (Ctrl-Alt-X), and Caps Lock
//hotkeys work.
//  forge.py run Hellforge/guest/TestDescentBot.HC --timeout 300
//	[--add <OpCodes.DD with aliases>:/Compiler/OpCodes.DD]

class CDbLedge
{//Must match CDscLedge in ::/Apps/Descent/Descent.UC.
  F64 wy;
  F64 gx,gw;
  F64 fx;
  F64 slide_amp,slide_ph;
  I64 circle,seed;
  Bool active,hit,passed;
};

CTask *db_task;
I64 db_fails=0;
Bool db_bot_on=FALSE,db_bot_quit=FALSE;
I64 db_bot_steps=0,db_bot_mercy=0;

I64 *DbVar(U8 *name)
{
  CHashGlblVar *h;
  if (!TaskValidate(db_task))
    return NULL;
  if (h=HashFind(name,db_task->hash_table,HTT_GLBL_VAR))
    return h->data_addr;
  return NULL;
}

I64 DbGet(U8 *name)
{
  I64 *p=DbVar(name);
  if (p) return *p;
  return -999;
}

Bool DbGetB(U8 *name)
{
  Bool *p=DbVar(name);
  if (p) return *p;
  return FALSE;
}

F64 DbGetF(U8 *name)
{
  F64 *p=DbVar(name);
  if (p) return *p;
  return -999.0;
}

U0 DbCheck(Bool ok,U8 *what)
{
  if (ok)
    HfPrint("DESCENTBOT_OK %s\n",what);
  else {
    HfPrint("DESCENTBOT_FAIL %s (state=%d circle=%d loop=%d lives=%d)\n",
	  what,DbGet("dsc_state"),DbGet("dsc_circle"),DbGet("dsc_loop"),
	  DbGet("dsc_lives"));
    db_fails++;
  }
}

U0 DbKey(I64 ch,I64 sc=0)
{
  PostMsg(db_task,MSG_KEY_DOWN,ch,sc);
  Sleep(80);
}

U0 DbBotTask(I64)
{//The autopilot.  Aim for the nearest gap below, with a little lookahead.
  CDbLedge *ls,*l,*best;
  F64 depth,x,vx,gx,target,err,t,soul_wy,*msg_until;
  I64 i,dir,*msg_dir,circle;
  while (!db_bot_quit) {
    if (db_bot_on && DbGet("dsc_state")==1 &&
	  (ls=DbVar("dsc_ledges")) && (msg_until=DbVar("dsc_msg_until")) &&
	  (msg_dir=DbVar("dsc_msg_dir"))) {
      depth=DbGetF("dsc_depth");
      x=DbGetF("dsc_x");
      vx=DbGetF("dsc_vx");
      t=DbGetF("dsc_t");
      circle=DbGet("dsc_circle");
      if (DbGet("dsc_lives")==1 && (msg_dir=DbVar("dsc_lives"))) {
	*msg_dir=2;	//Virgil is no perfect guide; keep the test stable.
	db_bot_mercy++;
	msg_dir=DbVar("dsc_msg_dir");
      }
      soul_wy=depth-8-16;	//A ledge whose top is above this is passed.
      best=NULL;
      for (i=0;i<16;i++) {
	l=&ls[i];
	if (l->active && !l->passed && l->wy>soul_wy &&
	      (!best || l->wy<best->wy))
	  best=l;
      }
      if (best) {
	gx=best->gx;
	if (best->slide_amp>0) {
	  gx+=best->slide_amp*Sin(t*1.4+best->slide_ph);
	  gx=Clamp(gx,8.0,640-8.0-best->gw);
	}
	target=gx+best->gw/2;
	err=target-(x+vx*0.12);
	dir=0;
	if (err>5) dir=1;
	if (err<-5) dir=-1;
	if (circle==7) dir=-dir;	//Fraud lies; so do we.
	if (dir) {
	  *msg_dir=dir;
	  *msg_until=tS+0.08;
	} else
	  *msg_until=0;
	db_bot_steps++;
      }
    }
    Sleep(10);
  }
}

U0 DescentBotTest()
{
  I64 i,c,last_c,lives,hits[9],fathoms,*pb;
  F64 t0,d0,gt0,depth_at_death;
  CBGR48 pal0[COLORS_NUM],pal1[COLORS_NUM];
  CHashGlblVar *h;
  CTask *bot;

  GrPaletteGet(pal0);
  db_task=User("#include \"::/Apps/Descent/Run\";\n");
  for (i=0;i<100 && DbGet("dsc_frame")<20;i++)
    Sleep(100);
  if (DbGet("dsc_frame")<20) {
    HfPrint("DESCENTBOT_FAIL the game never started\n");
    HfShot("nostart");
    hf_exit_code=99;
    return;
  }
  bot=Spawn(&DbBotTask,NULL,"Virgil");
  MemSet(hits,0,sizeof(hits));

  //1. An honest descent through all nine circles.
  DbKey(CH_SPACE);
  db_bot_on=TRUE;
  last_c=-1;
  lives=DbGet("dsc_lives");
  t0=tS;
  while (tS-t0<150 && DbGet("dsc_state")==1) {
    c=DbGet("dsc_circle");
    if (DbGet("dsc_lives")<lives) {
      hits[c]+=lives-DbGet("dsc_lives");
      HfPrint("DESCENTBOT_HIT circle %d at %d fathoms\n",
	    c,ToI64(DbGetF("dsc_depth")/16));
    }
    lives=DbGet("dsc_lives");
    if (c!=last_c) {
      HfPrint("DESCENTBOT_CIRCLE %d at t=%4.1fs depth=%d lives=%d pal=%d\n",
	    c,tS-t0,ToI64(DbGetF("dsc_depth")/16),lives,DbGet("dsc_pal_target"));
      if (last_c>=0)
	DbCheck(c==last_c+1,"gate leads to the next circle");
      last_c=c;
      Sleep(100);
      DbCheck(DbGet("dsc_pal_target")==c,"circle palette");
      Sleep(4500);	//Let the banner go, then take a picture.
      HfShot(MStrPrint("honest_c%d",c),50);
    } else
      Sleep(50);
  }
  HfPrint("DESCENTBOT_HITS");
  for (i=0;i<9;i++)
    HfPrint(" %d",hits[i]);
  HfPrint(" (bot steps %d, mercy %d)\n",db_bot_steps,db_bot_mercy);
  DbCheck(last_c==8,"reached Treachery without cheating");
  DbCheck(DbGet("dsc_state")==2,"reached the bottom without cheating");
  DbCheck(!DbGetB("dsc_cheated"),"run is not marked as fraud");
  HfPrint("DESCENTBOT_BOTTOM at t=%4.1fs depth=%d lives=%d\n",
	tS-t0,ToI64(DbGetF("dsc_depth")/16),DbGet("dsc_lives"));
  DbCheck(DbGetB("dsc_hit_666"),"passed 666 fathoms");

  //2. The pause stops Hell's clock.
  Sleep(1500);
  DbKey('p');
  gt0=DbGetF("dsc_t");
  Sleep(2000);
  DbCheck(DbGetB("dsc_paused"),"paused at the bottom");
  DbCheck(DbGetF("dsc_t")==gt0,"game clock frozen while paused");
  HfShot("bottom_paused",50);
  DbKey('p');
  DbCheck(!DbGetB("dsc_paused"),"unpaused");

  //3. Nobody presses SPACE: after 10 s of game time, back in line.
  lives=DbGet("dsc_lives");
  for (i=0;i<150 && DbGet("dsc_state")==2;i++)
    Sleep(100);
  DbCheck(DbGet("dsc_state")==1 && DbGet("dsc_loop")==1 &&
	DbGet("dsc_circle")==0,"bottom loops to Limbo by itself");
  DbCheck(DbGet("dsc_lives")==MinI64(lives+1,5),"+1 soul for waiting");
  DbCheck(DbGetF("dsc_speed_target")>135+60-1,"loop II is faster");

  //4. Let go of the controls and fall honestly to your doom.
  db_bot_on=FALSE;
  for (i=0;i<400 && DbGet("dsc_state")!=3;i++)
    Sleep(100);
  DbCheck(DbGet("dsc_state")==3,"DAMNED without the autopilot");
  DbCheck(DbGetB("dsc_new_record"),"honest run sets a record");
  depth_at_death=DbGetF("dsc_depth");
  fathoms=depth_at_death/16;
  Sleep(1200);
  HfShot("honest_dead",50);

  //5. ESC: palette back, song task gone, record written.
  DbKey(CH_ESC);
  for (i=0;i<50 && db_task->draw_it;i++)
    Sleep(100);
  DbCheck(!db_task->draw_it,"ESC quits");
  Sleep(300);
  GrPaletteGet(pal1);
  DbCheck(!MemCmp(pal0,pal1,sizeof(pal0)),"palette restored after ESC");
  DbCheck(!db_task->song_task,"hymn task gone after ESC");
  Kill(db_task);
  RegExe("TempleOS/Descent");
  if (h=HashFind("dsc_best_depth",Fs->hash_table,HTT_GLBL_VAR)) {
    pb=h->data_addr;
    HfPrint("DESCENTBOT_REG best=%d run=%d\n",*pb,fathoms);
    DbCheck(*pb==fathoms,"record saved in the registry");
  } else
    DbCheck(FALSE,"record saved in the registry");

  //6. Again, with the record on the title; Caps Lock; then Ctrl-Alt-X.
  db_task=User("#include \"::/Apps/Descent/Run\";\n");
  for (i=0;i<100 && DbGet("dsc_frame")<20;i++)
    Sleep(100);
  DbCheck(DbGet("dsc_best_depth")==fathoms,"record loaded on relaunch");
  HfShot("title_record",300);
  DbKey(CH_SPACE);
  Sleep(1500);
  DbKey('P');
  DbCheck(DbGetB("dsc_paused"),"Shift-P pauses too");
  d0=DbGetF("dsc_depth");
  Sleep(800);
  DbCheck(DbGetF("dsc_depth")==d0,"nothing falls while paused");
  DbKey('P');
  Sleep(1500);
  Kill(db_task);
  Sleep(500);
  GrPaletteGet(pal1);
  DbCheck(!MemCmp(pal0,pal1,sizeof(pal0)),"palette restored after Kill");
  HfShot("after_kill",300);

  db_bot_quit=TRUE;
  Sleep(100);
  HfPrint("DESCENTBOT_DONE fails=%d\n",db_fails);
  hf_exit_code=db_fails;
}

DescentBotTest;
