//TestUnholyC.HC: Unholy C keyword ALIASES on the OLD (stock) compiler.
//The aliases come from ::/Compiler/OpCodes.DD at boot, so no rebuild.
//It writes Unholy C sources to the RAM drive B:, compiles them
//with ExeFile(), and checks every alias.  Also checks Adam/UnholyC.HC.
//forge.py run Hellforge/guest/TestUnholyC.HC

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

U0 UcWrite(U8 *name,U8 *src)
{
  FileWrite(name,src,StrLen(src));
}

I64 UcEval(U8 *exp)
{//Compile+run one expression in this task, return its value.
  I64 res=-0x666;
  try
    res=ExePrint("%s;",exp);
  catch {
    HfPrint("EXCEPT in UcEval(%s)
",exp);
    Fs->catch_except=TRUE;
  }
  return res;
}

//Standard-spelled twin of the start:/end: sub-switch in Rites.UC.
I64 TwinStartEnd(I64 n)
{
  I64 r=0;
  switch (n) {
    case 0: r=5; break;
    start:
      r=100;
      case 1: r+=1; break;
      case 2: r+=2; break;
    end:
      r+=1000;
      break;
  }
  return r;
}

DirMk("B:/Unholy");

//A header, pulled in with both #summon and #edulcni.
UcWrite("B:/Unholy/Pit.UH",
"#curse PIT_DEPTH 9\n"
"#enifed PIT_FIRE 666\n"
"I64 PitCircles() { sacrifice PIT_DEPTH; }\n");

UcWrite("B:/Unholy/Gate.UH",
"#fednfi GATE_ONCE\n"
"#enifed GATE_ONCE 1\n"
"I64 gate_cnt=0;\n"
"#fidne\n"
"gate_cnt++;\n");

UcWrite("B:/Unholy/Rites.UC",
"//Unholy C rites, every keyword played backwards.\n"
"#summon \"B:/Unholy/Pit.UH\"\n"
"#edulcni \"B:/Unholy/Gate.UH\"\n"
"#edulcni \"B:/Unholy/Gate.UH\"\n"
"#enifed GATES 3\n"
"#fedfi GATES\n"
"I64 pp_fedfi=GATES;\n"
"#fidne\n"
"#fednfi NO_SUCH_GATE\n"
"I64 pp_fednfi=7;\n"
"#fidne\n"
"#fi GATES==3\n"
"I64 pp_fi=1;\n"
"#esle\n"
"I64 pp_fi=2;\n"
"#fidne\n"
"#tressa GATES==3\n"
"ssalc CSoul { I64 sins; I64 virtue; };\n"
"noinu UBeast { I64 i; U8 b[8]; };\n"
"I64 Fi(I64 x) { fi (x>3) nruter 1; esle nruter 2; }\n"
"I64 Elihw(I64 n) { I64 s=0; elihw (n>0) { s+=n; n--; fi (s>40) kaerb; } nruter s; }\n"
"I64 Od(I64 n) { I64 s=0; od { s++; n--; } elihw (n>0); nruter s; }\n"
"I64 Rof(I64 n) { I64 i,s=0; rof (i=0;i<n;i++) s+=i; nruter s; }\n"
"I64 Hctiws(I64 n) {\n"
"  hctiws (n) {\n"
"    esac 1: nruter 10;\n"
"    esac 2: nruter 20;\n"
"    tluafed: nruter 99;\n"
"  }\n"
"}\n"
"I64 StartEnd(I64 n) {\n"
"  I64 r=0;\n"
"  hctiws (n) {\n"
"    esac 0: r=5; kaerb;\n"
"    trats:\n"
"      r=100;\n"
"      esac 1: r+=1; kaerb;\n"
"      esac 2: r+=2; kaerb;\n"
"    dne:\n"
"      r+=1000;\n"
"      kaerb;\n"
"  }\n"
"  nruter r;\n"
"}\n"
"I64 Yrt() {\n"
"  I64 r=0;\n"
"  yrt { throw('Beast'); r=1; }\n"
"  hctac { fi (Fs->except_ch=='Beast') r=666; Fs->catch_except=TRUE; }\n"
"  nruter r;\n"
"}\n"
"I64 Tempt() {\n"
"  I64 r=0;\n"
"  tempt { throw('Snake'); }\n"
"  repent { r=7; Fs->catch_except=TRUE; }\n"
"  sacrifice r;\n"
"}\n"
"I64 Legion(I64 n) {\n"
"  legion (n) {\n"
"    esac 6: sacrifice 6;\n"
"    tluafed: forsake;\n"
"  }\n"
"  sacrifice 0;\n"
"}\n"
"I64 Forsake() { I64 i; rof (i=0;i<100;i++) fi (i==13) forsake; sacrifice i; }\n"
"I64 Descend(I64 n) { I64 r=0; fi (n) descend hell; r=1; hell: r+=10; sacrifice r; }\n"
"I64 Otog(I64 n) { fi (n) otog limbo; nruter 1; limbo: nruter 2; }\n"
"I64 Otherwise(I64 x) { fi (x) sacrifice 1; otherwise sacrifice 2; }\n"
"I64 Foezis() { nruter foezis(CSoul)+foezis(UBeast); }\n"
"I64 Tesffo() { nruter tesffo(CSoul.virtue); }\n"
"I64 Citats() { citats I64 cnt=0; nruter ++cnt; }\n"
"I64 kcol_glbl=0;\n"
"I64 Kcol() { kcol {kcol_glbl++;} nruter kcol_glbl; }\n"
"I64 Denifed() { nruter denifed(Fi)*10+denifed(NoSuchSoulEver); }\n"
"cilbup I64 Cilbup() { nruter 25; }\n"
"nretxe I64 Late();\n"
"I64 UseLate() { nruter Late; }\n"
"I64 Late() { nruter 13; }\n"
"msa {\n"
"_UNHOLY_SIX::\n"
"  MOV RAX,666\n"
"  RET\n"
"}\n"
"_extern _UNHOLY_SIX I64 UnholySix();\n"
"U8 *ClassOf(U8 *p,U8 *cls=ssalctsal) { no_warn p; nruter cls; }\n"
"I64 Ssalctsal() { CSoul s; nruter !StrCmp(ClassOf(&s),\"CSoul\"); }\n"
"I64 rites_done=BEAST;\n");

ExeFile("B:/Unholy/Rites.UC");

UcCheck("compiled (rites_done)",UcEval("rites_done"),666);
UcCheck("#summon #curse sacrifice",UcEval("PitCircles"),9);
UcCheck("#enifed in header",UcEval("PIT_FIRE"),666);
UcCheck("#edulcni twice, #fednfi guard",UcEval("gate_cnt"),2);
UcCheck("#fedfi #fidne",UcEval("pp_fedfi"),3);
UcCheck("#fednfi",UcEval("pp_fednfi"),7);
UcCheck("#fi #esle",UcEval("pp_fi"),1);
UcCheck("fi true",UcEval("Fi(5)"),1);
UcCheck("esle",UcEval("Fi(2)"),2);
UcCheck("elihw kaerb",UcEval("Elihw(10)"),45);
UcCheck("elihw",UcEval("Elihw(4)"),10);
UcCheck("od elihw",UcEval("Od(5)"),5);
UcCheck("od elihw runs once",UcEval("Od(0)"),1);
UcCheck("rof",UcEval("Rof(10)"),45);
UcCheck("hctiws esac",UcEval("Hctiws(2)"),20);
UcCheck("hctiws tluafed",UcEval("Hctiws(7)"),99);
UcCheck("trats dne (0)",UcEval("StartEnd(0)"),TwinStartEnd(0));
UcCheck("trats dne (1)",UcEval("StartEnd(1)"),TwinStartEnd(1));
UcCheck("trats dne (2)",UcEval("StartEnd(2)"),TwinStartEnd(2));
UcCheck("yrt hctac",UcEval("Yrt"),666);
UcCheck("tempt repent",UcEval("Tempt"),7);
UcCheck("legion",UcEval("Legion(6)"),6);
UcCheck("legion forsake",UcEval("Legion(1)"),0);
UcCheck("forsake",UcEval("Forsake"),13);
UcCheck("descend",UcEval("Descend(1)"),10);
UcCheck("no descend",UcEval("Descend(0)"),11);
UcCheck("otog",UcEval("Otog(1)"),2);
UcCheck("otherwise",UcEval("Otherwise(0)"),2);
UcCheck("ssalc noinu foezis",UcEval("Foezis"),24);
UcCheck("tesffo",UcEval("Tesffo"),8);
UcEval("Citats");
UcCheck("citats",UcEval("Citats"),2);
UcCheck("kcol",UcEval("Kcol"),1);
UcCheck("denifed",UcEval("Denifed"),10);
UcCheck("cilbup",UcEval("Cilbup"),25);
UcCheck("nretxe",UcEval("UseLate"),13);
UcCheck("msa",UcEval("UnholySix"),666);
UcCheck("ssalctsal",UcEval("Ssalctsal"),1);

//The aliases also work right here in this (plain .HC) test file.
I64 UcHere(I64 x)
{
  fi (x==BEAST) sacrifice 1;
  otherwise sacrifice 0;
}
UcCheck("aliases in this file",UcHere(666)+UcHere(7),1);

//The new keywords need the rebuilt compiler.  On the stock one
//"unless" is just a bad expression: a clean compile error, no crash.
HfPrint("INFO unless: %d (5 with the new compiler, 0 on the stock one)\n",
	UcEval("I64 uc_r=0; unless (0) uc_r=5; uc_r"));

//Adam/UnholyC.HC, compiled at boot.
U8 *uc_st=StrRev("god");
UcCheck("StrRev god",!StrCmp(uc_st,"dog"),1);
Free(uc_st);
uc_st=StrRev("");
UcCheck("StrRev empty",StrLen(uc_st),0);
Free(uc_st);
uc_st=StrRev("lived");
UcCheck("StrRev lived",!StrCmp(uc_st,"devil"),1);
Free(uc_st);
UcCheck("BEAST",BEAST,666);
Backmask("!dlroW ,olleH\n.dooG eht no daeR\n");
Backmask("%d :tsaeB eht fo rebmuN ehT\n!$$$$$$ ylno luos ruoY\n",BEAST);

HfPrint("SUMMARY pass=%d fail=%d\n",uc_pass,uc_fail);
HfShot("rites");
if (uc_fail)
  hf_exit_code=1;
else
  hf_exit_code=0;
