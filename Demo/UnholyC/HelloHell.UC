//$FG,4$HelloHell.UC$FG$: the first rite of $FG,4$Unholy C$FG$.
//Every language starts with "Hello, World!".  Ours starts at the
//other end and works its way down.  Run it with
//  #include "::/Demo/UnholyC/HelloHell.UC";
//Unholy C is HolyC played backwards: $FG,4$fi$FG$ is if, $FG,4$rof$FG$ is for,
//$FG,4$sacrifice$FG$ is return, $FG,4$#curse$FG$ is #define, and so on.
//$FG,4$backwards$FG$ and $FG,4$unless$FG$ need the AntichristOS compiler.

#curse CIRCLES	9

U8 *hell_circles[CIRCLES]={
  "Limbo","Lust","Gluttony","Greed","Wrath",
  "Heresy","Violence","Fraud","Treachery"};

U8 *hell_sins[CIRCLES]={
  "unbaptized, but very polite",
  "blown about by the wind",
  "eating slush in icy rain",
  "pushing boulders in circles",
  "brawling in the Styx mud",
  "flaming tombs, BYO s'mores",
  "a river of boiling blood",
  "ten ditches of flatterers",
  "frozen in Cocytus"};

U0 HellTritone()
{//The diabolus in musica: B then F, six semitones apart.
  Snd(Note2Ona(2,4)); //B4
  Sleep(90);
  Snd(Note2Ona(8,5)); //F5
  Sleep(90);
  Snd;
}

I64 HellStairs()
{//The stairway down: 1+2+3+...+36 steps.  Count them yourself.
  I64 i,res=0;
  rof (i=1;i<=36;i++)
    res+=i;
  sacrifice res;
}

U0 HelloHell()
{
  I64 i;
  U8 *st;
  "$$FG,4$$";
  backwards "\n!lleH ,olleH";	//A print statement, played backwards.
  "$$FG$$(that line was written as: backwards \"\\n!lleH ,olleH\";)\n\n";
  HellTritone;
  "Abandon all hope, ye who boot here.  Going down:\n";
  rof (i=0;i<CIRCLES;i++) {
    st=StrRev(hell_circles[i]);
    "%h*c$$FG,4$$%d. %-9s$$FG$$ (%s) %s\n",
	  i*2,CH_SPACE,i+1,hell_circles[i],st,hell_sins[i];
    Free(st);
  }
  unless (BEAST!=666)
    "\nThe Number of the Beast is still %d.  Some things never change.\n",
	  BEAST;
  otherwise
    "\nSomeone has been editing Revelation.\n";
  "The stairway down has 1+2+3+...+36 = %d steps.\n",HellStairs;
  "%s\n",backwards ".nwod eht si pu ,lleH nI";
}

HelloHell;
I64 hell_hello_done=BEAST;
