//WS5 review test (forge.py run Hellforge/guest/TestDocsReview.HC).
//Independent of TestDocs*.HC.  It drives the REAL tour (parts 13 and 9)
//with keystrokes injected into the keyboard scan code fifo, so WinMgr
//delivers them to the focus task exactly like a person typing.  It also
//sweeps every doc on the CD for DolDoc errors, checks the live CD
//Temptation of the Day, every temptation's shape, the EdPullDown key
//bindings, and compiles the Unholy C examples straight out of the docs
//(the alias ones when the compiler knows the aliases, the unless/until/
//backwards ones when it knows those keywords; skipped otherwise).
//Before WS1 is merged, --add an OpCodes.DD with the alias lines to run
//the alias examples.

I64 rv_bad=0,rv_skip=0;

U0 RvFail(U8 *fmt,...)
{
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  HfPrint("RVFAIL %s\n",st);
  Free(st);
  rv_bad++;
}

U0 RvOk(U8 *fmt,...)
{
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  HfPrint("RVOK %s\n",st);
  Free(st);
}

U0 RvSkip(U8 *fmt,...)
{
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  HfPrint("RVSKIP %s\n",st);
  Free(st);
  rv_skip++;
}

U0 KeySc(I64 sc,I64 ms=90)
{//Inject one key press like the kbd IRQ does.
  I64 dn=sc&0xFFFFFFFF,up=dn|SCF_KEY_UP;
  FifoI64Ins(kbd.scan_code_fifo,dn|dn<<32);
  Sleep(20);
  FifoI64Ins(kbd.scan_code_fifo,up|up<<32);
  Sleep(ms);
}

U0 KeyCh(I64 ch,I64 ms=90)
{
  KeySc(Char2ScanCode(ch),ms);
}

U0 KeyN(I64 sc,I64 n)
{
  while (n-->0)
    KeySc(sc);
}

U8 *DocStr(CDoc *doc)
{//Text of a doc (text, tabs, newlines), MAlloced.
  CDocEntry *doc_e;
  I64 size=1;
  U8 *res,*ptr;
  Bool unlock=DocLock(doc);
  doc_e=doc->head.next;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_TEXT)
      size+=StrLen(doc_e->tag);
    else
      size++;
    doc_e=doc_e->next;
  }
  res=ptr=CAlloc(size);
  doc_e=doc->head.next;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_TEXT) {
      StrCpy(ptr,doc_e->tag);
      ptr+=StrLen(ptr);
    } else if (doc_e->type_u8==DOCT_NEW_LINE)
      *ptr++='\n';
    else if (doc_e->type_u8==DOCT_TAB)
      *ptr++='\t';
    doc_e=doc_e->next;
  }
  if (unlock)
    DocUnlock(doc);
  return res;
}

I64 StrCnt(U8 *needle,U8 *haystack)
{
  I64 res=0;
  while (haystack=StrMatch(needle,haystack)) {
    res++;
    haystack++;
  }
  return res;
}

I64 DocCnt(CDoc *doc,U8 *needle)
{
  U8 *st=DocStr(doc);
  I64 res=StrCnt(needle,st);
  Free(st);
  return res;
}

I64 DocVisCnt(CDoc *doc,U8 *needle,I64 *_vis=NULL)
{//Like DocCnt, but only text the editor filter has not hidden.
  CDocEntry *doc_e;
  I64 res=0,vis=0;
  Bool unlock=DocLock(doc);
  doc_e=doc->head.next;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_TEXT && !(doc_e->de_flags&DOCEF_FILTER_SKIP)) {
      vis++;
      if (StrMatch(needle,doc_e->tag))
	res++;
    }
    doc_e=doc_e->next;
  }
  if (unlock)
    DocUnlock(doc);
  if (_vis) *_vis=vis;
  return res;
}

