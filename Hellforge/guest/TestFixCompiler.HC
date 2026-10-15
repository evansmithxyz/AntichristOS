//TestFixCompiler.HC: regressions for the compiler-area review fixes.
//Needs the rebuilt Compiler.BIN and kernel (forge.py bootstrap --install).
//forge.py run Hellforge/guest/TestFixCompiler.HC
//  1 Extensionless #include/ExeFile on an unmounted drive: the exception
//    still reaches the caller, and the task is not left Silent.
//  2 ExtDftUC (AdamFile/PopUpFile) resolves a name like #include does.
//  3 backwards "..." initializes U8 arrays (JIT and AOT).
//  4 backwards/paren class meta strs outlive the code; union layouts.
//  5 ST_INT_NAMES fit the debugger's Fault line; '<' prompt hints.
//Exit code: number of failed checks.

I64 fc_pass=0,fc_fail=0;

U0 FcChk(U8 *name,I64 got,I64 want)
{
  if (got==want) {
    fc_pass++;
    HfPrint("PASS %s = %d\n",name,got);
  } else {
    fc_fail++;
    HfPrint("FAIL %s got %d want %d\n",name,got,want);
  }
}

U0 FcChkStr(U8 *name,U8 *got,U8 *want)
{
  if (got && !StrCmp(got,want)) {
    fc_pass++;
    HfPrint("PASS %s = \"%Q\"\n",name,got);
  } else {
    fc_fail++;
    HfPrint("FAIL %s got \"%Q\" want \"%Q\"\n",name,got,want);
  }
}

U0 FcWrite(U8 *name,U8 *src)
{
  FileWrite(name,src,StrLen(src));
}

Bool FcDocHas(CTask *task,U8 *needle)
{
  CDoc *doc;
  U8 *buf;
  Bool res=FALSE;
  if (TaskValidate(task) && (doc=DocPut(task))) {
    buf=DocSave(doc);
    if (StrMatch(needle,buf))
      res=TRUE;
    Free(buf);
  }
  return res;
}

//////// 1  uc-fallback-silent-leak
I64 fc_exc;

U0 FcSilentCase(U8 *name,U8 *code,I64 want_exc)
{//ExePutS(code); want_exc=-1 means "don't care".
  U8 *nm;
  Bool s;
  fc_exc=0;
  Silent(OFF);
  try
    ExePutS(code);
  catch {
    fc_exc=Fs->except_ch;
    Fs->catch_except=TRUE;
  }
  s=IsSilent;
  Silent(OFF);
  nm=MStrPrint("%s: not Silent after",name);
  FcChk(nm,s,0);
  Free(nm);
  if (want_exc!=-1) {
    nm=MStrPrint("%s: exception reaches caller ('Drv'=0x%X)",name,'Drv');
    FcChk(nm,fc_exc,want_exc);
    Free(nm);
  }
}

U8 fc_drv=0;
I64 i;
for (i='C';i<='Z' && !fc_drv;i++)
  if (!Let2Drv(i,FALSE))
    fc_drv=i;
HfPrint("unmounted drive: %c\n",fc_drv);
FcChk("found an unmounted drive letter",fc_drv!=0,1);

U8 *fc_code;
fc_code=MStrPrint("#include \"%c:/Nope\";",fc_drv);
FcSilentCase("extless #include X:/Nope",fc_code,'Drv');
Free(fc_code);
fc_code=MStrPrint("#include \"%c:/Nope.HC\";",fc_drv);
FcSilentCase("explicit #include X:/Nope.HC",fc_code,'Drv');
Free(fc_code);
fc_code=MStrPrint("ExeFile(\"%c:/Nope\");",fc_drv);
FcSilentCase("ExeFile(X:/Nope)",fc_code,'Drv');
Free(fc_code);
FcSilentCase("extless #include B:/FcNope (mounted, missing)",
	"#include \"B:/FcNope\";",-1);

//The .UC fallback itself still works.
DirMk("B:/FcUc");
FcWrite("B:/FcUc/Fb.UC","I64 fc_uc_fb=666;\n");
I64 fc_got=0;
try
  fc_got=ExePutS("#include \"B:/FcUc/Fb\";\nfc_uc_fb;");
catch {
  HfPrint("EXCEPT in .UC fallback\n");
  Fs->catch_except=TRUE;
}
FcChk(".UC fallback #include B:/FcUc/Fb",fc_got,666);
FcChk(".UC fallback: not Silent after",IsSilent,0);

//The same thing typed in a real User terminal: it must not go mute.
CTask *fc_user=User;
Sleep(300);
XTalk(fc_user,"#include \"%c:/Nope\";\n",fc_drv);
Sleep(1200);
XTalk(fc_user,"\"ALIVE%%d\\n\",6*111;\n");
Sleep(1500);
FcChk("User term: ALIVE666 shown after bad extless #include",
	FcDocHas(fc_user,"ALIVE666"),1);
