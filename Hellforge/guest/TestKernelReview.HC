//WS2 review test, independent of TestKernel.HC.
//(forge.py run guest/TestKernelReview.HC --smp 4, rebuilt kernel needed)
//Checks that the themed kernel kept everything functional:
//version formats, every ST_INT_NAMES slot (old name kept as a prefix,
//blank slots still blank), task names on every core, explicit Spawn
//names, Beep edge cases and GetTSC timing, and the frozen strings the
//CD/DVD port prompt and the CD mount depend on.
//Exit code: number of failed checks.

I64 tkr_bad=0;

U0 TkrFail(U8 *what)
{
  HfPrint("TKR FAIL %s\n",what);
  tkr_bad++;
}

U0 TkrOk(U8 *what)
{
  HfPrint("TKR ok   %s\n",what);
}

Bool TkrHas(U8 *needle)
{//Search the running kernel image.
  U8 *kbase=mem_boot_base-sizeof(CBinFile),*ptr;
  I64 size=kbase(CBinFile *)->file_size,len=StrLen(needle);
  for (ptr=kbase;ptr+len<=kbase+size;ptr++)
    if (!MemCmp(ptr,needle,len))
      return TRUE;
  return FALSE;
}

U0 TkrIdle()
{
  while (TRUE)
    Sleep(1000);
}

F64 TkrSecs(I64 t0)
{
  return ToF64(GetTSC-t0)/cnts.time_stamp_freq;
}

U0 TestKernelReview()
{
  U8 buf[STR_LEN],*st,
	*old_names="Divide Error\0SingleStep\0NMI\0Breakpoint\0"
	"Overflow\0BOUND Range Exceeded\0Invalid Opcode\0No Math Coprocessor\0"
	"Double Fault\0Coprocessor Segment Fault\0Invalid TASK\0"
	"Segment Not Present\0Stk Segment Fault\0General Protection\0"
	"Page Fault\0 \0Math Fault\0Alignment Check\0Machine Check\0"
	"SIMD Exception\0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0"
	" \0 \0 \0 \0 \0 \0 \0 \0 \0 \0 \0MP Crash\0Wake\0Dbg\0";
  I64 i,t0,len;
  F64 dt;
  CTask *task;
  CCPU *c;

//Version, both the new and the old format.
  StrPrint(buf,"V%4.2f",sys_os_version);
  if (StrCmp(buf,"V6.66")) TkrFail(buf); else TkrOk(buf);
  StrPrint(buf,"V%5.3f",sys_os_version);
  if (StrCmp(buf,"V6.660")) TkrFail(buf); else TkrOk(buf);

//ST_INT_NAMES: 51 slots; each themed name starts with the old one.
  if (DefineCnt("ST_INT_NAMES")!=51)
    TkrFail("ST_INT_NAMES count");
  st=old_names;
  for (i=0;i<51;i++) {
    len=StrLen(st);
    if (!DefineSub(i,"ST_INT_NAMES")) {
      TkrFail("ST_INT_NAMES missing slot");
    } else if (!StrCmp(st," ")) {
      if (StrCmp(DefineSub(i,"ST_INT_NAMES")," "))
	TkrFail("blank ST_INT_NAMES slot was filled");
    } else if (StrNCmp(DefineSub(i,"ST_INT_NAMES"),st,len) ||
	  DefineSub(i,"ST_INT_NAMES")[len]!=' ' ||
	  DefineSub(i,"ST_INT_NAMES")[len+1]!='(') {
      HfPrint("TKR slot 0x%02X \"%s\" vs \"%s\"\n",
	    i,DefineSub(i,"ST_INT_NAMES"),st);
      TkrFail("ST_INT_NAMES name lost its prefix");
    }
    st+=len+1;
  }
  HfPrint("TKR Fault:0x%02X %Z\n",I_BPT,I_BPT,"ST_INT_NAMES");
  HfPrint("TKR Fault:0x%02X %Z\n",I_DBG,I_DBG,"ST_INT_NAMES");
  if (StrCmp(DefineSub(I_DBG,"ST_INT_NAMES"),"Dbg (Exorcism)"))
    TkrFail("I_DBG name");
  else
    TkrOk("ST_INT_NAMES 51 slots, prefixes kept");

//Task names on every core.
  if (StrCmp(adam_task->task_name,"madA Task CPU00"))
    TkrFail("adam name");
  for (i=0;i<mp_cnt;i++) {
    c=&cpu_structs[i];
    HfPrint("TKR cpu%d seth=\"%s\" idle=\"%s\"\n",i,
	  c->seth_task->task_name,c->idle_task->task_name);
    if (i) {
      StrPrint(buf,"hteS Task CPU%02X",i);
      if (StrCmp(c->seth_task->task_name,buf))
	TkrFail("seth name");
    }
    if (StrCmp(c->idle_task->task_name,"Idle Hands"))
      TkrFail("idle name");
  }
  TkrOk("task names checked");

//Spawn: explicit names win, the default is themed.
  task=Spawn(&TkrIdle,NULL,"Mephistopheles");
  Sleep(20);
  if (StrCmp(task->task_name,"Mephistopheles"))
    TkrFail("explicit spawn name");
  Kill(task);
  task=Spawn(&TkrIdle);
  Sleep(20);
  if (StrCmp(task->task_name,"Nameless Horror"))
    TkrFail("default spawn name");
  else
    TkrOk("Spawn names");
  Kill(task);

//Beep: low notes (no tritone below) and the busy path, timed by the TSC.
  t0=GetTSC;
  Beep(3,TRUE);
  dt=TkrSecs(t0);
  HfPrint("TKR Beep(3,TRUE) %6.3fs\n",dt);
  if (!(0.65<dt<0.80)) TkrFail("Beep(3,TRUE) time");
  t0=GetTSC;
  Beep(0,TRUE);
  dt=TkrSecs(t0);
  HfPrint("TKR Beep(0,TRUE) %6.3fs\n",dt);
  if (!(0.65<dt<0.80)) TkrFail("Beep(0,TRUE) time");
  t0=GetTSC;
  Beep(62,TRUE);
  dt=TkrSecs(t0);
  HfPrint("TKR Beep(62,TRUE) %6.3fs\n",dt);
  if (!(0.65<dt<0.80)) TkrFail("Beep(62,TRUE) time");
  if (scrncast.ona) TkrFail("Beep left the speaker on");
  else TkrOk("Beep timing, speaker off afterwards");

//Frozen and functional strings the themed text must not have broken.
  if (!TkrHas("TempleOS RedSea")) TkrFail("publisher id");
  if (!TkrHas("CD/DVD I/O Port Base0: 0x")) TkrFail("port prompt");
  if (!TkrHas("\nUnit (0 or 1): ")) TkrFail("unit prompt");
  if (!TkrHas("not a soul\n")) TkrFail("soul contract prompt");
  if (!TkrHas("\n\tUnholy C Debugger -- The Exorcist\n\n")) TkrFail("banner");
  if (!TkrHas("<G;\t\t\t\t//Resume execution.")) TkrFail("dbg help G;");
  if (!TkrHas("<Exit;\t\t\t\t//Exit (kill) task.")) TkrFail("dbg help Exit;");
  if (TkrHas("Speaking in Tongues")) TkrFail("guardrail: tongues");
  TkrOk("kernel strings");

  HfPrint("TKR END bad=%d\n",tkr_bad);
  hf_exit_code=tkr_bad;
}

TestKernelReview;