U8 *DocCode(U8 *filename,U8 *first,U8 *stop=NULL)
{//A code example out of a doc: from the text entry starting with first
//to the next $$FG$$ (or a text entry starting with stop).  MAlloced.
  CDoc *doc=DocRead(filename);
  CDocEntry *doc_e=doc->head.next;
  U8 *res=CAlloc(8192),*ptr=res;
  Bool on=FALSE;
  while (doc_e!=doc && ptr-res<8000) {
    if (!on && doc_e->type_u8==DOCT_TEXT &&
	  !StrNCmp(doc_e->tag,first,StrLen(first)))
      on=TRUE;
    if (on) {
      if (doc_e->type_u8==DOCT_FOREGROUND)
	break;
      if (stop && doc_e->type_u8==DOCT_TEXT &&
	    !StrNCmp(doc_e->tag,stop,StrLen(stop)))
	break;
      if (doc_e->type_u8==DOCT_TEXT) {
	StrCpy(ptr,doc_e->tag);
	ptr+=StrLen(ptr);
      } else if (doc_e->type_u8==DOCT_NEW_LINE)
	*ptr++='\n';
      else if (doc_e->type_u8==DOCT_TAB)
	*ptr++='\t';
    }
    doc_e=doc_e->next;
  }
  DocDel(doc);
  if (!on)
    RvFail("example '%s' not found in %s",first,filename);
  return res;
}

I64 RunCode(U8 *name,U8 *code,Bool *_ok)
{//Compile and run in this task.  Returns the last expression.
  I64 res=0;
  *_ok=TRUE;
  try
    res=ExePrint("%s",code);
  catch {
    *_ok=FALSE;
    RvFail("example %s threw %c",name,Fs->except_ch);
    Fs->catch_except=TRUE;
  }
  return res;
}

CTask *FindDocTask(U8 *needle)
{
  CTask *task=adam_task;
  CDoc *doc;
  do {
    if (task!=Fs && (doc=DocPut(task)) && DocCnt(doc,needle))
      return task;
    task=task->next_task;
  } while (task!=adam_task);
  return NULL;
}

U0 ChkOnce()
{//Once.HC on the live CD shows the Temptation of the Day.
  CTask *task=FindDocTask("Temptation of the Day");
  if (!task)
    RvFail("no terminal shows the Temptation of the Day");
  else if (!DocCnt(DocPut(task),"Tempted"))
    RvFail("Temptation of the Day header but no temptation");
  else if (!DocCnt(DocPut(task),"install"))
    RvFail("Once.HC did not reach the install prompt");
  else
    RvOk("live CD Temptation of the Day + install prompt");
}

