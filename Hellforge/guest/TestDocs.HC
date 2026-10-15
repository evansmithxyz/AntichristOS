//WS5 docs test (forge.py run Hellforge/guest/TestDocs.HC).
//Every rewritten doc must load with no DolDoc errors, Type() cleanly,
//the Temptation of the Day must work, LinkChk() runs, and the Welcome
//and Anti-Charter docs are screenshotted in a maximized window.

I64 docs_bad=0;

I64 DocErrCnt(U8 *filename,I64 *_entries=NULL)
{//Count DOCT_ERROR entries.  -1 if the file is missing.
  CDoc *doc;
  CDocEntry *doc_e;
  I64 errs=0,n=0;
  if (!FileFind(filename,,FUF_Z_OR_NOT_Z))
    return -1;
  doc=DocRead(filename);
  doc_e=doc->head.next;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_ERROR)
      errs++;
    n++;
    doc_e=doc_e->next;
  }
  DocDel(doc);
  if (_entries) *_entries=n;
  return errs;
}

U0 ChkDoc(U8 *filename,I64 min_entries=10)
{
  I64 n=0,errs=DocErrCnt(filename,&n);
  if (errs<0) {
    HfPrint("DOCFAIL %s missing\n",filename);
    docs_bad++;
  } else if (errs || n<min_entries) {
    HfPrint("DOCFAIL %s entries=%d errors=%d\n",filename,n,errs);
    docs_bad++;
  } else
    HfPrint("DOCOK %s entries=%d\n",filename,n);
}

I64 TipCnt(U8 *filename)
{//Number of '*' entries TipOfDay can choose from.
  CDoc *doc=DocRead(filename);
  CDocEntry *doc_e=doc->head.next;
  I64 res=0;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_TEXT && *doc_e->tag=='*')
      res++;
    doc_e=doc_e->next;
  }
  DocDel(doc);
  return res;
}

I64 PutDocEntries()
{
  CDoc *doc=DocPut;
  CDocEntry *doc_e=doc->head.next;
  I64 res=0;
  while (doc_e!=doc) {
    res++;
    doc_e=doc_e->next;
  }
  return res;
}

U0 ShotDoc(U8 *filename,U8 *shot_name)
{//Open a doc in a fresh maximized terminal, screenshot it, close it.
  CTask *task=User("WinMax;Ed(\"%s\");\n",filename);
  Sleep(2500);
  WinToTop(task);
  WinFocus(task);
  Sleep(500);
  HfShot(shot_name);
  Kill(task);
  Sleep(300);
}

U0 AnchorChk(U8 *link)
{//FF: anchors that old links and kernel comments depend on.
  if (Ed(link,EDF_BAIL))
    HfPrint("ANCHOROK %s\n",link);
  else {
    HfPrint("ANCHORFAIL %s\n",link);
    docs_bad++;
  }
}

U0 LinkChkTree(U8 *mask,U8 *flags=NULL)
{//Broken links are listed in this task's doc (HELLFORGE_DOC).
  I64 n=-1;
  F64 t0=tS;
  "$$PURPLE$$LinkChk(\"%s\")$$FG$$\n",mask;
  try
    n=LinkChk(mask,flags);
  catch {
    HfPrint("LINKCHK %s EXCEPT %c\n",mask,Fs->except_ch);
    "$$RED$$Except %c$$FG$$\n",Fs->except_ch;
    Fs->catch_except=TRUE;
  }
  HfPrint("LINKCHK %s broken=%d secs=%d\n",mask,n,ToI64(tS-t0));
}

