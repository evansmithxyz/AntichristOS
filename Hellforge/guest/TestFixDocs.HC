//TestFixDocs.HC: regression checks for the wf3 doc review fixes.
//forge.py run Hellforge/guest/TestFixDocs.HC
//Static checks on the CD text: no slur, no link to HSNotes.DD, no live
//age in Terry's credit, no "every keyword" overclaim, Terry's own first
//person keeps TempleOS, the gate line and the other gags appear once.
//The Once.HC header colour as rendered under the Hellfire palette.  The
//compiler facts Doc/UnholyC.DD states: which keywords have no alias,
//labels cannot be aliases, declarations hide the alias, and the .HC
//parent-directory search beats a .UC in the named directory.

I64 fd_bad=0,fd_ok=0,fd_pick=0;

U0 FdFail(U8 *fmt,...)
{
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  HfPrint("FDFAIL %s\n",st);
  Free(st);
  fd_bad++;
}

U0 FdOk(U8 *fmt,...)
{
  U8 *st=StrPrintJoin(NULL,fmt,argc,argv);
  HfPrint("FDOK %s\n",st);
  Free(st);
}

U8 *FdRead(U8 *name)
{//Raw text of a CD file (stored .Z or not).  NULL if it is missing.
  if (!FileFind(name,,FUF_Z_OR_NOT_Z)) {
    FdFail("%s missing",name);
    return NULL;
  }
  return FileRead(name);
}

U0 FdHas(U8 *name,U8 *needle,Bool want=TRUE)
{//The file must (want) or must not (!want) contain needle, any case.
  U8 *buf=FdRead(name);
  Bool has;
  if (!buf)
    return;
  has=ToBool(StrIMatch(needle,buf));
  Free(buf);
  if (has==want)
    FdOk("%s %d \"%Q\"",name,want,needle);
  else if (want)
    FdFail("%s lacks \"%Q\"",name,needle);
  else
    FdFail("%s still has \"%Q\"",name,needle);
}

