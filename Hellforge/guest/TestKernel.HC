//WS2 kernel and boot identity test (forge.py run guest/TestKernel.HC).
//Needs the rebuilt kernel (forge.py bootstrap --install).
//Exit code: bit mask of failed checks, 0=all good.
//  1 version  2 Adam name  4 Seth/idle names  8 ST_INT_NAMES
//  16 Beep timing  32 kernel strings  64 default task name
//  128 stage-1 boot loader messages

I64 tk_bad=0;

U0 TkFail(I64 bit,U8 *what)
{
  HfPrint("TK FAIL %s\n",what);
  tk_bad|=bit;
}

U8 *TkFindIn(U8 *base,I64 size,U8 *needle)
{//Adjacent string literals are merged by the compiler, so no NUL is required.
  U8 *ptr;
  I64 len=StrLen(needle);
  for (ptr=base;ptr<=base+size-len;ptr++)
    if (!MemCmp(ptr,needle,len))
      return ptr;
  return NULL;
}

U8 *TkFind(U8 *needle)
{//Search the running kernel image.
  U8 *kbase=mem_boot_base-sizeof(CBinFile);
  return TkFindIn(kbase,kbase(CBinFile *)->file_size,needle);
}

U0 TkSleeper()
{
  while (TRUE)
    Sleep(1000);
}

U0 TestKernel()
{
  I64 i;
  F64 t0,dt,ref;
  CCPU *c;
  CTask *task;
  U8 buf[STR_LEN];

  HfPrint("TK compile_time %D %T\n",sys_compile_time,sys_compile_time);
  HfPrint("TK sys_os_version V%4.2f (%9.6f)\n",sys_os_version,sys_os_version);
  if (!(6.6599<sys_os_version<6.6601))
    TkFail(1,"sys_os_version!=6.66");

  HfPrint("TK adam_task->task_name \"%s\"\n",adam_task->task_name);
  if (StrCmp(adam_task->task_name,"madA Task CPU00"))
    TkFail(2,"adam task name");

  HfPrint("TK mp_cnt %d\n",mp_cnt);
  for (i=0;i<mp_cnt;i++) {
    c=&cpu_structs[i];
    if (c->seth_task) {
      HfPrint("TK cpu%d seth \"%s\"\n",i,c->seth_task->task_name);
      if (i) {
	StrPrint(buf,"hteS Task CPU%02X",i);
	if (StrCmp(c->seth_task->task_name,buf))
	  TkFail(4,"seth task name");
      }
    }
    if (c->idle_task) {
      HfPrint("TK cpu%d idle \"%s\"\n",i,c->idle_task->task_name);
      if (StrCmp(c->idle_task->task_name,"Idle Hands"))
	TkFail(4,"idle task name");
    }
  }

  HfPrint("TK ST_INT_NAMES count %d\n",DefineCnt("ST_INT_NAMES"));
  if (DefineCnt("ST_INT_NAMES")!=51)
    TkFail(8,"ST_INT_NAMES count");
  for (i=0;i<DefineCnt("ST_INT_NAMES");i++)
    if (StrCmp(DefineSub(i,"ST_INT_NAMES")," "))
      HfPrint("TK int 0x%02X %s\n",i,DefineSub(i,"ST_INT_NAMES"));
  if (StrCmp(DefineSub(I_PAGE_FAULT,"ST_INT_NAMES"),
	"Page Fault (Torn from the Grimoire)"))
    TkFail(8,"page fault name");
  if (StrCmp(DefineSub(I_MP_CRASH,"ST_INT_NAMES"),"MP Crash (Pandemonium)"))
    TkFail(8,"MP crash name");
  if (StrCmp(DefineSub(I_WAKE,"ST_INT_NAMES"),"Wake (Raise the Dead)"))
    TkFail(8,"wake name");

//The old Beep slept 500+200 mS.  The tritone Beep sleeps 250+250+200 mS,
  //so it must take as long as a plain Sleep(700) on this machine (under
  //virtualization Sleep's jiffies can run slower than tS).
  t0=tS;
  Sleep(700);
  ref=tS-t0;
  HfPrint("TK Sleep(700) took %6.3fs (reference)\n",ref);
  t0=tS;
  Beep;
  dt=tS-t0;
  HfPrint("TK Beep(62) took %6.3fs\n",dt);
  if (!(0.8*ref<dt<1.2*ref))
    TkFail(16,"Beep timing");
  t0=tS;
  Beep(70,TRUE);
  dt=tS-t0;
  HfPrint("TK Beep(70,TRUE) took %6.3fs\n",dt);
  if (!(0.6<dt<0.9))
    TkFail(16,"Beep busy timing");

  if (TkFind("\n\tUnholy C Debugger -- The Exorcist\n\n"))
    HfPrint("TK kernel has debugger banner\n");
  else
    TkFail(32,"debugger banner");
  if (TkFind("Unholy Exception"))
    HfPrint("TK kernel has Unholy Exception\n");
  else
    TkFail(32,"Unholy Exception");
  if (TkFind("Abandon all hope, ye who boot here."))
    HfPrint("TK kernel has the verse\n");
  else
    TkFail(32,"verse");
  if (TkFind("TempleOS RedSea"))
    HfPrint("TK kernel still knows the publisher id\n");
  else
    TkFail(32,"publisher id");
  if (TkFind("\n\tTempleOS Debugger\n\n"))
    TkFail(32,"old debugger banner still present");

//Stage 1 (Adam/Opt/Boot/BootDVD.HC) was assembled at boot by MakeHome,
  //so its #assert held.  Check its messages made it in.
  HfPrint("TK BootDVD stage 1 size %d of %d\n",
	BDVD_END-BDVD_START,DVD_BOOT_LOADER_SIZE);
  if (TkFindIn(BDVD_START,BDVD_END-BDVD_START,"Summoning AntichristOS") &&
	TkFindIn(BDVD_START,BDVD_END-BDVD_START,
	"AntichristOS requires a 64-bit capable processor (and your soul)."))
    HfPrint("TK BootDVD messages OK\n");
  else
    TkFail(128,"BootDVD messages");

  task=Spawn(&TkSleeper);
  Sleep(50);
  HfPrint("TK default task name \"%s\"\n",task->task_name);
  if (StrCmp(task->task_name,"Nameless Horror"))
    TkFail(64,"default task name");
  Kill(task);

  HfShot("desktop");
  HfPrint("TK END bad=%d\n",tk_bad);
  hf_exit_code=tk_bad;
}

TestKernel;
