//WS5 tour test (forge.py run Hellforge/guest/TestDocsTour.HC).
//Runs the changed parts of The Descent against stubs of TourPut() and
//the In*() keystroke helpers, so every part compiles and runs end to end
//without anybody at the keyboard, then screenshots the real tour menu.
//Each part runs in a PopUp child of this task, so it sees the stubs.

CTask *tour_put=Fs,*tour_task=Fs;
Bool tour_okay_pressed=TRUE;
I64 tour_puts=0,tour_bad=0;

U0 TourPut(U8 *st,Bool wait_okay=FALSE)
{
  tour_puts++;
  HfPrint("TOURPUT %d %d: ",tour_puts,wait_okay);
  HfPutS(st);
  HfPutChar('\n');
}

U0 InGetStr(U8 *st)
{
  HfPrint("  [InGetStr %d]\n",StrLen(st));
}

U0 InPrint(I64 mS=100,U8 *fmt,...)
{
  HfPrint("  [InPrint %d] ",mS);
  HfPutS(fmt);
  HfPutChar('\n');
}

U0 InGetKey(I64 scan_code,I64 sc_mask=0)
{
  no_warn scan_code,sc_mask;
}

I64 InGetChar(...)
{
  return argc;
}

U0 InUntilKey(I64 scan_code,I64 sc_mask=0)
{
  no_warn scan_code,sc_mask;
}

I64 InUntilChar(...)
{
  return argc;
}

U0 TourPart(U8 *name,I64 want_puts)
{
  I64 before=tour_puts;
  U8 *st=MStrPrint("ExeFile(\"::/Misc/Tour/%s\");",name);
  HfPrint("TOURPART %s\n",name);
  PopUp(st,Fs);
  Free(st);
  HfPrint("TOURPART %s puts=%d want=%d\n",name,tour_puts-before,want_puts);
  if (tour_puts-before!=want_puts)
    tour_bad++;
}

U0 TourMenuShot()
{//Cut PopUpTourPart() out of the real Tour.IN and show the menu.
  U8 *src=FileRead("::/Misc/Tour/Tour.IN"),*a,*b;
  CTask *task;
  a=StrFind("public I64 PopUpTourPart()",src);
  b=StrFind("U0 TourMenu()",src);
  if (!a || !b) {
    HfPrint("TOURMENU not found\n");
    tour_bad++;
    Free(src);
    return;
  }
  *b=0;
  FileWrite("B:/TourMenuOnly.HC",a,StrLen(a));
  Free(src);
  task=User("ExeFile(\"B:/TourMenuOnly.HC\");\nPopUpTourPart;\n");
  Sleep(3000);
  HfShot("tourmenu");
  Kill(task);
  Sleep(300);
}

TourMenuShot;
TourPart("Tour2.IN",9);
TourPart("Tour8.IN",5);
TourPart("Tour9.IN",6);
TourPart("TourC.IN",1);
TourPart("TourD.IN",8);
HfPrint("TOUR_BAD %d\n",tour_bad);
hf_exit_code=tour_bad;
