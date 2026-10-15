//WS2 review: an uncaught throw must reach Panic("Unholy Exception")
//and The Exorcist, and "G;" must let the possessed task carry on.
//forge.py run guest/TestKernelPanic.HC --shots 12 --keys "15:G<semicolon><ret>"
//Exit 0 once the task resumed after the debugger.

Bool tkp_resumed=FALSE;

U0 TkpPossessed(U8 *)
{
  HfPrint("TKP throwing with no catcher\n");
  throw('Beast');
  HfPrint("TKP back from Panic\n");
  tkp_resumed=TRUE;
}

U0 TestKernelPanic()
{
  I64 i;
  Spawn(&TkpPossessed,NULL,"Possessed");
  for (i=0;i<600 && !tkp_resumed;i++)
    Sleep(100);
  if (tkp_resumed) {
    HfPrint("TKP resumed\n");
    HfShot("resumed");
    hf_exit_code=0;
  } else {
    HfPrint("TKP never resumed\n");
    hf_exit_code=1;
  }
}

TestKernelPanic;
