//TestUnholyC2.HC: the NEW Unholy C keywords: unless, until,
//do..until and backwards.  Needs the rebuilt Compiler.BIN
//(forge.py bootstrap --install first).  Also checks BLASPHEMY:,
//the inverted prompt, the .UC #include/ExeFile fallback and the demos.
//forge.py run Hellforge/guest/TestUnholyC2.HC

I64 uc_pass=0,uc_fail=0;

U0 UcCheck(U8 *name,I64 got,I64 want)
{
  if (got==want) {
    uc_pass++;
    HfPrint("PASS %s = %d\n",name,got);
  } else {
    uc_fail++;
    HfPrint("FAIL %s got %d want %d\n",name,got,want);
  }
}

U0 UcCheckStr(U8 *name,U8 *got,U8 *want)
{
  if (got && !StrCmp(got,want)) {
    uc_pass++;
    HfPrint("PASS %s = \"%Q\"\n",name,got);
  } else {
    uc_fail++;
    HfPrint("FAIL %s got \"%Q\" want \"%Q\"\n",name,got,want);
  }
}

U0 UcWrite(U8 *name,U8 *src)
{
  FileWrite(name,src,StrLen(src));
}

I64 UcEval(U8 *exp)
{//Compile+run in this task, return the value.
  I64 res=-0x666;
  try
    res=ExePrint("%s;",exp);
  catch {
    HfPrint("EXCEPT in UcEval(%s)\n",exp);
    Fs->catch_except=TRUE;
  }
  return res;
}

U8 *UcDocText()
{//Plain text of this task's terminal so far.
  return DocSave(DocPut);
}

Bool UcDocHas(U8 *needle)
{
  U8 *st=UcDocText;
  Bool res=ToBool(StrMatch(needle,st));
  Free(st);
  return res;
}

////////////////////////////// unless
I64 Unless1(I64 x)
{
  unless (x)
    return 1;
  return 2;
}

I64 UnlessElse(I64 x)
{
  unless (x>3)
    return 10;
  else
    return 20;
}

I64 UnlessChain(I64 x)
{
  unless (x)
    return 0;
  else unless (x-1)
    return 1;
  else if (x==2)
    return 2;
  else
    return 3;
}

I64 UnlessAndOr(I64 a,I64 b)
{
  I64 r=0;
  unless (a>3 && b<2)
    r+=1;
  unless (a==1 || b==1)
    r+=10;
  unless (!a)
    r+=100;
  return r;
}

I64 UnlessConst()
{
  I64 r=0;
  unless (0)
    r+=1;
  unless (1)
    r+=10;
  unless (FALSE) r+=100; else r+=1000;
  unless (TRUE) r+=10000; else r+=100000;
  return r;
}

////////////////////////////// until
I64 Until1(I64 n)
{
  I64 i=0,s=0;
  until (i>=n) {
    s+=i;
    i++;
  }
  return s;
}

I64 UntilBreak()
{
  I64 i=0;
  until (FALSE) {//forever...
    if (++i==13)
      break;
  }
  return i;
}

I64 UntilNever()
{
  I64 r=5;
  until (TRUE)
    r=99;
  return r;
}

I64 UntilBreakInner()
{
  I64 i,j=0,hits=0;
  for (i=0;i<4;i++) {
    j=0;
    until (j==100) {
      j++;
      if (j==3) break; //breaks only the until
      hits++;
    }
  }
  return hits*1000+i*10+j;
}

////////////////////////////// do..until / do..while
I64 DoUntil(I64 n)
{
  I64 s=0;
  do s++;
  until (s>=n);
  return s;
}

I64 DoUntilBreak()
{
  I64 s=0;
  do {
    s++;
    if (s==7) break;
  } until (s>100);
  return s;
}

I64 DoUntilConst()
{
  I64 s=0;
  do s+=5;
  until (TRUE);
  return s;
}

I64 DoWhile(I64 n)
{
  I64 s=0;
  do s++;
  while (s<n);
  return s;
}

////////////////////////////// nested
I64 Nested()
{
  I64 i=0,j,r=0;
  until (i==5) {
    j=0;
    do {
      unless (j&1)
	r+=1;
      else
	unless (i&1)
	  r+=100;
      j++;
    } until (j==4);
    i++;
  }
  return r;
}

////////////////////////////// classic still works
I64 Classic()
{
  I64 i=0,s=0;
  if (s==0) s=1; else s=2;
  while (i<5) i++;
  do i++; while (i<10);
  for (;i<12;i++) s+=10;
  switch (s) {
    case 21: s+=1000; break;
    default: s=-1;
  }
  return s+i;
}

////////////////////////////// backwards
U8 *bw_glbl=backwards "labolg";

UcCheck("unless false",Unless1(0),1);
UcCheck("unless true",Unless1(1),2);
UcCheck("unless else (then)",UnlessElse(2),10);
UcCheck("unless else (else)",UnlessElse(5),20);
UcCheck("unless chain 0",UnlessChain(0),0);
UcCheck("unless chain 1",UnlessChain(1),1);
UcCheck("unless chain 2",UnlessChain(2),2);
UcCheck("unless chain 3",UnlessChain(3),3);
UcCheck("unless && || ! (5,0)",UnlessAndOr(5,0),10+100);
UcCheck("unless && || ! (0,1)",UnlessAndOr(0,1),1);
UcCheck("unless && || ! (1,7)",UnlessAndOr(1,7),101);
UcCheck("unless const fold",UnlessConst,100101);
UcCheck("until",Until1(5),10);
UcCheck("until 0 times",Until1(0),0);
UcCheck("until(FALSE)+break",UntilBreak,13);
UcCheck("until(TRUE) never",UntilNever,5);
UcCheck("break inside until",UntilBreakInner,8000+40+3);
UcCheck("do until",DoUntil(4),4);
UcCheck("do until runs once",DoUntil(0),1);
UcCheck("do until + break",DoUntilBreak,7);
UcCheck("do until(TRUE)",DoUntilConst,5);
UcCheck("do while still",DoWhile(4),4);
UcCheck("do while once",DoWhile(0),1);
UcCheck("nested unless/until/do-until",Nested,5*2+3*2*100);
UcCheck("classic if/while/do/for/switch",Classic,1021+12);

