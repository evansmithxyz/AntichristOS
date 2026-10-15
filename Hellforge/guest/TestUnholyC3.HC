//TestUnholyC3.HC: Unholy C in the editor and on screen.
//Needs the rebuilt Compiler.BIN.  Checks that the reindenter (Ctrl-S
//code tools, EF_REINDENT) understands unless/until/do..until, then opens
//terminal windows running the demos and a blasphemous snippet, and
//takes screenshots.
//forge.py run Hellforge/guest/TestUnholyC3.HC

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

U8 *UcReindent(U8 *src)
{//Reindent the fun in src the way the editor does; return the text.
  CDoc *doc=DocNew("B:/Reindent.UC");
  U8 *res;
  DocPrint(doc,"%s",src);
  DocGoToLine(doc,3);
  EdCodeTools2(doc,EF_REINDENT,FALSE);
  res=DocSave(doc);
  DocDel(doc);
  src=res;
  while (*src) {//Drop the editor cursor char.
    if (*src==CH_CURSOR)
      StrCpy(src,src+1);
    else
      src++;
  }
  return res;
}

U0 UcCheckReindent(U8 *name,U8 *src,U8 *want)
{
  U8 *got=UcReindent(src);
  if (!StrCmp(got,want)) {
    uc_pass++;
    HfPrint("PASS reindent %s\n",name);
  } else {
    uc_fail++;
    HfPrint("FAIL reindent %s\n--- got ---\n%s--- want ---\n%s---\n",
	  name,got,want);
  }
  Free(got);
}

UcCheckReindent("unless/until/do-until",
"U0 F(I64 x)\n"
"{\n"
"unless (x)\n"
"x=1;\n"
"else\n"
"x=2;\n"
"until (x>9)\n"
"x++;\n"
"do\n"
"x--;\n"
"until (x<3);\n"
"unless (x) {\n"
"until (x) {\n"
"x--;\n"
"}\n"
"} else unless (x>1)\n"
"x=0;\n"
"}\n",
"U0 F(I64 x)\n"
"{\n"
"  unless (x)\n"
"    x=1;\n"
"  else\n"
"    x=2;\n"
"  until (x>9)\n"
"    x++;\n"
"  do\n"
"    x--;\n"
"  until (x<3);\n"
"  unless (x) {\n"
"    until (x) {\n"
"      x--;\n"
"    }\n"
"  } else unless (x>1)\n"
"    x=0;\n"
"}\n");

UcCheckReindent("classic if/while/do-while",
"U0 G(I64 x)\n"
"{\n"
"if (x)\n"
"x=1;\n"
"while (x)\n"
"x--;\n"
"do\n"
"x++;\n"
"while (x<3);\n"
"}\n",
"U0 G(I64 x)\n"
"{\n"
"  if (x)\n"
"    x=1;\n"
"  while (x)\n"
"    x--;\n"
"  do\n"
"    x++;\n"
"  while (x<3);\n"
"}\n");

U0 UcShow(U8 *name,U8 *cmd,I64 ms=2500)
{//Open a terminal window, run cmd in it, screenshot, close it.
  CTask *task=User("%s\n",cmd);
  Sleep(ms);
  HfShot(name);
  Kill(task);
  Sleep(200);
}

UcShow("hellohell","#include \"::/Demo/UnholyC/HelloHell.UC\";");
UcShow("backmasked","#include \"::/Demo/UnholyC/Backmasked.UC\";");
UcShow("unlessuntil","#include \"::/Demo/UnholyC/UnlessUntil.UC\";");
UcShow("editor","Ed(\"::/Demo/UnholyC/UnlessUntil.UC\");",1500);
UcShow("blasphemy","\"Feeling lucky\\n\"; unless 666 \"oops\";");

HfPrint("SUMMARY pass=%d fail=%d\n",uc_pass,uc_fail);
if (uc_fail)
  hf_exit_code=1;
else
  hf_exit_code=0;