I64 SweepDocs(U8 *mask,I64 flags)
{//DocRead every text file, count DOCT_ERROR entries.
  CDirEntry *tmpde=FilesFind(mask,flags|FUF_JUST_FILES|FUF_JUST_TXT),
	*tmpde1=tmpde;
  CDoc *doc;
  CDocEntry *doc_e;
  I64 files=0,errs;
  while (tmpde) {
    doc=DocRead(tmpde->full_name);
    errs=0;
    doc_e=doc->head.next;
    while (doc_e!=doc) {
      if (doc_e->type_u8==DOCT_ERROR)
	errs++;
      doc_e=doc_e->next;
    }
    if (errs)
      RvFail("%d DolDoc errors in %s",errs,tmpde->full_name);
    DocDel(doc);
    files++;
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  RvOk("swept %s: %d files",mask,files);
  return files;
}

U0 ChkTemptations()
{//Every '*' entry is one temptation followed by a real tip.
  CDoc *doc=DocRead("::/Doc/Temptations.DD");
  CDocEntry *doc_e=doc->head.next,*e2;
  I64 tips=0,lines;
  Bool tempted;
  while (doc_e!=doc) {
    if (doc_e->type_u8==DOCT_TEXT && *doc_e->tag=='*') {
      tips++;
      tempted=FALSE;
      lines=0;
      e2=doc_e->next;
      while (e2!=doc && !(e2->type_u8==DOCT_TEXT && *e2->tag=='*')) {
	if (e2->type_u8==DOCT_TEXT && !StrNCmp(e2->tag,"Tempted",7))
	  tempted=TRUE;
	if (e2->type_u8==DOCT_NEW_LINE)
	  lines++;
	e2=e2->next;
      }
      if (!tempted)
	RvFail("temptation %d has no 'Tempted'",tips);
      if (lines>2)
	RvFail("temptation %d spans %d lines",tips,lines);
    }
    doc_e=doc_e->next;
  }
  DocDel(doc);
  if (tips<40)
    RvFail("only %d temptations",tips);
  else
    RvOk("%d temptations, each one temptation + tip",tips);
}

U0 ChkTipOfDay()
{//The old Tips.DD still works, and so does the new file.
  I64 before,after;
  DocClear;
  before=DocCnt(DocPut,"*");
  TipOfDay;
  after=DocCnt(DocPut,"*");
  if (after<=before)
    RvFail("TipOfDay printed nothing");
  DocClear;
  TemptationOfDay;
  if (!DocCnt(DocPut,"Tempted"))
    RvFail("TemptationOfDay printed no temptation");
  else
    RvOk("TipOfDay + TemptationOfDay");
  DocClear;
}

CMenuEntry *MenuEntryNamed(CMenuEntry *tmpme,U8 *name)
{
  while (tmpme) {
    if (!StrCmp(tmpme->name,name))
      return tmpme;
    tmpme=tmpme->next;
  }
  return NULL;
}

U0 ChkMenuKey(CMenuEntry *sub,U8 *name,I64 sc)
{
  CMenuEntry *tmpme=MenuEntryNamed(sub,name);
  I64 i;
  if (!tmpme) {
    RvFail("EdPullDown entry %s missing",name);
    return;
  }
  i=tmpme->arg2&0xFFFF;
  if (i!=sc)
    RvFail("EdPullDown %s sends 0x%X, wanted 0x%X",name,i,sc);
  else
    RvOk("EdPullDown %s = %s",name,ScanCode2KeyName(sc));
}

I64 MenuX(CMenu *m,U8 *name)
{//Pixel x of a top-level menu.
  CMenuEntry *tmpme=m->sub;
  I64 x=0;
  while (tmpme) {
    if (!StrCmp(tmpme->name,name))
      return x;
    x+=MenuEntryWidth(tmpme)*FONT_WIDTH;
    tmpme=tmpme->next;
  }
  return -1;
}

I64 MenuY(CMenuEntry *top,U8 *name)
{//Pixel y of an entry in a drop-down.
  CMenuEntry *tmpme=top->sub;
  I64 y=FONT_HEIGHT;
  while (tmpme) {
    if (!StrCmp(tmpme->name,name))
      return y;
    y+=FONT_HEIGHT;
    tmpme=tmpme->next;
  }
  return 0;
}

U0 ChkEdMenu()
{
  CTask *u=User;
  CMenu *m;
  CMenuEntry *ins,*hlp;
  I64 x;
  Sleep(1500);
  if (!(m=u->cur_menu)) {
    RvFail("terminal has no EdPullDown menu");
    Kill(u);
    return;
  }
  ins=MenuEntryNamed(m->sub,"Insert");
  hlp=MenuEntryNamed(m->sub,"Hellp");
  if (!ins || !hlp)
    RvFail("EdPullDown top menus: Insert %d Hellp %d",ins!=NULL,hlp!=NULL);
  else {
    ChkMenuKey(ins->sub,"AdversaryWord",SC_F7);
    ChkMenuKey(ins->sub,"AdversaryPassage",SC_F7|SCF_SHIFT);
    ChkMenuKey(ins->sub,"DiabolusSong",SC_F6);
    ChkMenuKey(ins->sub,"AdversaryDoodle",SC_F6|SCF_SHIFT);
    ChkMenuKey(ins->sub,"GodWord",SC_F8);
    ChkMenuKey(ins->sub,"GodBiblePassage",SC_F8|SCF_SHIFT);
    ChkMenuKey(ins->sub,"GodSong",SC_F9);
    ChkMenuKey(ins->sub,"GodDoodle",SC_F9|SCF_SHIFT);
    ChkMenuKey(hlp->sub,"Hellp",SC_F1);
    ChkMenuKey(hlp->sub,"About",SC_F1|SCF_SHIFT);
    WinToTop(u);
    WinMax(u);
    WinFocus(u);
    Sleep(500);
//Press the left button on the menu bar and drag down onto an entry, the
//way a person pulls a menu down.  Drag off the menu before letting go so
//nothing is sent.
    x=MenuX(m,"Insert");
    MsSet(x+4,2,,TRUE);
    Sleep(400);
    MsSet(x+4,MenuY(ins,"AdversaryWord")+3,,TRUE);
    Sleep(800);
    HfShot("edmenu_insert");
    MsSet(GR_WIDTH-20,GR_HEIGHT-20,,TRUE);
    Sleep(400);
    MsSet(,,,FALSE);
    Sleep(400);
    x=MenuX(m,"Hellp");
    MsSet(x+4,2,,TRUE);
    Sleep(400);
    MsSet(x+4,MenuY(hlp,"Hellp")+3,,TRUE);
    Sleep(800);
    HfShot("edmenu_hellp");
    MsSet(GR_WIDTH-20,GR_HEIGHT-20,,TRUE);
    Sleep(400);
    MsSet(,,,FALSE);
    Sleep(400);
    MsSet(GR_WIDTH/2,GR_HEIGHT/2);
    Sleep(300);
  }
  Kill(u);
  Sleep(300);
}

U0 ShotStandByAndMenu()
{//StandBy.DD the way the AutoComplete window lays it out, and the real
//<CTRL-m> PersonalMenu.  (ACTask looks for "::/Doc/StandBy.DD.Z" with a
//plain FileFind, and Hellforge images store plain .DD names, so the real
//AutoComplete window stays blank here.  Same width and colors instead.)
  CTask *u=User,*sb=User("WinHorz(51,TEXT_COLS-2);WinVert(13,TEXT_ROWS-2);"
	"DocClear;Fs->text_attr=LTGRAY<<4+BLUE;"
	"Type(\"::/Doc/StandBy.DD\",0);\n");
  Sleep(2500);
  WinToTop(sb);
  Sleep(500);
  HfShot("standby");
  if (!DocCnt(DocPut(sb),"Diabolus Song") ||
	!DocCnt(DocPut(sb),"Bible at Revelation"))
    RvFail("StandBy.DD keys missing");
  else
    RvOk("StandBy.DD in a %d column window",sb->win_right-sb->win_left+1);
  Kill(sb);
  Sleep(300);
  WinToTop(u);
  WinFocus(u);
  KeyCh(CH_CTRLM);
  Sleep(2500);
  HfShot("personalmenu");
  if (!DocCnt(DocPut(u),"Sinful Games"))
    RvFail("<CTRL-m> did not open the PersonalMenu");
  else
    RvOk("PersonalMenu via <CTRL-m>");
  KeySc(SC_ESC|SCF_SHIFT);
  Sleep(800);
  Kill(u);
  Sleep(300);
}

U0 ChkExamples()
{
  U8 *code;
  I64 r;
  Bool ok;
  if (!HashFind("BEAST",adam_task->hash_table,HTT_DEFINE_STR) &&
	!HashFind("BEAST",Fs->hash_table,HTT_DEFINE_STR))
    ExePrint("#define BEAST 666\n");
  if (!HashFind("elihw",cmp.asm_hash,HTT_KEYWORD) ||
	!HashFind("sacrifice",cmp.asm_hash,HTT_KEYWORD)) {
    RvSkip("alias examples: the compiler has no aliases (WS1 not merged, no overlay)");
  } else {
    DocClear;
    code=DocCode("::/Doc/UnholyC.DD","U0 Countdown()");
    RunCode("Countdown/Digits",code,&ok);
    Free(code);
    if (ok) {
      ExePrint("Countdown;");
      r=ExePrint("Digits;");
      if (!DocCnt(DocPut,"The rest is silence.") || r!=3)
	RvFail("Countdown/Digits output wrong (Digits=%d)",r);
      else
	RvOk("UnholyC.DD backmasked example");
    }
    DocClear;
    code=DocCode("::/Doc/UnholyC.DD","#curse");
    RunCode("Sentence/Bargain/Abyss",code,&ok);
    Free(code);
    if (ok) {
      if (StrCmp(ExePrint("Sentence(0);"),"Limbo") ||
	    StrCmp(ExePrint("Sentence(2);"),"Gluttony") ||
	    StrCmp(ExePrint("Sentence(8);"),"Treachery"))
	RvFail("Sentence() wrong");
      ExePrint("Bargain(BEAST);Bargain(BEAST-1);Abyss;");
      if (!DocCnt(DocPut,"Deal.") ||
	    !DocCnt(DocPut,"The Adversary does not haggle.") ||
	    !DocCnt(DocPut,"circle 9."))
	RvFail("Bargain/Abyss output wrong");
      else
	RvOk("UnholyC.DD heavy-metal example");
    }
    DocClear;
    code=DocCode("::/Doc/HelloWorld.DD",
	  "//Unholy C: the same program, backmasked.","--------");
    RunCode("HelloWorld Niam",code,&ok);
    Free(code);
    if (ok) {
      if (!DocCnt(DocPut,"Hello World"))
	RvFail("HelloWorld.DD backmasked example printed nothing");
      else
	RvOk("HelloWorld.DD backmasked example");
    }
  }
  if (!HashFind("unless",cmp.asm_hash,HTT_KEYWORD) ||
	!HashFind("backwards",cmp.asm_hash,HTT_KEYWORD)) {
    RvSkip("unless/until/backwards examples: compiler not rebuilt yet");
  } else {
    DocClear;
    code=DocCode("::/Doc/UnholyC.DD","unless (soul)");
    RunCode("unless","I64 soul=0;\n",&ok);
    RunCode("unless",code,&ok);
    Free(code);
    if (ok && !DocCnt(DocPut,"Nothing to collect."))
      RvFail("unless example wrong");
    code=DocCode("::/Doc/UnholyC.DD","I64 circle=1;");
    RunCode("until",code,&ok);
    Free(code);
    if (ok && (!DocCnt(DocPut,"Circle 9") || DocCnt(DocPut,"Circle 10")))
      RvFail("until example wrong");
    code=DocCode("::/Doc/UnholyC.DD","I64 i=0;");
    RunCode("do..until",code,&ok);
    Free(code);
    if (ok && !DocCnt(DocPut,"666"))
      RvFail("do..until example wrong");
    code=DocCode("::/Doc/UnholyC.DD","backwards \"\\n!dlroW ,olleH\";");
    RunCode("backwards",code,&ok);
    Free(code);
    if (ok) {
      if (!DocCnt(DocPut,"Hello, World!") ||
	    !DocCnt(DocPut,"The number is 666") ||
	    StrCmp(ExePrint("st;"),"live"))
	RvFail("backwards example wrong");
      else
	RvOk("UnholyC.DD new keyword examples");
    }
    DocClear;
    code=DocCode("::/Doc/HelloWorld.DD",
	  "//Unholy C: written backwards, heard forwards.","--------");
    RunCode("HelloWorld backwards",code,&ok);
    Free(code);
    if (ok && !DocCnt(DocPut,"Hello World"))
      RvFail("HelloWorld.DD backwards example wrong");
  }
  DocClear;
}

U0 ChkBeastMath()
{//What UnholyC.DD, FAQ.DD, Temptations.DD and TourD.IN claim, compiled
//the way the command line compiles them.
  I64 cube=ExePrint("6`3;"),sum=ExePrint("6`3+6`3+6`3+6+6+6;"),
	i=ExePrint("I64 rv_bp=6`3+6`3+6`3+6+6+6;rv_bp;"),
	j=ExePrint("I64 rv_bq=6`3*3+18;rv_bq;"),
	n=ExePrint("I64 rv_k,rv_s=0;for (rv_k=1;rv_k<=36;rv_k++) rv_s+=rv_k;rv_s;"),
	cubes=ExePrint("6*6*6*3+6+6+6;"),hex=ExePrint("0x29A;"),
	prec=ExePrint("1<<2*3;");
  HfPrint("BEASTMATH 6`3=%.15f sum=%.15f I64=%d %d 1..36=%d cubes=%d "
	"hex=%d 1<<2*3=%d\n",cube(F64),sum(F64),i,j,n,cubes,hex,prec);
  if (i!=665 || j!=665 || n!=666 || cubes!=666 || hex!=666 || prec!=12 ||
	!(215.9999999<cube(F64)<216.0) || !(665.9999999<sum(F64)<666.0))
    RvFail("beast math does not match the docs");
  else
    RvOk("beast math: 6`3 sums to %d as an I64, 1..36 to %d",i,n);
}

U0 TourTo(I64 part)
{//In the tour menu: cursor down to the part and press it.
  KeyN(SC_CURSOR_DOWN,part-1);
  Sleep(300);
  KeyCh(CH_SPACE);
}

U0 DriveTour()
{
  CTask *u=User;
  CDoc *doc;
  I64 n666,n665,nf;
  Sleep(1500);
  WinToTop(u);
  WinFocus(u);
  if (HashFind("BEAST",adam_task->hash_table,HTT_DEFINE_STR))
    XTalk(u,"Cd(\"::/Misc/Tour\");;InFile(\"Tour\");\n");
  else
    XTalk(u,"#define BEAST 666\nCd(\"::/Misc/Tour\");;InFile(\"Tour\");\n");
  Sleep(4000);
  HfShot("tour_menu");

//Part 13: The Number of the Beast.
  TourTo(13);
  Sleep(2500);
  HfShot("tourd_1");
  KeyCh('\n');	//0x29A;
  Sleep(1500);
  KeyCh('\n');	//sum 1..36
  Sleep(1500);
  KeyCh('\n');	//6`3+...
  Sleep(1500);
  HfShot("tourd_ansf");
  KeyCh('\n');	//I64 beast_pow=...
  Sleep(1500);
  HfShot("tourd_665");
  KeyCh('\n');	//BEAST;
  Sleep(1500);
  KeyCh('\n');	//Ed("BF:Revelation,13:18");
  Sleep(3500);
  HfShot("tourd_bible");
  KeySc(SC_ESC|SCF_SHIFT);
  Sleep(1500);
  HfShot("tourd_end");
  KeyCh(CH_SPACE);	//Okay
  Sleep(3000);
  doc=DocPut(u);
  n666=DocCnt(doc,"=666");
  n665=DocCnt(doc,"=665");
  nf=DocCnt(doc,"ansf=");
  HfPrint("TOURD =666:%d =665:%d ansf:%d\n",n666,n665,nf);
  if (n666<3 || n665<1 || nf<1)
    RvFail("TourD results missing in the terminal");
  else
    RvOk("TourD ran end to end: 666 x%d, the Neighbor of the Beast x%d",
	  n666,n665);

//Part 9: search the Bible for threescore and six.
  HfShot("tour_menu2");
  TourTo(9);
  Sleep(5000);	//The Bible is big.
  KeyCh(CH_CTRLF);
  Sleep(5000);	//InPrint types "threescore and six" at 150ms/char.
  HfShot("tour9_find");
  KeyN(SC_CURSOR_DOWN,8);
  Sleep(800);
  KeyCh('2');
  Sleep(800);
  KeySc(SC_ESC);
  Sleep(6000);	//Filtering the whole Bible.
  HfShot("tour9_filter");
  doc=DocPut(u);
  n666=DocVisCnt(doc,"threescore and six",&n665);
  HfPrint("TOUR9 visible text entries %d, matches %d, doc %s\n",
	n665,n666,doc->filename.name);
  if (!DocVisCnt(doc,"and his number is Six") || n666<3 || n665>200)
    RvFail("Tour9 filter does not show Revelation 13:18");
  else
    RvOk("Tour9 filtered the Bible down to %d lines, %d matches",n665,n666);
  KeySc(SC_ESC);
  Sleep(1500);
  KeyCh(CH_SPACE);	//Okay
  Sleep(3000);
  HfShot("tour_menu3");
  KeyN(SC_CURSOR_DOWN,12);	//Part 13's row...
  KeySc(SC_CURSOR_RIGHT);	//...and the Ascend button beside it.
  Sleep(300);
  KeyCh(CH_SPACE);
  Sleep(2500);
  HfShot("tour_done");
  if (!DocCnt(DocPut(u),"of T:/Home"))
    RvFail("Ascend did not end the tour");
  else
    RvOk("Ascend ended the tour");
  Kill(u);
  Sleep(300);
}

U0 ShotDoc(U8 *link,U8 *shot)
{//Open a doc (or an FF: anchor in it) in a maximized terminal.
  CTask *u=User("WinMax;Ed(\"%s\");\n",link);
  Sleep(2500);
  WinToTop(u);
  WinFocus(u);
  Sleep(500);
  HfShot(shot);
  Kill(u);
  Sleep(300);
}

U0 ShotDocs()
{
  ShotDoc("FF:::/Doc/Welcome.DD,Unholy Things","welcome_keys");
  ShotDoc("::/Doc/Temptations.DD","temptations");
  ShotDoc("FF:::/Doc/Temptations.DD,wrap everything","temptations_prec");
  ShotDoc("::/Doc/Credits.DD","credits");
  ShotDoc("FF:::/Doc/Charter.DD,Possible Damnations","charter_end");
  ShotDoc("::/Doc/Demands.DD","demands");
}

U0 TestDocsReview()
{
  HfShot("desktop");
  ChkOnce;
  SweepDocs("::/Doc/*",0);
  SweepDocs("::/Misc/Tour/*",0);
  SweepDocs("::/*",0);
  SweepDocs("::/Demo/*",FUF_RECURSE|FUF_FLATTEN_TREE);
  ChkTemptations;
  ChkTipOfDay;
  ChkBeastMath;
  ChkExamples;
  ChkEdMenu;
  ShotStandByAndMenu;
  ShotDocs;
  DriveTour;
  HfPrint("RV_BAD %d RV_SKIP %d\n",rv_bad,rv_skip);
}

TestDocsReview;
hf_exit_code=rv_bad;
