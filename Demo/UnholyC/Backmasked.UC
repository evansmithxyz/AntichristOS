//$FG,4$Backmasked.UC$FG$: a whole program with every keyword played backwards.
//
//In the 1980s people played rock records backwards, hunting for hidden
//messages.  This is a complete Unholy C program written the same way.
//The compiler does not mind: each reversed keyword is one more line in
//::/Compiler/OpCodes.DD that points at the OLD keyword number, e.g.
//  KEYWORD fi 6;  (6 is "if")
//so it even runs on the stock compiler.  Cheat sheet:
//  $FG,4$fi$FG$=if  $FG,4$esle$FG$=else  $FG,4$rof$FG$=for  $FG,4$elihw$FG$=while  $FG,4$od$FG$=do
//  $FG,4$nruter$FG$=return  $FG,4$kaerb$FG$=break  $FG,4$hctiws$FG$=switch  $FG,4$esac$FG$=case
//  $FG,4$tluafed$FG$=default  $FG,4$trats$FG$/$FG,4$dne$FG$=start/end  $FG,4$ssalc$FG$=class
//  $FG,4$yrt$FG$=try  $FG,4$hctac$FG$=catch  $FG,4$#enifed$FG$=#define  $FG,4$citats$FG$=static
//  $FG,4$foezis$FG$=sizeof
//Run it with  #include "::/Demo/UnholyC/Backmasked.UC";

#enifed TRACKS		7
#enifed RPM		33

//What kind of evil is pressed into each groove.
#enifed K_MESSAGE	0 //A hidden message (played backwards).
#enifed K_SEMORDNILAP	1 //A word that is another word backwards.
#enifed K_PALINDROME	2 //Says the same thing both ways.
#enifed K_SCRATCH	3 //The needle skips.

ssalc CTrack
{
  U8 *title;
  U8 *groove; //What is cut into the vinyl.  Forwards: gibberish.
  I64 kind;
};

CTrack bm_album[TRACKS]={
  {"Stairway to Somewhere",	".ssolf ot rebmemeR",K_MESSAGE},
  {"Number Nine, Number Nine",	".nam daed ,no em nruT",K_MESSAGE},
  {"Desserts of Babylon",	"stressed",K_SEMORDNILAP},
  {"Lived Fast",		"lived",K_SEMORDNILAP},
  {"Highway to Hull",		"kssshhhkkkk",K_SCRATCH},
  {"Oscillate",			"Satan, oscillate my metallic sonatas",
	K_PALINDROME},
  {"(Hidden Track)",		".seirrow ehS .rehtom ruoy llaC",K_MESSAGE}
};

U0 BmPlayBackwards(U8 *groove)
{//Start at the end of the groove and drop the needle in reverse.
  I64 i=StrLen(groove);
  elihw (i--)
    '' groove[i];
}

Bool BmIsLetter(U8 ch)
{
  nruter 'A'<=ToUpper(ch)<='Z';
}

Bool BmIsPalindrome(U8 *st)
{//Same both ways, ignoring case, spaces and punctuation.
  I64 i=0,j=StrLen(st)-1;
  elihw (i<j) {
    fi (!BmIsLetter(st[i]))
      i++;
    esle fi (!BmIsLetter(st[j]))
      j--;
    esle fi (ToUpper(st[i++])!=ToUpper(st[j--]))
      nruter FALSE;
  }
  nruter TRUE;
}

U0 BmSpin()
{//Spin up to speed.  An od..elihw loop, for the purists.
  citats I64 total_turns=0;
  I64 turns=0;
  od {
    turns++;
    total_turns++;
  } elihw (turns<RPM);
  fi (total_turns==RPM*TRACKS)
    "$$FG,3$$(The turntable has turned %d times.  It is getting dizzy.)$$FG$$\n",
	  total_turns;
}

U0 Backmasked()
{
  I64 i,found=0,scratches=0;
  U8 *st;
  CTrack *t;
  "$$FG,4$$THE SATANIC PANIC RECORD PLAYER$$FG$$\n";
  "%d tracks at %d RPM, %d bytes of sleeve notes per track.\n\n",
	TRACKS,RPM,foezis(CTrack);
  rof (i=0;i<TRACKS;i++) {
    t=&bm_album[i];
    "$$FG,1$$Track %d: %s$$FG$$\n",i+1,t->title;
    "  Forward : %s\n",t->groove;
    yrt {
      hctiws (t->kind) {
	trats:
	  "  Backward: $$FG,4$$";
	  esac K_MESSAGE:
	    BmPlayBackwards(t->groove);
	    kaerb;
	  esac K_SEMORDNILAP:
	    st=StrRev(t->groove);
	    "%s$$FG$$  (Coincidence?  Yes.)",st;
	    Free(st);
	    kaerb;
	  esac K_PALINDROME:
	    BmPlayBackwards(t->groove);
	    fi (BmIsPalindrome(t->groove))
	      "$$FG$$  (Same both ways.)";
	    kaerb;
	dne:
	  "$$FG$$\n";
	  found++;
	  kaerb;
	esac K_SCRATCH:
	  throw('Scratch');
	tluafed:
	  "  (silence)\n";
      }
    } hctac {
      fi (Fs->except_ch=='Scratch') {
	"  Backward: $$FG,4$$*SCRITCH*$$FG$$ The needle skipped.  Blame the cat.\n";
	scratches++;
	Fs->catch_except=TRUE;
      }
    }
    BmSpin;
  }
  "\n$$FG,4$$Hidden messages found: %d.  Scratches: %d.$$FG$$\n",found,scratches;
  "Conclusion: the Devil mostly wants you to floss and call your mother.\n";
}

Backmasked;
I64 backmasked_done=BEAST;