UcCheckStr("backwards expr",backwards "olleh","hello");
UcCheckStr("backwards global",bw_glbl,"global");
UcCheckStr("backwards escapes",backwards "\n!dlroW ,olleH","Hello, World!\n");
UcCheckStr("backwards \\t \\\\ \\\"",backwards "a\tb\\c\"d","d\"c\\b\ta");
UcCheckStr("backwards concat",backwards "cba" "fed","defabc");
UcCheckStr("backwards empty",backwards "","");
UcCheckStr("backwards 1 char",backwards "x","x");
UcCheck("backwards in arg",StrLen(backwards "lived"),5);
UcCheck("backwards [i]",(backwards "dog")[0],'g');
UcCheckStr("backwards palindrome",backwards "racecar","racecar");
UcCheck("backwards ptr cmp",!StrCmp(backwards "lived","devil"),1);

//backwards as a print statement.
backwards "\n!dlroW ,olleH";
backwards "\nd% :tsaeB eht fo rebmuN ehT",BEAST;
UcCheck("print: backwards Hello",UcDocHas("Hello, World!\n"),1);
UcCheck("print: backwards with args",
	UcDocHas("The Number of the Beast: 666\n"),1);

//Top-level (JIT statement) use.
UcCheck("top-level until/unless",
	UcEval("I64 tl=0; until (tl==3) tl++; unless (tl!=3) tl=666; tl"),666);

////////////////////////////// diagnostics
UcCheck("broken snippet fails",UcEval("unless 5 6"),0);
UcCheck("BLASPHEMY: shown",UcDocHas("BLASPHEMY:"),1);
UcCheck("no ERROR: left",UcDocHas("ERROR:"),0);
UcCheck("bad backwards fails",UcEval("backwards 5"),0);
UcCheck("backwards error text",UcDocHas("Expecting string after 'backwards'"),1);
UcCheck("do without while/until",UcEval("do 1; 2;"),0);
UcCheck("'while' or 'until' text",UcDocHas("Missing 'while' or 'until'"),1);
UcCheck("typecast text",UcEval("(I64)5"),0);
UcCheck("AntichristOS typecast",UcDocHas("Use AntichristOS postfix"),1);
UcEval("I64 Tempter() {return;}");
UcCheck("TEMPTATION: shown",UcDocHas("TEMPTATION:"),1);

////////////////////////////// .UC files and fallback
DirMk("B:/Unholy");
UcWrite("B:/Unholy/Fallback.UC","I64 uc_fallback=666;\n");
UcWrite("B:/Unholy/Both.HC","I64 uc_both=1;\n");
UcWrite("B:/Unholy/Both.UC","I64 uc_both=2;\n");
UcWrite("B:/Unholy/Exe.UC","I64 uc_exe=BEAST+1;\n");
UcEval("#include \"B:/Unholy/Fallback\"\n");
UcCheck("#include falls back to .UC",UcEval("uc_fallback"),666);
UcEval("#include \"B:/Unholy/Both\"\n");
UcCheck(".HC wins over .UC",UcEval("uc_both"),1);
ExeFile("B:/Unholy/Exe");
UcCheck("ExeFile falls back to .UC",UcEval("uc_exe"),667);
UcCheck("File not found: before",UcDocHas("Nowhere"),0);
UcEval("#include \"B:/Unholy/Nowhere\"\n");
UcCheck("missing: names the .HC",UcDocHas("File not found: \"B:/Unholy/Nowhere.HC.Z\""),1);
UcCheck("missing: no .UC noise",UcDocHas("Nowhere.UC"),0);
//The non-DolDoc (boot-time) include path, briefly.
UcWrite("B:/Unholy/Raw.UC","I64 uc_raw=13;\n");
LBtr(&sys_run_level,RLf_DOC);
ExePrint("#include \"B:/Unholy/Raw\"\n");
LBts(&sys_run_level,RLf_DOC);
UcCheck("raw (boot) path falls back",UcEval("uc_raw"),13);
UcCheck("FILEMASK_JIT has .UC",FilesFindMatch("Foo.UC",FILEMASK_JIT),TRUE);
UcCheck("FILEMASK_SRC has .UH",FilesFindMatch("Foo.UH.Z",FILEMASK_SRC),TRUE);

////////////////////////////// demos
//(Separate statements: a command line lexes one token ahead.)
ExeFile("::/Demo/UnholyC/HelloHell.UC");
UcCheck("demo HelloHell",UcEval("hell_hello_done"),666);
UcCheck("demo HelloHell output",UcDocHas("Hello, Hell!"),1);
ExeFile("::/Demo/UnholyC/Backmasked.UC");
UcCheck("demo Backmasked",UcEval("backmasked_done"),666);
UcCheck("demo Backmasked output",UcDocHas("Remember to floss."),1);
ExeFile("::/Demo/UnholyC/UnlessUntil.UC");
UcCheck("demo UnlessUntil",UcEval("unless_until_done"),666);
UcCheck("demo UnlessUntil output",UcDocHas("DCLXVI"),1);
HfShot("demos");

HfPrint("SUMMARY pass=%d fail=%d\n",uc_pass,uc_fail);
if (uc_fail)
  hf_exit_code=1;
else
  hf_exit_code=0;
