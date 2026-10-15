//WS5: the alias examples from ::/Doc/UnholyC.DD and ::/Doc/HelloWorld.DD
//must compile and do what the docs say.  Needs the Unholy C keyword
//aliases in ::/Compiler/OpCodes.DD (WS1).  Before the merge, overlay them:
//  forge.py run Hellforge/guest/TestDocsExamples.HC
//	--add Hellforge/out/ws5ops/OpCodes.DD:/Compiler/OpCodes.DD
//The new keywords (unless, until, backwards) need the rebuilt compiler and
//are left to WS1's TestUnholyC2.HC.

I64 ex_bad=0;

#ifndef BEAST
#define BEAST 666
#endif

//---- Backmasked Keywords ----
U0 Countdown()
{
  I64 i;
  rof (i=6;i>0;i--) {
    fi (i==3)
      kaerb;
    esle
      "%d...",i;
  }
  "\nThe rest is silence.\n";
}

I64 Digits(I64 n=BEAST)
{//Prints the digits of n last-to-first.
  I64 cnt=0;
  elihw (n) {
    "%d",n%10;
    n/=10;
    cnt++;
  }
  '\n';
  nruter cnt;
}

//---- Heavy-Metal Keywords ----
#curse	CIRCLES	9

U8 *Sentence(I64 sin)
{
  legion (sin) {
    case 0:  sacrifice "Limbo";
    case 1:  sacrifice "Lust";
    case 2:  sacrifice "Gluttony";
    case 3...7: forsake;
  }
  sacrifice "Treachery";
}

U0 Bargain(I64 offer)
{
  tempt {
    fi (offer!=BEAST)
      throw('LowBall');
    "Deal.\n";
  } repent {
    "The Adversary does not haggle.\n";
    Fs->catch_except=TRUE;
  }
}

I64 abyss_depth;
U0 Abyss()
{
  I64 depth=0;
deeper:
  fi (++depth<CIRCLES)
    descend deeper;
  otherwise
    "You have reached the bottom: circle %d.\n",depth;
  abyss_depth=depth;
}

//---- HelloWorld.DD ----
U0 Niam()
{
  fi (TRUE)
    "Hello World\n";
  esle
    "dlroW olleH\n";
}

//---- #summon ----
//#exe runs at compile time, so the imp exists before it is summoned.
#exe {FileWrite("B:/Imp.HC","I64 imp=BEAST;\n",StrLen("I64 imp=BEAST;\n"));};
#summon "B:/Imp.HC"

U0 Expect(Bool ok,U8 *what)
{
  if (ok)
    HfPrint("EXOK %s\n",what);
  else {
    HfPrint("EXFAIL %s\n",what);
    ex_bad++;
  }
}

Countdown;
Expect(Digits==3,"Digits");
Expect(!StrCmp(Sentence(1),"Lust"),"Sentence(1)");
Expect(!StrCmp(Sentence(5),"Treachery"),"Sentence(5)");
Expect(!StrCmp(Sentence(66),"Treachery"),"Sentence(66)");
Bargain(BEAST);
Bargain(13);
Abyss;
Expect(abyss_depth==CIRCLES,"Abyss");
Niam;
Expect(imp==666,"summon");
I64 i=0,beast=0;
od beast=beast*10+6;
elihw (++i<3);
Expect(beast==BEAST,"od-elihw");
HfPrint("EX_BAD %d\n",ex_bad);
hf_exit_code=ex_bad;
