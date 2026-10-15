//Hellforge test for Apps/Descent (WS6): the real keyboard path.
//The host types the keys (QEMU sendkey), so they travel through the
//keyboard IRQ, kbd.down_bitmap and the window manager's focus task:
//  forge.py run Hellforge/guest/TestDescentKeys.HC --name dkeys
//	--add <OpCodes.DD with aliases>:/Compiler/OpCodes.DD
//	--keys "14:<spc>;16:<left><left><left><left><left><left><left><left>;
//		19:<right><right><right><right><right><right><right><right>;
//		22:<esc>"
//(one --keys argument, no line breaks).

CTask *dk_task;
I64 dk_fails=0;

I64 *DkVar(U8 *name)
{
  CHashGlblVar *h;
  if (!TaskValidate(dk_task))
    return NULL;
  if (h=HashFind(name,dk_task->hash_table,HTT_GLBL_VAR))
    return h->data_addr;
  return NULL;
}

I64 DkGet(U8 *name)
{
  I64 *p=DkVar(name);
  if (p)
    return *p;
  return -999;
}

F64 DkGetF(U8 *name)
{
  F64 *p=DkVar(name);
  if (p)
    return *p;
  return -999.0;
}

U0 DkCheck(Bool ok,U8 *what)
{
  if (ok)
    HfPrint("DESCENT_OK %s\n",what);
  else {
    HfPrint("DESCENT_FAIL %s (state=%d)\n",what,DkGet("dsc_state"));
    dk_fails++;
  }
}

U0 DescentKeysTest()
{
  I64 i;
  F64 x0,lo,hi,x;
  Bool *bp;
  dk_task=User("#include \"::/Apps/Descent/Run\";\n");
  for (i=0;i<100 && DkGet("dsc_frame")<20;i++)
    Sleep(100);
  DkCheck(DkGet("dsc_frame")>=20,"game started");
  DkCheck(sys_focus_task==dk_task,"game window has the focus");
  for (i=0;i<300 && DkGet("dsc_state")!=1;i++)
    Sleep(100);
  DkCheck(DkGet("dsc_state")==1,"real SPACE key starts the descent");
  HfShot("started",300);
  if (bp=DkVar("dsc_deal"))
    *bp=TRUE; //Keep the soul alive for the test.
  x0=DkGetF("dsc_x");
  lo=hi=x0;
  for (i=0;i<120 && !(DkGet("dsc_quit")&0xFF);i++) {
    x=DkGetF("dsc_x");
    if (x<lo) lo=x;
    if (x>hi) hi=x;
    Sleep(50);
  }
  HfPrint("DESCENT_KEYS x0=%d min=%d max=%d last=%d\n",
	ToI64(x0),ToI64(lo),ToI64(hi),ToI64(x));
  DkCheck(lo<x0-30,"real LEFT key steers left");
  DkCheck(x>lo+30,"real RIGHT key steers right (back from the minimum)");
  for (i=0;i<100 && dk_task->draw_it;i++)
    Sleep(100);
  DkCheck(!dk_task->draw_it,"real ESC key quits");
  HfShot("quit",300);
  Kill(dk_task);
  HfPrint("DESCENT_DONE fails=%d\n",dk_fails);
  hf_exit_code=dk_fails;
}

DescentKeysTest;