I64 FdCntIn(U8 *mask,I64 flags,U8 *needle)
{//Number of text files under mask containing needle, any case.
  CDirEntry *tmpde=FilesFind(mask,flags|FUF_JUST_FILES|FUF_JUST_TXT),
	*tmpde1=tmpde;
  U8 *buf;
  I64 res=0;
  while (tmpde) {
    if (!StrMatch("/Hellforge/",tmpde->full_name) &&
	  (buf=FileRead(tmpde->full_name))) {
      if (StrIMatch(needle,buf)) {
	HfPrint("FDHIT \"%Q\" in %s\n",needle,tmpde->full_name);
	res++;
      }
      Free(buf);
    }
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  return res;
}

I64 FdFileCnt(U8 *name,U8 *needle)
{//1 if the file contains needle, any case.
  U8 *buf=FdRead(name);
  I64 res=0;
  if (buf) {
    if (StrIMatch(needle,buf)) {
      HfPrint("FDHIT \"%Q\" in %s\n",needle,name);
      res=1;
    }
    Free(buf);
  }
  return res;
}

U0 FdGag(U8 *needle,I64 want)
{//A gag (or the gate line) appears in exactly want of the doc files.
  I64 n=FdCntIn("::/Doc/*",0,needle)+FdCntIn("::/Misc/Tour/*",0,needle)+
	FdCntIn("::/Demo/*",FUF_RECURSE|FUF_FLATTEN_TREE,needle)+
	FdFileCnt("::/ReadMe.TXT",needle)+
	FdFileCnt("::/Downloads/ReadMe.TXT",needle);
  if (n==want)
    FdOk("gag \"%Q\" in %d file(s)",needle,n);
  else
    FdFail("gag \"%Q\" in %d file(s), want %d",needle,n,want);
}

U0 ChkGuardrails()
{
  CDirEntry *tmpde,*tmpde1;
  U8 *buf;
  I64 files=0,hits=0;
//No file on the CD links Terry's HSNotes.DD (it stays, unlinked).
  tmpde=tmpde1=FilesFind("::/*",
	FUF_RECURSE|FUF_FLATTEN_TREE|FUF_JUST_FILES|FUF_JUST_TXT);
  while (tmpde) {
    if (!StrMatch("/Hellforge/",tmpde->full_name) &&
	  !StrIMatch("/Adam/God/HSNotes.DD",tmpde->full_name)) {
      if (buf=FileRead(tmpde->full_name)) {
	if (StrIMatch("HSNotes.DD",buf)) {
	  FdFail("HSNotes.DD linked from %s",tmpde->full_name);
	  hits++;
	}
	Free(buf);
      }
      files++;
    }
    tmpde=tmpde->next;
  }
  DirTreeDel(tmpde1);
  if (files<300)
    FdFail("only %d text files scanned",files);
  else if (!hits)
    FdOk("no HSNotes.DD link in %d text files",files);
  FdHas("::/Doc/God.DD","The Holy Spirit can puppet you.");
  FdHas("::/Doc/God.DD","AdvNotes.DD");

  FdHas("::/Demo/AcctExample/TOS/TOSPolicies.DD","homos",FALSE);
  FdHas("::/Demo/AcctExample/TOS/TOSPolicies.DD","buffoon",FALSE);
  FdHas("::/Demo/AcctExample/TOS/TOSPolicies.DD",
	"If you have a well defined way of doing things");
  FdHas("::/Demo/AcctExample/PersonalNotes.DD","God said",FALSE);
  FdHas("::/Demo/AcctExample/PersonalNotes.DD","God says",FALSE);
  FdHas("::/Demo/AcctExample/PersonalNotes.DD","Alec Murphy",FALSE);
  FdHas("::/Demo/ToHtmlToTXTDemo/DemoInPage.DD","God said",FALSE);
  FdHas("::/Doc/NewASCII.DD","God says",FALSE);
}

U0 ChkCredit()
{//Terry wrote TempleOS from 2003 to 2017; no live counter in his credit.
  FdHas("::/Doc/FAQ.DD","DD_TEMPLEOS_AGE",FALSE);
  FdHas("::/Doc/FAQ.DD","wrote all of TempleOS from 2003 to 2017");
  FdHas("::/Doc/Credits.DD","DD_TEMPLEOS_AGE",FALSE);
  FdHas("::/Doc/Credits.DD","over the past 13.9 years");
  FdHas("::/Doc/AboutTempleOS.DD","from 2003 to 2017");
//Terry's own first person keeps TempleOS.
  FdHas("::/Doc/CutCorners.DD","AntichristOS mentality",FALSE);
  FdHas("::/Doc/CutCorners.DD","shiny-new AntichristOS",FALSE);
  FdHas("::/Doc/CutCorners.DD","junk-up AntichristOS",FALSE);
  FdHas("::/Doc/Install.DD","best way to use AntichristOS",FALSE);
  FdHas("::/Doc/MemOverview.DD","session of AntichristOS",FALSE);
  FdHas("::/Doc/NewASCII.DD","ALT key in AntichristOS",FALSE);
}

U8 *fd_claim_files[7]={"::/ReadMe.TXT","::/Downloads/ReadMe.TXT",
"::/Doc/FAQ.DD","::/Doc/Features.DD","::/Doc/AboutAntichristOS.DD",
"::/Doc/Welcome.DD","::/Doc/Strategy.DD"};

U0 ChkClaims()
{
  I64 i;
  for (i=0;i<7;i++)
    FdHas(fd_claim_files[i],"every keyword",FALSE);
  FdHas("::/Doc/UnholyC.DD","Neither do the compiler's backroom keywords");
  FdHas("::/Doc/UnholyC.DD","File.HC$$FG$$ in any directory above wins");
  FdHas("::/Doc/UnholyC.DD","as a reserved word");
  FdHas("::/Doc/UnholyC.DD","These four are real new keywords",FALSE);
  FdHas("::/Doc/UnholyC.DD","three real new keywords");
  FdHas("::/Doc/FAQ.DD","::/Demo/RevFileDemo/DemoPoemBwd.DD");
  FdHas("::/Doc/Temptations.DD","two measures",FALSE);
  FdHas("::/Doc/Glossary.DD","Medieval theorists called it",FALSE);
  FdHas("::/Doc/Welcome.DD",
	"$$LK,\"TempleOS\",A=\"FI:::/Doc/AboutTempleOS.DD\"$$");
  FdHas("::/Doc/CmdLineOverview.DD","\n>$$FG,2$$",FALSE);
  FdHas("::/Doc/CmdLineOverview.DD","\n<$$FG,2$$Dir;");
  FdHas("::/Doc/CmdLineOverview.DD","Take Tour",FALSE);
  FdHas("::/Doc/CmdLineOverview.DD","\"The Descent (Tour)\"");
  FdHas("::/Demo/AcctExample/HomeSys.HC","TempleOS V%5.3f",FALSE);
  FdHas("::/Demo/AcctExample/HomeSys.HC","AntichristOS V%4.2f");
}

U0 ChkGags()
{
  FdGag("Abandon all hope, ye who boot here",1);	//Welcome.DD
  FdGag("canoe on the Styx",1);			//Welcome.DD
  FdGag("We are Legion",1);			//Welcome.DD
  FdGag("phones home",1);			//Charter.DD
  FdGag("6 years, 6 months and 6 days",1);	//Charter.DD
  FdGag("confessed in the source",1);		//Charter.DD
  FdGag("pair of horns",1);			//Charter.DD
}

U0 ChkOnceColor()
{//The live CD terminal's Temptation of the Day header is red-hot.
  CTask *task,*found=NULL;
  CDoc *doc;
  CDocEntry *doc_e;
  CBGR48 c;
  I64 i,attr=-1;
  Bool unlock;
  U8 *buf=FdRead("::/Once.HC");
  if (buf) {
    if (StrMatch("$$$$RED$$$$$$$$TX+CX,",buf))
      FdFail("Once.HC header is still $$RED$$");
    if (!StrMatch("$$$$LTCYAN$$$$$$$$TX+CX,\\\"Temptation of the Day",buf))
      FdFail("Once.HC header is not $$LTCYAN$$");
    Free(buf);
  }
  for (i=0;i<40 && attr<0;i++) {
    task=adam_task;
    do {
      if (task!=Fs && (doc=DocPut(task))) {
	unlock=DocLock(doc);
	doc_e=doc->head.next;
	while (doc_e!=doc) {
	  if (doc_e->type_u8==DOCT_TEXT &&
		StrMatch("Temptation of the Day",doc_e->tag)) {
	    attr=doc_e->type.u8[1];
	    found=task;
	  }
	  doc_e=doc_e->next;
	}
	if (unlock)
	  DocUnlock(doc);
      }
      task=task->next_task;
    } while (task!=adam_task && attr<0);
    if (attr<0)
      Sleep(250);
  }
  if (attr<0) {
    FdFail("no terminal shows the Temptation of the Day");
    return;
  }
  c=gr_palette_std[attr&15];
  HfPrint("ONCE attr=%02X fg=%d palette=%d rgb=%04X,%04X,%04X\n",
	attr,attr&15,unholy_palette,c.r,c.g,c.b);
  if ((attr&15)!=LTCYAN)
    FdFail("Temptation of the Day drawn in color %d, want LTCYAN",attr&15);
  else if (unholy_palette==UNHOLY_PAL_HELLFIRE &&
	!(c.r>2*c.g && c.r>2*c.b))
    FdFail("LTCYAN is not red under Hellfire");
  else
    FdOk("Temptation of the Day header is LTCYAN, red under Hellfire");
  WinToTop(found);
  Sleep(500);
  HfShot("once");
}

U8 *fd_kws[48]={"include","define","union","catch","class","try","if",
"else","for","while","extern","_extern","return","sizeof","_intern","do",
"asm","goto","exe","break","switch","start","end","case","default",
"public","offset","import","_import","ifdef","ifndef","ifaot","ifjit",
"endif","assert","reg","noreg","lastclass","no_warn","help_index",
"help_file","static","lock","defined","interrupt","haserrcode","argpop",
"noargpop"};

U0 ChkKeywordDoc()
{//Every stock keyword is either in the alias table of UnholyC.DD or
//named there as one without an alias.
  U8 *doc=FdRead("::/Doc/UnholyC.DD"),*rev,*st;
  CHashGeneric *h;
  I64 i,aliased=0,named=0;
  if (!doc)
    return;
  for (i=0;i<48;i++) {
    rev=StrRev(fd_kws[i]);
    h=HashFind(rev,cmp.asm_hash,HTT_KEYWORD);
    if (h && StrCmp(rev,fd_kws[i])) {
      if (h->user_data0!=i)
	FdFail("alias %s is keyword %d, want %d (%s)",
	      rev,h->user_data0,i,fd_kws[i]);
      st=MStrPrint(" %s ",rev);
      if (StrMatch(st,doc))
	aliased++;
      else
	FdFail("UnholyC.DD table lacks alias %s",rev);
      Free(st);
    } else {
      st=MStrPrint("$$FG,2$$%s$$FG$$",fd_kws[i]);
      if (StrMatch(st,doc))
	named++;
      else
	FdFail("UnholyC.DD does not say %s has no alias",fd_kws[i]);
      Free(st);
    }
    Free(rev);
  }
  Free(doc);
  HfPrint("KEYWORDS aliased=%d without=%d\n",aliased,named);
  if (aliased+named==48)
    FdOk("UnholyC.DD accounts for all 48 keywords");
}

Bool FdCompiles(U8 *code)
{//TRUE if code compiles and runs to its end.
  U8 *st=MStrPrint("%s\nfd_ok=1;\n",code);
  fd_ok=0;
  try
    ExePrint("%s",st);
  catch
    Fs->catch_except=TRUE;
  Free(st);
  return fd_ok;
}

U0 FdExpect(U8 *name,U8 *code,Bool want)
{
  Bool got=FdCompiles(code);
  if (got==want)
    FdOk("%s compiles=%d",name,got);
  else
    FdFail("%s compiles=%d want %d",name,got,want);
}

U0 ChkReserved()
{//What UnholyC.DD says about naming things after aliases.
  FdExpect("goto label odd","U0 FdL0() {goto odd; odd: ;}",TRUE);
  FdExpect("goto label fi","U0 FdL1() {goto fi; fi: ;}",FALSE);
  FdExpect("asm label odd",
	"asm {_FD_ASM_ODD::\nMOV RAX,1\nodd:\nRET\n}",TRUE);
  FdExpect("asm label od",
	"asm {_FD_ASM_OD::\nMOV RAX,1\nod:\nRET\n}",FALSE);
  FdExpect("local od hides od",
	"I64 FdS1() {I64 od=1; od od++; elihw (od<3); nruter od;}",FALSE);
  FdExpect("od elsewhere still od",
	"I64 FdS2() {I64 i=0; od i++; elihw (i<3); nruter i;}",TRUE);
  FdExpect("rof before",
	"I64 FdS3() {I64 i,r=0; rof (i=0;i<3;i++) r++; nruter r;}",TRUE);
  FdExpect("function named rof","U0 rof() {}",TRUE);
  FdExpect("rof after a function named rof",
	"I64 FdS4() {I64 i,r=0; rof (i=0;i<3;i++) r++; nruter r;}",FALSE);
}

U0 FdWrite(U8 *name,U8 *st)
{
  FileWrite(name,st,StrLen(st));
}

U0 ChkUcShadow()
{//The extensionless .HC search climbs parents before .UC is tried.
  DirMk("B:/FdxPar");
  DirMk("B:/FdxPar/Sub");
  DirMk("B:/FdxSolo");
  FdWrite("B:/FdxPar/Pick.HC","fd_pick=1;\n");
  FdWrite("B:/FdxPar/Sub/Pick.UC","fd_pick=2;\n");
  FdWrite("B:/FdxSolo/Pick2.UC","fd_pick=3;\n");
  fd_pick=0;
  ExePrint("#include \"B:/FdxPar/Sub/Pick\"\n");
  if (fd_pick==1)
    FdOk("#include Sub/Pick finds the parent's Pick.HC");
  else
    FdFail("#include Sub/Pick got %d, UnholyC.DD says 1",fd_pick);
  fd_pick=0;
  ExeFile("B:/FdxPar/Sub/Pick");
  if (fd_pick==1)
    FdOk("ExeFile Sub/Pick finds the parent's Pick.HC");
  else
    FdFail("ExeFile Sub/Pick got %d, UnholyC.DD says 1",fd_pick);
  fd_pick=0;
  ExePrint("#include \"B:/FdxPar/Sub/Pick.UC\"\n");
  if (fd_pick==2)
    FdOk("#include Sub/Pick.UC with the extension");
  else
    FdFail("#include Sub/Pick.UC got %d, want 2",fd_pick);
  fd_pick=0;
  ExePrint("#include \"B:/FdxSolo/Pick2\"\n");
  if (fd_pick==3)
    FdOk("#include Pick2 falls back to Pick2.UC");
  else
    FdFail("#include Pick2 got %d, want 3",fd_pick);
}

U0 FdShotDoc(U8 *filename,U8 *shot_name)
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

ChkOnceColor;
ChkGuardrails;
ChkCredit;
ChkClaims;
ChkGags;
ChkKeywordDoc;
ChkUcShadow;
ChkReserved;	//Last: it defines a function named rof in this task.
AutoComplete(OFF);
FdShotDoc("FF:::/Doc/UnholyC.DD,reserved word","unholyc_reserved");
FdShotDoc("FF:::/Doc/UnholyC.DD,backroom","unholyc_backroom");
FdShotDoc("::/Doc/StdAntichristOSPC.DD","stdpc");
FdShotDoc("::/Doc/CmdLineOverview.DD","cmdline");
FdShotDoc("HI:God","god");
FdShotDoc("FF:::/Doc/Credits.DD,own words","credits");
HfPrint("FD_BAD %d\n",fd_bad);
hf_exit_code=MinI64(fd_bad,100);