FcChk("User term: Except shown",FcDocHas(fc_user,"Except"),1);
FcChk("User term: DISPLAYf_SILENT after",
	Bt(&fc_user->display_flags,DISPLAYf_SILENT),0);
Kill(fc_user);
Sleep(300);

//////// 2  uc-fallback-parent-dir-shadow (ExtDftUC)
U8 *FcRes()
{
  U8 *st=NULL;
  if (FileFind("B:/FcRes.TXT",,FUF_Z_OR_NOT_Z))
    st=FileRead("B:/FcRes.TXT");
  if (!st) st=StrNew("none");
  Del("B:/FcRes.TXT");
  return st;
}

U0 FcChkRes(U8 *name,U8 *want)
{
  U8 *st=FcRes;
  FcChkStr(name,st,want);
  Free(st);
}

Bool FcEndsWith(U8 *st,U8 *tail)
{
  I64 l=StrLen(st),l2=StrLen(tail);
  return l>=l2 && !StrCmp(st+l-l2,tail);
}

DirMk("B:/FcPar");
DirMk("B:/FcPar/Sub");
FcWrite("B:/FcPar/Pick.HC","FileWrite(\"B:/FcRes.TXT\",\"parentHC\",8);\n");
FcWrite("B:/FcPar/Sub/Pick.UC","FileWrite(\"B:/FcRes.TXT\",\"subUC\",5);\n");
FcWrite("B:/FcPar/Sub/Only.UC","FileWrite(\"B:/FcRes.TXT\",\"onlyUC\",6);\n");
Del("B:/FcRes.TXT");

U8 *fc_e=ExtDftUC("B:/FcPar/Sub/Pick");
HfPrint("ExtDftUC(B:/FcPar/Sub/Pick)=%s\n",fc_e);
FcChk("ExtDftUC: a parent .HC wins, as for #include",
	FcEndsWith(fc_e,"/FcPar/Sub/Pick.HC.Z"),1);
Free(fc_e);
fc_e=ExtDftUC("B:/FcPar/Sub/Only");
HfPrint("ExtDftUC(B:/FcPar/Sub/Only)=%s\n",fc_e);
FcChk("ExtDftUC: .UC when no .HC anywhere",
	FcEndsWith(fc_e,"/FcPar/Sub/Only.UC.Z"),1);
Free(fc_e);

try ExePutS("#include \"B:/FcPar/Sub/Pick\";");
catch Fs->catch_except=TRUE;
FcChkRes("#include B:/FcPar/Sub/Pick","parentHC");
AdamFile("B:/FcPar/Sub/Pick",FALSE);
FcChkRes("AdamFile(B:/FcPar/Sub/Pick) runs the same file","parentHC");
AdamFile("B:/FcPar/Sub/Only",FALSE);
FcChkRes("AdamFile(B:/FcPar/Sub/Only)","onlyUC");

Cd("B:/FcPar/Sub");
fc_e=ExtDftUC("Pick");
FcChkStr("ExtDftUC(rel) keeps cur_dir",Fs->cur_dir,"/FcPar/Sub");
Free(fc_e);
Cd("B:/");

//////// 3  backwards-u8-array-init (JIT)
U8 fc_res[16];

U0 FcJit(U8 *name,U8 *code,U8 *want,I64 n)
{//Run code, which fills fc_res; compare n bytes with want.
  U8 *nm;
  Bool ok=FALSE;
  MemSet(fc_res,0xEE,sizeof(fc_res));
  try {
    ExePutS(code);
    ok=TRUE;
  } catch {
    HfPrint("EXCEPT in %s\n",name);
    Fs->catch_except=TRUE;
  }
  nm=MStrPrint("JIT %s",name);
  if (ok && !MemCmp(fc_res,want,n)) {
    fc_pass++;
    HfPrint("PASS %s\n",nm);
  } else {
    fc_fail++;
    HfPrint("FAIL %s got %02X %02X %02X %02X %02X\n",nm,
	  fc_res[0],fc_res[1],fc_res[2],fc_res[3],fc_res[4]);
  }
  Free(nm);
}

FcJit("glbl U8 [4]=backwards",
	"U8 fc_g4[4]=backwards \"cba\";MemCpy(fc_res,fc_g4,4);","abc",4);
FcJit("control glbl U8 [4]=plain",
	"U8 fc_c4[4]=\"abc\";MemCpy(fc_res,fc_c4,4);","abc",4);
FcJit("static U8 [4]=backwards",
	"U8 *FcS4() {static U8 s[4]=backwards \"cba\"; return s;}"
	"MemCpy(fc_res,FcS4,4);","abc",4);