U0 TestDocs()
{
  I64 i,n,before,after,t0;
  U8 *st;
  HfShot("desktop");

  ChkDoc("::/Doc/Welcome.DD");
  ChkDoc("::/Doc/Charter.DD");
  ChkDoc("::/Doc/UnholyC.DD");
  ChkDoc("::/Doc/HolyC.DD");
  ChkDoc("::/Doc/FAQ.DD");
  ChkDoc("::/Doc/Start.DD",4);
  ChkDoc("::/Doc/HelpIndex.DD");
  ChkDoc("::/Doc/Temptations.DD");
  ChkDoc("::/Doc/AboutAntichristOS.DD");
  ChkDoc("::/Doc/AboutTempleOS.DD");
  ChkDoc("::/Doc/StdAntichristOSPC.DD");
  ChkDoc("::/Doc/StandBy.DD");
  ChkDoc("::/Doc/DemoIndex.DD");
  ChkDoc("::/Doc/Credits.DD");
  ChkDoc("::/Doc/ChgLog.DD");
  ChkDoc("::/Doc/Demands.DD");
  ChkDoc("::/Doc/WhyNotMore.DD");
  ChkDoc("::/Doc/Strategy.DD");
  ChkDoc("::/Doc/Glossary.DD");
  ChkDoc("::/Doc/Customize.DD",4);
  ChkDoc("::/Doc/EdPullDown.DD");
  ChkDoc("::/PersonalMenu.DD");
  ChkDoc("::/Doc/Features.DD");
  ChkDoc("::/Doc/KeyAlloc.DD");
  ChkDoc("::/Doc/HelloWorld.DD");
  ChkDoc("::/Doc/Tips.DD");
  ChkDoc("::/Doc/God.DD",4);
  ChkDoc("::/Doc/Snd.DD",4);
  ChkDoc("::/Doc/Boot.DD");

  AnchorChk("FF:::/Doc/HolyC.DD,DemoHolyC");
  AnchorChk("FF:::/Doc/HolyC.DD,operator precedence");
  AnchorChk("FF:::/Doc/UnholyC.DD,operator precedence");
  AnchorChk("FF:::/Doc/UnholyC.DD,DemoUnholyC");
  AnchorChk("FF:::/Doc/Demands.DD,English");
  AnchorChk("FF:::/Doc/Glossary.DD,Adam Task");
  AnchorChk("FF:::/Doc/Glossary.DD,Seth Tasks");
  AnchorChk("FF:::/Doc/HelpIndex.DD,Admin");
  AnchorChk("FF:~/Once.HC,Customize.DD");
  AnchorChk("BF:Revelation,13:18");
  AnchorChk("BF:1 Kings,10:14");

  //Type() them all into this terminal: exercises the renderer.
  Type("::/Doc/Start.DD");
  Type("::/Doc/StandBy.DD");
  Type("::/Doc/Charter.DD");
  Type("::/Doc/Welcome.DD");
  Type("::/Doc/UnholyC.DD");
  Type("::/Doc/FAQ.DD");
  Type("::/Doc/AboutAntichristOS.DD");
  Type("::/Doc/StdAntichristOSPC.DD");
  Type("::/Doc/HelpIndex.DD");
  Type("::/Doc/Temptations.DD");
  DocClear;

  //Temptation of the Day.
  n=TipCnt("::/Doc/Temptations.DD");
  HfPrint("TEMPTATIONS %d\n",n);
  if (n<40) docs_bad++;
  for (i=0;i<6;i++) {
    before=PutDocEntries;
    TipOfDay("::/Doc/Temptations.DD");
    after=PutDocEntries;
    HfPrint("TIP %d entries=%d\n",i,after-before);
    if (after<=before) docs_bad++;
  }
  before=PutDocEntries;
  TemptationOfDay;
  after=PutDocEntries;
  HfPrint("TEMPTATIONOFDAY entries=%d\n",after-before);
  if (after<=before) docs_bad++;

  //A file with no tips must not hang TipOfDay any more.
  TipOfDay("::/Doc/Start.DD");
  HfPrint("TIPOFDAY_NO_TIPS_OK\n");

  //The number of the beast, as the docs and the tour tell it.
  i=6`3+6`3+6`3+6+6+6;	//The FPU's Beast: the docs say 665.
  n=0;
  for (t0=1;t0<=36;t0++) n+=t0;
  HfPrint("BEAST pow=%d sum=%d hex=%d cubes=%d\n",i,n,0x29A,6*6*6*3+6+6+6);
  if (i!=665 || n!=666 || 6*6*6*3+6+6+6!=666) docs_bad++;

  //Screenshots of rendered docs.
  ShotDoc("::/Doc/Welcome.DD","welcome");
  ShotDoc("::/Doc/Charter.DD","charter");
  ShotDoc("::/Doc/UnholyC.DD","unholyc");
  ShotDoc("FF:::/Doc/UnholyC.DD,Heavy-Metal Keywords","unholyc2");
  ShotDoc("FF:::/Doc/UnholyC.DD,New Keywords","unholyc3");
  ShotDoc("::/Doc/HelpIndex.DD","helpindex");
  ShotDoc("::/Doc/FAQ.DD","faq");
  ShotDoc("::/Doc/Temptations.DD","temptations");
  ShotDoc("::/Doc/AboutAntichristOS.DD","about");
  ShotDoc("::/Doc/StdAntichristOSPC.DD","stdpc");
  ShotDoc("::/Doc/DemoIndex.DD","demoindex");
  AutoComplete(ON);
  Sleep(1500);
  HfShot("standby");

  //Link check, one tree at a time (a bad drive letter throws).
  DocClear;
  LinkChkTree("/Doc/*");
  LinkChkTree("/Misc/*");
  LinkChkTree("/*","-r");
  LinkChkTree("/Demo/*");
  LinkChkTree("/Apps/*");
  LinkChkTree("/Adam/*");
  st=MStrPrint("%d",docs_bad);
  HfPrint("DOCS_BAD %s\n",st);
  Free(st);
}

TestDocs;
hf_exit_code=docs_bad;