FcJit("class member U8 [4]=backwards",
	"class CFcBk {U8 n[4]; I64 x;}; CFcBk fc_cm={backwards \"cba\",5};"
	"MemCpy(fc_res,fc_cm.n,4);fc_res[4]=fc_cm.x;","abc\0\x05",5);
FcJit("2-D {backwards,plain}",
	"U8 fc_2d[2][4]={backwards \"cba\",\"def\"};MemCpy(fc_res,fc_2d,8);",
	"abc\0def",8);
FcJit("backwards backwards",
	"U8 fc_bb[4]=backwards backwards \"abc\";MemCpy(fc_res,fc_bb,4);",
	"abc",4);
FcJit("U8 [2]=backwards \"x\" (not a ptr byte)",
	"U8 fc_one[2]=backwards \"x\";MemCpy(fc_res,fc_one,2);","x",2);
FcJit("concatenated strs",
	"U8 fc_cat[7]=backwards \"fed\" \"cba\";MemCpy(fc_res,fc_cat,7);",
	"abcdef",7);
FcJit("U8 *=backwards (ptr)",
	"U8 *fc_p=backwards \"cba\";StrCpy(fc_res,fc_p);","abc",4);
FcJit("dft arg backwards",
	"U8 *FcDft(U8 *s=backwards \"cba\") {return s;}StrCpy(fc_res,FcDft);",
	"abc",4);
FcJit("expression backwards",
	"StrCpy(fc_res,backwards \"olleh\");","hello",6);

DocClear;
try ExePutS("U8 fc_bad[4]=backwards 5;");
catch Fs->catch_except=TRUE;
U8 *fc_doc=DocSave(DocPut);
FcChk("backwards 5 still an error",
	ToBool(StrMatch("Expecting string after 'backwards'",fc_doc)),1);
Free(fc_doc);
FcChk("backwards 5: not Silent after",IsSilent,0);

//////// 3b  backwards-u8-array-init (AOT)
U8 *fc_aot_hdr=
	"#include \"::/Kernel/KernelA.HH\"\n"
	"#include \"::/Compiler/CompilerA.HH\"\n"
	"#exe {Option(OPTf_EXTERNS_TO_IMPORTS,ON);};\n"
	"#include \"::/Kernel/KernelB.HH\"\n"
	"#include \"::/Kernel/KernelC.HH\"\n"
	"#exe {Option(OPTf_EXTERNS_TO_IMPORTS,OFF);};\n";
U8 *fc_aot_body=
	"U8 fa_g[4]=backwards \"cba\";\n"
	"U8 *FaS() {static U8 s[4]=backwards \"cba\"; return s;}\n"
	"class CFa {U8 n[4]; I64 x;};\n"
	"CFa fa_c={backwards \"cba\",5};\n"
	"U8 *fa_p=backwards \"cba\";\n"
	"U8 fa_c4[4]=\"abc\";\n"
	"U8 fa_out[64];\n"
	"StrPrint(fa_out,\"%s|%s|%s,%d|%s|%s\",fa_g,FaS,fa_c.n,fa_c.x,fa_p,fa_c4);\n"
	"FileWrite(\"B:/FcAot/Res.TXT\",fa_out,StrLen(fa_out));\n";
I64 fc_errs=-1;
DirMk("B:/FcAot");
fc_code=MStrPrint("%s%s",fc_aot_hdr,fc_aot_body);
FcWrite("B:/FcAot/Bk.PRJ",fc_code);
Free(fc_code);
DocClear;
try
  fc_errs=Cmp("B:/FcAot/Bk.PRJ");
catch {
  HfPrint("EXCEPT in Cmp\n");
  Fs->catch_except=TRUE;
}
fc_doc=DocSave(DocPut);
FcChk("AOT Cmp errs",fc_errs,0);
FcChk("AOT KernelA.HH: no Assert Failed",
	ToBool(StrMatch("Assert Failed",fc_doc)),0);
Free(fc_doc);
if (!fc_errs) {
  try
    Load("B:/FcAot/Bk.BIN");
  catch {
    HfPrint("EXCEPT in Load\n");
    Fs->catch_except=TRUE;
  }
  fc_code=FileRead("B:/FcAot/Res.TXT");
  FcChkStr("AOT glbl|static|class,x|ptr|control",fc_code,
	"abc|abc|abc,5|abc|abc");
  Free(fc_code);
}

//////// 4  backwards-class-meta-uaf, and union layouts
ExePutS(
	"class CFcMeta {\n"
	"  I64 a format backwards \"cba\";\n"
	"  I64 b format \"plain\";\n"
	"  I64 c format (\"paren\");\n"
	"  I64 d format backwards \"\\n!dlroW ,olleH\";\n"
	"  I64 e dft_val 6/2 percentile 54.20;\n"
	"};\n");
CHashClass *fc_hc=HashFind("CFcMeta",Fs->hash_table,HTT_CLASS);
U8 *fc_blk[256];
FcChk("class CFcMeta defined",fc_hc!=NULL,1);
if (fc_hc) {
  for (i=0;i<256;i++) {//Churn the code heap the dead JIT code lived in.
    fc_blk[i]=MAlloc(16+(i&63)*8,Fs->code_heap);
    MemSet(fc_blk[i],'Z',16+(i&63)*8);
  }
  FcChkStr("meta format backwards",
	MemberMetaData("format",MemberFind("a",fc_hc)),"abc");
  FcChkStr("meta format plain",
	MemberMetaData("format",MemberFind("b",fc_hc)),"plain");
  FcChkStr("meta format (paren)",
	MemberMetaData("format",MemberFind("c",fc_hc)),"paren");
  FcChkStr("meta format backwards long",
	MemberMetaData("format",MemberFind("d",fc_hc)),"Hello, World!\n");
  FcChk("meta backwards is MLMF_IS_STR",
	MemberMetaFind("format",MemberFind("a",fc_hc))->flags&MLMF_IS_STR,
	MLMF_IS_STR);
  FcChk("meta dft_val 6/2",MemberMetaData("dft_val",MemberFind("e",fc_hc)),3);
  FcChk("meta percentile*100",ToI64(MemberMetaData("percentile",
	MemberFind("e",fc_hc))(F64)*100+0.5),5420);
  for (i=0;i<256;i++)
    Free(fc_blk[i]);
}

ExePutS(
	"class CFcJ {I64 a; union {U8 c[7]; I64 d;}; I64 e;};\n"
	"class CFcK {I64 a format \"x\"; union {U8 c[3]; I64 d;};"
	"  U8 f[5] format backwards \"zy\"; I64 g;};\n");
FcChk("CFcJ.d offset",ExePutS("offset(CFcJ.d);"),8);
FcChk("CFcJ.e offset",ExePutS("offset(CFcJ.e);"),16);
FcChk("sizeof(CFcJ)",ExePutS("sizeof(CFcJ);"),24);
FcChk("CFcK.f offset",ExePutS("offset(CFcK.f);"),16);
FcChk("CFcK.g offset",ExePutS("offset(CFcK.g);"),21);
FcChk("sizeof(CFcK)",ExePutS("sizeof(CFcK);"),29);
fc_hc=HashFind("CFcK",Fs->hash_table,HTT_CLASS);
if (fc_hc)
  FcChkStr("CFcK.f meta format backwards",
	MemberMetaData("format",MemberFind("f",fc_hc)),"yz");
FcChk("boot sizeof(CIntermediateCode)",sizeof(CIntermediateCode),232);
FcChk("boot CIntermediateCode.ic_body",offset(CIntermediateCode.ic_body),101);

//////// 5  dbg-fault-line-wraps and the '<' prompt hints
I64 fc_long=0;
U8 *fc_st;
FcChk("ST_INT_NAMES count",DefineCnt("ST_INT_NAMES"),51);
for (i=0;i<DefineCnt("ST_INT_NAMES");i++) {
  fc_st=DefineSub(i,"ST_INT_NAMES");
  if (StrLen(fc_st)>36) {
    HfPrint("too long for the Fault line (%d): %s\n",StrLen(fc_st),fc_st);
    fc_long++;
  }
}
FcChk("ST_INT_NAMES longer than 36 chars",fc_long,0);
FcChkStr("General Protection name",DefineSub(13,"ST_INT_NAMES"),
	"General Protection (Holy Water)");

Bool FcKernelHas(U8 *needle)
{//Search the running kernel image.
  U8 *kbase=mem_boot_base-sizeof(CBinFile),*ptr;
  I64 size=kbase(CBinFile *)->file_size,len=StrLen(needle);
  for (ptr=kbase;ptr+len<=kbase+size;ptr++)
    if (!MemCmp(ptr,needle,len))
      return TRUE;
  return FALSE;
}
FcChk("Fault banner says <Help;",
	FcKernelHas("<Help;\t//For help.  The power of Help compels you."),1);
FcChk("Fault banner no longer says >Help;",
	FcKernelHas(">Help;\t//For help.  The power of Help compels you."),0);

fc_st=FileRead("::/Adam/DolDoc/DocCodeTools.HC");
FcChk("editor menu: Reindent Unholy C Fun",
	ToBool(StrMatch("Reindent Unholy C Fun",fc_st)),1);
Free(fc_st);

HfPrint("TestFixCompiler pass=%d fail=%d\n",fc_pass,fc_fail);
hf_exit_code=fc_fail;
